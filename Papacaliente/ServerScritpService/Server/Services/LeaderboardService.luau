local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local BOARDS = {
	MatchesWon = "HotPotato_LB_MatchesWon",
	PassKills = "HotPotato_LB_PassKills",
	RoundsSurvived = "HotPotato_LB_RoundsSurvived",
	TotalPoints = "HotPotato_LB_TotalPoints",
}

function LeaderboardService.new(remotesService, remoteNames, playerDataService)
	local self = setmetatable({}, LeaderboardService)
	self.Data = playerDataService
	self.RE_Update = remotesService:GetOrCreateRemoteEvent(remoteNames.LeaderboardUpdate)
	self.Stores = {}
	for key, storeName in pairs(BOARDS) do
		self.Stores[key] = DataStoreService:GetOrderedDataStore(storeName)
	end

	Players.PlayerAdded:Connect(function(player)
		task.delay(2, function()
			if player.Parent == Players then
				self:SendSnapshot(player)
			end
		end)
	end)

	self:EnsureBoard()

	return self
end

function LeaderboardService:EnsureBoard()
	local lobbySpawn = workspace:FindFirstChild("LobbySpawn", true)
	if not lobbySpawn or not lobbySpawn:IsA("BasePart") then
		return
	end

	local board = workspace:FindFirstChild("GlobalLeaderboardBoard")
	if not board then
		board = Instance.new("Part")
		board.Name = "GlobalLeaderboardBoard"
		board.Anchored = true
		board.CanCollide = true
		board.Size = Vector3.new(8, 5, 1)
		board.CFrame = lobbySpawn.CFrame * CFrame.new(10, 3, 0)
		board.Parent = workspace

		local gui = Instance.new("SurfaceGui")
		gui.Name = "LeaderboardSurface"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = board

		local label = Instance.new("TextLabel")
		label.Name = "BoardText"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(15, 22, 29)
		label.BorderSizePixel = 0
		label.TextColor3 = Color3.fromRGB(241, 245, 248)
		label.TextSize = 20
		label.Font = Enum.Font.GothamBold
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Parent = gui
	end
end

function LeaderboardService:PushPlayerStats(player)
	local profile = self.Data and self.Data:GetProfile(player)
	if not profile or not profile.Stats then
		return
	end

	local writes = {
		MatchesWon = profile.Stats.MatchesWon or 0,
		PassKills = profile.Stats.PassKills or 0,
		RoundsSurvived = profile.Stats.RoundsSurvived or 0,
		TotalPoints = profile.TotalPoints or 0,
	}

	for key, value in pairs(writes) do
		pcall(function()
			self.Stores[key]:SetAsync(tostring(player.UserId), value)
		end)
	end
end

function LeaderboardService:GetTop(key, limit)
	local out = {}
	local ok, pages = pcall(function()
		return self.Stores[key]:GetSortedAsync(false, limit or 10)
	end)
	if not ok or not pages then
		return out
	end

	for _, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(out, {
			userId = tonumber(entry.key) or 0,
			value = entry.value,
		})
	end
	return out
end

function LeaderboardService:BuildSnapshot()
	return {
		MatchesWon = self:GetTop("MatchesWon", 10),
		PassKills = self:GetTop("PassKills", 10),
		RoundsSurvived = self:GetTop("RoundsSurvived", 10),
		TotalPoints = self:GetTop("TotalPoints", 10),
	}
end

function LeaderboardService:SendSnapshot(player)
	local snapshot = self:BuildSnapshot()
	self.RE_Update:FireClient(player, snapshot)

	local board = workspace:FindFirstChild("GlobalLeaderboardBoard")
	local surface = board and board:FindFirstChild("LeaderboardSurface")
	local label = surface and surface:FindFirstChild("BoardText")
	if label and label:IsA("TextLabel") then
		local lines = { "TOP HISTORICO", "" }
		for index, entry in ipairs(snapshot.MatchesWon or {}) do
			table.insert(lines, ("%d. %s - %d wins"):format(index, tostring(entry.userId), tonumber(entry.value) or 0))
			if index >= 5 then
				break
			end
		end
		label.Text = table.concat(lines, "\n")
	end
end

return LeaderboardService
