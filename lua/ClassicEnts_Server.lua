// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts_Server.lua
// - Dragon

Script.Load("lua/ClassicEnts_Shared.lua")
Script.Load("lua/ClassicEnts/ControlledTeleporter.lua")
Script.Load("lua/ClassicEnts/ControlledTimedEmitter.lua")
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
	Shared.Message(string.format("Classic Entities Debug messages set to %s.", gDebugClassicEnts and "Enabled" or "Disabled"))
end

Event.Hook("Console_classicentsdebug", OnCommandDebugCents)
Event.Hook("Console_centsdebug", OnCommandDebugCents)

//New PathingObstacleAdd function, uses model extents and scale
function UpdateScaledModelPathingMesh(entity)

    if GetIsPathingMeshInitialized() then
   
        if entity.obstacleId ~= -1 then
            Pathing.RemoveObstacle(entity.obstacleId)
            gAllObstacles[entity] = nil
        end
		
		//This gets really hacky.. some models are setup much differently.. their origin is not center mass.
		//Limit maximum amount of adjustment to try to correct ones that are messed up, but not break ones that are good.
		local extents = entity:GetModelExtentsVector()
		local scale = entity:GetModelScale()
        local radius = extents.x * scale.x
		local position = entity:GetOrigin() + Vector(0, -100, 0)
		local yaw = entity:GetAngles().yaw
		position.x = position.x + (math.cos(yaw) * radius / 2)
		position.z = position.z - (math.sin(yaw) * radius / 2)
		radius = math.min(radius, 2)
		local height = 1000.0
		
        entity.obstacleId = Pathing.AddObstacle(position, radius, height) 
      
        if entity.obstacleId ~= -1 then
            gAllObstacles[entity] = true
        end
    
    end
    
end