// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ControlledButtonEmitter.lua
// - Dragon

Script.Load("lua/ScriptActor.lua")
Script.Load("lua/Mixins/ClientModelMixin.lua")
Script.Load("lua/Mixins/SignalEmitterMixin.lua")
Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/UsableMixin.lua")
Script.Load("lua/ClassicEnts/ScaleModelMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")

//In terms of function, these are very similar to ButtonEmitter.  However, these support being disabled/enabled, and more crucially support a model.
//In terms of mapping effort its really not logical to use your button entity as the model, you would simply use a prop and position the button entity inside.
//However this could be used to have animations and/or such effects for buttons also... however at this time I dont think thats done.

//Uses values from ControlledMixin, also uses cooldown for delay between uses, allowedTeam for an allowed team number (0 = anyteam).
//Emits on emitChannel when pushed, can be toggled on/off using listenChannel.  Can also use resetOnTrigger to make useable once.

//Good default model - models/props/generic/terminals/generic_controlpanel_02.model

class 'ControlledButtonEmitter' (ScriptActor)

ControlledButtonEmitter.kMapName = "controlled_button_emitter"

local kDefaultCooldown = 0.5 //Prevent spammage a bit.

local networkVars = 
{
	cooldown = "integer",
	timeLastUsed = "time",
	allowedTeam = string.format("integer (-1 to %d)", kSpectatorIndex)
}

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ClientModelMixin, networkVars)
AddMixinNetworkVars(ScaleModelMixin, networkVars)
AddMixinNetworkVars(ControlledMixin, networkVars)

function ControlledButtonEmitter:OnCreate() 

    ScriptActor.OnCreate(self)
	
	InitMixin(self, BaseModelMixin)
    InitMixin(self, ClientModelMixin)
	InitMixin(self, SignalListenerMixin)
	InitMixin(self, SignalEmitterMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	self:SetUpdates(false)
	self:SetRelevancyDistance(kMaxRelevancyDistance)
	
	self.timeLastUsed = 0
	self.cooldown = 0
	self.allowedTeam = 0

end

function ControlledButtonEmitter:OnInitialized()

    ScriptActor.OnInitialized(self)
	
	InitMixin(self, ControlledMixin)
	
	if Server then

		self.modelName = self.model
        
        if self.modelName ~= nil then
			//These can get re-created midgame, check for precached model
			if Shared.GetModelIndex(self.modelName) == 0 and GetFileExists(self.modelName) then
				Shared.PrecacheModel(self.modelName)
			end
            self:SetModel(self.modelName)
        end
	
		InitMixin(self, EEMMixin)

	end

	InitMixin(self, ScaleModelMixin)
	
end

function ControlledButtonEmitter:Reset()
	//Jic realllly long cooldown
	self.timeLastUsed = 0
end

function ControlledButtonEmitter:GetUsablePoints()
    return { self:GetOrigin() }
end

function ControlledButtonEmitter:GetCooldown()
    return self.cooldown or kDefaultCooldown
end

function ControlledButtonEmitter:GetAllowedTeam()
    return self.allowedTeam or 0
end

function ControlledButtonEmitter:GetCanBeUsed(player, useSuccessTable)
	local teamNumber = player:GetTeamNumber()
    useSuccessTable.useSuccess = self:GetIsEnabled() and self.timeLastUsed + self:GetCooldown() <= Shared.GetTime() and (self:GetAllowedTeam() == 0 or self:GetAllowedTeam() == teamNumber)
end

function ControlledButtonEmitter:OnUse(player, elapsedTime, useAttachPoint, usePoint, useSuccessTable)
	//Trigger, basic validation
	if Server then
		self:EmitSignal(self.emitChannel, self.emitMessage)
		self.timeLastUsed = Shared.GetTime()
	end
end

Shared.LinkClassToMap("ControlledButtonEmitter", ControlledButtonEmitter.kMapName, networkVars)