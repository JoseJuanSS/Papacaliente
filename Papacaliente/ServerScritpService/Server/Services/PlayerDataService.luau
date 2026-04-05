local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local DATA_VERSION = 9
local STORE_NAME = "HotPotato_PlayerData_v6"
local AUTOSAVE_INTERVAL = 60

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, nested in pairs(value) do
		copy[key] = deepCopy(nested)
	end
	return copy
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
		Premium = {
			Gamepasses = {},
			LastSyncAt = 0,
		},
		Pets = {
			Owned = {},
			Equipped = nil,
			Slots = 1,
		},
		Skills = {
			Unlocked = { DASH = true },
			Equipped = "DASH",
		},
		BattlePass = {
			SeasonId = "S1",
			XP = 0,
			ClaimedFree = {},
			ClaimedPremium = {},
			PremiumUnlocked = false,
		},
		SeasonProgress = {},
		AudienceVote = {
			LastMapVote = nil,
			LastVotedAt = 0,
		},
		Debug = {
			LastLoadOk = false,
			LastSaveOk = false,
			LastError = "",
		},
	}
end

local function mergeSession(target, source)
	if type(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			mergeSession(target[key], value)
		elseif value ~= nil then
			target[key] = deepCopy(value)
		end
	end

	return target
end

function PlayerDataService.new(economyService)
	local self = setmetatable({}, PlayerDataService)
	self.DS = DataStoreService:GetDataStore(STORE_NAME)
	self.Economy = economyService
	self.Sessions = {}
	self.DataStoreEnabled = true
	self._autosaveThread = nil

	Players.PlayerAdded:Connect(function(player)
		self:Load(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:Save(player, "PlayerRemoving")
		self.Sessions[player.UserId] = nil
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(function()
				self:Save(player, "BindToClose")
			end)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:Load(player)
	end

	self:StartAutosave()
	return self
end

function PlayerDataService:StartAutosave()
	if self._autosaveThread then
		return
	end

	self._autosaveThread = task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				self:Save(player, "AutoSave")
			end
		end
	end)
end

function PlayerDataService:GetSession(player)
	local session = self.Sessions[player.UserId]
	if not session then
		session = defaultSession()
		self.Sessions[player.UserId] = session
	end
	return session
end

function PlayerDataService:NormalizeSession(session)
	session = mergeSession(defaultSession(), session or {})
	session.DataVersion = DATA_VERSION
	session.Stats = mergeSession(defaultStats(), session.Stats or {})
	session.Inventory = mergeSession({ Aura = {}, Trail = {} }, session.Inventory or {})
	session.equipped = mergeSession({ Aura = nil, Trail = nil }, session.equipped or {})
	session.Mastery = mergeSession({ Unlocked = {}, Progress = {} }, session.Mastery or {})
	session.Premium = mergeSession({ Gamepasses = {}, LastSyncAt = 0 }, session.Premium or {})
	session.Pets = mergeSession({ Owned = {}, Equipped = nil, Slots = 1 }, session.Pets or {})
	session.Skills = mergeSession({ Unlocked = { DASH = true }, Equipped = "DASH" }, session.Skills or {})
	session.BattlePass = mergeSession({
		SeasonId = "S1",
		XP = 0,
		ClaimedFree = {},
		ClaimedPremium = {},
		PremiumUnlocked = false,
	}, session.BattlePass or {})
	session.AudienceVote = mergeSession({ LastMapVote = nil, LastVotedAt = 0 }, session.AudienceVote or {})
	session.Debug = mergeSession({ LastLoadOk = false, LastSaveOk = false, LastError = "" }, session.Debug or {})
	return session
end

function PlayerDataService:BuildPayload(player, session)
	return {
		DataVersion = DATA_VERSION,
		owned = session.owned,
		equipped = session.equipped,
		coins = self.Economy and self.Economy:GetCoins(player) or session.Coins or 0,
		Points = self.Economy and self.Economy:GetPoints(player) or session.Points or 0,
		TotalPoints = self.Economy and self.Economy:GetTotalPoints(player) or session.TotalPoints or 0,
		XP = session.XP,
		Level = session.Level,
		Missions = session.Missions,
		Inventory = session.Inventory,
		Stats = session.Stats,
		Mastery = session.Mastery,
		Premium = session.Premium,
		Pets = session.Pets,
		Skills = session.Skills,
		BattlePass = session.BattlePass,
		SeasonProgress = session.SeasonProgress,
		AudienceVote = session.AudienceVote,
	}
end

function PlayerDataService:MarkDataStoreUnavailable(context, err)
	self.DataStoreEnabled = false
	warn(("[PlayerDataService] DataStore unavailable during %s: %s"):format(tostring(context), tostring(err)))
	if RunService:IsStudio() then
		warn("[PlayerDataService] En Studio activa 'Enable Studio Access to API Services' para probar persistencia real.")
	end
end

function PlayerDataService:Load(player)
	local userId = player.UserId
	local key = "u_" .. tostring(userId)
	local loaded = nil

	local ok, err = pcall(function()
		loaded = self.DS:GetAsync(key)
	end)

	local session = self:NormalizeSession(defaultSession())

	if ok and type(loaded) == "table" then
		session = self:NormalizeSession(loaded)
		session.Debug.LastLoadOk = true
		session.Debug.LastError = ""
		print(("[PlayerDataService] Load OK for %s"):format(player.Name))
	elseif not ok then
		session.Debug.LastLoadOk = false
		session.Debug.LastError = tostring(err)
		self:MarkDataStoreUnavailable("load", err)
	else
		session.Debug.LastLoadOk = true
		session.Debug.LastError = ""
		print(("[PlayerDataService] No existing save for %s, using defaults."):format(player.Name))
	end

	self.Sessions[userId] = session

	if self.Economy then
		self.Economy:SetCoins(player, session.Coins or 0)
		self.Economy:SetPoints(player, session.Points or 0)
		self.Economy:SetTotalPoints(player, session.TotalPoints or 0)
	end

	return session
end

function PlayerDataService:Save(player, reason)
	local session = self.Sessions[player.UserId]
	if not session then
		return false
	end

	local key = "u_" .. tostring(player.UserId)
	local latestPayload = self:BuildPayload(player, self:NormalizeSession(session))

	local ok, err = pcall(function()
		self.DS:UpdateAsync(key, function(oldData)
			local merged = self:NormalizeSession(type(oldData) == "table" and oldData or {})
			return mergeSession(merged, latestPayload)
		end)
	end)

	session.Debug.LastSaveOk = ok
	session.Debug.LastError = ok and "" or tostring(err)

	if ok then
		print(("[PlayerDataService] Save OK for %s (%s)"):format(player.Name, tostring(reason or "manual")))
		return true
	end

	self:MarkDataStoreUnavailable("save", err)
	return false
end

function PlayerDataService:GetProfile(player)
	return self.Sessions[player.UserId]
end

return PlayerDataService
