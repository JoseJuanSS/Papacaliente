local RewardResolver = {}
RewardResolver.__index = RewardResolver

local DEFAULT_BREAKDOWN = {
	ParticipateMatch = 0,
	SurviveRound = 0,
	WinMatch = 0,
	PassKill = 0,
}

function RewardResolver.new(economyService, remotesService, remoteNames, playerDataService)
	local self = setmetatable({}, RewardResolver)
	self.Economy = economyService
	self.RemotesService = remotesService
	self.RemoteNames = remoteNames
	self.Data = playerDataService
	self:Reset()
	return self
end

function RewardResolver:Reset()
	self.CoinsEarned = {}
	self.XPEarned = {}
	self.LevelBefore = {}
	self.XPBefore = {}
	self.CoinsBreakdown = {}
	self.XPBreakdown = {}
	self.MatchStats = {}
	self.MatchTelemetry = {
		modifier = "Classic",
		mapName = "",
		roundsPlayed = 0,
		passesTotal = 0,
		eliminations = 0,
		passKills = 0,
		durationSeconds = 0,
	}
end

function RewardResolver:EnsureBreakdown(tbl, userId)
	tbl[userId] = tbl[userId] or {
		ParticipateMatch = 0,
		SurviveRound = 0,
		WinMatch = 0,
		PassKill = 0,
	}
	return tbl[userId]
end

function RewardResolver:EnsureMatchStats(userId)
	self.MatchStats[userId] = self.MatchStats[userId] or {
		PassesMade = 0,
		PassKills = 0,
		RoundsSurvived = 0,
		TimeAsHolder = 0,
	}
	return self.MatchStats[userId]
end

function RewardResolver:GetProfile(player)
	return self.Data and self.Data:GetProfile(player) or nil
end

function RewardResolver:EnsureProfileStats(player)
	local profile = self:GetProfile(player)
	if not profile then return nil end

	profile.Stats = profile.Stats or {}

	local defaults = {
		MatchesPlayed = 0,
		MatchesWon = 0,
		RoundsSurvived = 0,
		PassKills = 0,
		PassesMade = 0,
		TimeAsHolder = 0,
	}

	for key, value in pairs(defaults) do
		if type(profile.Stats[key]) ~= "number" then
			profile.Stats[key] = value
		end
	end

	return profile.Stats
end

function RewardResolver:AddPersistentStat(player, statName, amount)
	amount = tonumber(amount) or 0
	if amount == 0 then return end

	local stats = self:EnsureProfileStats(player)
	if not stats then return end

	stats[statName] = (stats[statName] or 0) + amount
end

function RewardResolver:CaptureBefore(players, xpService)
	if not xpService or not xpService.GetLevelXP then
		return
	end

	for _, player in ipairs(players) do
		local level, xp = xpService:GetLevelXP(player)
		self.LevelBefore[player.UserId] = level
		self.XPBefore[player.UserId] = xp
	end
end

function RewardResolver:AwardXP(player, amount, reason, playersService)
	amount = tonumber(amount) or 0
	if amount <= 0 then return end
	if not player or player.Parent ~= playersService then return end

	local xpService = _G.XPService
	if not xpService then return end

	self.XPEarned[player.UserId] = (self.XPEarned[player.UserId] or 0) + math.floor(amount)
	local breakdown = self:EnsureBreakdown(self.XPBreakdown, player.UserId)
	if breakdown[reason] ~= nil then
		breakdown[reason] += amount
	end

	pcall(function()
		xpService:AddXP(player, amount, reason)
	end)
end

function RewardResolver:AwardCoins(player, amount, reason, playersService)
	amount = tonumber(amount) or 0
	if amount == 0 then return end
	if not player or player.Parent ~= playersService then return end

	self.CoinsEarned[player.UserId] = (self.CoinsEarned[player.UserId] or 0) + math.floor(amount)
	local breakdown = self:EnsureBreakdown(self.CoinsBreakdown, player.UserId)
	if breakdown[reason] ~= nil then
		breakdown[reason] += amount
	end

	if self.Economy and self.Economy.BE_AddCoins then
		self.Economy.BE_AddCoins:Fire(player, amount)
	else
		local bindable = self.RemotesService:GetOrCreateBindableEvent(self.RemoteNames.BE_AddCoins)
		bindable:Fire(player, amount)
	end
end

function RewardResolver:RecordPass(player)
	if not player then return end
	self:EnsureMatchStats(player.UserId).PassesMade += 1
	self:AddPersistentStat(player, "PassesMade", 1)
	self.MatchTelemetry.passesTotal += 1
end

function RewardResolver:RecordPassKill(player)
	if not player then return end
	self:EnsureMatchStats(player.UserId).PassKills += 1
	self:AddPersistentStat(player, "PassKills", 1)
	self.MatchTelemetry.passKills += 1
end

function RewardResolver:RecordRoundSurvived(player)
	if not player then return end
	self:EnsureMatchStats(player.UserId).RoundsSurvived += 1
	self:AddPersistentStat(player, "RoundsSurvived", 1)
end

function RewardResolver:RecordMatchPlayed(player)
	if not player then return end
	self:AddPersistentStat(player, "MatchesPlayed", 1)
	self:EnsureMatchStats(player.UserId)
end

function RewardResolver:RecordMatchWin(player)
	if not player then return end
	self:AddPersistentStat(player, "MatchesWon", 1)
end

function RewardResolver:RecordElimination()
	self.MatchTelemetry.eliminations += 1
end

function RewardResolver:SetMatchTelemetry(modifier, roundsPlayed, durationSeconds, mapName)
	self.MatchTelemetry.modifier = modifier or self.MatchTelemetry.modifier
	self.MatchTelemetry.roundsPlayed = tonumber(roundsPlayed) or self.MatchTelemetry.roundsPlayed
	self.MatchTelemetry.durationSeconds = tonumber(durationSeconds) or self.MatchTelemetry.durationSeconds
	self.MatchTelemetry.mapName = mapName or self.MatchTelemetry.mapName
end

function RewardResolver:RecordHolderTime(player, seconds)
	if not player then return end
	local rounded = math.max(0, math.round((tonumber(seconds) or 0) * 10) / 10)
	if rounded <= 0 then return end

	self:EnsureMatchStats(player.UserId).TimeAsHolder += rounded
	self:AddPersistentStat(player, "TimeAsHolder", rounded)
end

function RewardResolver:BuildMatchResultPayload(player, winner, modifier, roundsPlayed, masterySnapshot, liveOpsSnapshot)
	local xpService = _G.XPService
	local levelAfter, xpAfter = 1, 0
	local xpForNext = 100

	if xpService and xpService.GetLevelXP then
		levelAfter, xpAfter = xpService:GetLevelXP(player)
		if xpService.GetXPToNext then
			xpForNext = xpService:GetXPToNext(levelAfter)
		end
	end

	local matchStats = self:EnsureMatchStats(player.UserId)
	local profileStats = self:EnsureProfileStats(player) or {}

	return {
		version = 2,
		winnerName = winner and winner.Name or "",
		wasWinner = winner == player,
		coins = {
			total = self.CoinsEarned[player.UserId] or 0,
			breakdown = self.CoinsBreakdown[player.UserId] or DEFAULT_BREAKDOWN,
		},
		xp = {
			total = self.XPEarned[player.UserId] or 0,
			breakdown = self.XPBreakdown[player.UserId] or DEFAULT_BREAKDOWN,
		},
		level = {
			before = self.LevelBefore[player.UserId] or levelAfter,
			after = levelAfter,
		},
		xpBefore = self.XPBefore[player.UserId] or 0,
		xpAfter = xpAfter,
		xpForNext = xpForNext,
		stats = {
			match = {
				passesMade = matchStats.PassesMade,
				passKills = matchStats.PassKills,
				roundsSurvived = matchStats.RoundsSurvived,
				timeAsHolder = matchStats.TimeAsHolder,
			},
			lifetime = {
				matchesPlayed = profileStats.MatchesPlayed or 0,
				matchesWon = profileStats.MatchesWon or 0,
				roundsSurvived = profileStats.RoundsSurvived or 0,
				passKills = profileStats.PassKills or 0,
				passesMade = profileStats.PassesMade or 0,
				timeAsHolder = profileStats.TimeAsHolder or 0,
			},
		},
		progression = {
			modifier = modifier,
			roundsPlayed = roundsPlayed,
		},
		telemetry = self.MatchTelemetry,
		mastery = masterySnapshot or {
			unlockedNow = {},
			totalUnlocked = 0,
			totalAchievements = 0,
		},
		liveOps = liveOpsSnapshot or {
			sessionMinutes = 0,
			matchesPlayed = 0,
			abandons = 0,
			recentMatchesTracked = 0,
			averageDurationSeconds = 0,
			averageRounds = 0,
			averageAbandons = 0,
		},
	}
end

return RewardResolver
