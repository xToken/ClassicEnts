// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts_Server.lua
// - Dragon

Script.Load("lua/ClassicEnts/BreakableEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledButtonEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledMoveable.lua")
Script.Load("lua/ClassicEnts/ControlledTeleporter.lua")
Script.Load("lua/ClassicEnts/ControlledTimedEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledWeldableEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledDialogListener.lua")
Script.Load("lua/ClassicEnts/EmitterMultiplier.lua")
Script.Load("lua/ClassicEnts/ExtendedSignals.lua")
Script.Load("lua/ClassicEnts/FunctionListener.lua")
Script.Load("lua/ClassicEnts/PathingWaypoint.lua")

kFrontDoorEntityTimer = 360
kSiegeDoorEntityTimer = 1500

local kMapNameTranslationTable = 
{
	["func_door"] = "controlled_moveable",
	["frontdoor"] = "controlled_moveable",
	["siegedoor"] = "controlled_moveable",
	["func_moveable"] = "controlled_moveable",
	["func_platform"] = "controlled_moveable",
	["func_train_waypoint"] = "pathing_waypoint",
	["logic_button"] = "controlled_button_emitter",
	["logic_multiplier"] = "emitter_multiplier",
	["logic_emitter"] = "emitter_multiplier",
	["logic_switch"] = "emitter_multiplier",
	["logic_listener"] = "emitter_multiplier",
	["logic_weldable"] = "controlled_weldable_emitter",
	["logic_timer"] = "controlled_timed_emitter",
	["logic_dialogue"] = "controlled_dialog_listener",
	["logic_worldtooltip"] = "controlled_dialog_listener",
	["logic_function"] = "function_listener",
	["teleport_trigger"] = "controlled_teleporter",
	["teleport_destination"] = "controlled_teleporter",
	["logic_breakable"] = "breakable_emitter"
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
			// Map Entities with LiveMixin can be destroyed during the game.
            if HasMixin(entity, "Live") then
                //Store values for reset
                table.insert(Server.mapLoadLiveEntityValues, {mapName, groupName, values})
                //Store ent ID to delete
                table.insert(Server.mapLiveEntities, entity:GetId())
            end
		end
		return false
	end
	return oldGetLoadEntity(mapName, groupName, values)
end

gDebugClassicEnts = false
local function OnCommandDebugCents(client)
	gDebugClassicEnts = not gDebugClassicEnts
end

Event.Hook("Console_classicentsdebug", OnCommandDebugCents)