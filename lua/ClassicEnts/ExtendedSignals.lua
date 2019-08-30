-- Natural Selection 2 'Classic Entities Mod'
-- Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
-- Designed to work with maps developed for Extra Entities Mod.  
-- Source located at - https://github.com/xToken/ClassicEnts
-- lua\ExtendedSignals.lua
-- Dragon

-- This extends the vanilla channel/message system to add compatibility with the EEM style system.
-- Lookup target and provided names to provided channels as needed.  Start above a certain constant to avoid any problems with vanilla maps (hopefully)

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
end

function LookupOrRegisterExtendedChannelToName(name)
	assert(name ~= nil and name ~= "")
	-- Check to see if already registered.  Cannot be certain about load orders and want to make sure these get setup correctly.
	if table.contains(kRegisteredExtendedChannels, name) then
		--Shared.Message(string.format("Associating %s name to channel %s.", name, LookupExtendedChannelByName(name)))
		return LookupExtendedChannelByName(name)
	end
	table.insert(kRegisteredExtendedChannels, name)
	--Shared.Message(string.format("Registering %s name to channel %s.", name, kExtendedStartingChannel + #kRegisteredExtendedChannels))
	return kExtendedStartingChannel + #kRegisteredExtendedChannels
end

-- Allow for global emitters/listeners
function SignalEmitterMixin:EmitSignal(channel, message)
	local listeners = GetEntitiesWithMixin("SignalListener")
	for _, listener in ipairs(listeners) do
		local inRange = (listener:GetOrigin() - self:GetOrigin() ):GetLengthSquaredXZ() <= (self.signalRange * self.signalRange)
		if listener:GetListenChannel() == channel and (listener:GetIsGlobalListener() or self:GetIsGlobalEmitter() or inRange) then
			if gDebugClassicEnts then
				Shared.Message(string.format("Signalling %s entity %s class for channel %s.", listener:GetId(), listener:GetClassName(), channel))
			end
			listener:OnSignal(message)
		end
		
	end
end

-- These seem like basic utility functions, no reason they are not part of the mixin.
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