// 
// 
// lua\ControlledTeleporterTrigger.lua
// - Dragon

Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/Trigger.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")

class 'ControlledTeleporterTrigger' (Trigger)

ControlledTeleporterTrigger.kMapName = "controlled_teleporter_trigger"

local kTeleporterGlobalTable = { }
local kDefaultCooldown = 1

//Singular Entrance, multiple exits supported.
local function RegisterInGlobalTable(networkId, entrance, entityId)
	if kTeleporterGlobalTable[networkId] then
		//Already registered network, check missing side
		if entrance then
			kTeleporterGlobalTable[networkId].entrance = entityId
		elseif not entrance then
			if not kTeleporterGlobalTable[networkId].destination then
				kTeleporterGlobalTable[networkId].destination = { }
			end
			table.insert(kTeleporterGlobalTable[networkId].destination, entityId)
		else
			assert(false)
		end
	else
		kTeleporterGlobalTable[networkId] = { }
		if entrance then
			kTeleporterGlobalTable[networkId].entrance = entityId
		else
			kTeleporterGlobalTable[networkId].destination = { }
			table.insert(kTeleporterGlobalTable[networkId].destination, entityId)
		end
	end
end

local function LookupDestinationTable(networkId)
	if kTeleporterGlobalTable[networkId] then
		return kTeleporterGlobalTable[networkId].destination
	end
end

local function GetTeleportDestinationCoords(self)

    local destinationEntityIds = LookupDestinationTable(self.teleportDestinationId)
	if destinationEntityIds then
		local destinationId = destinationEntityIds[math.random(1, #destinationEntityIds)]
		if destinationId and Shared.GetEntity(destinationId) then
			return Shared.GetEntity(destinationId):GetCoords()
		end
	end

end

local networkVars = { }

function ControlledTeleporterTrigger:OnCreate() 

    Trigger.OnCreate(self)
	
	InitMixin(self, SignalListenerMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	self.exitOnly = false
	self.entranceOnly = false
	self.allowedTeam = 0
	self.timeLastTeleport = 0
	
	self:SetPropagate(Entity.Propagate_Never)
	
end

function ControlledTeleporterTrigger:OnInitialized()

    Trigger.OnInitialized(self)
	
	InitMixin(self, ControlledMixin)
	InitMixin(self, EEMMixin)
	
	//vanilla system checks if .teleportDestinationId == .teleportDestinationId then
	//EEM uses .destination against .name
	
	local entrance = true
	local destination = true
	local entranceId
	local destinationId	
	
	if self.teleportDestinationId and self.oldMapName == "teleport_destination" then
		//We are an exit
		entrance = false
		self.exitOnly = true
		destinationId = self.teleportDestinationId
	elseif self.teleportDestinationId and self.oldMapName == "teleport_trigger" then
		//We were an entrance
		destination = false
		self.entranceOnly = true
		entranceId = self.teleportDestinationId
	end
	
	if not self.teleportDestinationId then
		//We are an eem teleporter, register new names for teleport network IDs
		entranceId = LookupOrRegisterExtendedChannelToName(ToString(self.name .. "_teleporter"))
		if self.exitonly then
			//EEM exit only
			self.exitOnly = true
			destinationId = entranceId
			entrance = false
		elseif not self.destination then
            Shared.Message(string.format("Error: ControlledTeleporterTrigger %s has no destination", self.name))
		else
			destinationId = LookupOrRegisterExtendedChannelToName(ToString(self.destination .. "_teleporter"))
		end
	end
	
	if entrance then
		RegisterInGlobalTable(entranceId, true, self:GetId())
	end
	if destination then
		RegisterInGlobalTable(destinationId, false, self:GetId())
	end
	
	if not self.exitOnly then
		self.teleportDestinationId = entranceId
	end
	
	self:SetTriggerCollisionEnabled(true)
	
end

function ControlledTeleporterTrigger:GetAllowedTeam()
    return self.allowedTeam or 0
end

function ControlledTeleporterTrigger:GetCooldown()
	return self.timerDelay or kDefaultCooldown
end

function ControlledTeleporterTrigger:GetIsMapEntity()
    return true
end

local kTeleportClassNames =
{
    "ReadyRoomPlayer",
    "Embryo",
    "Skulk",
    "Gorge",
    "Lerk",
    "Fade",
    "Onos",
    "Marine",
    "JetpackMarine",
    "Exo"
}

function ControlledTeleporterTrigger:CanTeleportEntity(entity)
	if not self.exitOnly and self:GetIsEnabled() and self.timeLastTeleport + self:GetCooldown() < Shared.GetTime() then
		local className = entity:GetClassName()
		if table.contains(kTeleportClassNames, className) then
			if self:GetAllowedTeam() == 0 or (entity.GetTeamNumber and entity:GetTeamNumber() == self:GetAllowedTeam()) then
				return true
			end
		end
	end
	return false
end

function ControlledTeleporterTrigger:OnTriggerEntered(enterEnt, triggerEnt)

    if self:CanTeleportEntity(enterEnt) then

        local destinationCoords = GetTeleportDestinationCoords(self)

        if destinationCoords then
        
            local oldCoords = enterEnt:GetCoords()
        
            enterEnt:SetCoords(destinationCoords)
            
            if enterEnt:isa("Player") then
            
                local newAngles = Angles(0, 0, 0)            
                newAngles.yaw = GetYawFromVector(destinationCoords.zAxis)
                enterEnt:SetOffsetAngles(newAngles)
            
            end
            
            GetEffectManager():TriggerEffects("teleport_trigger", { effecthostcoords = oldCoords }, self)
            GetEffectManager():TriggerEffects("teleport_trigger", { effecthostcoords = destinationCoords }, self)
			
			//EEM seems to place teleporters much closer to the brush objects
			// make sure nothing blocks us
			local destYaw = enterEnt:GetAngles().yaw
			local extents = LookupTechData(enterEnt:GetTechId(), kTechDataMaxExtents)
			local teleportPointBlocked = Shared.CollideCapsule(enterEnt:GetOrigin(), extents.y, math.max(extents.x, extents.z), CollisionRep.Default, PhysicsMask.AllButPCs, nil)
			if teleportPointBlocked then
				// move it a bit so we're not getting blocked
				local antiStuckVector = Vector(0,0,0)
				antiStuckVector.z = math.cos(destYaw)
				antiStuckVector.x = math.sin(destYaw)
				antiStuckVector.y = 0.5
				enterEnt:SetOrigin(enterEnt:GetOrigin() + antiStuckVector)
			end
            
            enterEnt.timeOfLastPhase = Shared.GetTime()
			self.timeLastTeleport = Shared.GetTime()
        
        end
    
    end
	
end

Shared.LinkClassToMap("ControlledTeleporterTrigger", ControlledTeleporterTrigger.kMapName, networkVars)