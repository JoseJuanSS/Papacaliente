local BattlePassConfig = {}

BattlePassConfig.ActiveSeason = {
	id = "S1",
	displayName = "Season 1",
	startDate = "2026-04-01",
	endDate = "2026-06-30",
}

BattlePassConfig.XP = {
	PlayMatch = 20,
	SurviveRound = 8,
	PassKill = 20,
	WinMatch = 35,
}

BattlePassConfig.Tiers = {
	[1] = {
		requiredXP = 0,
		free = { type = "Coins", amount = 50 },
		premium = { type = "Pet", id = "PUPPY" },
	},
	[2] = {
		requiredXP = 60,
		free = { type = "Aura", id = "AURA_FIRE" },
		premium = { type = "Coins", amount = 120 },
	},
	[3] = {
		requiredXP = 140,
		free = { type = "Trail", id = "TRAIL_SPARK" },
		premium = { type = "Pet", id = "SPARK" },
	},
	[4] = {
		requiredXP = 260,
		free = { type = "Coins", amount = 150 },
		premium = { type = "Aura", id = "AURA_GOLD" },
	},
	[5] = {
		requiredXP = 420,
		free = { type = "Pet", id = "ASTRO" },
		premium = { type = "Trail", id = "TRAIL_RAINBOW" },
	},
}

return BattlePassConfig
