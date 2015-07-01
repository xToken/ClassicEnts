// 
// 
// lua\EmitterMultiplier.lua
// - Dragon

Script.Load("lua/Mixins/SignalEmitterMixin.lua")
Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")

class 'EmitterMultiplier' (Entity)

EmitterMultiplier.kMapName = "emitter_multiplier"

//In terms of the Emitter/Listener, these are not needed.  However EEM used names, so multiple output channels were created to multiply signals.
//Use these to adapt to new system.  Realistically, once these are created they can be destroyed, but I doubt they will impact perf in a measurable
//way if done correctly.

local networkVars = { }

local function TriggerAllChildren(self)
	if self.emitChannels then
		for i = 1, #self.emitChannels do
			self:EmitSignal(self.emitChannels[i], self.emitMessage)
		end
	elseif self.emitChannel then
		self:EmitSignal(self.emitChannel, self.emitMessage)
	end
end

function EmitterMultiplier:OnCreate() 

    Entity.OnCreate(self)
	
	InitMixin(self, SignalEmitterMixin)
	InitMixin(self, SignalListenerMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	self:SetPropagate(Entity.Propagate_Never)
    self:SetUpdates(false)
	
	self:RegisterSignalListener(function() TriggerAllChildren(self) end)

end

function EmitterMultiplier:OnInitialized()

    Entity.OnInitialized(self)
	
	InitMixin(self, EEMMixin)
	
end

Shared.LinkClassToMap("EmitterMultiplier", EmitterMultiplier.kMapName, networkVars)