-- Natural Selection 2 'Classic Entities Mod'
-- Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
-- Designed to work with maps developed for Extra Entities Mod.  
-- Source located at - https://github.com/xToken/ClassicEnts
-- lua\ClassicEnts\ControlledMoveable.lua
-- Dragon

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
local kLowUpdateRate = 0.25
local kMaxDetectionRadius = 25
local kControllerScale = 0.75
local kNonPlayerDamageScale = 10
local kCollideTypes = 
{
	"ARC",
	"Armory",
	"ArmsLab",
	"Crag",
	"Egg",
	"Hydra",
	"InfantryPortal",
	"Observatory",
	"PhaseGate",
	"PrototypeLab",
	"ResourceTower",
	"RoboticsFactory",
	"Sentry",
	"SentryBattery",
	"Shade",
	"Shift",
	"Spur",
	"TunnelEntrance",
	"Veil"
}

function RegisterControlledMoveableColliderClass(className)
	table.insert(kCollideTypes, className)
end

-- These objects support basic interations/triggering, but not pausing once started.  
-- Doors open/close automatically, are enabled/disabled accordingly when triggered.
-- Elevators pause for a short period at each waypoint before continuing.  Triggering an elevator causes it to move.
-- Gates work just like doors, however they do not open/close automatically.  Gates are moved on trigger.

local networkVars = 
{
	moving = "boolean",
	speed = "float",
	destination = "vector",
	objectType = "enum ControlledMoveable.kObjectTypes",
	blockedDamage = "integer",
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
		
		-- GetEntsInRange will grab a little further than passed ranged.
		-- Allow ents to still not trigger door opening if they want (rooted whips etc), but ignore range override.
		local entities = Shared.GetEntitiesWithTagInRange("Door", self:GetOrigin(), self:GetDetectionRadius())
		for i = 1, #entities do
            local entity = entities[i]
			if entity then
				local opensForEntity = entity:GetCanDoorInteract(self)
				if opensForEntity then
					desiredOpenState = true
					break
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
	
	-- SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	
	if Server then
		self.moving = false
		self.speed = 10
		self.objectType = ControlledMoveable.kObjectTypes.Gate
		self.destination = Vector(0, 0, 0)
		self.open = false
		self.commVisible = true
		self.waypoint = -1
		self.lastWaypoint = -1
		self.detectionRadius = DoorMixin.kMaxOpenDistance
		self.blockedDamage = 0
		self:SetUpdateRate(kRealTimeUpdateRate)
	else
		-- run full speed on the client to prevent ghosting?
		self:SetUpdateRate(kRealTimeUpdateRate)
	end	

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
			-- These can get re-created midgame, check for precached model
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
			self:AddTimedCallback(function(self) self:MoveToWaypoint(1, true) end, 1)
		end
		
		self.detectionRadius = Clamp(self.detectionRadius, 1, kMaxDetectionRadius)
		
		-- Editor wont allow redefining a property with the same name without crashing :/
		if self.realSpeed ~= nil then
			self.speed = self.realSpeed
		end
		
		local mask = bit.bor(kRelevantToTeam1Unit, kRelevantToTeam2Unit, kRelevantToReadyRoom)
		if self.commVisible then
			mask = bit.bor(mask, kRelevantToTeam1Commander, kRelevantToTeam2Commander)
		end
		self:SetExcludeRelevancyMask( mask )
		self:SetRelevancyDistance(kMaxRelevancyDistance)

	end
	
	InitMixin(self, ScaleModelMixin)
	InitMixin(self, GameWorldMixin)
	
	self:SetPhysicsType(PhysicsType.Kinematic)
	self.homeWaypoint = self.open and 1 or 0
	
end

function ControlledMoveable:OverrideListener()
	if self.objectType == ControlledMoveable.kObjectTypes.Door then
		self:MoveToWaypoint(0)
		self:SetIsEnabled(not self:GetIsEnabled())
	else
		self:MoveToWaypoint()
	end
end

function ControlledMoveable:GetNextWaypoint(number)
	local waypoints = LookupPathingWaypoints(self.name)
	local target
	if waypoints then
		number = number or (self.waypoint + 1)
		target = waypoints[1]
		for i = 1, #waypoints do
			if waypoints[i] and waypoints[i].number >= number then
				-- Found closest waypoint to number, but dont move if its already where we are.
				if self.waypoint ~= waypoints[i].number then
					target = waypoints[i]
				end
				break
			end
		end
	else
		Shared.Message(string.format("Moveable %s has no valid waypoints!", self.name))
	end
	return target
end


function ControlledMoveable:MoveToWaypoint(number, force)

	if self:GetIsAnimated() then
		self.open = number ~= 0
		return
	end
	if self.objectType == ControlledMoveable.kObjectTypes.Elevator and self:GetIsMoving() and not force then
		-- Triggers to move to next WP will always just call this blank.
		-- But map resets/etc will pass this 0 to send home, still want those to override elevators.
		return
	end
	local target = self:GetNextWaypoint(number)
	if target then
		-- We are go
		if gDebugClassicEnts then
			Shared.Message(string.format("Moveable %s moving from waypoint %s at %s to waypoint %s at %s.", self.name, self.waypoint, ToString(self:GetOrigin()), target.number, ToString(target.origin)))
		end
		self.lastWaypoint = self.waypoint
		self.waypoint = target.number
		self.destination = target.origin
		self.moving = true
		self:RemoveFromMesh()
		self:CleanupAdditionalPhysicsModel()
		self:SetUpdateRate(kRealTimeUpdateRate)
	end
	self.open = self.waypoint ~= 0
	
end

function ControlledMoveable:Reset()
	self.waypoint = -1
	self:MoveToWaypoint(self.homeWaypoint, true)
end

function ControlledMoveable:GetIsMoving()
    return self.moving
end

function ControlledMoveable:GetSpeed()
    return self.speed
end

function ControlledMoveable:GetDetectionRadius()
    return self.detectionRadius
end

function ControlledMoveable:GetBlockedDamage()
    return self.blockedDamage
end

function ControlledMoveable:GetIsOpen()
    return self.open
end

function ControlledMoveable:GetIsAnimated()
    return self.animationGraphIndex > 0
end

function ControlledMoveable:GetInfluencesMovement()
	return self.objectType == ControlledMoveable.kObjectTypes.Elevator
end

function ControlledMoveable:GetCanBeUsed(player, useSuccessTable)
    useSuccessTable.useSuccess = false
end

function ControlledMoveable:OnWaypointReached()

	self.moving = false
	if Server and not self:GetIsOpen() and self.objectType ~= ControlledMoveable.kObjectTypes.Elevator then
		self:UpdateScaledModelPathingMesh()
		self:AddAdditionalPhysicsModel()
	end
	self:OnUpdatePhysics()
	self:SetUpdateRate(kLowUpdateRate)
	if gDebugClassicEnts then
		Shared.Message(string.format("Moveable %s completed move to waypoint %s at %s.", self.name, self.waypoint, ToString(self:GetOrigin())))
	end
	
end

function ControlledMoveable:OnProcessCollision(entity, damageScale)
	if Server then
		local killed = false
		if self.blockedDamage > 0 then
			killed, _ = entity:TakeDamage(self.blockedDamage * damageScale, nil, nil, nil, nil, 0, self.blockedDamage * damageScale, kDamageType.Normal)
		end
		if not killed then
			self:MoveToWaypoint(self.lastWaypoint, true)
			return false
		end
	else
		-- HACK
		-- Clients are not networked waypoints, so just send the elevator back in time on the client, server updates will straighten the rest out
		local moveAmount = self:GetMoveAmount(self.destination, self:GetSpeed() * -1, 0.2)
		self:SetOrigin(self:GetOrigin() + moveAmount)
	end
	return true
end

function ControlledMoveable:GetMoveAmount(endPoint, moveSpeed, deltaTime)

	local deltaVector = endPoint - self:GetOrigin()
	local moveVector = GetNormalizedVector(deltaVector) * (deltaTime * moveSpeed)
	
	-- When we get really close, dont overshoot.
	if moveVector:GetLength() > deltaVector:GetLength() then
		moveVector = deltaVector
	end
	
	return moveVector
end

function ControlledMoveable:MoveObjectToTarget(endPoint, moveSpeed, deltaTime)

	local moveAmount = self:GetMoveAmount(endPoint, moveSpeed, deltaTime)
	local origin = self:GetOrigin()
	
	-- Moveables DGAF, just go unless something tells us to stop.
	-- Elevators should check for non-player entities that might block us
	if self:GetInfluencesMovement() then
		if not self.traceExtents then
			local s = self:GetModelScale()
			local e = self:GetModelExtentsVector()
			self.traceExtents = Vector(s.x * e.x * kControllerScale, s.y * e.y * kControllerScale, s.z * e.z * kControllerScale)
		end
		local trace = Shared.TraceBox(self.traceExtents, origin, origin + moveAmount, CollisionRep.Default, PhysicsMask.AllButPCs, EntityFilterOneAndIsa(self, "Player"))
        if trace.entity and HasMixin(trace.entity, "Live") and table.contains(kCollideTypes, trace.entity:GetClassName()) then
			-- Should we only collide with certain things or things which take structural damage atm?
			if not self:OnProcessCollision(trace.entity, kNonPlayerDamageScale) then
				-- Changing direction, dont run rest of move.
				return
			end
		end
	end
	
	self:SetOrigin(origin + moveAmount)

	if (self:GetOrigin() - endPoint):GetLength() < 0.01 then
		self:OnWaypointReached()
	end
    
end

function ControlledMoveable:OnUpdate(deltaTime)

    PROFILE("ControlledMoveable:OnUpdate")
	
	ScriptActor.OnUpdate(self, deltaTime)
	
	if self:GetIsMoving() then
		self:MoveObjectToTarget(self.destination, self:GetSpeed(), deltaTime)
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