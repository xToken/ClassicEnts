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
		
		if not self:GetIsAnimated() then
			self:SetPhysicsType(CollisionObject.Static)
		end
		
		AddPathingWaypoint(self.name, "home", self:GetOrigin(), 0, self:GetId())
		self:SetPhysicsGroup(PhysicsGroup.CommanderUnitGroup)

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

function ControlledMoveable:GetControllerSize()
    return GetTraceCapsuleFromExtents(self:GetExtents())
end

function ControlledMoveable:GetCanBeUsed(player, useSuccessTable)
    useSuccessTable.useSuccess = false
end

function ControlledMoveable:UpdatePathingMesh()

    if GetIsPathingMeshInitialized() and Server then
   
        if self.obstacleId ~= -1 then
            Pathing.RemoveObstacle(self.obstacleId)
            gAllObstacles[self] = nil
        end
		
		local extents = Vector(1, 1, 1)
		if self.modelName then
			_, extents = Shared.GetModel(Shared.GetModelIndex(self.modelName)):GetExtents(self.boneCoords)  
		end
		
		//This gets really hacky.. some models are setup much differently.. their origin is not center mass.
		//Limit maximum amount of adjustment to try to correct ones that are messed up, but not break ones that are good.
        local radius = extents.x * self.scale.x
		local position = self:GetOrigin() + Vector(0, -100, 0)
		local yaw = self:GetAngles().yaw
		position.x = position.x + (math.cos(yaw) * radius / 2)
		position.z = position.z - (math.sin(yaw) * radius / 2)
		radius = math.min(radius, 2)
		local height = 1000.0
		
        self.obstacleId = Pathing.AddObstacle(position, radius, height) 
      
        if self.obstacleId ~= -1 then
        
            gAllObstacles[self] = true
            if self.GetResetsPathing and self:GetResetsPathing() then
                InformEntitiesInRange(self, 25)
            end
            
        end
    
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

function ControlledMoveable:OnWaypointReached()
	self.moving = false
	if not self:GetIsOpen() and self.objectType ~= ControlledMoveable.kObjectTypes.Elevator then
		self:UpdatePathingMesh()
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
		self:MoveObjectToTarget(PhysicsMask.All, self.destination, self:GetSpeed(), deltaTime)
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