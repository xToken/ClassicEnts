// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts_Shared.lua
// - Dragon

Script.Load("lua/ClassicEnts/BreakableEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledButtonEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledConveyor.lua")
Script.Load("lua/ClassicEnts/ControlledMoveable.lua")
Script.Load("lua/ClassicEnts/ControlledWeldableEmitter.lua")
Script.Load("lua/ClassicEnts/ControlledDialogListener.lua")
Script.Load("lua/ClassicEnts/ControlledPusher.lua")
Script.Load("lua/ClassicEnts/MoveableMixin.lua")

local function AppendToEnum( tbl, key )
	if rawget(tbl,key) ~= nil then
		//Already used key
		return
	end
	
	local max = 0
	for k, v in pairs(tbl) do
		//Find last key
		if type(v) == "number" and v > max then
			max = v
		end
	end
	
	//set numerical ref and key ref
	rawset( tbl, key, max + 1 )
	rawset( tbl, max + 1, key )
	
end

AppendToEnum( kMinimapBlipType, 'ControlledWeldableEmitter' )

local originalPlayerOnCreate
originalPlayerOnCreate = Class_ReplaceMethod("Player", "OnCreate",
	function(self)
		originalPlayerOnCreate(self)
		InitMixin(self, MoveableMixin)
	end
)

local networkVars = { }

AddMixinNetworkVars(MoveableMixin, networkVars)

Shared.LinkClassToMap("Player", Player.kMapName, networkVars, true)

