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
