CourseplayEvent = {};
CourseplayEvent_mt = Class(CourseplayEvent, Event);

InitEventClass(CourseplayEvent, "CourseplayEvent");

function CourseplayEvent:onCreate(id)
	print('CourseplayEvent:onCreate('..tostring(id)..')')
	
	--local upkbase = OnCreateUPK:new(g_server ~= nil, g_client ~= nil)
	--if upkbase==false or upkbase~=nil then
	--	upkbase:load(id)
	--	g_currentMission:addOnCreateLoadedObject(upkbase)
	--	upkbase:register(true)
	--else
	--	upkbase:detele()
	--end
end;

function CourseplayEvent:emptyNew()
	print('## Courseplay: CourseplayEvent:emptyNew');
	courseplay:debug("recieve new event",5)
	local self = Event:new(CourseplayEvent_mt);
	self.className = "CourseplayEvent";
	return self;
end

function CourseplayEvent:new(vehicle, func, value, page)
    if (vehicle == nil) then
	    print('## Courseplay: CourseplayEvent:new - vehicle[nil]');
	else
 	    print('## Courseplay: CourseplayEvent:new - vehicle['..tostring(networkGetObjectId(vehicle))..']');
	end
	self.vehicle = vehicle;
	self.messageNumber = Utils.getNoNil(self.messageNumber,0) +1
	self.func = func
	self.value = value;
	self.type = type(value)
	self.page = page
	return self;
end

function CourseplayEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	local id = streamReadInt32(streamId);
	self.vehicle = networkGetObject(id);
	local messageNumber = streamReadFloat32(streamId);
	self.func = streamReadString(streamId);
	self.page = streamReadInt32(streamId);
	if self.page == 999 then
		self.page = "global"
	elseif self.page == 998 then
		self.page = true
	elseif self.page == 997 then
		self.page = false
	end
	self.type = streamReadString(streamId);
	if self.type == "boolean" then
		self.value = streamReadBool(streamId);
	elseif self.type == "string" then
		self.value = streamReadString(streamId);
	elseif self.type == "nil" then
		self.value = streamReadString(streamId);
	else 
		self.value = streamReadFloat32(streamId);
	end
	

	courseplay:debug("	readStream",5)
	if (self.vehicle == nil) then
		courseplay:debug("		id: self.vehicle is nil(id - "..tostring(id)..")/"..tostring(messageNumber), 5);
    else
		courseplay:debug("		id: "..tostring(networkGetObjectId(self.vehicle)).."/"..tostring(messageNumber), 5);
	end
	courseplay:debug("      function: "..tostring(self.func), 5);
	courseplay:debug("      self.value: "..tostring(self.value), 5);
	courseplay:debug("      self.page: "..tostring(self.page), 5);
	courseplay:debug("      self.type: "..self.type,5);

	self:run(connection);
end

function CourseplayEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("		writeStream",5)
	courseplay:debug("			id: "..tostring(networkGetObjectId(self.vehicle)).."/"..tostring(self.messageNumber), 5)
	courseplay:debug("          function: "..tostring(self.func), 5)
	courseplay:debug("          value: "..tostring(self.value), 5)
	courseplay:debug("          type: "..tostring(self.type), 5)
	courseplay:debug("          page: "..tostring(self.page), 5)
	
	streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
	streamWriteFloat32(streamId, self.messageNumber);
	streamWriteString(streamId, self.func);
	if self.page == "global" then
		self.page = 999
	elseif self.page == true then
		self.page = 998
	elseif self.page == false then
		self.page = 997
	end
	streamWriteInt32(streamId, self.page);
	streamWriteString(streamId, self.type);
	if self.type == "boolean" then
		streamWriteBool(streamId, self.value);
	elseif self.type == "string" then
		streamWriteString(streamId, self.value);
	elseif self.type == "nil" then
		streamWriteString(streamId, "nil");
	else
		streamWriteFloat32(streamId, self.value);
	end
end

function CourseplayEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("\t\t\trun",5)
	courseplay:debug(('\t\t\t\tid=%s, function=%s, value=%s'):format(tostring(networkGetObjectId(self.vehicle)), tostring(self.func), tostring(self.value)), 5);
	if (self.vehicle == nil) then
		courseplay:debug("CourseplayEvent:run - self.vehicle is nil", 5);
	else
	    self.vehicle:setCourseplayFunc(self.func, self.value, true, self.page);
		if not connection:getIsServer() then
			courseplay:debug("broadcast event feedback",5)
			g_server:broadcastEvent(CourseplayEvent:new(self.vehicle, self.func, self.value, self.page), nil, connection, self.object);
		end;
	end
end

function CourseplayEvent.sendEvent(vehicle, func, value, noEventSend, page) -- hilfsfunktion, die Events anst��te (wirde von setRotateDirection in der Spezi aufgerufen) 
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			courseplay:debug("broadcast event",5)
			courseplay:debug(('\tid=%s, function=%s, value=%s, page=%s'):format(tostring(networkGetObjectId(vehicle)), tostring(func), tostring(value), tostring(page)), 5);
			g_server:broadcastEvent(CourseplayEvent:new(vehicle, func, value, page), nil, nil, vehicle);
		else
			courseplay:debug("send event",5)
			courseplay:debug(('\tid=%s, function=%s, value=%s, page=%s'):format(tostring(networkGetObjectId(vehicle)), tostring(func), tostring(value), tostring(page)), 5);
			g_client:getServerConnection():sendEvent(CourseplayEvent:new(vehicle, func, value, page));
		end;
	end;
end

function courseplay:checkForChangeAndBroadcast(self, stringName, variable , variableMemory)
	if variable ~= variableMemory then
		print(string.format("checkForChangeAndBroadcast: %s = %s",stringName,tostring(variable))) 
		--CourseplayEvent.sendEvent(self, stringName, variable)
		variableMemory = variable
	end
	return variableMemory

end



---------------------------------



--
-- based on PlayerJoinFix
--
-- SFM-Modding
-- @author:  Manuel Leithner
-- @date:    01/08/11
-- @version: v1.1
-- @history: v1.0 - initial implementation
--           v1.1 - adaption to courseplay
--

local modName = g_currentModName;
local Server_sendObjects_old = Server.sendObjects;

function Server:sendObjects(connection, x, y, z, viewDistanceCoeff)
	connection:sendEvent(CourseplayJoinFixEvent:new());

	Server_sendObjects_old(self, connection, x, y, z, viewDistanceCoeff);
end


CourseplayJoinFixEvent = {};
CourseplayJoinFixEvent_mt = Class(CourseplayJoinFixEvent, Event);

InitEventClass(CourseplayJoinFixEvent, "CourseplayJoinFixEvent");

function CourseplayJoinFixEvent:emptyNew()
	local self = Event:new(CourseplayJoinFixEvent_mt);
	self.className = modName .. ".CourseplayJoinFixEvent";
	return self;
end

function CourseplayJoinFixEvent:new()
	local self = CourseplayJoinFixEvent:emptyNew()
	return self;
end

function CourseplayJoinFixEvent:writeStream(streamId, connection)

	if connection:getIsServer() then
		courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  name:"..tostring(self.name).." CourseplayJoinFixEvent: server does not write stream", 5)
	else
		courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  name:"..tostring(self.name).." CourseplayJoinFixEvent: write stream", 5)

	    --courseplay:debug("manager transfering courses", 8);
		--transfer courses
		local course_count = 0
		for _,_ in pairs(g_currentMission.cp_courses) do
			course_count = course_count + 1
		end
		print(string.format("\t### CourseplayMultiplayer: writing %d courses ", course_count ))
		streamDebugWriteInt32(streamId, course_count, "course_count")
		for id, course in pairs(g_currentMission.cp_courses) do
			streamDebugWriteString(streamId, course.name, "course.name")
			streamDebugWriteString(streamId, course.uid, "course.uid")
			streamDebugWriteString(streamId, course.type, "course.type")
			streamDebugWriteInt32(streamId, course.id, "course.id")
			streamDebugWriteInt32(streamId, course.parent, "course.parent")
			streamDebugWriteInt32(streamId, #(course.waypoints), "#(course.waypoints)")
			for w = 1, #(course.waypoints) do
				streamDebugWriteFloat32(streamId, course.waypoints[w].cx, "course.waypoints[w].cx")
				streamDebugWriteFloat32(streamId, course.waypoints[w].cz, "course.waypoints[w].cz")
				streamDebugWriteFloat32(streamId, course.waypoints[w].angle, "course.waypoints[w].angle")
				streamDebugWriteBool(streamId, course.waypoints[w].wait, "course.waypoints[w].wait")
				streamDebugWriteBool(streamId, course.waypoints[w].rev, "course.waypoints[w].rev")
				streamDebugWriteBool(streamId, course.waypoints[w].crossing, "course.waypoints[w].crossing")
				streamDebugWriteInt32(streamId, course.waypoints[w].speed, "course.waypoints[w].speed")

				streamDebugWriteBool(streamId, course.waypoints[w].generated, "course.waypoints[w].generated")
				streamDebugWriteString(streamId, (course.waypoints[w].laneDir or ""), "(course.waypoints[w].laneDir or \"\")")
				streamDebugWriteString(streamId, course.waypoints[w].turn, "course.waypoints[w].turn")
				streamDebugWriteBool(streamId, course.waypoints[w].turnStart, "course.waypoints[w].turnStart")
				streamDebugWriteBool(streamId, course.waypoints[w].turnEnd, "course.waypoints[w].turnEnd")
				streamDebugWriteInt32(streamId, course.waypoints[w].ridgeMarker, "course.waypoints[w].ridgeMarker")
			end
		end
				
		local folderCount = 0
		for _,_ in pairs(g_currentMission.cp_folders) do
			folderCount = folderCount + 1
		end
		streamDebugWriteInt32(streamId, folderCount, "folderCount")
		print(string.format("\t### CourseplayMultiplayer: writing %d folders ", folderCount ))
		for id, folder in pairs(g_currentMission.cp_folders) do
			streamDebugWriteString(streamId, folder.name, "folder.name")
			streamDebugWriteString(streamId, folder.uid, "folder.uid")
			streamDebugWriteString(streamId, folder.type, "folder.type")
			streamDebugWriteInt32(streamId, folder.id, "folder.id")
			streamDebugWriteInt32(streamId, folder.parent, "folder.parent")
		end
				
		local fieldsCount = 0
		for _, field in pairs(courseplay.fields.fieldData) do
			if field.isCustom then
				fieldsCount = fieldsCount+1
			end
		end
		streamDebugWriteInt32(streamId, fieldsCount, "fieldsCount")
		print(string.format("\t### CourseplayMultiplayer: writing %d custom fields ", fieldsCount))
		for id, course in pairs(courseplay.fields.fieldData) do
			if course.isCustom then
				streamDebugWriteString(streamId, course.name, "course.name")
				streamDebugWriteInt32(streamId, course.numPoints, "course.numPoints")
				streamDebugWriteBool(streamId, course.isCustom, "course.isCustom")
				streamDebugWriteInt32(streamId, course.fieldNum, "course.fieldNum")
				streamDebugWriteInt32(streamId, #(course.points), "#(course.points)")
				for p = 1, #(course.points) do
					streamDebugWriteFloat32(streamId, course.points[p].cx, "course.points[p].cx")
					streamDebugWriteFloat32(streamId, course.points[p].cy, "course.points[p].cy")
					streamDebugWriteFloat32(streamId, course.points[p].cz, "course.points[p].cz")
				end
			end
		end
		
		courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  base: write stream end", 5)
	end;
end

function CourseplayJoinFixEvent:readStream(streamId, connection)
	if not connection:getIsServer() then
	    courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  name:"..tostring(self.name).."CourseplayJoinFixEvent: not server so not reading stream", 5)
	else
		courseplay:debug("id: "..tostring(networkGetObjectId(self)).."  name:"..tostring(self.name).."CourseplayJoinFixEvent: read stream", 5)
		local course_count = streamDebugReadInt32(streamId, "course_count")
		print(string.format("\t### CourseplayMultiplayer: reading %d couses ", course_count ))
		g_currentMission.cp_courses = {}
		for i = 1, course_count do
			--courseplay:debug("got course", 8);
			local course_name = streamDebugReadString(streamId, "course_name")
			local courseUid = streamDebugReadString(streamId, "courseUid")
			local courseType = streamDebugReadString(streamId, "courseType")
			local course_id = streamDebugReadInt32(streamId, "course_id")
			local courseParent = streamDebugReadInt32(streamId, "courseParent")
			local wp_count = streamDebugReadInt32(streamId, "wp_count")
			local waypoints = {}
			for w = 1, wp_count do
				--courseplay:debug("got waypoint", 8);
				local cx = streamDebugReadFloat32(streamId, "cx")
				local cz = streamDebugReadFloat32(streamId, "cz")
				local angle = streamDebugReadFloat32(streamId, "angle")
				local wait = streamDebugReadBool(streamId, "wait")
				local rev = streamDebugReadBool(streamId, "rev")
				local crossing = streamDebugReadBool(streamId, "crossing")
				local speed = streamDebugReadInt32(streamId, "speed")

				local generated = streamDebugReadBool(streamId, "generated")
				local dir = streamDebugReadString(streamId, "dir")
				local turn = streamDebugReadString(streamId, "turn")
				local turnStart = streamDebugReadBool(streamId, "turnStart")
				local turnEnd = streamDebugReadBool(streamId, "turnEnd")
				local ridgeMarker = streamDebugReadInt32(streamId, "ridgeMarker")
				
				local wp = {
					cx = cx, 
					cz = cz, 
					angle = angle, 
					wait = wait, 
					rev = rev, 
					crossing = crossing, 
					speed = speed,
					generated = generated,
					laneDir = dir,
					turn = turn,
					turnStart = turnStart,
					turnEnd = turnEnd,
					ridgeMarker = ridgeMarker 
				};
				table.insert(waypoints, wp)
			end
			local course = { id = course_id, uid = courseUid, type = courseType, name = course_name, nameClean = courseplay:normalizeUTF8(course_name), waypoints = waypoints, parent = courseParent }
			g_currentMission.cp_courses[course_id] = course
			g_currentMission.cp_sorted = courseplay.courses:sort()
		end
		
		local folderCount = streamDebugReadInt32(streamId, "folderCount")
		print(string.format("\t### CourseplayMultiplayer: reading %d folders ", folderCount ))
		g_currentMission.cp_folders = {}
		for i = 1, folderCount do
			local folderName = streamDebugReadString(streamId, "folderName")
			local folderUid = streamDebugReadString(streamId, "folderUid")
			local folderType = streamDebugReadString(streamId, "folderType")
			local folderId = streamDebugReadInt32(streamId, "folderId")
			local folderParent = streamDebugReadInt32(streamId, "folderParent")
			local folder = { id = folderId, uid = folderUid, type = folderType, name = folderName, nameClean = courseplay:normalizeUTF8(folderName), parent = folderParent }
			g_currentMission.cp_folders[folderId] = folder
			g_currentMission.cp_sorted = courseplay.courses:sort(g_currentMission.cp_courses, g_currentMission.cp_folders, 0, 0)
		end
		
		local fieldsCount = streamDebugReadInt32(streamId, "fieldsCount")		
		print(string.format("\t### CourseplayMultiplayer: reading %d custom fields ", fieldsCount))
		courseplay.fields.fieldData = {}
		for i = 1, fieldsCount do
			local name = streamDebugReadString(streamId, "name")
			local numPoints = streamDebugReadInt32(streamId, "numPoints")
			local isCustom = streamDebugReadBool(streamId, "isCustom")
			local fieldNum = streamDebugReadInt32(streamId, "fieldNum")
			local ammountPoints = streamDebugReadInt32(streamId, "ammountPoints")
			local waypoints = {}
			for w = 1, ammountPoints do 
				local cx = streamDebugReadFloat32(streamId, "cx")
				local cy = streamDebugReadFloat32(streamId, "cy")
				local cz = streamDebugReadFloat32(streamId, "cz")
				local wp = { cx = cx, cy = cy, cz = cz}
				table.insert(waypoints, wp)
			end
			local field = { name = name, numPoints = numPoints, isCustom = isCustom, fieldNum = fieldNum, points = waypoints}
			courseplay.fields.fieldData[fieldNum] = field
		end
		print("\t### CourseplayMultiplayer: courses/folders reading end")
	end;
end

function CourseplayJoinFixEvent:run(connection)
	--courseplay:debug("CourseplayJoinFixEvent Run function should never be called", 8);
end;