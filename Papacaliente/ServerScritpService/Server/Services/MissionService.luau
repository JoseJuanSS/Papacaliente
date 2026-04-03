-- ServerScriptService/Server/Services/MissionService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MissionConfig"))

local MissionService = {}
MissionService.__index = MissionService

function MissionService.new(remotesService, remoteNames, playerDataService, economyService, xpService)
	local self = setmetatable({}, MissionService)
	self.RemotesService = remotesService
	self.RemoteNames = remoteNames
	self.Data = playerDataService
	self.Economy = economyService
	self.XP = xpService

	self.RE_MissionsUpdate = remotesService:GetOrCreateRemoteEvent(remoteNames.MissionsUpdate)
	self.RE_MissionsClaim = remotesService:GetOrCreateRemoteEvent(remoteNames.MissionsClaim)
	self.RE_MissionsRequest = remotesService:GetOrCreateRemoteEvent(remoteNames.MissionsRequest)

	self._lastClaimAt = {}

	return self
end

local function utcDateKey()
	local t = os.date("!*t")
	return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

local function utcWeekKey()
	local year = os.date("!%Y")
	local week = os.date("!%W")
	return tostring(year) .. "-" .. tostring(week)
end

local function deepCopy(tbl)
	local out = {}
	for k, v in pairs(tbl) do
		out[k] = (typeof(v) == "table") and deepCopy(v) or v
	end
	return out
end

local function pickN(pool, n)
	local copy = deepCopy(pool)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	local result = {}
	for i = 1, math.min(n, #copy) do
		table.insert(result, copy[i])
	end
	return result
end

function MissionService:_ensureMissionData(session)
	session.Missions = session.Missions or {}
	session.Missions.Daily = session.Missions.Daily or {}
	session.Missions.Weekly = session.Missions.Weekly or {}
	session.Missions.DailyKey = session.Missions.DailyKey or ""
	session.Missions.WeeklyKey = session.Missions.WeeklyKey or ""
end

function MissionService:_regenDaily(session)
	session.Missions.DailyKey = utcDateKey()
	session.Missions.Daily = {}

	local picked = pickN(MissionConfig.DailyPool, MissionConfig.DailyCount)
	for _, m in ipairs(picked) do
		session.Missions.Daily[m.id] = {
			id = m.id,
			title = m.title,
			event = m.event,
			target = m.target,
			progress = 0,
			rewardCoins = m.rewardCoins,
			rewardXP = m.rewardXP,
			claimed = false,
		}
	end
end

function MissionService:_regenWeekly(session)
	session.Missions.WeeklyKey = utcWeekKey()
	session.Missions.Weekly = {}

	local picked = pickN(MissionConfig.WeeklyPool, MissionConfig.WeeklyCount)
	for _, m in ipairs(picked) do
		session.Missions.Weekly[m.id] = {
			id = m.id,
			title = m.title,
			event = m.event,
			target = m.target,
			progress = 0,
			rewardCoins = m.rewardCoins,
			rewardXP = m.rewardXP,
			claimed = false,
		}
	end
end

function MissionService:_refreshIfNeeded(player)
	local session = self.Data:GetProfile(player)
	if not session then
		return
	end

	self:_ensureMissionData(session)

	local dKey = utcDateKey()
	local wKey = utcWeekKey()

	if session.Missions.DailyKey ~= dKey then
		self:_regenDaily(session)
	end
	if session.Missions.WeeklyKey ~= wKey then
		self:_regenWeekly(session)
	end
end

function MissionService:_serialize(session)
	local daily = {}
	local weekly = {}

	for id, m in pairs(session.Missions.Daily) do
		daily[id] = m
	end
	for id, m in pairs(session.Missions.Weekly) do
		weekly[id] = m
	end

	return {
		DailyKey = session.Missions.DailyKey,
		WeeklyKey = session.Missions.WeeklyKey,
		Daily = daily,
		Weekly = weekly,

		-- compatibilidad
		dailyKey = session.Missions.DailyKey,
		weeklyKey = session.Missions.WeeklyKey,
		daily = daily,
		weekly = weekly,
	}
end

function MissionService:Send(player)
	local session = self.Data:GetProfile(player)
	if not session then
		return
	end
	self:_refreshIfNeeded(player)
	self.RE_MissionsUpdate:FireClient(player, self:_serialize(session))
end

function MissionService:Record(player, eventName, amount)
	if not player or player.Parent ~= Players then
		return
	end
	if typeof(eventName) ~= "string" then
		return
	end

	amount = tonumber(amount) or 1
	if amount <= 0 then
		return
	end

	local session = self.Data:GetProfile(player)
	if not session then
		return
	end

	self:_refreshIfNeeded(player)

	local function applyToBucket(bucket)
		for _, m in pairs(bucket) do
			if m.claimed ~= true and m.event == eventName and m.progress < m.target then
				m.progress = math.min(m.target, m.progress + amount)
			end
		end
	end

	applyToBucket(session.Missions.Daily)
	applyToBucket(session.Missions.Weekly)

	self:Send(player)
end

function MissionService:_tryClaim(player, missionId)
	local now = os.clock()
	local uid = player.UserId
	local last = self._lastClaimAt[uid] or 0
	if now - last < 0.4 then
		return false
	end
	self._lastClaimAt[uid] = now

	local session = self.Data:GetProfile(player)
	if not session then
		return false
	end
	self:_refreshIfNeeded(player)

	local m = session.Missions.Daily[missionId] or session.Missions.Weekly[missionId]
	if not m then
		return false
	end
	if m.claimed then
		return false
	end
	if m.progress < m.target then
		return false
	end

	m.claimed = true

	if self.Economy and self.Economy.BE_AddCoins and m.rewardCoins and m.rewardCoins > 0 then
		self.Economy.BE_AddCoins:Fire(player, m.rewardCoins)
	end

	if self.XP and self.XP.AddXP and m.rewardXP and m.rewardXP > 0 then
		self.XP:AddXP(player, m.rewardXP, "MissionReward")
	end

	return true
end

function MissionService:Start()
	self.RE_MissionsRequest.OnServerEvent:Connect(function(player)
		if not player or player.Parent ~= Players then
			return
		end
		self:Send(player)
	end)

	self.RE_MissionsClaim.OnServerEvent:Connect(function(player, missionId)
		if not player or player.Parent ~= Players then
			return
		end
		if typeof(missionId) ~= "string" then
			return
		end
		self:_tryClaim(player, missionId)
		self:Send(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.delay(0.4, function()
			if player.Parent ~= Players then
				return
			end
			self:_refreshIfNeeded(player)
			self:Send(player)
		end)
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		self:_refreshIfNeeded(p)
		self:Send(p)
	end
end

return MissionService