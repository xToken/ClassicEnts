// 
// 
// lua\ScaleModelMixin.lua
// - Dragon

ScaleModelMixin = CreateMixin(ScaleModelMixin)
ScaleModelMixin.type = "ScaleModel"

ScaleModelMixin.networkVars =
{
    scale = "vector"
}

function ScaleModelMixin:__initmixin()
	if not self.scale or not type(self.scale) == "cdata" or not self.scale:isa("Vector") then
		self.scale = Vector(1, 1, 1)
	end
end

function ScaleModelMixin:GetModelScale()
    return self.scale
end

function ScaleModelMixin:SetModelScale(newScale)
	if newScale and type(newScale) == "cdata" and newScale:isa("Vector") then
		self.scale = newScale
	end
end

function ScaleModelMixin:OnAdjustModelCoords(modelCoords)
    local coords = modelCoords
    if self.scale and coords then
        coords.xAxis = coords.xAxis * self.scale.x
        coords.yAxis = coords.yAxis * self.scale.y
        coords.zAxis = coords.zAxis * self.scale.z
    end
    return coords
end