// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\PathingWaypoint.lua
// - Dragon

Script.Load("lua/ClassicEnts/EEMMixin.lua")

class 'PathingWaypoint' (Entity)

PathingWaypoint.kMapName = "pathing_waypoint"

//Pathing ent used for all moveables.  requires name of moveable to be set as parentName property.  number property should be set to the number in the
//sequence of pathing objects, starting with 1.  0 will automatically be set as the initial location for the moveable.  If this is for a door as an example
//you would only need to make 1 point which is where the door opens to fully.  For an elevator with 3 possible floors, you could have 2 of these.

//Global table which stores all pathing waypoints
local kPathingWaypointObjectTable = { }

local networkVars = { }

local function SortByNumber(path1, path2)
    return path1.number < path2.number 
end

local function UpdatePathingTable(name, waypointName, origin, number, entId)
	if not kPathingWaypointObjectTable[name] then
		//New Parent Object
		kPathingWaypointObjectTable[name] = { }
	end
	//Insert
	table.insert(kPathingWaypointObjectTable[name], {name = waypointName, number = number, origin = Vector(origin), entId = entId})
	//Sort
	table.sort(kPathingWaypointObjectTable[name], SortByNumber)
end

local function UpdatePathingWaypointTable(self)
	//Validate inputs and add to table, then sort.
	if self.moveableName then
		local waypointFor = self.moveableName
		local waypointName = self.name or self:GetId()
		local waypointSequenceNum = self.number or 1
		local origin = self:GetOrigin()
		UpdatePathingTable(waypointFor, waypointName, origin, waypointSequenceNum, self:GetId())
	else
		Shared.Message(string.format("Orphaned pathing waypoint %s located at %s", self.name, ToString(self:GetOrigin())))
	end
end

function AddPathingWaypoint(name, waypointName, origin, number, entId)
	UpdatePathingTable(name, waypointName, origin, number, entId)
end

function UpdateWaypointOrigin(name, entId, origin)
	local updated = false
	if kPathingWaypointObjectTable[name] then
		for i = 1, #kPathingWaypointObjectTable[name] do
			if kPathingWaypointObjectTable[name][i].entId == entId then
				kPathingWaypointObjectTable[name][i].origin = origin
				updated = true
				break
			end
		end
	end
	return updated
end

function LookupPathingWaypoints(name)
	
	if kPathingWaypointObjectTable[name] then
		//We have a table for this object
		return kPathingWaypointObjectTable[name]
	end
	
end

function PathingWaypoint:OnCreate() 

    Entity.OnCreate(self)
	
	self:SetPropagate(Entity.Propagate_Never)
    self:SetUpdates(false)

end

function PathingWaypoint:OnInitialized()

    Entity.OnInitialized(self)
	
	InitMixin(self, EEMMixin)
	
	UpdatePathingWaypointTable(self)
	
end

Shared.LinkClassToMap("PathingWaypoint", PathingWaypoint.kMapName, networkVars)