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

class 'ControlledMoveable' (ScriptActor)

ControlledMoveable.kMapName = "controlled_moveable"

ControlledMoveable.kDefaultDoor = "models/misc/door/door.model"
ControlledMoveable.kDefaultDoorClean = "models/misc/door/door_clean.model"
ControlledMoveable.kDefaultAnimationGraph = "models/misc/door/door.animation_graph"
ControlledMoveable.kObjectTypes = enum( {'Door', 'Elevator', 'Gate'} )

local kUpdateAutoOpenRate = 0.3
local kMoveableUpdateRate = 0
local kMoveableHeightRange = 2

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
		
		self:SetPhysicsType(CollisionObject.Static)

		if self.open then
			self:AddTimedCallback(function(self) self:MoveToWaypoint(1) end, 1)
		end
		
	end
	
	self.initialOpenState = self.open
	
	InitMixin(self, ScaleModelMixin)
	
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
			//Invalidate any current movements
			if self.cursor then
				self.cursor = nil
				self.points = nil
			end
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
		entity:SetIsRiding(true)
		entity:SetRidingId(self:GetId())
    end
    
end

function ControlledMoveable:CheckObjectTarget(endPoint)

    // if we don't have a cursor, or the targetPoint differs, create a new path
    if self.cursor == nil or (self.targetPoint - endPoint):GetLengthXZ() > 0.01 then

        self.targetPoint = endPoint
        self.points = { self:GetOrigin(), endPoint }
        SmoothPathPoints( self.points, 0.5 , 40) 
        
        self.cursor = PathCursor():Init(self.points)
        
    end
    
    return true
    
end

function ControlledMoveable:IsPointOnMoveable(point, deltaTime)
    
	// Check dot product
	local coords = self:GetCoords()
	local toPoint = point - coords.origin
	local extents = self:GetModelExtents()
	local scale = self:GetModelScale()
	local yDistance = coords.yAxis:DotProduct(toPoint)
	local xDistance = math.abs(coords.xAxis:DotProduct(toPoint))
	local zDistance = math.abs(coords.zAxis:DotProduct(toPoint))
	local xzDistance = math.sqrt(zDistance * zDistance + xDistance * xDistance)
	//This probably wont work with offset origin models, ever..
	if xzDistance <= math.abs(extents.x * scale.x) and xzDistance <= math.abs(extents.z * scale.z) and math.abs(yDistance) <= self:GetSpeed() * deltaTime + 0.05 then
		return true, yDistance
	end
	return false, 0
	
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
	local ReRegisteredPlayers = { }
	for i = 1, #self.registeredPlayers do
		if self.registeredPlayers[i] then
			local player = Shared.GetEntity(self.registeredPlayers[i])
			//Only sim if Server or local player on client NOT doing prediction.
			if player then
				local onMoveable, yDistance = self:IsPointOnMoveable(player:GetOrigin(), deltaTime)
				if onMoveable then
					local newOrigin = player:GetOrigin()
					newOrigin.x = newOrigin.x + moved.x
					newOrigin.y = newOrigin.y + moved.y
					newOrigin.z = newOrigin.z + moved.z
					if gDebugClassicEnts then
						Shared.Message(string.format("Moving player %s to compensate for moveable.", ToString(player:GetOrigin() - newOrigin)))
					end
					player:SetOrigin(newOrigin)
					table.insert(ReRegisteredPlayers, self.registeredPlayers[i])
				else
					player:SetIsRiding(false)
				end
			end
		end
	end
	self.registeredPlayers = ReRegisteredPlayers
end

function ControlledMoveable:OnWaypointReached()
	self.moving = false
	self:CleanRegisteredPlayers()
	if Server and not self:GetIsOpen() and self.objectType ~= ControlledMoveable.kObjectTypes.Elevator then
		UpdateScaledModelPathingMesh(self)
	end
	if gDebugClassicEnts then
		Shared.Message(string.format("Moveable %s completed move to waypoint %s at %s.", self.name, self.waypoint, ToString(self:GetOrigin())))
	end
end

function ControlledMoveable:MoveObjectToTarget(physicsGroupMask, endPoint, movespeed, time)

    PROFILE("ControlledMoveable:MoveObjectToTarget")
    
	//Target is never invalid here.
    self:CheckObjectTarget(endPoint)
    
    // save the cursor in case we need to slow down
    local origCursor = PathCursor():Clone(self.cursor)
    self.cursor:Advance(movespeed, time)
    
    local maxSpeed = movespeed
    
    if maxSpeed < movespeed then
        // use the copied cursor and discard the current cursor
        self.cursor = origCursor
        self.cursor:Advance(maxSpeed, time)
    end
    
    // update our position to the cursors position, after adjusting for ground or hover
    local newLocation = self.cursor:GetPosition()
    self:SetOrigin(newLocation)
         
    // we are done if we have reached the last point in the path or we have a close-enough condition
    local done = self.cursor:TargetReached()
    if done then
    
        self.cursor = nil
        self.points = nil
		self:OnWaypointReached()
		
    end
    
end

//Note that while this should make the objects move smoothly, players riding on them still will bounce.
//Would need to move players that are riding to have perfectly smooth experience for them.
function ControlledMoveable:OnUpdate(deltaTime)

    PROFILE("ControlledMoveable:OnUpdate")
	ScriptActor.OnUpdate(self, deltaTime)
	self:OnUpdateMoveable(deltaTime)
	
end

function ControlledMoveable:OnUpdateMoveable(deltaTime)

    PROFILE("ControlledMoveable:OnUpdateMoveable")
	if self:GetIsMoving() then
		local dV = self:GetOrigin()
		self:MoveObjectToTarget(PhysicsMask.All, self.destination, self:GetSpeed(), deltaTime)
		if Server then
			//self:OnUpdatePlayers(self:GetOrigin() - dV, deltaTime)
		end
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