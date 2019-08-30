-- Natural Selection 2 'Classic Entities Mod'
-- Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
-- Designed to work with maps developed for Extra Entities Mod.  
-- Source located at - https://github.com/xToken/ClassicEnts
-- lua\ClassicEnts_Shared.lua
-- Dragon

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
		-- Already used key
		return
	end
	
	local max = 0
	for k, v in pairs(tbl) do
		-- Find last key
		if type(v) == "number" and v > max then
			max = v
		end
	end
	
	-- set numerical ref and key ref
	rawset( tbl, key, max + 1 )
	rawset( tbl, max + 1, key )
	
end

-- This doesnt exist in older builds
if not debug.getupvaluex then
	local old = debug.getupvalue
    local function getupvalue(f, up, recursive)
        if type(up) ~= "string" then
            return old(f, up)
        end

        if recursive == nil then
            recursive = true
        end

        local funcs   = {}
        local i, n, v = 0
        repeat
            i = i + 1
            n, v = old(f, i)
            if recursive and type(v) == "function" then
                table.insert(funcs, v)
            end
        until
            n == nil or n == up

        -- Do a recursive search
        if n == nil then
            for _, subf in ipairs(funcs) do
                v, f, i = getupvalue(subf, up)
                if f ~= nil then
                    return v, f, i
                end
            end
        elseif n == up then
            return v, f, i
        end
    end
    debug.getupvaluex = getupvalue
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

