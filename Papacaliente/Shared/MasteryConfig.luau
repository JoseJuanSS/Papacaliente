local MasteryConfig = {}

MasteryConfig.Achievements = {
	{
		id = "FIRST_WIN",
		title = "Primera Victoria",
		stat = "MatchesWon",
		target = 1,
	},
	{
		id = "PASSER_10",
		title = "Paser Pro",
		stat = "PassesMade",
		target = 10,
	},
	{
		id = "PASSKILL_5",
		title = "Boom Tactico",
		stat = "PassKills",
		target = 5,
	},
	{
		id = "SURVIVE_25",
		title = "Superviviente",
		stat = "RoundsSurvived",
		target = 25,
	},
	{
		id = "HOLDER_60",
		title = "Bomba Humana",
		stat = "TimeAsHolder",
		target = 60,
	},
}

return MasteryConfig
