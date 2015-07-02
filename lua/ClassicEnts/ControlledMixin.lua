// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ControlledMixin.lua
// - Dragon

ControlledMixin = CreateMixin(ControlledMixin)
ControlledMixin.type = "Controlled"

//Allows enabling/disabling of interactable entities.  Uses initial enable flag from map, defaults to true.
//disableOnNotify & enableOnNotify determine what happens when this receives a signal.
//

ControlledMixin.networkVars =
{
    enabled = "boolean"
}

function ControlledMixin:__initmixin()
	if self.enabled == nil then
		self.enabled = true
	end
	self.disableOnNotify = false
	self.enableOnNotify = false
	self.initialSetting = self.enabled
	
	self:RegisterSignalListener(function() self:OnReceiveSignal() end)
end

function ControlledMixin:GetIsEnabled()
    return self.enabled
end

function ControlledMixin:Reset()
	self.enabled = self.initialSetting
end

function ControlledMixin:OnReceiveSignal()
    if self.OverrideListener then
		self:OverrideListener()
	else
		if self.disableOnNotify then
			//disable
			self.enabled = false
		elseif self.enableOnNotify then
			//enable
			self.enabled = true		
		else
			//Default toggle
			self.enabled = not self.enabled
		end
	end
end

function ControlledMixin:SetIsEnabled(enabled)
	assert(type(enabled) == "boolean")
    self.enabled = enabled
	if enabled and self.OnSetEnabled then
		self:OnSetEnabled()
	end
end