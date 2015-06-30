// 
// 
// lua\ExtendedSignals.lua
// - Dragon

// This extends the vanilla channel/message system to add compatibility with the EEM style system.
// Lookup target and provided names to provided channels as needed.  Start above a certain constant to avoid any problems with vanilla maps (hopefully)

Script.Load("lua/Mixins/SignalEmitterMixin.lua")
Script.Load("lua/Mixins/SignalListenerMixin.lua")

local kExtendedStartingChannel = 255  //Starts one above this technically.
local kRegisteredExtendedChannels = { }

local function LookupExtendedChannelByName(name)
	for i = 1, #kRegisteredExtendedChannels do
		if kRegisteredExtendedChannels[i] == name then
			return kExtendedStartingChannel + i
		end
	end
	assert(false)
end

function LookupOrRegisterExtendedChannelToName(name)
	assert(name ~= nil and name ~= "")
	//Check to see if already registered.  Cannot be certain about load orders and want to make sure these get setup correctly.
	if table.contains(kRegisteredExtendedChannels, name) then
		return LookupExtendedChannelByName(name)
	end
	table.insert(kRegisteredExtendedChannels, name)
	return kExtendedStartingChannel + #kRegisteredExtendedChannels
end

//Allow for global emitters/listeners
function SignalEmitterMixin:EmitSignal(channel, message)
	local listeners = GetEntitiesWithMixin("SignalListener")
	for _, listener in ipairs(listeners) do
		local inRange = (listener:GetOrigin() - self:GetOrigin() ):GetLengthSquaredXZ() <= (self.signalRange * self.signalRange)
		if listener:GetListenChannel() == channel and (listener:GetIsGlobalListener() or self:GetIsGlobalEmitter() or inRange) then
			listener:OnSignal(message)
		end
		
	end
end

//These seem like basic utility functions, no reason they are not part of the mixin.
function SignalEmitterMixin:SetEmitChannel(setChannel)

    assert(type(setChannel) == "number")
    assert(setChannel >= 0)
    self.emitChannel = setChannel
    
end

function SignalEmitterMixin:SetEmitMessage(setMessage)

    assert(type(setMessage) == "string")
    self.emitMessage = setMessage
    
end

function SignalEmitterMixin:GetIsGlobalEmitter()
	if self.globalEmitter and self.globalEmitter == true then
		return true
	end
	return false
end

function SignalListenerMixin:GetIsGlobalListener()
	if self.globalListener and self.globalListener == true then
		return true
	end
	return false
end