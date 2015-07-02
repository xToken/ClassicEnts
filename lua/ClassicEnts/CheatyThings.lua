// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\CheatyThings.lua - YEA WHAT
// - Dragon

//SCARYHOOK
local oldCanEntityDoDamageTo = CanEntityDoDamageTo
function CanEntityDoDamageTo(attacker, target, cheats, devMode, friendlyFire, damageType)

    if GetGameInfoEntity():GetState() == kGameState.NotStarted then
		return false
    end
	
	if target:isa("BreakableEmitter") then
        return true
    end
	
	return oldCanEntityDoDamageTo(attacker, target, cheats, devMode, friendlyFire, damageType)
	
end