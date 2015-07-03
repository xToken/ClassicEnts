// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts_Client.lua
// - Dragon

Script.Load("lua/ClassicEnts/BreakableEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledButtonEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledMoveable.lua")
Script.Load("lua/ClassicEnts/ControlledWeldableEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledDialogListener.lua")

local kInterceptClasses = 
{
	"logic_dialogue",
	"logic_worldtooltip",
	"controlled_dialog_listener"
}

local oldLoadMapEntity = LoadMapEntity
function LoadMapEntity(className, groupName, values)
	if table.contains(kInterceptClasses, className) then
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
	else
		oldLoadMapEntity(className, groupName, values)
	end
end