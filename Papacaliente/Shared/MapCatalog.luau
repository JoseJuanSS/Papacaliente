local MapCatalog = {}

MapCatalog.Maps = {
	City = {
		id = "City",
		displayName = "City",
		enabled = true,
		weight = 4,
		recommendedPlayers = 2,
		tags = { "default", "urban" },
	},
	Arena = {
		id = "Arena",
		displayName = "Arena",
		enabled = true,
		weight = 3,
		recommendedPlayers = 4,
		tags = { "default", "open" },
	},
	Rooftops = {
		id = "Rooftops",
		displayName = "Rooftops",
		enabled = true,
		weight = 2,
		recommendedPlayers = 4,
		tags = { "new", "chase" },
	},
	Garden = {
		id = "Garden",
		displayName = "Garden",
		enabled = true,
		weight = 2,
		recommendedPlayers = 6,
		tags = { "new", "casual" },
	},
}

return MapCatalog
