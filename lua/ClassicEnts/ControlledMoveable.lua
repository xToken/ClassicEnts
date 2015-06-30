// 
// 
// lua\ControlledMoveable.lua
// - Dragon

Script.Load("lua/ScriptActor.lua")
Script.Load("lua/PathingMixin.lua")
Script.Load("lua/Mixins/ClientModelMixin.lua")
Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/ClassicEnts/ScaleModelMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")

class 'ControlledMoveable' (ScriptActor)

ControlledMoveable.kMapName = "controlled_moveable"

local kUpdateAutoOpenRate = 0.3
local kElevatorPauseTime = 3
local kMoveableUpdateRate = 0
ControlledMoveable.kObjectTypes = enum( {'Door', 'Elevator', 'Gate'} )

//These objects support basic interations/triggering, but not pausing once started.  Doors open then automatically close and can optionally open & close automatically.
//Elevators pause for a short period at each waypoint before continuing.
//Doors and Elevators both return to their original waypoints.
//Gates are ONLY controlled by emitters.

local networkVars = 
{
	moving = "boolean",
	autoTrigger = "boolean",
	destination = "vector",
	objectType = "enum ControlledMoveable.kObjectTypes"
}

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ClientModelMixin, networkVars)
AddMixinNetworkVars(ScaleModelMixin, networkVars)
AddMixinNetworkVars(ControlledMixin, networkVars)

local function UpdateAutoOpen(self, timePassed)
  
    if self:GetIsEnabled() then
    
        local desiredOpenState = false

        local entities = Shared.GetEntitiesWithTagInRange("Door", self:GetOrigin(), DoorMixin.kMaxOpenDistance)
        for index = 1, #entities do
            
            local entity = entities[index]
            local opensForEntity, openDistance = entity:GetCanDoorInteract(self)
			
            if opensForEntity then
            
                local distSquared = self:GetDistanceSquared(entity)
                if (not HasMixin(entity, "Live") or entity:GetIsAlive()) and entity:GetIsVisible() and distSquared < (openDistance * openDistance) then
                
                    desiredOpenState = true
                    break
                
                end
            
            end
            
        end
        
        if desiredOpenState and not self:GetIsMoving() then
			self:MoveToWaypoint()
        elseif not desiredOpenState then
			self:MoveToWaypoint(0)
        end
        
    end
    
    return true

end

local function TriggerListener(self)
	self:MoveToWaypoint()
end

function ControlledMoveable:OnCreate() 

    ScriptActor.OnCreate(self)
	
	InitMixin(self, BaseModelMixin)
    InitMixin(self, ClientModelMixin)
	InitMixin(self, PathingMixin)
	InitMixin(self, SignalListenerMixin)
	
	self.moving = false
	self.speed = 10
	self.objectType = ControlledMoveable.kObjectTypes.Gate
	self.autoTrigger = false
	self.destination = Vector(0, 0, 0)
	self.waypoint = 0
	self.lastUpdate = Shared.GetTime()
	
	self:RegisterSignalListener(function() TriggerListener(self) end)

end

function ControlledMoveable:OnInitialized()

    ScriptActor.OnInitialized(self)
	
	if Server then
	
		self.modelName = self.model
        
        if self.modelName ~= nil then
        
            Shared.PrecacheModel(self.modelName)
            self:SetModel(self.modelName)
            
        end
		
		self:AddTimedCallback(ControlledMoveable.OnUpdateMoveable, kMoveableUpdateRate)
		
		InitMixin(self, EEMMixin)
		
		AddPathingWaypoint(self.name, "home", self:GetOrigin(), self:GetAngles(), 0)
			
		if self.autoTrigger and self.objectType == ControlledMoveable.kObjectTypes.Door then
			//If we are a door that autoopens
			self:AddTimedCallback(UpdateAutoOpen, kUpdateAutoOpenRate)
		end
		
	end
	
	InitMixin(self, ScaleModelMixin)
	InitMixin(self, ControlledMixin)
	
end

function ControlledMoveable:MoveToWaypoint(number)

	local waypoints = LookupPathingWaypoints(self.name)
	if waypoints then
		local target = number or self.waypoint + 1
		if waypoints[target] then
			//We are go
			self.waypoint = waypoints[target].number
			self.destination = waypoints[target].origin
			self.destinationagles = waypoints[target].angles
			self.moving = true
		else
			//Go home
			self.waypoint = waypoints[0].number
			self.destination = waypoints[0].origin
			self.destinationagles = waypoints[0].angles
			self.moving = true
		end
	else
		assert(false)
	end
	
end

function ControlledMoveable:GetIsMoving()
    return self.moving
end

function ControlledMoveable:GetSpeed()
    return self.speed
end

function ControlledMoveable:PreventTurning()
    return true
end

function ControlledMoveable:GetIsFlying()
    return true
end

function ControlledMoveable:GetControllerSize()
    return GetTraceCapsuleFromExtents(self:GetExtents())
end

function ControlledMoveable:GetCanBeUsed(player, useSuccessTable)
    useSuccessTable.useSuccess = false
end

function ControlledMoveable:OnUpdateMoveable(deltaTime)

    PROFILE("ControlledMoveable:OnUpdateMoveable")
	
	if self:GetIsEnabled() and self:GetIsMoving() then
		local t = Shared.GetTime()
		if not deltaTime then
			deltaTime = t - self.lastUpdate
		end
		self:MoveToTarget(PhysicsMask.All, self.destination, self:GetSpeed(), deltaTime)
		if self:IsTargetReached(self.destination, kAIMoveOrderCompleteDistance) then
			//WE DID IT DAD!
			self.moving = false
		end
		self.lastUpdate = t
	end
	
	return true

end

Shared.LinkClassToMap("ControlledMoveable", ControlledMoveable.kMapName, networkVars)