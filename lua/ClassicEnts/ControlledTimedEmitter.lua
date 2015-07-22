// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ControlledTimedEmitter.lua
// - Dragon

Script.Load("lua/Mixins/SignalEmitterMixin.lua")
Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")

//Triggers on emitChannel after emitTime seconds.  Reset on GameReset.  emitOnce determines if object is reset automatically on triggering.
//enable will set initial state on map load, and after resets.

class 'ControlledTimedEmitter' (Entity)

ControlledTimedEmitter.kMapName = "controlled_timed_emitter"

local kDefaultEmitTime = 10

local networkVars = { }

local function UpdateEmitTime(self, deltaTime)

	if self:GetIsEnabled() then
		local t = Shared.GetTime()
		if not deltaTime then
			deltaTime = t - self.lastUpdate
		end
		
		self.totalTime = self.totalTime + deltaTime
		
		if self.totalTime >= self:GetEmitTime() then
			//Trigger
			self:EmitSignal(self.emitChannel, self.emitMessage)
			if self.emitOnce then
				self.enabled = false
			else
				self.totalTime = 0
			end
		end
		
		self.lastUpdate = t
	end
	
	return true
end

function ControlledTimedEmitter:OnCreate() 

    Entity.OnCreate(self)
	
	InitMixin(self, SignalListenerMixin)
	InitMixin(self, SignalEmitterMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	self:SetPropagate(Entity.Propagate_Never)
	self:SetUpdates(true)
	
	self.lastUpdate = Shared.GetTime()
	self.totalTime = 0
	
	self:AddTimedCallback(UpdateEmitTime, 1)

end

function ControlledTimedEmitter:OnInitialized()

    Entity.OnInitialized(self)
	InitMixin(self, ControlledMixin)
	InitMixin(self, EEMMixin)

end

function ControlledTimedEmitter:Reset()
	self.totalTime = 0
	self.lastUpdate = Shared.GetTime()
end

function ControlledTimedEmitter:OnSetEnabled()
	if enabled then
		//This entity needs to reset for everything to work, so if something turns in on, be sure.
		self.totalTime = 0
		self.lastUpdate = Shared.GetTime()
	end
end

function ControlledTimedEmitter:GetEmitTime()
	return self.emitTime or kDefaultEmitTime
end

Shared.LinkClassToMap("ControlledTimedEmitter", ControlledTimedEmitter.kMapName, networkVars)