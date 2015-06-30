// 
// 
// lua\ClassicEnts_Server.lua
// - Dragon

Script.Load("lua/ClassicEnts/ControlledButtonEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledMoveable.lua")
Script.Load("lua/ClassicEnts/ControlledTimedEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledWeldableEmitter.lua")
Script.Load("lua/ClassicEnts/DialogListener.lua")
Script.Load("lua/ClassicEnts/EmitterMultiplier.lua")
Script.Load("lua/ClassicEnts/ExtendedSignals.lua")
Script.Load("lua/ClassicEnts/PathingWaypoint.lua")

kFrontDoorEntityTimer = 360
//Testing
kFrontDoorEntityTimer = 30
kSiegeDoorEntityTimer = 1500

local kMapNameTranslationTable = 
{
	["logic_multiplier"] = "emitter_multiplier",
	["frontdoor"] = "controlled_moveable",
	["siegedoor"] = "controlled_moveable",
	["func_moveable"] = "controlled_moveable",
	["func_platform"] = "controlled_moveable",
	["func_train_waypoint"] = "pathing_waypoint",
	["logic_button"] = "controlled_button_emitter",
	["logic_emitter"] = "", //CODE THIS
	["logic_weldable"] = "controlled_weldable_emitter",
	["logic_timer"] = "controlled_timed_emitter",
	["logic_dialogue"] = "dialog_listener"
}

local oldGetLoadEntity = GetLoadEntity

function GetLoadEntity(mapName, groupName, values)
	//Check translation table
	if kMapNameTranslationTable[mapName] then
		values["oldMapName"] = mapName
		mapName = kMapNameTranslationTable[mapName]
		local entity = Server.CreateEntity(mapName, values)
        if entity then
            entity:SetMapEntity()
		end
		return false
	end
	return oldGetLoadEntity(mapName, groupName, values)
end