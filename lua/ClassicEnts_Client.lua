// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts_Client.lua
// - Dragon

Script.Load("lua/ClassicEnts_Shared.lua")
Script.Load("lua/ClassicEnts/GUIHooks.lua")
Script.Load("lua/ClassicEnts/Elixer_Utility.lua")
Elixer.UseVersion( 1.8 )

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

local function SetupGUIMinimap()
	local kBlipInfo 		= GetUpValue( GUIMinimap.Initialize, "kBlipInfo", { LocateRecurse = true } )
	local kBlipColorType 	= GetUpValue( GUIMinimap.Initialize, "kBlipColorType", { LocateRecurse = true } )
	local kBlipSizeType 	= GetUpValue( GUIMinimap.Initialize, "kBlipSizeType", { LocateRecurse = true } )
	local kStaticBlipsLayer = GetUpValue( GUIMinimap.Initialize, "kStaticBlipsLayer", { LocateRecurse = true } )
	kBlipInfo[kMinimapBlipType.ControlledWeldableEmitter] = { kBlipColorType.Waypoint, kBlipSizeType.UnpoweredPowerPoint, kStaticBlipsLayer }
end

GHook:AddPreInitOverride("GUIMinimapFrame", SetupGUIMinimap)

local oldBuildClassToGrid = BuildClassToGrid
function BuildClassToGrid()
	local ClassToGrid = oldBuildClassToGrid()
	ClassToGrid["ControlledWeldableEmitter"] = { 1, 1 }
	return ClassToGrid
end

AddClientUIScriptForTeam("all", "ClassicEnts/GUIDialogMessage")