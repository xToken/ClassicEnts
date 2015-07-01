// 
// 
// lua\EEMMixin.lua
// - Dragon

EEMMixin = CreateMixin(EEMMixin)
EEMMixin.type = "EEMMixin"

//This extends an entity to allow compatibility with Extra Entities Mod.  This will convert ALL EEM properties from an entity to
//corresponding values to work with vanilla style systems.  This automatically registers listenChannel and emitChannels for EEM entities.
//Since EEM used names, cannot be sure that entities are in close proximity.  Always register as global.

EEMMixin.networkVars = { }

local function StartsOpenedCallback(self)
	//Need to account for when the startsOpened flag is set, and waypoint is actually created like it should be.. derp.
	local updated = false
	local waypoints = LookupPathingWaypoints(self.name)
	//Grab first waypoint, invert this moveable and it.
	if waypoints and waypoints[1] and waypoints[1].entId then
		local newOrigin = waypoints[1].origin
		local waypointOrigin = self:GetOrigin()
		local waypoint = Shared.GetEntity(waypoints[1].entId)
		if waypoint then
			waypoint:SetOrigin(waypointOrigin)
			self:SetOrigin(newOrigin)
			updated = true
			//Update Table
			AddPathingWaypoint(self.name, "home", newOrigin, -1, self:GetId())
			UpdateWaypointOrigin(self.name, waypoint:GetId(), waypointOrigin)
		end
	end
	if not updated then
		Shared.Message(string.format("Failed to set door %s to Open state.", self.name))
	end
	return false
end

local function BuildPathingEntityFromDirection(self, direction)
	local waypointOrigin = self:GetOrigin()
	//Lookup extents, EEM moved the object the entirety of its extents
	local extents = self.scale or Vector(1, 1, 1)
	if self.model then
		_, extents = Shared.GetModel(Shared.GetModelIndex(self.model)):GetExtents(self.boneCoords)  
	end
	if direction == 0 then
		waypointOrigin.y = waypointOrigin.y + (extents.y * self.scale.y)
	elseif direction == 1 then 
		waypointOrigin.y = waypointOrigin.y - (extents.y * self.scale.y)
	elseif direction == 2 then
		local directionVector = AnglesToVector(self)
		waypointOrigin.x = waypointOrigin.x + (directionVector.z * -extents.x)
		waypointOrigin.z = waypointOrigin.z + (directionVector.x * extents.x)
		//directionVector
	elseif direction == 3 then
		local directionVector = AnglesToVector(self)
		waypointOrigin.x = waypointOrigin.x + (directionVector.z * extents.x)
		waypointOrigin.z = waypointOrigin.z + (directionVector.x * -extents.x)
	end
	if waypointOrigin ~= self:GetOrigin() then
		//We dont want to malform this.  To make this as seemless as possible, just create a fake 'waypoint' for this door.
		local entity = Server.CreateEntity("pathing_waypoint", { origin = waypointOrigin, moveableName = self.name })
		if entity then
			entity:SetMapEntity()
			self.directionWaypointId = entity:GetId()
		end
	end
end

local function CheckRequiredSiegeDoorEntities(self, doorTime)
	//Check waypoints
	local waypoints = LookupPathingWaypoints(self.name)
	if #waypoints == 1 then
		//Missing waypoint, gen default up waypoint
		BuildPathingEntityFromDirection(self, 0)
		Shared.Message(string.format("Building default up waypoint for %s as no valid waypoints provided in map.", self.name))
	end
	//Check triggers
	local matching = false
	for index, entity in ientitylist(Shared.GetEntitiesWithTag("SignalEmitter")) do
		if entity.emitChannel == self.listenChannel then
			matching = true
		elseif entity.emitChannels then
			for i = 1, #entity.emitChannels do
				if entity.emitChannels[i] == self.listenChannel then
					matching = true
				end
			end
		end
		if matching then
			break
		end
	end
	if not matching then
		//Missing trigger, add basic timer
		local entity = Server.CreateEntity("controlled_timed_emitter", { origin = self:GetOrigin(), emitChannel = self.listenChannel, timerDelay = doorTime, resetOnTrigger = false, name = ToString(self.name .. "_timer"), enabled = true })
		if entity then
			entity:SetMapEntity()
		end
		Shared.Message(string.format("Building timer for %s as no valid triggers provided in map.", self.name))
	end
	return false
end

function EEMMixin:__initmixin()

    //Objects should ALWAYS have a name IMO
	if self.name == nil or self.name == "" then
		//fake set name to entID
		self.name = self:GetId()
	end
	
	//The EEM name becomes the listenChannel, if not set
	if not self.listenChannel then
		self.listenChannel = LookupOrRegisterExtendedChannelToName(self.name)
		self.globalListener = true
	end
	
	//Support EEM 'train' waypoints
	if self.trainName ~= nil and self.trainName ~= "" then
		self.moveableName = self.trainName
	end
	
	//EEM Cooldown
	if self.coolDownTime ~= nil then
		self.cooldown = math.floor(self.coolDownTime)
	end
	
	//EEM AllowedTeam
	if self.teamNumber ~= nil then
		self.allowedTeam = Clamp(math.floor(self.teamNumber), 0, kSpectatorIndex)
	end
	
	//EEM TeamType?  not doing anything with this ATM.
	//self.teamType
	
	//EEM TriggerAction
	//self.onTriggerAction - Seems to be used to handle disabling on use - 0 = Toggle, 1 - Always on, 2 - Turn Off.  Default will turn trigger off.
	//Triggers cant be triggered if off, so toggle is sorta moot.
	if self.onTriggerAction ~= nil then
		if self.onTriggerAction == 2 then
			self.disableOnNotify = true
		elseif self.onTriggerAction == 2 then
			self.enableOnNotify = true
		end
	end
	
	//EEM ShowGUI
	//self.showGUI - Will show optional client side GUI for this object.
	
	//EEM Timer Action - Handles how timers reset after triggering.  0 = disables, 1 = reset, 2 = reset also?
	if self.onTimeAction ~= nil and not self.resetOnTrigger then
		self.resetOnTrigger = self.onTimeAction == 1 or self.onTimeAction == 2
	end
	
	//EEM Timer delay - How long into the round that a timer takes to trigger.
	if self.waitDelay ~= nil then
		self.timerDelay = self.waitDelay
	end
	
	//EEM MoveSpeed
	if self.moveSpeed ~= nil then
		self.speed = self.moveSpeed
	end
	
	//EEM Direction - numerical translation to how moveable objects.. move.  0 = up, 1-= down, 2 = east, 3 = west (I THINK), 4 = Use waypoints
	//Realistically this is kinda sloppy, everything should just use waypoints for greater control, but need to support what exists
	if self.direction ~= nil then
		BuildPathingEntityFromDirection(self, self.direction)
	end
	
	//EEM Also supports a basic dialogue GUI system...  How these are handled doesnt exact make complete sense to me, they could just be client side ents.
	//But we need to work with what is already in play...
	//Actual TEXT length is networked as 1000 character string, going to try to hack those values in client side.
	//Hack in .sound for the Client, .text, .characterName and .iconDisplay
	
	if self.fadeIn ~= nil then
		self.guiFadeIn = self.fadeIn
	end
	
	if self.fadeOut ~= nil then
		self.guiFadeOut = self.fadeOut
	end
	
	if self.repeats ~= nil then
		self.repeating = self.repeats
	end
	
	//Why have a GUI if it would never be shown?
	if self.showOnScreen ~= nil then
		self.showGUIOnScreen = self.showOnScreen
	end
	
	//How long GUI is onscreen
	if self.displayTime ~= nil then
		self.showGUITime = self.displayTime
	end
	
	//Might be a siege only property here
	if self.scaleWeldTimeOnTeamSize ~= nil then
		self.weldTimeScales = self.scaleWeldTimeOnTeamSize
	end
	
	if self.weldTime ~= nil then
		self.timeToWeld = self.weldTime
	end
	
	//EEM callFunction - controls what happens when function listener is trigger.
	if self.callFunction ~= nil then
		self.functionOperation = self.callFunction
	end
	
	//Translate output1 as the main 'emit channel'.  If output1 etc are used, I should always use them right..?
	if self.output1 ~= nil and self.output1 ~= "" then
		self.emitChannel = LookupOrRegisterExtendedChannelToName(self.output1)
		self.globalEmitter = true
	end
	
	//These become the emit channels.  EEM seems to have supported up to 10.
	for i = 1, 10 do
		local output = "output" .. ToString(i)
		if self[output] ~= nil and self[output] ~= "" then
			if self.emitChannels == nil then self.emitChannels = { } end
			table.insert(self.emitChannels, LookupOrRegisterExtendedChannelToName(self[output]))
			self.globalEmitter = true
		end
	end
	
	//Translation table sets oldMapNames, use this to do some basic checks
	if self.oldMapName == "frontdoor" then
		self.objectType = ControlledMoveable.kObjectTypes.Gate
		self:AddTimedCallback(function(self) CheckRequiredSiegeDoorEntities(self, kFrontDoorEntityTimer) end, 1)
	end
	
	if self.oldMapName == "siegedoor" then
		self.objectType = ControlledMoveable.kObjectTypes.Gate
		self:AddTimedCallback(function(self) CheckRequiredSiegeDoorEntities(self, kSiegeDoorEntityTimer) end, 1)
	end
	
	if self.oldMapName == "func_platform" then
		self.objectType = ControlledMoveable.kObjectTypes.Elevator
	end
	
	if self.oldMapName == "func_door" then
		self.objectType = ControlledMoveable.kObjectTypes.Door
		self.enabled = true
		self.initialSetting = true
		if self.startsOpen then
			self.open = true
		end
		//These will never auto open/close
		if self.stayOpen then
			self.enabled = false
			self.initialSetting = false
		end
	end
	
	//EEM StartsOpened - this makes little sense logically, only ref checks if object is also not a door..  In good design this should really never exist.
	//Object should just be set to inverse direction movement.  But need to support this most likely for 'gates'
	//Hack this a bit for now.
	if self.startsOpened and self.objectType ~= ControlledMoveable.kObjectTypes.Door then
		self:AddTimedCallback(StartsOpenedCallback, 0.1)
	else
		//Register ourselves
		AddPathingWaypoint(self.name, "home", self:GetOrigin(), -1, self:GetId())
	end
	
end

function EEMMixin:OnDestroy()
    if self.directionWaypointId and Shared.GetEntity(self.directionWaypointId) then
		DestroyEntity(Shared.GetEntity(self.directionWaypointId))
		self.directionWaypointId = nil
	end
end