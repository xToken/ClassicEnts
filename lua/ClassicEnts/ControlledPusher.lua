-- Natural Selection 2 'Classic Entities Mod'
-- Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
-- Designed to work with maps developed for Extra Entities Mod.  
-- Source located at - https://github.com/xToken/ClassicEnts
-- lua\ClassicEnts\ControlledPusher.lua
-- Dragon

Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/Trigger.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")

class 'ControlledPusher' (Trigger)

ControlledPusher.kMapName = "controlled_pusher"

local kDefaultForce = 50
local kPushPlayerCooldown = 0.3
local kVerticleScalar = 1.2 //EEM used to move player up a bit, use this to account for that.

local networkVars = 
{ 
	direction = "vector",
	force = "float"
}

-- Maintain Compat with EEM
local function AnglesToVector(angles)     
    local direction = Vector(0,0,0)
    if angles then
        direction.z = math.cos(angles.pitch)
        direction.y = -math.sin(angles.pitch) * kVerticleScalar
        if angles.yaw ~= 0 then
            direction.x = direction.z * math.sin(angles.yaw)
            direction.z = direction.z * math.cos(angles.yaw)
        end  
    end
    return direction
end

function ControlledPusher:OnCreate() 

    Trigger.OnCreate(self)
	
	InitMixin(self, SignalListenerMixin)
	
	-- SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	self.direction = Vector(0, 1, 0) -- Straight upppp tooo the mooon.
	self.force = kDefaultForce
	self:SetRelevancyDistance(kMaxRelevancyDistance)
	
end

function ControlledPusher:OnInitialized()

    Trigger.OnInitialized(self)
	
	InitMixin(self, ControlledMixin)
	
	if Server then
	
		InitMixin(self, EEMMixin)
		self.direction = AnglesToVector(self:GetAngles())
		
		-- Editor wont allow redefining a property with the same name without crashing :/
		if self.realforce ~= nil then
			self.force = self.realforce
		elseif self.realForce ~= nil then
			-- Incase anyone caught my earlier mistake and fixed it in the map
			self.force = self.realForce
		end
		
	end
	
	self:SetTriggerCollisionEnabled(true)
	
end

function ControlledPusher:GetIsMapEntity()
    return true
end

function ControlledPusher:CanPushEntity(entity)
	if self:GetIsEnabled() and entity and entity:isa("Player") and HasMixin(entity, "Moveable") and entity:GetIsAlive() and entity.pushTime + kPushPlayerCooldown < Shared.GetTime() then
		return true
	end
	return false
end

function ControlledPusher:OnSetEnabled(enabled)
	if enabled then
		self:ForEachEntityInTrigger(self.OnTriggerEntered)
	end
end

function ControlledPusher:OnTriggerEntered(enterEnt, triggerEnt)

    if self:CanPushEntity(enterEnt) then
		if gDebugClassicEnts then
			Shared.Message(string.format("Pushing entity %s in direction %s with %s force.", enterEnt:GetId(), self.direction, self.force))
		end
		enterEnt:SetBaseVelocity(self.direction * self.force, true)
		enterEnt.pushTime = Shared.GetTime()
		
    end
	
end

Shared.LinkClassToMap("ControlledPusher", ControlledPusher.kMapName, networkVars)