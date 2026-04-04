local GameConfig = {}

GameConfig.Match = {
	States = {
		LOBBY = "LOBBY",
		INTERMISSION = "INTERMISSION",
		RUNNING = "RUNNING",
		RESULT = "RESULT",
	},
	MinPlayers = 2,
	IntermissionTime = 10,
	StartDelay = 2,
	RoundTime = 10,
	FinalRoundTime = 8,
	FinalRoundPlayerThreshold = 3,
	TouchCooldown = 1.2,
	SpawnNoPassWindow = 1.5,
	SuddenDeathStart = 3,
	DefaultModifier = "Classic",
	ResultDisplayTime = 2,
}

GameConfig.Modifiers = {
	Pool = {
		"Classic",
		"SpeedUp",
		"BoomShorter",
		"DoublePass",
		"RapidPass",
	},
	Configs = {
		Classic = {
			id = "Classic",
			displayName = "Classic",
			type = "None",
			weight = 5,
			description = "Ronda estandar.",
		},
		SpeedUp = {
			id = "SpeedUp",
			displayName = "Speed Up",
			type = "SpeedBoostOnSuddenDeath",
			weight = 2,
			boostWalkSpeed = 24,
			boostJumpPower = 60,
			description = "Todos aceleran al entrar en sudden death.",
		},
		BoomShorter = {
			id = "BoomShorter",
			displayName = "Boom Shorter",
			type = "ShorterRound",
			weight = 3,
			roundTime = 7,
			finalRoundTime = 5,
			description = "La bomba explota mas rapido.",
		},
		DoublePass = {
			id = "DoublePass",
			displayName = "Double Pass",
			type = "RewardMultiplier",
			weight = 2,
			targetReason = "PassKill",
			xpMultiplier = 2,
			coinsMultiplier = 2,
			description = "Los pass-kills valen el doble.",
		},
		RapidPass = {
			id = "RapidPass",
			displayName = "Rapid Pass",
			type = "TouchCooldown",
			weight = 3,
			touchCooldown = 0.7,
			description = "La papa se puede pasar mas rapido.",
		},
	},
}

GameConfig.Rewards = {
	XP = {
		ParticipateMatch = 10,
		SurviveRound = 10,
		PassKill = 25,
		WinMatch = 50,
	},
	Coins = {
		ParticipateMatch = 10,
		SurviveRound = 5,
		PassKill = 10,
		WinMatch = 25,
	},
}

return GameConfig
