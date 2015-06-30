// 
// 
// lua\ControlledMixin.lua
// - Dragon

ControlledMixin = CreateMixin(ControlledMixin)
ControlledMixin.type = "Controlled"

//Allows enabling/disabling of interactable entities.  Uses initial enable flag from map, defaults to true.
//Also uses resetOnTrigger to determine change after trigger, defaults to true.

ControlledMixin.networkVars =
{
    enabled = "boolean"
}

function ControlledMixin:__initmixin()
	if self.enabled == nil then
		self.enabled = true
	end
	if self.resetOnTrigger == nil then
		self.resetOnTrigger = true
	end
	self.initialSetting = self.enabled
end

function ControlledMixin:GetIsEnabled()
    return self.enabled
end

function ControlledMixin:Reset()
	self.enabled = self.initialSetting
end

function ControlledMixin:SetIsEnabled(enabled)
	assert(type(enabled) == "boolean")
    self.enabled = enabled
	if enabled and self.OnSetEnabled then
		self:OnSetEnabled()
	end
end

function ControlledMixin:EmitSignal(channel, message)
	//Dont care about signal here.  Can only emit if enabled...
	if self.resetOnTrigger then
		self:Reset()
	else
		self.enabled = false
	end
end