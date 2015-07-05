// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\BreakableEmitter.lua
// - Dragon

Script.Load("lua/ScriptActor.lua")
Script.Load("lua/Mixins/SignalEmitterMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/ClassicEnts/ScaleModelMixin.lua")
Script.Load("lua/LiveMixin.lua")
Script.Load("lua/TeamMixin.lua")
Script.Load("lua/GameEffectsMixin.lua")

//Destroyable entities which are re-created on game reset, can emit on channel when destroyed.
//Takes health, surface, emitChannel, allowedTeam.  Optionally a cinematicName for onKill

class 'BreakableEmitter' (ScriptActor)

BreakableEmitter.kMapName = "breakable_emitter"

kBreakableSurfaceEnum = enum(kSurfaceList)
						
local kDefaultBreakableHealth = 100

local networkVars = 
{
	breakableSurface = "enum kBreakableSurfaceEnum",
	allowedTeam = string.format("integer (-1 to %d)", kSpectatorIndex)
}

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ClientModelMixin, networkVars)
AddMixinNetworkVars(LiveMixin, networkVars)
AddMixinNetworkVars(TeamMixin, networkVars)
AddMixinNetworkVars(ScaleModelMixin, networkVars)
AddMixinNetworkVars(GameEffectsMixin, networkVars)

function BreakableEmitter:OnCreate() 

    ScriptActor.OnCreate(self)
	
	InitMixin(self, BaseModelMixin)
    InitMixin(self, ClientModelMixin)
	InitMixin(self, SignalEmitterMixin)
	InitMixin(self, LiveMixin)
    InitMixin(self, TeamMixin)
    InitMixin(self, GameEffectsMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	self.allowedTeam = 0
	self.breakableSurface = kBreakableSurfaceEnum.metal
	self:SetUpdates(false)
	self:SetRelevancyDistance(kMaxRelevancyDistance)

end

function BreakableEmitter:OnInitialized()

    ScriptActor.OnInitialized(self)
	
	if Server then
	
		self.modelName = self.model
        
        if self.modelName ~= nil then
			//These can get re-created midgame, check for precached model
			if Shared.GetModelIndex(self.modelName) == 0 and GetFileExists(self.modelName) then
				Shared.PrecacheModel(self.modelName)
			end
            self:SetModel(self.modelName)
        end
		
		if self.cinematicName and self.cinematicName ~= "" then
			if Shared.GetCinematicIndex(self.cinematicName) == 0 then
				//Precache
				Shared.PrecacheCinematic(self.cinematicName)
			end
		end
	
		InitMixin(self, EEMMixin)
		
	end
	
	if self.surface then
		local newSurface = StringToEnum(kBreakableSurfaceEnum, self.surface)
		if newSurface and newSurface > 0 then
			self.breakableSurface = newSurface
		end
	end
	
	self.health = self.health or kDefaultBreakableHealth
	self:SetMaxHealth(self.health)
	self:SetHealth(self.health)
	
	InitMixin(self, ScaleModelMixin)
	
end

function BreakableEmitter:Reset()
	//These should get re-created regardless now.
end

function BreakableEmitter:GetSendDeathMessageOverride()
    return false
end

function BreakableEmitter:GetCanBeUsed(player, useSuccessTable)
    useSuccessTable.useSuccess = false
end   

function BreakableEmitter:GetCanTakeDamageOverride()
    return true
end

function BreakableEmitter:OnTakeDamage(damage, attacker, doer, point)
end

function BreakableEmitter:GetShowHitIndicator()
    return true
end

function BreakableEmitter:GetAllowedTeam()
    return self.allowedTeam or 0
end

function BreakableEmitter:GetSurfaceOverride()
    return EnumToString(kBreakableSurfaceEnum, self.breakableSurface)
end

if Server then

	function BreakableEmitter:OnKill(damage, attacker, doer, point, direction)
		ScriptActor.OnKill(self, damage, attacker, doer, point, direction)
		self:EmitSignal(self.emitChannel, self.emitMessage)
		self:TriggerEffects("death", { cinematic = self.cinematicName } )
		DestroyEntity(self)
	end
	
end

//Breakables are ALWAYS MY ENEMY!
local oldGetAreEnemies = GetAreEnemies
function GetAreEnemies(entityOne, entityTwo)
	//If target is breakable
	if entityTwo and entityTwo:isa("BreakableEmitter") and (entityTwo:GetAllowedTeam() == 0 or entityOne and entityOne.GetTeamNumber and entityOne:GetTeamNumber() == entityTwo:GetAllowedTeam()) then
		return true
	end
	return oldGetAreEnemies(entityOne, entityTwo)
end

Shared.LinkClassToMap("BreakableEmitter", BreakableEmitter.kMapName, networkVars)