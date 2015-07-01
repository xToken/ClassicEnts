// 
// 
// lua\ControlledWeldableEmitter.lua
// - Dragon

Script.Load("lua/ScriptActor.lua")
Script.Load("lua/Mixins/ClientModelMixin.lua")
Script.Load("lua/Mixins/SignalEmitterMixin.lua")
Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/LiveMixin.lua")
Script.Load("lua/TeamMixin.lua")
Script.Load("lua/WeldableMixin.lua")
Script.Load("lua/ClassicEnts/ScaleModelMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")
Script.Load("lua/GameEffectsMixin.lua")

//Uses value from ControlledMixin.  allowedTeam sets the team which can weld this object, might also make it work with healspray for aliens.
//timeToWeld controls how many seconds it takes to weld this for it to trigger.  Once trigger, it emits on emitChannel.  This entity can also
//be toggled on listenChannel.  resetOnTrigger can be used to control what happens after this is welded.

//Good default model - models/props/generic/terminals/generic_controlpanel_01.model

class 'ControlledWeldableEmitter' (ScriptActor)

ControlledWeldableEmitter.kMapName = "controlled_weldable_emitter"

local kDefaultWeldTime = 10

local networkVars = 
{
	welded = "interpolated float (0 to 1 by 0.01)",
	allowedTeam = string.format("integer (-1 to %d)", kSpectatorIndex)
}

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ClientModelMixin, networkVars)
AddMixinNetworkVars(LiveMixin, networkVars)
AddMixinNetworkVars(TeamMixin, networkVars)
AddMixinNetworkVars(ScaleModelMixin, networkVars)
AddMixinNetworkVars(ControlledMixin, networkVars)
AddMixinNetworkVars(GameEffectsMixin, networkVars)

function ControlledWeldableEmitter:OnCreate() 

    ScriptActor.OnCreate(self)
	
	InitMixin(self, BaseModelMixin)
    InitMixin(self, ClientModelMixin)
	InitMixin(self, SignalListenerMixin)
	InitMixin(self, SignalEmitterMixin)
	InitMixin(self, LiveMixin)
    InitMixin(self, TeamMixin)
    InitMixin(self, GameEffectsMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil	
	self:SetRelevancyDistance(kMaxRelevancyDistance)
	
	self.welded = 0
	self.allowedTeam = 0
	self.weldedTime = 0

end

function ControlledWeldableEmitter:OnInitialized()

    ScriptActor.OnInitialized(self)
	
	if Server then
		
		self.modelName = self.model
        
        if self.modelName ~= nil then
        
            Shared.PrecacheModel(self.modelName)
            self:SetModel(self.modelName)
            
        end
		
		InitMixin(self, EEMMixin)
		self:SetTeamNumber(kTeam1Index)
		
	end
	
	InitMixin(self, WeldableMixin)
	InitMixin(self, ScaleModelMixin)
	InitMixin(self, ControlledMixin)
	
	self:SetArmor(0)
	
end

function ControlledWeldableEmitter:GetCanTakeDamageOverride()
    return false
end

function ControlledWeldableEmitter:GetUsablePoints()
    return { self:GetOrigin() }
end

function ControlledWeldableEmitter:GetCanBeUsed(player, useSuccessTable)
    useSuccessTable.useSuccess = false
end

function ControlledWeldableEmitter:Reset()
    self.welded = 0
	self.weldedTime = 0
end

function ControlledWeldableEmitter:OnSetEnabled(enabled)
	//This entity needs to reset for everything to work, so if something turns in on, be sure.
	self.welded = 0
	self.weldedTime = 0
end

function ControlledWeldableEmitter:GetWeldTime()
    return self.timeToWeld or kDefaultWeldTime
end

function ControlledWeldableEmitter:GetAllowedTeam()
    return self.allowedTeam or 0
end

function ControlledWeldableEmitter:GetTechId()
	//Hack to prevent issues with LiveMixin
    return kTechId.Door
end

function ControlledWeldableEmitter:GetCanBeWeldedOverride(doer)
	if doer and doer.GetTeamNumber then
		return self.welded < 1 and (self:GetAllowedTeam() == 0 or doer:GetTeamNumber() == self:GetAllowedTeam())
	end
	return true
end

function ControlledWeldableEmitter:OnWeldOverride(doer, elapsedTime)
    if Server then
		if self.weldTimeScales then
			local team = self:GetTeam()
			if team then
				elapsedTime = elapsedTime / team:GetNumPlayers()
			end
		end
		self.weldedTime = self.weldedTime + elapsedTime
		self.welded = Clamp(self.weldedTime / self:GetWeldTime(), 0, 1)
		if self.welded == 1 then
			self:OnWeldCompleted()
		end
    end
end

function ControlledWeldableEmitter:GetWeldPercentageOverride()    
    return self.welded 
end

function ControlledWeldableEmitter:OnWeldCompleted()
	self:EmitSignal(self.emitChannel, self.emitMessage)
	self.weldedTime = 0
end

Shared.LinkClassToMap("ControlledWeldableEmitter", ControlledWeldableEmitter.kMapName, networkVars)