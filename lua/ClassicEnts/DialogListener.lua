// 
// 
// lua\DialogListener.lua
// - Dragon

Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")

class 'DialogListener' (Entity)

DialogListener.kMapName = "dialog_listener"

local kMaxDialogNameLength = 31

local kClientDialogData = { }

local networkVars = 
{ 
	// replace m_origin
    m_origin = "interpolated position (by 1000 [0 0 0], by 1000 [0 0 0], by 1000 [0 0 0])",
    // replace m_angles
    m_angles = "interpolated angles (by 10 [0], by 10 [0], by 10 [0])",
	dialogName = "string (" .. kMaxDialogNameLength .. ")",
}

AddMixinNetworkVars(ControlledMixin, networkVars)

local function TriggerDialog(self)

end

function DialogListener:OnCreate() 

    Entity.OnCreate(self)
	
	InitMixin(self, SignalListenerMixin)
	
	self:SetUpdates(false)
	self:SetRelevancyDistance(Math.infinity)
	
	if Server then
		self:RegisterSignalListener(function() TriggerDialog(self) end)
	end

end

function DialogListener:OnInitialized()

    Entity.OnInitialized(self)
	
	if Server then
		InitMixin(self, EEMMixin)
	end
	
	//self.dialogName = string.sub(self.name, 0, kMaxDialogNameLength)
	self.dialogName =  "potato"
	
end


Shared.LinkClassToMap("DialogListener", DialogListener.kMapName, networkVars)