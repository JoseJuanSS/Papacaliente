-- ServerScriptService/Server/Services/EconomyService.lua
local Players = game:GetService("Players")

local EconomyService = {}
EconomyService.__index = EconomyService

function EconomyService.new(remotesService, remoteNames, playerDataService)
	local self = setmetatable({}, EconomyService)
	self.Remotes = remotesService
	self.Names = remoteNames
	self.Data = playerDataService -- opcional

	-- BindableEvent único para sumar coins desde otros servicios (MatchService, etc.)
	self.BE_AddCoins = remotesService:GetOrCreateBindableEvent(remoteNames.BE_AddCoins)

	self.BE_AddCoins.Event:Connect(function(player, amount)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
		self:AddCoins(player, tonumber(amount) or 0)
	end)

	Players.PlayerAdded:Connect(function(plr)
		self:EnsureLeaderstats(plr)
		self:SyncFromProfile(plr)
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		self:EnsureLeaderstats(plr)
		self:SyncFromProfile(plr)
	end

	return self
end

function EconomyService:SetDataService(playerDataService)
	self.Data = playerDataService
end

function EconomyService:EnsureLeaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end

	local function ensureInt(name, default)
		local v = ls:FindFirstChild(name)
		if not v then
			v = Instance.new("IntValue")
			v.Name = name
			v.Value = default or 0
			v.Parent = ls
		end
		return v
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
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Coins")
	return v and v.Value or 0
end

function EconomyService:SetCoins(player, value)
	self:EnsureLeaderstats(player)
	local v = math.max(0, math.floor(value or 0))
	player.leaderstats.Coins.Value = v

	local profile = self:GetProfile(player)
	if profile then profile.Coins = v end
end

function EconomyService:AddCoins(player, delta)
	self:EnsureLeaderstats(player)
	local add = math.floor(delta or 0)
	if add == 0 then return end

	local v = player.leaderstats.Coins
	v.Value = math.max(0, v.Value + add)

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

	local v = player.leaderstats.Points
	v.Value = math.max(0, v.Value + add)

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

	local v = player.leaderstats.TotalPoints
	v.Value = math.max(0, v.Value + add)

	local profile = self:GetProfile(player)
	if profile then
		profile.TotalPoints = (profile.TotalPoints or 0) + add
		if profile.TotalPoints < 0 then profile.TotalPoints = 0 end
	end
end

return EconomyService
