-- ServerScriptService/Server/Services/PlayerDataService.lua
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local DATA_VERSION = 8

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = deepCopy(v)
	end
	return out
end

local function defaultStats()
	return {
		MatchesPlayed = 0,
		MatchesWon = 0,
		RoundsSurvived = 0,
		PassKills = 0,
		PassesMade = 0,
		TimeAsHolder = 0,
	}
end

local function defaultSession()
	return {
		DataVersion = DATA_VERSION,
		owned = {},
		equipped = { Aura = nil, Trail = nil },
		XP = 0,
		Level = 1,
		Coins = 0,
		Points = 0,
		TotalPoints = 0,
		Missions = {
			Daily = {},
			Weekly = {},
			DailyKey = "",
			WeeklyKey = "",
		},
		Inventory = {
			Aura = {},
			Trail = {},
		},
		Stats = defaultStats(),
		Mastery = {
			Unlocked = {},
			Progress = {},
		},
	}
end

function PlayerDataService.new(economyService)
	local self = setmetatable({}, PlayerDataService)

	self.DS = DataStoreService:GetDataStore("HotPotato_PlayerData_v6")
	self.Economy = economyService
	self.Sessions = {}

	Players.PlayerAdded:Connect(function(plr)
		self:Load(plr)
	end)

	Players.PlayerRemoving:Connect(function(plr)
		self:Save(plr)
		self.Sessions[plr.UserId] = nil
	end)

	game:BindToClose(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			pcall(function()
				self:Save(plr)
			end)
		end
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		self:Load(plr)
	end

	return self
end
function PlayerDataService:GetSession(player)
	local s = self.Sessions[player.UserId]
	if not s then
		s = defaultSession()
		self.Sessions[player.UserId] = s
	end
	return s
end

function PlayerDataService:Load(player)
	local userId = player.UserId
	local key = "u_" .. tostring(userId)

	local data
	local ok = pcall(function()
		data = self.DS:GetAsync(key)
	end)

	local session = defaultSession()

	if ok and type(data) == "table" then
		if type(data.DataVersion) == "number" then session.DataVersion = data.DataVersion end
		if type(data.XP) == "number" then session.XP = data.XP end
		if type(data.Level) == "number" then session.Level = data.Level end
		if type(data.coins) == "number" then session.Coins = data.coins end
		if type(data.Points) == "number" then session.Points = data.Points end
		if type(data.TotalPoints) == "number" then session.TotalPoints = data.TotalPoints end
		if type(data.owned) == "table" then session.owned = deepCopy(data.owned) end
		if type(data.equipped) == "table" then
			session.equipped.Aura = data.equipped.Aura
			session.equipped.Trail = data.equipped.Trail
		end
		self.Economy:SetCoins(player, session.Coins or 0)
		self.Economy:SetPoints(player, session.Points or 0)
		self.Economy:SetTotalPoints(player, session.TotalPoints or 0)
		if type(data.Missions) == "table" then
			session.Missions = deepCopy(data.Missions)
		end
		if type(data.Inventory) == "table" then
			session.Inventory = deepCopy(data.Inventory)
		end
		if type(data.Mastery) == "table" then
			session.Mastery = deepCopy(data.Mastery)
			session.Mastery.Unlocked = session.Mastery.Unlocked or {}
			session.Mastery.Progress = session.Mastery.Progress or {}
		end
		if type(data.Stats) == "table" then
			for key, value in pairs(defaultStats()) do
				if type(data.Stats[key]) == "number" then
					session.Stats[key] = data.Stats[key]
				else
					session.Stats[key] = value
				end
			end
		end
	end

	session.DataVersion = DATA_VERSION

	self.Sessions[userId] = session
	return session
end

function PlayerDataService:Save(player)
	local session = self.Sessions[player.UserId]
	if not session then return end

	local key = "u_" .. tostring(player.UserId)
	local payload = {
		DataVersion = DATA_VERSION,
		owned = session.owned,
		equipped = session.equipped,
		coins = self.Economy:GetCoins(player),
		Points = self.Economy:GetPoints(player),
		TotalPoints = self.Economy:GetTotalPoints(player),

		XP = session.XP,
		Level = session.Level,

		Missions = session.Missions,
		Inventory = session.Inventory,
		Stats = session.Stats,
		Mastery = session.Mastery,
	}

	pcall(function()
		self.DS:SetAsync(key, payload)
	end)
end

function PlayerDataService:GetProfile(player)
	return self.Sessions[player.UserId]
end

return PlayerDataService
