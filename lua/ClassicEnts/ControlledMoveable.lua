// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts\ControlledMoveable.lua
// - Dragon

Script.Load("lua/ScriptActor.lua")
Script.Load("lua/PathingMixin.lua")
Script.Load("lua/ObstacleMixin.lua")
Script.Load("lua/Mixins/ModelMixin.lua")
Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/ClassicEnts/ScaleModelMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")
Script.Load("lua/ClassicEnts/GameWorldMixin.lua")

class 'ControlledMoveable' (ScriptActor)

ControlledMoveable.kMapName = "controlled_moveable"

ControlledMoveable.kDefaultDoor = "models/misc/door/door.model"
ControlledMoveable.kDefaultDoorClean = "models/misc/door/door_clean.model"
ControlledMoveable.kDefaultAnimationGraph = "models/misc/door/door.animation_graph"
ControlledMoveable.kObjectTypes = enum( {'Door', 'Elevator', 'Gate'} )

local kUpdateAutoOpenRate = 0.3

//These objects support basic interations/triggering, but not pausing once started.  
//Doors open/close automatically, are enabled/disabled accordingly when triggered.
//Elevators pause for a short period at each waypoint before continuing.  Triggering an elevator causes it to move.
//Gates work just like doors, however they do not open/close automatically.  Gates are moved on trigger.

local networkVars = 
{
	moving = "boolean",
	destination = "vector",
	objectType = "enum ControlledMoveable.kObjectTypes",
	open = "boolean"
}

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ModelMixin, networkVars)
AddMixinNetworkVars(ObstacleMixin, networkVars)
AddMixinNetworkVars(ScaleModelMixin, networkVars)
AddMixinNetworkVars(ControlledMixin, networkVars)

local function UpdateAutoOpen(self, timePassed)
  
    if self:GetIsEnabled() then
    
        local desiredOpenState = false
		
		local entities = Shared.GetEntitiesWithTagInRange("Door", self:GetOrigin(), DoorMixin.kMaxOpenDistance)
		for i = 1, #entities do
   
            local entity = entities[i]
			if entity then
				local opensForEntity, openDistance = entity:GetCanDoorInteract(self)
				
				if opensForEntity then
				
					local distSquared = self:GetDistanceSquared(entity)
					if (not HasMixin(entity, "Live") or entity:GetIsAlive()) and entity:GetIsVisible() and distSquared < (openDistance * openDistance) then
					
						desiredOpenState = true
						break
					
					end
				
				end
			end
            
        end
        
        if desiredOpenState and not self:GetIsOpen() then
			self:MoveToWaypoint()
        elseif not desiredOpenState and self:GetIsOpen() then
			self:MoveToWaypoint(0)
        end
        
    end
    
    return true

end

function ControlledMoveable:OnCreate() 

    ScriptActor.OnCreate(self)
	
	InitMixin(self, BaseModelMixin)
    InitMixin(self, ModelMixin)
	InitMixin(self, PathingMixin)
	InitMixin(self, SignalListenerMixin)
	InitMixin(self, ObstacleMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	self.moving = false
	self.speed = 10
	self.objectType = ControlledMoveable.kObjectTypes.Gate
	self.destination = Vector(0, 0, 0)
	self.waypoint = -1
	self.open = false
	self.registeredPlayers = { }
	
end

function ControlledMoveable:OnInitialized()

    ScriptActor.OnInitialized(self)
	
	InitMixin(self, ControlledMixin)
	
	if Server then
	
		InitMixin(self, EEMMixin)
		
		if not self.model then
			Shared.Message(string.format("No model provided for moveable %s.", self.name))
		end
		
		self.modelName = self.model
        
        if self.modelName ~= nil then
			//These can get re-created midgame, check for precached model
			if Shared.GetModelIndex(self.modelName) == 0 and GetFileExists(self.modelName) then
				Shared.PrecacheModel(self.modelName)
			end
			if self.animationGraph ~= nil and self.animationGraph ~= "" then
				if Shared.GetAnimationGraphIndex(self.animationGraph) == 0 and GetFileExists(self.animationGraph) then
					Shared.PrecacheAnimationGraph(self.animationGraph)
				end
			else
				self.animationGraph = nil
			end
            self:SetModel(self.modelName, self.animationGraph)
        end

		if self.objectType == ControlledMoveable.kObjectTypes.Door then
			self:AddTimedCallback(UpdateAutoOpen, kUpdateAutoOpenRate)	
		end
		
		AddPathingWaypoint(self.name, "home", self:GetOrigin(), 0, self:GetId())

		if self.open then
			self:AddTimedCallback(function(self) self:MoveToWaypoint(1) end, 1)
		end
		
	end
	
	self:SetPhysicsType(PhysicsType.Kinematic)
	self.initialOpenState = self.open
	self:SetLagCompensated(true)
	InitMixin(self, ScaleModelMixin)
	InitMixin(self, GameWorldMixin)
	
end

function ControlledMoveable:OverrideListener()
	if self.objectType == ControlledMoveable.kObjectTypes.Door then
		self:MoveToWaypoint(0)
		self:SetIsEnabled(not self:GetIsEnabled())
	else
		self:MoveToWaypoint()
	end
end

function ControlledMoveable:MoveToWaypoint(number)

	if self:GetIsAnimated() then
		self.open = number ~= 0
		return
	end
	if self.objectType == ControlledMoveable.kObjectTypes.Elevator and self:GetIsMoving() and number ~= 0 then
		//Triggers to move to next WP will always just call this blank.
		//But map resets/etc will pass this 0 to send home, still want those to override elevators.
		return
	end
	local waypoints = LookupPathingWaypoints(self.name)
	if waypoints then
		number = number or (self.waypoint + 1)
		local target = waypoints[1]
		for i = 1, #waypoints do
			if waypoints[i] and waypoints[i].number >= number then
				target = waypoints[i]
				break
			end
		end
		if target and self.waypoint ~= target.number then
			//We are go
			if gDebugClassicEnts then
				Shared.Message(string.format("Moveable %s moving from waypoint %s at %s to waypoint %s at %s.", self.name, self.waypoint, ToString(self:GetOrigin()), target.number, ToString(target.origin)))
			end
			self.waypoint = target.number
			self.destination = target.origin
			self.moving = true
			self:RemoveFromMesh()
			self:CleanupPhysicsModelAdder()
		end
	else
		Shared.Message(string.format("Moveable %s with invalid waypoints.", self.name))
	end
	self.open = self.waypoint ~= 0
	
end

function ControlledMoveable:Reset()

	self.waypoint = -1
	if self.initialOpenState then
		self:MoveToWaypoint(1)
	else
		self:MoveToWaypoint(0)
	end
	self:CleanRegisteredPlayers()
	self.open = self.initialOpenState
	
end

function ControlledMoveable:GetIsMoving()
    return self.moving
end

function ControlledMoveable:GetSpeed()
    return self.speed
end

function ControlledMoveable:GetIsOpen()
    return self.open
end

function ControlledMoveable:GetIsAnimated()
    return self.animationGraphIndex > 0
end

function ControlledMoveable:GetCanBeUsed(player, useSuccessTable)
    useSuccessTable.useSuccess = false
end

function ControlledMoveable:RegisterRidingPlayer(playerId)
	table.insertunique(self.registeredPlayers, playerId)
end

function ControlledMoveable:RemoveRidingPlayer(playerId)
	table.remove(self.registeredPlayers, playerId)
end

function ControlledMoveable:OnCapsuleTraceHit(entity)

    PROFILE("ControlledMoveable:OnCapsuleTraceHit")

    if entity and HasMixin(entity, "Moveable") and self.objectType == ControlledMoveable.kObjectTypes.Elevator then
		self:RegisterRidingPlayer(entity:GetId())
		if self:GetIsMoving() then
			entity:SetIsRiding(true)
			entity:SetRidingId(self:GetId())
		end
    end
    
end

function ControlledMoveable:IsPlayerOnMoveable(player, moveableId)

	PROFILE("ControlledMoveable:IsPointOnMoveable")
	
    local point = player:GetOrigin()
	local yAdjustment = 0
	local onMoveable = false
    local trace = Shared.TraceRay(Vector(point.x, point.y + 1, point.z), Vector(point.x, point.y - 100, point.z), CollisionRep.Move, PhysicsMask.AllButPCs, EntityFilterOne(player))
    if trace.fraction ~= 1 then
        yAdjustment = trace.endPoint.y - point.y
		onMoveable = trace.entity ~= nil and trace.entity:GetId() == moveableId
	end
	return onMoveable, yAdjustment
	
end

function ControlledMoveable:CleanRegisteredPlayers()

	for i = 1, #self.registeredPlayers do
		if self.registeredPlayers[i] then
			local player = Shared.GetEntity(self.registeredPlayers[i])
			if player then
				player:SetIsRiding(false)
			end
		end
	end
	self.registeredPlayers = { }
	
end

function ControlledMoveable:OnUpdatePlayers(moved, deltaTime)

	PROFILE("ControlledMoveable:OnUpdatePlayers")
	
	for i = #self.registeredPlayers, 1, -1 do
		if self.registeredPlayers[i] then
			local player = Shared.GetEntity(self.registeredPlayers[i])
			if player and player:GetIsOnGround() then
				local onMoveable, yAdjustment = self:IsPlayerOnMoveable(player, self:GetId())
				if onMoveable then
					local newOrigin = player:GetOrigin()
					newOrigin.x = newOrigin.x + moved.x
					if moved.y <= 0 then
						newOrigin.y = newOrigin.y + yAdjustment
					end
					newOrigin.z = newOrigin.z + moved.z
					if gDebugClassicEnts then
						Shared.Message(string.format("Moving player %s to compensate for moveable.", ToString(newOrigin - player:GetOrigin())))
					end
					player:SetOrigin(newOrigin)
					player:SetIsRiding(true)
					player:SetRidingId(self:GetId())
				else
					player:SetIsRiding(false)
				end
			end
		end
	end

end

function ControlledMoveable:OnWaypointReached()

	self.moving = false
	self:CleanRegisteredPlayers()
	self:CleanupPhysicsModelAdder()
	if Server and not self:GetIsOpen() and self.objectType ~= ControlledMoveable.kObjectTypes.Elevator then
		self:UpdateScaledModelPathingMesh()
		self:AddAdditionalPhysicsModel()
	end
	self:OnUpdatePhysics()
	if gDebugClassicEnts then
		Shared.Message(string.format("Moveable %s completed move to waypoint %s at %s.", self.name, self.waypoint, ToString(self:GetOrigin())))
	end
	
end

function ControlledMoveable:MoveObjectToTarget(endPoint, movespeed, time)

    PROFILE("ControlledMoveable:MoveObjectToTarget")
	
	local deltaVector = endPoint - self:GetOrigin()
	local moveVector = GetNormalizedVector(deltaVector) * (time * movespeed)
	
	//When we get really close, dont overshoot.
	if moveVector:GetLength() > deltaVector:GetLength() then
		moveVector = deltaVector
	end
	
	self:SetOrigin(self:GetOrigin() + moveVector)

	if (self:GetOrigin() - endPoint):GetLength() < 0.01 then
		self:OnWaypointReached()
	end
	
	return moveVector
    
end

function ControlledMoveable:OnUpdate(deltaTime)

    PROFILE("ControlledMoveable:OnUpdate")
	ScriptActor.OnUpdate(self, deltaTime)
	self:OnUpdateMoveable(deltaTime)
	
end

function ControlledMoveable:OnUpdateMoveable(deltaTime)

    PROFILE("ControlledMoveable:OnUpdateMoveable")
	if self:GetIsMoving() then
		local dV = self:MoveObjectToTarget(self.destination, self:GetSpeed(), deltaTime)
		//self:OnUpdatePlayers(dV, deltaTime)
	end

end

function ControlledMoveable:OnUpdateAnimationInput(modelMixin)

    PROFILE("ControlledMoveable:OnUpdateAnimationInput")
	
	if self:GetIsAnimated() then
		modelMixin:SetAnimationInput("open", self:GetIsOpen())
		modelMixin:SetAnimationInput("lock", not self:GetIsEnabled())
	end
    
end

Shared.LinkClassToMap("ControlledMoveable", ControlledMoveable.kMapName, networkVars, true)