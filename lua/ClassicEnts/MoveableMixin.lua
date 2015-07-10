// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts\MoveableMixin.lua
// - Dragon

MoveableMixin = CreateMixin( MoveableMixin )
MoveableMixin.type = "Moveable"

MoveableMixin.networkVars =
{
    riding = "compensated boolean"
}

function MoveableMixin:__initmixin()
    self.riding = false
	self.ridingId = Entity.invalidId
end

function MoveableMixin:GetIsRiding()
    return self.riding
end

function MoveableMixin:SetRidingId(entId)
    self.ridingId = entId
end

function MoveableMixin:SetIsRiding(riding)
    self.riding = riding
end

function MoveableMixin:OnJumpRequest()
    self:SetIsRiding(false)
end

//This sucks a bit
function Player:OverrideUpdateOnGround(onGround)
    return onGround or self:GetIsRiding()
end

function Skulk:OverrideUpdateOnGround(onGround)
    return Player.OverrideUpdateOnGround(self, onGround) or self:GetIsWallWalking()
end

function Lerk:OverrideUpdateOnGround(onGround)
    return (Player.OverrideUpdateOnGround(self, onGround) or self:GetIsWallGripping()) and not self.gliding
end

function JetpackMarine:OverrideUpdateOnGround(onGround)
    return Player.OverrideUpdateOnGround(self, onGround) and not self:GetIsJetpacking()
end