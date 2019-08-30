-- Natural Selection 2 'Classic Entities Mod'
-- Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
-- Designed to work with maps developed for Extra Entities Mod.  
-- Source located at - https://github.com/xToken/ClassicEnts
-- lua\ClassicEnts_Client.lua
-- Dragon

Script.Load("lua/ClassicEnts_Shared.lua")

local kDialogClasses = 
{
	"logic_dialogue",
	"logic_worldtooltip",
	"controlled_dialog_listener"
}

local oldLoadMapEntity = LoadMapEntity
function LoadMapEntity(className, groupName, values)
	if table.contains(kDialogClasses, className) then
		local dialog = values["dialogText"]
		if className == "logic_dialogue" then
			dialog = values["text"]
		elseif className == "logic_worldtooltip" then
			dialog = values["tooltip"]
		end
		if dialog then
			RegisterClientDialogData(dialog)
		else
			Shared.Message("Dialog entity with invalid display text field!")
		end
		return true
	end
	if className == "lua_loader" or className == "logic_lua" then
		if values["luaFile"] and GetFileExists(values["luaFile"]) then
			Script.Load(values["luaFile"])
		end
		return true
	end
	return oldLoadMapEntity(className, groupName, values)
end

local function SetupGUIMinimap(name, script)
	if name == 'GUIMinimapFrame' then
		local kBlipInfo 		= debug.getupvaluex( GUIMinimap.Initialize, "kBlipInfo", true )
		local kBlipColorType 	= debug.getupvaluex( GUIMinimap.Initialize, "kBlipColorType", true )
		local kBlipSizeType 	= debug.getupvaluex( GUIMinimap.Initialize, "kBlipSizeType", true )
		local kStaticBlipsLayer = debug.getupvaluex( GUIMinimap.Initialize, "kStaticBlipsLayer", true )
		kBlipInfo[kMinimapBlipType.ControlledWeldableEmitter] = { kBlipColorType.Waypoint, kBlipSizeType.UnpoweredPowerPoint, kStaticBlipsLayer }
		script:Uninitialize()
		script:Initialize()
	end
end

ClientUI.AddScriptCreationEventListener(SetupGUIMinimap)

local oldBuildClassToGrid = BuildClassToGrid
function BuildClassToGrid()
	local ClassToGrid = oldBuildClassToGrid()
	ClassToGrid["ControlledWeldableEmitter"] = { 7, 1 }
	return ClassToGrid
end

AddClientUIScriptForTeam("all", "ClassicEnts/GUIDialogMessage")