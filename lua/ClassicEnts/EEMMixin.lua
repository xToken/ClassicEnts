// 
// 
// lua\EEMMixin.lua
// - Dragon

EEMMixin = CreateMixin(EEMMixin)
EEMMixin.type = "EEMMixin"

//This extends an entity to allow compatibility with Extra Entities Mod.  This will convert ALL EEM properties from an entity to
//corresponding values to work with vanilla style systems.  This automatically registers listenChannels and emitChannels for EEM entities.
//Since EEM used names, cannot be sure that entities are in close proximity.  Always register as global.

EEMMixin.networkVars = { }

function EEMMixin:__initmixin()

	self.emitChannels = { }

    //The EEM name becomes the listenChannel, if not set
	//Objects should ALWAYS have a name IMO
	if not self.listenChannel or self.listenChannel == 0 then
		if not self.name or self.name == "" then
			//fake set name to entID
			self.name = self:GetId()
		end
		self.listenChannel = LookupOrRegisterExtendedChannelToName(self.name)
		self.globalListener = true
	end
	
	//Support EEM 'train' waypoints
	if self.trainName and not self.parentName then
		self.parentName = self.trainName
	end
	
	//These become the emit channels.  EEM seems to have supported up to 10.
	for i = 1, 10 do
		local output = "output" .. ToString(i)
		if self[output] and self[output]~= "" then
			table.insert(self.emitChannels, LookupOrRegisterExtendedChannelToName(self[output]))
			self.globalEmitter = true
		end
	end
	
	//EEM Cooldown
	if self.coolDownTime then
		self.cooldown = math.floor(self.coolDownTime)
	end
	
	//EEM AllowedTeam
	if self.teamNumber then
		self.allowedTeam = Clamp(math.floor(self.teamNumber), 0, kSpectatorIndex)
	end
	
	//EEM TeamType?  not doing anything with this ATM.
	//self.teamType
	
	//EEM TriggerAction
	//self.onTriggerAction - Seems to be used to handle disabling on use - 0 = Toggle, 1 - Always on, 2 - Turn Off.  Default will turn trigger off.
	//Triggers cant be triggered if off, so toggle is sorta moot.
	if self.onTriggerAction then
		self.resetOnTrigger = self.onTriggerAction == 1
	end
	
	//EEM ShowGUI
	//self.showGUI - Will show optional client side GUI for this object.
	
	//EEM Timer Action - Handles how timers reset after triggering.  0 = disables, 1 = reset, 2 = reset also?
	if self.onTimeAction and not self.resetOnTrigger then
		self.resetOnTrigger = self.onTimeAction == 1 or self.onTimeAction == 2
	end
	
	//EEM Timer delay - How long into the round that a timer takes to trigger.
	if self.waitDelay then
		self.timerDelay = self.waitDelay
	end
	
	//EEM MoveSpeed
	if self.moveSpeed then
		self.speed = self.moveSpeed
	end
	
	//EEM IsDoor - looks to be used only for startsOpened check, and automatic opening/closing callback.  EEM doors always open/close automatically.
	if self.isDoor then
		self.objectType = ControlledMoveable.kObjectTypes.Door
		self.autoTrigger = self.enabled and self.enabled == true
	end
	
	//EEM Direction - numerical translation to how moveable objects.. move.  0 = up, 1-= down, 2 = east, 3 = west (I THINK), 4 = Use waypoints
	//Realistically this is kinda sloppy, everything should just use waypoints for greater control, but need to support what exists
	if self.direction then
		local waypointOrigin = self:GetOrigin()
		//Lookup extents, EEM moved the object the entirety of its extents
		local extents = self.scale or Vector(1, 1, 1)
		if self.model then
			_, extents = Shared.GetModel(Shared.GetModelIndex(self.model)):GetExtents(self.boneCoords)        
		end
		if self.direction == 0 then
			waypointOrigin.y = extents.y
		elseif  self.direction == 1 then 
			waypointOrigin.y = -extents.y
		elseif  self.direction == 2 then
			local directionVector = AnglesToVector(self)
			waypointOrigin.x = directionVector.z * -extents.x
			waypointOrigin.z = directionVector.x * extents.x
			//directionVector
		elseif  self.direction == 3 then
			local directionVector = AnglesToVector(self)
			waypointOrigin.x = directionVector.z * extents.x
			waypointOrigin.z = directionVector.x * -extents.x
		end
		if waypointOrigin ~= self:GetOrigin() then
			//We dont want to malform this.  To make this as seemless as possible, just create a fake 'waypoint' for this door.
			local entity = Server.CreateEntity("pathing_waypoint", { origin = waypointOrigin, parentName = self.name })
            if entity then
				entity:SetMapEntity()
				self.directionWaypointId = entity:GetId()
			end
		end
		
	end
		
	//EEM StartsOpened - this makes little sense logically, only ref checks if object is also not a door..  In good design this should really never exist.
	//Object should just be set to inverse direction movement.  But need to support this most likely for 'gates'
	//Hack this a bit for now.  Base moveable class sets up its 'home' waypoint after this is initialized.
	if self.startsOpened and not self.objectType == ControlledMoveable.kObjectTypes.Door then
		if self.directionWaypointId and Shared.GetEntity(self.directionWaypointId) then
			local waypoint = Shared.GetEntity(self.directionWaypointId)
			if waypoint then
				local newOrigin = waypoint:GetOrigin()
				local waypointOrigin = self:GetOrigin()
				waypoint:SetOrigin(waypointOrigin)
				self:SetOrigin(newOrigin)
			end
		end
	end
	
	//EEM Also supports a basic dialogue GUI system...  How these are handled doesnt exact make complete sense to me, they could just be client side ents.
	//But we need to work with what is already in play...
	//Actual TEXT length is networked as 1000 character string, going to try to hack those values in client side.
	//Hack in .sound for the Client, .text, .characterName and .iconDisplay
	
	if self.fadeIn then
		self.guiFadeIn = self.fadeIn
	end
	
	if self.fadeOut then
		self.guiFadeOut = self.fadeOut
	end
	
	if self.repeats then
		self.repeating = self.repeats
	end
	
	//Why have a GUI if it would never be shown?
	if self.showOnScreen then
		self.showGUIOnScreen = self.showOnScreen
	end
	
	//How long GUI is onscreen
	if self.displayTime then
		self.showGUITime = self.displayTime
	end
	
	//Might be a siege only property here
	//scaleWeldTimeOnTeamSize
	
	if self.weldTime then
		self.timeToWeld = self.weldTime
	end
	
	//Translate output1 as the main 'emit channel'.
	if self.output1 and self.output1 ~= "" and not self.emitChannel then
		self.emitChannel = LookupOrRegisterExtendedChannelToName(self.output1)
		self.globalEmitter = true
	end
	
	//Translation table sets oldMapNames, use this to do some basic checks
	if self.oldMapName == "frontdoor" then
		self.objectType = ControlledMoveable.kObjectTypes.Gate
		//Automatically Add timer entity to open this door.
		local entity = Server.CreateEntity("controlled_timed_emitter", { origin = self:GetOrigin(), emitChannel = self.listenChannel, timerDelay = kFrontDoorEntityTimer, resetOnTrigger = false, name = ToString(self.name .. "_timer"), enabled = true })
		if entity then
			entity:SetMapEntity()
		end
		self.autoTrigger = false
	end
	
	if self.oldMapName == "siegedoor" then
		self.objectType = ControlledMoveable.kObjectTypes.Gate
		local entity = Server.CreateEntity("controlled_timed_emitter", { origin = self:GetOrigin(), emitChannel = self.listenChannel, timerDelay = kSiegeDoorEntityTimer, resetOnTrigger = false, name = ToString(self.name .. "_timer"), enabled = true })
		if entity then
			entity:SetMapEntity()
		end
		self.autoTrigger = false
	end
	
	if self.oldMapName == "func_platform" then
		self.objectType = ControlledMoveable.kObjectTypes.Elevator
	end
	
end

function EEMMixin:OnDestroy()
    if self.directionWaypointId and Shared.GetEntity(self.directionWaypointId) then
		DestroyEntity(Shared.GetEntity(self.directionWaypointId))
		self.directionWaypointId = nil
	end
end