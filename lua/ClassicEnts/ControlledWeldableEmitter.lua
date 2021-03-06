-- Natural Selection 2 'Classic Entities Mod'
-- Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
-- Designed to work with maps developed for Extra Entities Mod.  
-- Source located at - https://github.com/xToken/ClassicEnts
-- lua\ClassicEnts\ControlledWeldableEmitter.lua
-- Dragon

Script.Load("lua/ScriptActor.lua")
Script.Load("lua/Mixins/ClientModelMixin.lua")
Script.Load("lua/Mixins/SignalEmitterMixin.lua")
Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/LiveMixin.lua")
Script.Load("lua/TeamMixin.lua")
Script.Load("lua/WeldableMixin.lua")
Script.Load("lua/MapBlipMixin.lua")
Script.Load("lua/UnitStatusMixin.lua")
Script.Load("lua/SelectableMixin.lua")
Script.Load("lua/ClassicEnts/ScaleModelMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")
Script.Load("lua/GameEffectsMixin.lua")

-- Uses value from ControlledMixin.  teamNumber sets the team which can weld this object.
-- timeToWeld controls how many seconds it takes to weld this for it to trigger.  Once trigger, it emits on emitChannel.  This entity can also
-- be toggled on listenChannel.  resetOnTrigger can be used to control what happens after this is welded.
-- allowHealSpray allows aliens to combat welding and/or trigger this again by 'healing' it.

-- Good default model - models/props/generic/terminals/generic_controlpanel_01.model

class 'ControlledWeldableEmitter' (ScriptActor)

ControlledWeldableEmitter.kMapName = "controlled_weldable_emitter"

local kDefaultWeldTime = 10
local kHealSprayTimeSlice = 0.45  //Each heal spray is worth this much time.
local kWeldableMaxHealth = 10

local networkVars = 
{
	welded = "interpolated float (0 to 1 by 0.01)"
}

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ClientModelMixin, networkVars)
AddMixinNetworkVars(LiveMixin, networkVars)
AddMixinNetworkVars(TeamMixin, networkVars)
AddMixinNetworkVars(ScaleModelMixin, networkVars)
AddMixinNetworkVars(ControlledMixin, networkVars)
AddMixinNetworkVars(GameEffectsMixin, networkVars)
AddMixinNetworkVars(SelectableMixin, networkVars)

function ControlledWeldableEmitter:OnCreate() 

    ScriptActor.OnCreate(self)
	
	InitMixin(self, BaseModelMixin)
    InitMixin(self, ClientModelMixin)
	InitMixin(self, SignalListenerMixin)
	InitMixin(self, SignalEmitterMixin)
	InitMixin(self, LiveMixin)
    InitMixin(self, TeamMixin)
	InitMixin(self, SelectableMixin)
    InitMixin(self, GameEffectsMixin)
	
	-- SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil	
	
	self.commVisible = true
	self.welded = 0
	self.weldedTime = 0

end

function ControlledWeldableEmitter:OnInitialized()

    ScriptActor.OnInitialized(self)
	
	if Server then
		
		self.modelName = self.model
        
        if self.modelName ~= nil then
			-- These can get re-created midgame, check for precached model
			if Shared.GetModelIndex(self.modelName) == 0 and GetFileExists(self.modelName) then
				Shared.PrecacheModel(self.modelName)
			end
            self:SetModel(self.modelName)
        end
		
		-- This Mixin must be inited inside this OnInitialized() function.
        if not HasMixin(self, "MapBlip") then
            InitMixin(self, MapBlipMixin)
        end
		
		InitMixin(self, EEMMixin)
		self:SetTeamNumber(self.teamNumber)
		
		local mask = bit.bor(kRelevantToTeam1Unit, kRelevantToTeam2Unit, kRelevantToReadyRoom)
		if self.commVisible then
			mask = bit.bor(mask, kRelevantToTeam1Commander, kRelevantToTeam2Commander)
		end
		self:SetExcludeRelevancyMask( mask )
		self:SetRelevancyDistance(kMaxRelevancyDistance)
		
	elseif Client then
        InitMixin(self, UnitStatusMixin)
	end
	
	InitMixin(self, WeldableMixin)
	InitMixin(self, ScaleModelMixin)
	InitMixin(self, ControlledMixin)
	
	self:SetMaxHealth(kWeldableMaxHealth)
	self:SetHealth(1)
	
end

function ControlledWeldableEmitter:GetCanTakeDamageOverride()
    return false
end

function ControlledWeldableEmitter:GetCanBeHealed()
    return false
end

function ControlledWeldableEmitter:GetUsablePoints()
    return { self:GetOrigin() }
end

function ControlledWeldableEmitter:GetCanBeUsed(player, useSuccessTable)
    useSuccessTable.useSuccess = false
end

function ControlledWeldableEmitter:GetHealthbarOffset()
    return 0.6
end

function ControlledWeldableEmitter:GetUnitNameOverride(viewer)
    return "Weldable"
end

function ControlledWeldableEmitter:Reset()
    self.welded = 0
	self.weldedTime = 0
	self:SetHealth(1)
end

function ControlledWeldableEmitter:OnSetEnabled()
	if enabled then
		-- This entity needs to reset for everything to work, so if something turns in on, be sure.
		self.welded = 0
		self.weldedTime = 0
		self:SetHealth(1)
	end
end

function ControlledWeldableEmitter:GetWeldTime()
    return self.timeToWeld or kDefaultWeldTime
end

function ControlledWeldableEmitter:OnHealSpray()
    -- Hmmm
	if Server and self:GetIsEnabled() then
		local timeSlice = kHealSprayTimeSlice
		if self.weldTimeScales then
			local team = self:GetTeam()
			if team then
				timeSlice = timeSlice / team:GetNumPlayers()
			end
		end
		self.weldedTime = Clamp(self.weldedTime + timeSlice, 0, self:GetWeldTime())
		self.welded = Clamp(self.weldedTime / self:GetWeldTime(), 0, 1)
		self:SetHealth(math.max(self.welded * kWeldableMaxHealth, 1))
		if self.welded == 1 then
			self:OnWeldCompleted()
		end
	end
end

function ControlledWeldableEmitter:GetCanBeWeldedOverride(doer)
	if doer and doer.GetTeamNumber then
		return self.welded < 1 and self:GetIsEnabled(), true
	end
	return true, true
end

function ControlledWeldableEmitter:OnWeldOverride(doer, elapsedTime)
    if Server and self:GetIsEnabled() then
		if self.weldTimeScales then
			local team = self:GetTeam()
			if team then
				elapsedTime = elapsedTime / team:GetNumPlayers()
			end
		end
		self.weldedTime = Clamp(self.weldedTime + elapsedTime, 0, self:GetWeldTime())
		self.welded = Clamp(self.weldedTime / self:GetWeldTime(), 0, 1)
		self:SetHealth(math.max(self.welded * kWeldableMaxHealth, 1))
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
	self:SetIsEnabled(false)
end

Shared.LinkClassToMap("ControlledWeldableEmitter", ControlledWeldableEmitter.kMapName, networkVars)