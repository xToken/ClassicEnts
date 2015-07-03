// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ControlledDialogListener.lua
// - Dragon

Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")
Script.Load("lua/ClassicEnts/ControlledMixin.lua")

class 'ControlledDialogListener' (Entity)

ControlledDialogListener.kMapName = "controlled_dialog_listener"

local kDialogGUIScript = "ttt"
local kDialogDefaultDisplayTime = 2
local kLocalizedDisplayRange = 2

local kClientDialogData = { }

local networkVars = 
{ 
	dialogChannel = "integer"
}

AddMixinNetworkVars(ControlledMixin, networkVars)

function RegisterClientDialogData(text)
	table.insert(kClientDialogData, text)
	return #kClientDialogData
end

function RetrieveClientDialogData(channel)
	return kClientDialogData[channel]
end

local function DisableListener(self)
	self:SetRelevancyDistance(Entity.Propagate_Never)
end

function ControlledDialogListener:OnCreate() 

    Entity.OnCreate(self)
	
	InitMixin(self, SignalListenerMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	
	if Server then
		self.dialogChannel = 0
		self.teamNumber = 0
	end
	
	self:SetUpdates(false)
	self:SetRelevancyDistance(Entity.Propagate_Never)

end

function ControlledDialogListener:OnInitialized()

    Entity.OnInitialized(self)
	
	InitMixin(self, ControlledMixin)
	
	if Server then
	
		InitMixin(self, EEMMixin)
		
		self.dialogChannel = RegisterClientDialogData(self.dialogText)
		
		if self.teamNumber == 1 then
			self:SetIncludeRelevancyMask(kRelevantToTeam1)
		elseif self.teamNumber == 2 then
			self:SetIncludeRelevancyMask(kRelevantToTeam2)
		end
		
		if self.localDialog then
			self:SetRelevancyDistance(kLocalizedDisplayRange)
		end
		
	end
	
	self.dialogTime = self.dialogTime or kDialogDefaultDisplayTime

	//These are created as non-relevant to everything.  Once enabled, they become relevant to Clients
	if Client and self:GetIsEnabled() then
		//Create GUI or whatever, display dialog
		//This is cheated into teammessages atm
		local player = Client.GetLocalPlayer()
		if player and HasMixin(player, "TeamMessage") and RetrieveClientDialogData(self.dialogChannel) then
			player:SetTeamMessage(RetrieveClientDialogData(self.dialogChannel))
		end
		
	end
	
end

function ControlledDialogListener:OverrideListener()
	if not self.localDialog then
		self:SetRelevancyDistance(Math.infinity)
		self:AddTimedCallback(DisableListener, self.dialogTime)
		//Add callback to turn off.
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

function ControlledDialogListener:Reset()
	if not self.localDialog then
		self:SetRelevancyDistance(Entity.Propagate_Never)
	end
end

if Client then

	function BreakableEmitter:OnDestroy()
		Entity.OnDestroy(self)
		//Cleanup GUI
	end
	
end

Shared.LinkClassToMap("ControlledDialogListener", ControlledDialogListener.kMapName, networkVars)