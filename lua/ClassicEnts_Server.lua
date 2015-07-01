// 
// 
// lua\ClassicEnts_Server.lua
// - Dragon

Script.Load("lua/ClassicEnts/ControlledButtonEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledMoveable.lua")
Script.Load("lua/ClassicEnts/ControlledTeleporter.lua")
Script.Load("lua/ClassicEnts/ControlledTimedEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledWeldableEmitter.lua")
Script.Load("lua/ClassicEnts/DialogListener.lua")
Script.Load("lua/ClassicEnts/EmitterMultiplier.lua")
Script.Load("lua/ClassicEnts/ExtendedSignals.lua")
Script.Load("lua/ClassicEnts/FunctionListener.lua")
Script.Load("lua/ClassicEnts/PathingWaypoint.lua")

kFrontDoorEntityTimer = 360
kSiegeDoorEntityTimer = 1500
//Testing
kFrontDoorEntityTimer = 30
kSiegeDoorEntityTimer = 90

local kMapNameTranslationTable = 
{
	["logic_multiplier"] = "emitter_multiplier",
	["func_door"] = "controlled_moveable",
	["frontdoor"] = "controlled_moveable",
	["siegedoor"] = "controlled_moveable",
	["func_moveable"] = "controlled_moveable",
	["func_platform"] = "controlled_moveable",
	["func_train_waypoint"] = "pathing_waypoint",
	["logic_button"] = "controlled_button_emitter",
	["logic_emitter"] = "emitter_multiplier",
	["logic_weldable"] = "controlled_weldable_emitter",
	["logic_timer"] = "controlled_timed_emitter",
	["logic_dialogue"] = "dialog_listener",
	["logic_function"] = "function_listener",
	["teleport_trigger"] = "controlled_teleporter_trigger",
	["teleport_destination"] = "controlled_teleporter_trigger",
	["logic_switch"] = "emitter_multiplier",
	["logic_listener"] = "emitter_multiplier"
}

local function DumpServerEntity(mapName, groupName, values)

    Print("------------ %s ------------", ToString(mapName))
    
    for key, value in pairs(values) do    
        Print("[%s] %s", ToString(key), ToString(value))
    end
    
    Print("---------------------------------------------")

end

local oldGetLoadEntity = GetLoadEntity

function GetLoadEntity(mapName, groupName, values)
	//Check translation table
	if kMapNameTranslationTable[mapName] then
		//DumpServerEntity(mapName, groupName, values)
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

gDebugClassicEnts = true
local function OnCommandDebugCents(client)
	gDebugClassicEnts = not gDebugClassicEnts
	
end

Event.Hook("Console_classicentsdebug", OnCommandDebugCents)