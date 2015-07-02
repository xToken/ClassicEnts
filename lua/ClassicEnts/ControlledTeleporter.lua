// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ControlledTeleporter.lua
// - Dragon

Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/Trigger.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")

class 'ControlledTeleporter' (Trigger)

ControlledTeleporter.kMapName = "controlled_teleporter"

local kTeleporterGlobalTable = { }
local kDefaultCooldown = 1

local function RegisterInGlobalTable(networkId, entityId)
	if not kTeleporterGlobalTable[networkId] then
		kTeleporterGlobalTable[networkId] = { }
	end
	table.insert(kTeleporterGlobalTable[networkId], entityId)
end

local function LookupDestinationTable(networkId)
	if kTeleporterGlobalTable[networkId] then
		return kTeleporterGlobalTable[networkId]
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

function ControlledTeleporter:OnCreate() 

    Trigger.OnCreate(self)
	
	InitMixin(self, SignalListenerMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	self.exitOnly = false
	self.allowedTeam = 0
	self.timeLastTeleport = 0
	
	self:SetPropagate(Entity.Propagate_Never)
	
end

function ControlledTeleporter:OnInitialized()

    Trigger.OnInitialized(self)
	
	InitMixin(self, ControlledMixin)
	InitMixin(self, EEMMixin)
	
	//vanilla system checks if .teleportDestinationId == .teleportDestinationId then
	//EEM uses .destination against .name
	
	if self.teleportDestinationId and self.oldMapName == "teleport_destination" then
		//We are an destination, register in global table.
		self.exitOnly = true
		RegisterInGlobalTable(self.teleportDestinationId, self:GetId())
	end
	
	if not self.teleportDestinationId then
		//We are an eem teleporter, register new names for teleport network IDs.  All EEM teleporters can be a destination, but not necessarily an entrance.
		local destinationId = RegisterInGlobalTable(LookupOrRegisterExtendedChannelToName(ToString(self.name .. "_teleporter")), self:GetId())
		if self.exitonly then
			//EEM exit only, we can set teleportDestinationId for consistency with vanilla ents but its never used atm.
			self.exitOnly = true
			self.teleportDestinationId = destinationId
		elseif self.destination then
			//If we are not a destination, then register our channel and set it as our destinationId.
            self.teleportDestinationId = LookupOrRegisterExtendedChannelToName(ToString(self.destination .. "_teleporter"))
		else
			Shared.Message(string.format("Error: ControlledTeleporterTrigger %s has no destination", self.name))
		end
	end
	
	self:SetTriggerCollisionEnabled(true)
	
end

function ControlledTeleporter:GetAllowedTeam()
    return self.allowedTeam or 0
end

function ControlledTeleporter:GetCooldown()
	return self.timerDelay or kDefaultCooldown
end

function ControlledTeleporter:GetIsMapEntity()
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

function ControlledTeleporter:CanTeleportEntity(entity)
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

function ControlledTeleporter:OnTriggerEntered(enterEnt, triggerEnt)

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

Shared.LinkClassToMap("ControlledTeleporter", ControlledTeleporter.kMapName, networkVars)