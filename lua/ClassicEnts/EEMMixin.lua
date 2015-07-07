// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts\EEMMixin.lua
// - Dragon

EEMMixin = CreateMixin(EEMMixin)
EEMMixin.type = "EEMMixin"

//This extends an entity to allow compatibility with Extra Entities Mod.  This will convert ALL EEM properties from an entity to
//corresponding values to work with vanilla style systems.  This automatically registers listenChannel and emitChannels for EEM entities.
//Since EEM used names, cannot be sure that entities are in close proximity.  Always register as global.

EEMMixin.networkVars = { }

local function BuildPathingEntityFromDirection(self, direction)
	local waypointOrigin = self:GetOrigin()
	//Lookup extents, EEM moved the object the entirety of its extents
	local extents = Vector(1, 1, 1)
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
		if gDebugClassicEnts then
			Shared.Message(string.format("Building default up waypoint for %s as no valid waypoints provided in map.", self.name))
		end
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
		local entity = Server.CreateEntity("controlled_timed_emitter", { origin = self:GetOrigin(), emitChannel = self.listenChannel, emitTime = doorTime, emitOnce = true, name = ToString(self.name .. "_timer"), enabled = true })
		if entity then
			entity:SetMapEntity()
		end
		if gDebugClassicEnts then
			Shared.Message(string.format("Building timer for %s as no valid triggers provided in map.", self.name))
		end
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
	
	//EEM Timer Action - Handles how timers reset after triggering.  0 = disables, 1 = reset, 2 = reset also?
	if self.onTimeAction ~= nil and not self.emitOnce then
		self.emitOnce = self.onTimeAction == 0
	end
	
	//EEM Timer delay - How long into the round that a timer takes to trigger.
	if self.waitDelay ~= nil then
		self.emitTime = self.waitDelay
	end
	
	//EEM MoveSpeed
	if self.moveSpeed ~= nil then
		self.speed = self.moveSpeed
	end
	
	//EEM Direction - numerical translation to how moveable objects.. move.  0 = up, 1-= down, 2 = east, 3 = west (I THINK), 4 = Use waypoints
	//Realistically this is kinda sloppy, everything should just use waypoints for greater control, but need to support what exists
	if self.direction ~= nil then
		self:AddTimedCallback(function(self) BuildPathingEntityFromDirection(self, self.direction) end, 1)
	end
	
	//EEM Also supports a basic dialogue GUI system...  How these are handled doesnt exactly make sense to me, they could just be client side.
	//But we need to work with what is already in play...
	//Actual TEXT length is networked as 1000 character string, going to try to hack those values in client side.
		
	//How long GUI is onscreen
	if self.displayTime ~= nil then
		self.dialogTime = self.displayTime
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
	
	//EEM Texts
	if self.text ~= nil then
		self.dialogText = self.text
	end
	
	if self.tooltip ~= nil then
		self.dialogText = self.tooltip
		self.localDialog = true
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
	
	//EEM only allowed marines to 'weld'
	if self.oldMapName == "logic_weldable" then
		self.teamNumber = kTeam1Index
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
			self.open = true
			self.enabled = false
			self.initialSetting = false
		end
		//EEM Default door models
		if self.clean then
			self.model = ControlledMoveable.kDefaultDoorClean
		else
			self.model = ControlledMoveable.kDefaultDoor
		end
		self.animationGraph = ControlledMoveable.kDefaultAnimationGraph
	end
	
	if self.startsOpened then
		self.open = true
	end

end

function EEMMixin:OnDestroy()
    if self.directionWaypointId and Shared.GetEntity(self.directionWaypointId) then
		DestroyEntity(Shared.GetEntity(self.directionWaypointId))
		self.directionWaypointId = nil
	end
end