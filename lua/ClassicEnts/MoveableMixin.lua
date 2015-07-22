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
    baseVelocity = "vector",
	onMoveable = "compensated boolean"
}

function MoveableMixin:__initmixin()
	if Server then
		self:ClearBaseVelocity()
        self.onMoveable = false
	end
end

function MoveableMixin:ClearBaseVelocity()
    self.baseVelocity = Vector(0, 0, 0)
	self.clear = false
end

function MoveableMixin:SetBaseVelocity(vel, clear)
    self.baseVelocity = vel
	self.clear = clear
end

function MoveableMixin:GetBaseVelocity()
    return self.baseVelocity
end

function MoveableMixin:SetOnMoveable(onMoveable)
    self.onMoveable = onMoveable
end

function MoveableMixin:ModifyVelocity(input, velocity, deltaTime)
	
	if self.baseVelocity:GetLength() > 0.01 then
		if self.baseVelocity.y > 0 then
			//liftoff
			self.onGround = false  
            self.jumping = true
		end
		velocity:Add(self.baseVelocity)
		if self.clear then
			self:ClearBaseVelocity()
		end
	end
	
	if self.onMoveable then
		local moveable = self:IsPlayerOnMoveable()
		if moveable and self:GetIsOnGround() then
			//If we are ON a moveable but its not yet moving, dont clear it in case we press the button
			if moveable:GetIsMoving() then
				local moveAmount = moveable:GetMoveAmount(moveable.destination, moveable:GetSpeed(), deltaTime)
				if gDebugClassicEnts then
					Shared.Message(string.format("Moving player %s to compensate for moveable.", ToString(moveAmount)))
				end
				local completedMove, hitEntities, averageSurfaceNormal = self:PerformMovement(moveAmount, 3, nil, true)
				local blockedMove = not completedMove
				if not completedMove and hitEntities then
					for _, entity in ipairs(hitEntities) do
						if entity == moveable then
							//We dont care if we just hit the moveable.
							blockedMove = false
						else
							blockedMove = true
							break
						end
					end
				end
				if blockedMove then
					moveable:OnProcessCollision(self, 1)
					self:SetOnMoveable(false)
				end
			end
		else
			self:SetOnMoveable(false)
		end
	end
	
end

function MoveableMixin:IsPlayerOnMoveable()

	PROFILE("MoveableMixin:IsPointOnMoveable")
	
	local pHeight = self:GetExtents().y * 2
	//Special case the onos..
	if self:isa("Onos") then
		pHeight = 3.0
	end
    local point = self:GetOrigin() + Vector(0, pHeight, 0)
	local onMoveable = nil
	//This is critical for allowing players to block moveables, trace must start at headlevel
    local trace = Shared.TraceRay(point, Vector(point.x, point.y - (pHeight + 2), point.z), CollisionRep.Move, PhysicsMask.AllButPCs, EntityFilterOne(self))
    if trace.fraction ~= 1 and trace.entity ~= nil and trace.entity:isa("ControlledMoveable") then
		onMoveable = trace.entity
	end
	return onMoveable
	
end

function MoveableMixin:OnCapsuleTraceHit(entity)

    PROFILE("MoveableMixin:OnCapsuleTraceHit")

    if entity and entity:isa("ControlledMoveable") and entity:GetInfluencesMovement() then
		self:SetOnMoveable(true)
    end
    
end