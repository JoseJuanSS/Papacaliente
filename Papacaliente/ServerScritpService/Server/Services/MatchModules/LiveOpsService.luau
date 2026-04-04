local LiveOpsService = {}
LiveOpsService.__index = LiveOpsService

function LiveOpsService.new(config)
	local self = setmetatable({}, LiveOpsService)
	self.Config = config or {}
	self.RecentModifiers = {}
	self.RecentMaps = {}
	self.RecentMatches = {}
	self.PlayerSessions = {}
	return self
end

function LiveOpsService:_pushRecent(list, value, maxSize)
	if not value or value == "" then
		return
	end

	table.insert(list, 1, value)
	while #list > (maxSize or 1) do
		table.remove(list)
	end
end

function LiveOpsService:_contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

function LiveOpsService:RegisterPlayer(player)
	if not player then return end

	local userId = player.UserId
	self.PlayerSessions[userId] = self.PlayerSessions[userId] or {
		joinedAt = os.clock(),
		matchesPlayed = 0,
		abandons = 0,
	}
end

function LiveOpsService:MarkMatchPlayed(players)
	for _, player in ipairs(players or {}) do
		self:RegisterPlayer(player)
		local session = self.PlayerSessions[player.UserId]
		if session then
			session.matchesPlayed += 1
		end
	end
end

function LiveOpsService:MarkAbandon(player)
	if not player then return end
	self:RegisterPlayer(player)

	local session = self.PlayerSessions[player.UserId]
	if session then
		session.abandons += 1
	end
end

function LiveOpsService:GetSessionSnapshot(player)
	self:RegisterPlayer(player)
	local session = self.PlayerSessions[player.UserId]
	if not session then
		return {
			sessionMinutes = 0,
			matchesPlayed = 0,
			abandons = 0,
		}
	end

	return {
		sessionMinutes = math.max(0, math.floor((os.clock() - session.joinedAt) / 60)),
		matchesPlayed = session.matchesPlayed or 0,
		abandons = session.abandons or 0,
	}
end

function LiveOpsService:ChooseModifier(pool, configs, defaultModifier)
	if type(pool) ~= "table" or #pool == 0 then
		return defaultModifier
	end

	local candidates = {}
	for _, modifierId in ipairs(pool) do
		if not self:_contains(self.RecentModifiers, modifierId) then
			table.insert(candidates, modifierId)
		end
	end

	if #candidates == 0 then
		candidates = pool
	end

	local totalWeight = 0
	for _, modifierId in ipairs(candidates) do
		local config = configs and configs[modifierId]
		totalWeight += math.max(1, tonumber(config and config.weight) or 1)
	end

	local roll = math.random(1, math.max(1, totalWeight))
	local cursor = 0

	for _, modifierId in ipairs(candidates) do
		local config = configs and configs[modifierId]
		cursor += math.max(1, tonumber(config and config.weight) or 1)
		if roll <= cursor then
			return modifierId
		end
	end

	return defaultModifier or candidates[1]
end

function LiveOpsService:ChooseMap(mapNames, defaultMapName)
	if type(mapNames) ~= "table" or #mapNames == 0 then
		return defaultMapName
	end

	local candidates = {}
	for _, mapName in ipairs(mapNames) do
		if not self:_contains(self.RecentMaps, mapName) then
			table.insert(candidates, mapName)
		end
	end

	if #candidates == 0 then
		candidates = mapNames
	end

	return candidates[math.random(1, #candidates)]
end

function LiveOpsService:CommitModifier(modifierId)
	self:_pushRecent(self.RecentModifiers, modifierId, self.Config.ModifierHistorySize or 1)
end

function LiveOpsService:CommitMap(mapName)
	self:_pushRecent(self.RecentMaps, mapName, self.Config.MapHistorySize or 1)
end

function LiveOpsService:RecordMatch(summary)
	if type(summary) ~= "table" then
		return
	end

	table.insert(self.RecentMatches, 1, summary)
	while #self.RecentMatches > (self.Config.RecentMatchSamples or 10) do
		table.remove(self.RecentMatches)
	end
end

function LiveOpsService:GetRecentSnapshot()
	local tracked = #self.RecentMatches
	if tracked == 0 then
		return {
			recentMatchesTracked = 0,
			averageDurationSeconds = 0,
			averageRounds = 0,
			averageAbandons = 0,
		}
	end

	local totalDuration = 0
	local totalRounds = 0
	local totalAbandons = 0

	for _, summary in ipairs(self.RecentMatches) do
		totalDuration += tonumber(summary.durationSeconds) or 0
		totalRounds += tonumber(summary.roundsPlayed) or 0
		totalAbandons += tonumber(summary.abandons) or 0
	end

	return {
		recentMatchesTracked = tracked,
		averageDurationSeconds = math.floor((totalDuration / tracked) * 10 + 0.5) / 10,
		averageRounds = math.floor((totalRounds / tracked) * 10 + 0.5) / 10,
		averageAbandons = math.floor((totalAbandons / tracked) * 10 + 0.5) / 10,
	}
end

return LiveOpsService
