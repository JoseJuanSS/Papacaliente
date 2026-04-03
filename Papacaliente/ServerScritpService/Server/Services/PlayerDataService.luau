-- ServerScriptService/Server/Services/PlayerDataService.lua
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

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

function PlayerDataService:GetSession(player)
	local s = self.Sessions[player.UserId]
	if not s then
		s = {
			owned = {},
			equipped = { Aura = nil, Trail = nil },

			XP = 0,
			Level = 1,

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
		}
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

	local session = {
		owned = {},
		equipped = { Aura = nil, Trail = nil },

		XP = 0,
		Level = 1,

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
	}

	if ok and type(data) == "table" then
		if type(data.XP) == "number" then session.XP = data.XP end
		if type(data.Level) == "number" then session.Level = data.Level end
		if type(data.owned) == "table" then session.owned = deepCopy(data.owned) end
		if type(data.equipped) == "table" then
			session.equipped.Aura = data.equipped.Aura
			session.equipped.Trail = data.equipped.Trail
		end
		if type(data.coins) == "number" then
			self.Economy:SetCoins(player, data.coins)
		end
		if type(data.Missions) == "table" then
			session.Missions = deepCopy(data.Missions)
		end
		if type(data.Inventory) == "table" then
			session.Inventory = deepCopy(data.Inventory)
		end
	end

	self.Sessions[userId] = session
	return session
end

function PlayerDataService:Save(player)
	local session = self.Sessions[player.UserId]
	if not session then return end

	local key = "u_" .. tostring(player.UserId)
	local payload = {
		owned = session.owned,
		equipped = session.equipped,
		coins = self.Economy:GetCoins(player),

		XP = session.XP,
		Level = session.Level,

		Missions = session.Missions,
		Inventory = session.Inventory,
	}

	pcall(function()
		self.DS:SetAsync(key, payload)
	end)
end

function PlayerDataService:GetProfile(player)
	return self.Sessions[player.UserId]
end

return PlayerDataService