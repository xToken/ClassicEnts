// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\DialogListener.lua
// - Dragon

Script.Load("lua/Mixins/SignalListenerMixin.lua")
Script.Load("lua/ClassicEnts/EEMMixin.lua")

class 'DialogListener' (Entity)

DialogListener.kMapName = "dialog_listener"

local kDialogGUIScript = "ttt"
local kDialogDefaultDisplayTime = 2

local kClientDialogData = { }

local networkVars = 
{ 
	// replace m_origin
    m_origin = "interpolated position (by 1000 [0 0 0], by 1000 [0 0 0], by 1000 [0 0 0])",
    // replace m_angles
    m_angles = "interpolated angles (by 10 [0], by 10 [0], by 10 [0])",
	dialogChannel = "integer"
}

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

local function TriggerListener(self)
	self:SetRelevancyDistance(Math.infinity)
	self:AddTimedCallback(DisableListener, self.showGUITime)
	//Add callback to turn off.
end

function DialogListener:OnCreate() 

    Entity.OnCreate(self)
	
	InitMixin(self, SignalListenerMixin)
	
	//SignalMixin sets this on init, but I need to confirm its set on ent.
	self.listenChannel = nil
	
	self:SetUpdates(false)
	self:SetRelevancyDistance(Entity.Propagate_Never)
	
	if Server then
		self:RegisterSignalListener(function() TriggerListener(self) end)
		self.dialogChannel = 0
		self.teamNumber = 0
	end

end

function DialogListener:Reset()
	self:SetRelevancyDistance(Entity.Propagate_Never)
end

function DialogListener:OnInitialized()

    Entity.OnInitialized(self)
	
	if Server then
	
		InitMixin(self, EEMMixin)
		
		self.dialogChannel = RegisterClientDialogData(self.dialogText)
		
		if self.teamNumber == 1 then
			self:SetIncludeRelevancyMask(kRelevantToTeam1)
		elseif self.teamNumber == 2 then
			self:SetIncludeRelevancyMask(kRelevantToTeam2)
		end
		
	end
	
	self.dialogTime = self.dialogTime or kDialogDefaultDisplayTime

	//These are created as non-relevant to everything.  Once enabled, they become relevant to Clients
	if Client then
		//Create GUI or whatever, display dialog
		//This is cheated into teammessages atm
		local player = Client.GetLocalPlayer()
		if player and HasMixin(player, "TeamMessage") then
			player:SetTeamMessage(RetrieveClientDialogData(self.dialogChannel))
		end
		
	end
	
end

if Client then

	function BreakableEmitter:OnDestroy()
		Entity.OnDestroy(self)
		//Cleanup GUI
	end
	
end

Shared.LinkClassToMap("DialogListener", DialogListener.kMapName, networkVars)