// 
// 
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

local function UpdatePathingTable(name, waypointName, origin, angles, number)
	if not kPathingWaypointObjectTable[name] then
		//New Parent Object
		kPathingWaypointObjectTable[name] = { }
	end
	
	//Insert
	kPathingWaypointObjectTable[name][number] = {name = waypointName, number = number, origin = Vector(origin), angles = Angles(angles)}
end

local function UpdatePathingWaypointTable(self)
	//Validate inputs and add to table, then sort.
	if self.parentName then
		local waypointFor = self.parentName
		local waypointName = self.name or self:GetId()
		local waypointSequenceNum = self.number or 1
		local origin = self:GetOrigin()
		local angles = self:GetAngles()
		UpdatePathingTable(waypointFor, waypointName, origin, angles, waypointSequenceNum)
	end
end

function AddPathingWaypoint(name, waypointName, origin, angles, number)
	UpdatePathingTable(name, waypointName, origin, angles, number)
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