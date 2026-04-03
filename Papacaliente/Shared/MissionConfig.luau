-- ReplicatedStorage/Shared/MissionConfig.lua
local MissionConfig = {}

MissionConfig.DailyPool = {
	{
		id = "D_PLAY_3",
		title = "Juega 3 partidas",
		event = "PlayMatch",
		target = 3,
		rewardCoins = 40,
		rewardXP = 30,
	},
	{
		id = "D_SURVIVE_5",
		title = "Sobrevive 5 rondas",
		event = "SurviveRound",
		target = 5,
		rewardCoins = 50,
		rewardXP = 45,
	},
	{
		id = "D_PASSKILL_2",
		title = "Logra 2 Pass-Kills",
		event = "PassKill",
		target = 2,
		rewardCoins = 60,
		rewardXP = 60,
	},
	{
		id = "D_WIN_1",
		title = "Gana 1 partida",
		event = "WinMatch",
		target = 1,
		rewardCoins = 80,
		rewardXP = 80,
	},
}

MissionConfig.WeeklyPool = {
	{
		id = "W_PLAY_20",
		title = "Juega 20 partidas",
		event = "PlayMatch",
		target = 20,
		rewardCoins = 300,
		rewardXP = 250,
	},
	{
		id = "W_SURVIVE_40",
		title = "Sobrevive 40 rondas",
		event = "SurviveRound",
		target = 40,
		rewardCoins = 350,
		rewardXP = 320,
	},
	{
		id = "W_PASSKILL_10",
		title = "Logra 10 Pass-Kills",
		event = "PassKill",
		target = 10,
		rewardCoins = 400,
		rewardXP = 380,
	},
	{
		id = "W_WIN_5",
		title = "Gana 5 partidas",
		event = "WinMatch",
		target = 5,
		rewardCoins = 450,
		rewardXP = 450,
	},
}

MissionConfig.DailyCount = 3
MissionConfig.WeeklyCount = 3

return MissionConfig