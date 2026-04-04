-- ServerScriptService/Server/Services/EconomyService.lua
local Players = game:GetService("Players")

local EconomyService = {}
EconomyService.__index = EconomyService

function EconomyService.new(remotesService, remoteNames, playerDataService)
	local self = setmetatable({}, EconomyService)
	self.Remotes = remotesService
	self.Names = remoteNames
	self.Data = playerDataService

	self.BE_AddCoins = remotesService:GetOrCreateBindableEvent(remoteNames.BE_AddCoins)
	self.BE_AddCoins.Event:Connect(function(player, amount)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
		self:AddCoins(player, tonumber(amount) or 0)
	end)

	Players.PlayerAdded:Connect(function(player)
		self:EnsureLeaderstats(player)
		self:SyncFromProfile(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:EnsureLeaderstats(player)
		self:SyncFromProfile(player)
	end

	return self
end

function EconomyService:SetDataService(playerDataService)
	self.Data = playerDataService
end

function EconomyService:EnsureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local function ensureInt(name, defaultValue)
		local value = leaderstats:FindFirstChild(name)
		if not value then
			value = Instance.new("IntValue")
			value.Name = name
			value.Value = defaultValue or 0
			value.Parent = leaderstats
		end
		return value
	end

	ensureInt("Coins", 0)
	ensureInt("Points", 0)
	ensureInt("TotalPoints", 0)
end

function EconomyService:GetProfile(player)
	if not self.Data then return nil end
	return self.Data:GetProfile(player)
end

function EconomyService:SyncFromProfile(player)
	local profile = self:GetProfile(player)
	if not profile then return end
	self:EnsureLeaderstats(player)

	profile.Coins = profile.Coins or 0
	profile.Points = profile.Points or 0
	profile.TotalPoints = profile.TotalPoints or 0

	player.leaderstats.Coins.Value = profile.Coins
	player.leaderstats.Points.Value = profile.Points
	player.leaderstats.TotalPoints.Value = profile.TotalPoints
end

function EconomyService:GetCoins(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Coins")
	return value and value.Value or 0
end

function EconomyService:GetPoints(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Points")
	return value and value.Value or 0
end

function EconomyService:GetTotalPoints(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("TotalPoints")
	return value and value.Value or 0
end

function EconomyService:SetCoins(player, value)
	self:EnsureLeaderstats(player)
	local safeValue = math.max(0, math.floor(value or 0))
	player.leaderstats.Coins.Value = safeValue

	local profile = self:GetProfile(player)
	if profile then
		profile.Coins = safeValue
	end
end

function EconomyService:SetPoints(player, value)
	self:EnsureLeaderstats(player)
	local safeValue = math.max(0, math.floor(value or 0))
	player.leaderstats.Points.Value = safeValue

	local profile = self:GetProfile(player)
	if profile then
		profile.Points = safeValue
	end
end

function EconomyService:SetTotalPoints(player, value)
	self:EnsureLeaderstats(player)
	local safeValue = math.max(0, math.floor(value or 0))
	player.leaderstats.TotalPoints.Value = safeValue

	local profile = self:GetProfile(player)
	if profile then
		profile.TotalPoints = safeValue
	end
end

function EconomyService:AddCoins(player, delta)
	self:EnsureLeaderstats(player)
	local add = math.floor(delta or 0)
	if add == 0 then return end

	local value = player.leaderstats.Coins
	value.Value = math.max(0, value.Value + add)

	local profile = self:GetProfile(player)
	if profile then
		profile.Coins = (profile.Coins or 0) + add
		if profile.Coins < 0 then profile.Coins = 0 end
	end
end

function EconomyService:AddPoints(player, delta)
	self:EnsureLeaderstats(player)
	local add = math.floor(delta or 0)
	if add == 0 then return end

	local value = player.leaderstats.Points
	value.Value = math.max(0, value.Value + add)

	local profile = self:GetProfile(player)
	if profile then
		profile.Points = (profile.Points or 0) + add
		if profile.Points < 0 then profile.Points = 0 end
	end
end

function EconomyService:AddTotalPoints(player, delta)
	self:EnsureLeaderstats(player)
	local add = math.floor(delta or 0)
	if add == 0 then return end

	local value = player.leaderstats.TotalPoints
	value.Value = math.max(0, value.Value + add)

	local profile = self:GetProfile(player)
	if profile then
		profile.TotalPoints = (profile.TotalPoints or 0) + add
		if profile.TotalPoints < 0 then profile.TotalPoints = 0 end
	end
end

return EconomyService