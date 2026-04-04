local MapManager = {}
MapManager.__index = MapManager

function MapManager.new(workspaceRef)
	local self = setmetatable({}, MapManager)
	self.Workspace = workspaceRef or workspace
	self:Refresh()
	return self
end

function MapManager:Refresh()
	self.LobbySpawn = self:FindPartAnywhere("LobbySpawn")
	self.MapsFolder = self.Workspace:FindFirstChild("Maps")
end

function MapManager:FindPartAnywhere(name)
	for _, inst in ipairs(self.Workspace:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name == name then
			return inst
		end
	end
	return nil
end

function MapManager:FindPartDeep(model, name)
	if not model then return nil end
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name == name then
			return inst
		end
	end
	return nil
end

function MapManager:GetLobbySpawn()
	return self.LobbySpawn
end

function MapManager:ValidateMap(map)
	if not map or not map:IsA("Model") then
		return false
	end

	return self:FindPartDeep(map, "ArenaSpawn") ~= nil
		or self:FindPartDeep(map, "MapSpawn") ~= nil
end

function MapManager:PickRandomMap()
	if not self.MapsFolder then
		return nil
	end

	local validMaps = {}
	local fallbackMaps = {}
	for _, map in ipairs(self.MapsFolder:GetChildren()) do
		if map:IsA("Model") then
			if self:ValidateMap(map) then
				table.insert(validMaps, map)
			else
				table.insert(fallbackMaps, map)
			end
		end
	end

	if #validMaps > 0 then
		return validMaps[math.random(1, #validMaps)]
	end

	if #fallbackMaps > 0 then
		warn("[MapManager] Ningun mapa tiene ArenaSpawn/MapSpawn; se usara fallback.")
		return fallbackMaps[math.random(1, #fallbackMaps)]
	end

	return nil
end

function MapManager:GetPlayableMapNames()
	if not self.MapsFolder then
		return {}
	end

	local validNames = {}
	local fallbackNames = {}

	for _, map in ipairs(self.MapsFolder:GetChildren()) do
		if map:IsA("Model") then
			if self:ValidateMap(map) then
				table.insert(validNames, map.Name)
			else
				table.insert(fallbackNames, map.Name)
			end
		end
	end

	if #validNames > 0 then
		return validNames
	end

	return fallbackNames
end

function MapManager:GetRandomMapName(preferredName)
	local source = self:GetPlayableMapNames()
	if #source == 0 then
		return nil
	end

	if preferredName then
		for _, mapName in ipairs(source) do
			if mapName == preferredName then
				return mapName
			end
		end
	end

	return source[math.random(1, #source)]
end

function MapManager:GetMapByName(mapName)
	if not self.MapsFolder or not mapName then
		return nil
	end

	local map = self.MapsFolder:FindFirstChild(mapName)
	if map and map:IsA("Model") then
		return map
	end

	return nil
end

function MapManager:GetArenaSpawnInfo(activeMapModel)
	local arena = self:FindPartDeep(activeMapModel, "ArenaSpawn")
	if arena then return arena.CFrame, "ArenaSpawn" end

	local mapSpawn = self:FindPartDeep(activeMapModel, "MapSpawn")
	if mapSpawn then return mapSpawn.CFrame, "MapSpawn" end

	if activeMapModel then
		return activeMapModel:GetPivot(), "Pivot"
	end

	local globalArena = self:FindPartAnywhere("ArenaSpawn")
	if globalArena then
		return globalArena.CFrame, "GlobalArenaSpawn"
	end

	return nil, "Missing"
end

function MapManager:ActivateMap(map)
	if map then
		map.Parent = self.Workspace
	end
	return map
end

function MapManager:DeactivateMap(activeMapModel)
	if activeMapModel and self.MapsFolder then
		pcall(function()
			activeMapModel.Parent = self.MapsFolder
		end)
	end
	return nil
end

return MapManager
