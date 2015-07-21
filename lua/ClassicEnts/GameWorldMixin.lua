// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts\GameWorldMixin.lua
// - Dragon

GameWorldMixin = CreateMixin(GameWorldMixin)
GameWorldMixin.type = "GameWorld"

GameWorldMixin.networkVars = { }

function GameWorldMixin:__initmixin()
end

//This creates/deletes a physics model not attached to an entity, so it wont be filtered out of traces.
function GameWorldMixin:AddAdditionalPhysicsModel()
	self:CleanupAdditionalPhysicsModel()
	if not self.additionalPhysicsModel then
		self.additionalPhysicsModel = Shared.CreatePhysicsModel(self.model, false, self:GetCoords(), nil) 
		self.additionalPhysicsModel:SetPhysicsType(CollisionObject.Static)
	end
end

function GameWorldMixin:CleanupAdditionalPhysicsModel()
	if self.additionalPhysicsModel then
        Shared.DestroyCollisionObject(self.additionalPhysicsModel)
        self.additionalPhysicsModel = nil
    end   
end

//New PathingObstacleAdd function, uses model extents and scale
function GameWorldMixin:UpdateScaledModelPathingMesh()

    if GetIsPathingMeshInitialized() then
   
        if self.obstacleId ~= -1 then
            Pathing.RemoveObstacle(self.obstacleId)
            gAllObstacles[self] = nil
        end
		
		//This gets really hacky.. some models are setup much differently.. their origin is not center mass.
		//Limit maximum amount of adjustment to try to correct ones that are messed up, but not break ones that are good.
		local extents = self:GetModelExtentsVector()
		local scale = self:GetModelScale()
        local radius = extents.x * scale.x
		local position = self:GetOrigin() + Vector(0, -100, 0)
		local yaw = self:GetAngles().yaw
		position.x = position.x + (math.cos(yaw) * radius / 2)
		position.z = position.z - (math.sin(yaw) * radius / 2)
		radius = math.min(radius, 2)
		local height = 1000.0
		
        self.obstacleId = Pathing.AddObstacle(position, radius, height) 
      
        if self.obstacleId ~= -1 then
            gAllObstacles[self] = true
        end
    
    end
    
end

function GameWorldMixin:OnDestroy()
	self:CleanupAdditionalPhysicsModel()
	self:RemoveFromMesh()
end