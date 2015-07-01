// 
// 
// lua\FunctionListener.lua
// - Dragon

Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")

class 'FunctionListener' (Entity)

//This can be expanded to have additional in game effects triggereable.

FunctionListener.kMapName = "function_listener"

local networkVars = {  }

local function TriggerListener(self)
	if self.functionOperation == 0 then
        Print("Test")
	end
end

function FunctionListener:OnCreate() 

    Entity.OnCreate(self)
	
	InitMixin(self, SignalListenerMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	self:SetUpdates(false)
	self:SetRelevancyDistance(Entity.Propagate_Never)
	
	self:RegisterSignalListener(function() TriggerListener(self) end)

end

function FunctionListener:OnInitialized()

    Entity.OnInitialized(self)
	
	InitMixin(self, EEMMixin)
	
end

Shared.LinkClassToMap("FunctionListener", FunctionListener.kMapName, networkVars)