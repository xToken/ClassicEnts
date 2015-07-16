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
    baseVelocity = "compensated vector",
}

function MoveableMixin:__initmixin()
    self:ClearBaseVelocity()
end

function MoveableMixin:ClearBaseVelocity()
    self.baseVelocity = Vector(0, 0, 0)
end

function MoveableMixin:SetBaseVelocity(vel)
    self.baseVelocity = vel
end

function MoveableMixin:GetBaseVelocity()
    return self.baseVelocity
end

function MoveableMixin:ModifyVelocity(input, velocity, deltaTime)
	
	if self.baseVelocity:GetLength() > 0.01 then
		if self.baseVelocity.y > 0 then
			//liftoff
			self.onGround = false  
            self.jumping = true
		end
		velocity:Add(self.baseVelocity)
		self:ClearBaseVelocity()
	end
	
end