-- Natural Selection 2 'Classic Entities Mod'
-- Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
-- Designed to work with maps developed for Extra Entities Mod.  
-- Source located at - https://github.com/xToken/ClassicEnts
-- lua\ClassicEnts\ControlledConveyor.lua
-- Dragon

Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/Trigger.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")

class 'ControlledConveyor' (Trigger)

ControlledConveyor.kMapName = "controlled_conveyor"

local kDefaultSpeed = 5

local networkVars = 
{
	direction = "vector",
	speed = "float"
}

-- Maintain Compat with EEM
local function RotationToDirection(angles)     
    local direction = Vector(1, 0, 1)
    if angles and angles.yaw ~= 0 then
		direction.x = direction.x * math.sin(angles.yaw)
		direction.z = direction.z * math.cos(angles.yaw)
    end
    return direction
end

function ControlledConveyor:OnCreate() 

    Trigger.OnCreate(self)
	
	InitMixin(self, SignalListenerMixin)
	
	if Server then
		self.direction = Vector(1, 0, 1)
		self.speed = kDefaultSpeed
	end
	
	self:SetRelevancyDistance(kMaxRelevancyDistance)
	
end

function ControlledConveyor:OnInitialized()

    Trigger.OnInitialized(self)
	
	InitMixin(self, ControlledMixin)
	
	if Server then
		self.direction = RotationToDirection(self:GetAngles())
		
		-- Editor wont allow redefining a property with the same name without crashing :/
		if self.realForce ~= nil then
			self.force = self.realForce
		end
	end
	
	self:SetTriggerCollisionEnabled(true)
	
end

function ControlledConveyor:GetIsMapEntity()
    return true
end

function ControlledConveyor:CanPushEntity(entity)
	if self:GetIsEnabled() and entity and entity:isa("Player") and HasMixin(entity, "Moveable") and entity:GetIsAlive() then
		return true
	end
	return false
end

function ControlledConveyor:OnSetEnabled(enabled)
	if enabled then
		self:ForEachEntityInTrigger(function(ent) self:OnTriggerEntered(ent) end)
	else
		self:ForEachEntityInTrigger(function(ent) if ent and ent:isa("Player") and HasMixin(ent, "Moveable") then ent:ClearBaseVelocity() end end)
	end
end

function ControlledConveyor:OnTriggerEntered(enterEnt)

    if self:CanPushEntity(enterEnt) then
		enterEnt:SetBaseVelocity(self.direction * self.speed, false)	
    end
	
end

function ControlledConveyor:OnTriggerExited(exitEntity)

	if exitEntity and exitEntity:isa("Player") and HasMixin(exitEntity, "Moveable") then
		exitEntity:ClearBaseVelocity()
	end
	
end

Shared.LinkClassToMap("ControlledConveyor", ControlledConveyor.kMapName, networkVars)