-- ReplicatedStorage/Shared/CrateConfig.lua
local CrateConfig = {}

CrateConfig.RarityWeights = {
	Common = 60,
	Rare = 30,
	Epic = 9,
	Legendary = 1,
}

CrateConfig.Crates = {
	BasicCrate = {
		id = "BasicCrate",
		title = "Caja Básica",
		priceCoins = 150,
		dupeRefundPercent = 0.35,

		items = {
			Common = {
				{ id = "Trail_Blue", type = "Trail", displayName = "Blue Trail" },
				{ id = "Trail_Red", type = "Trail", displayName = "Red Trail" },
				{ id = "Aura_Spark", type = "Aura", displayName = "Spark Aura" },
			},
			Rare = {
				{ id = "Trail_Purple", type = "Trail", displayName = "Purple Trail" },
				{ id = "Aura_Flame", type = "Aura", displayName = "Flame Aura" },
			},
			Epic = {
				{ id = "Trail_Neon", type = "Trail", displayName = "Neon Trail" },
				{ id = "Aura_Storm", type = "Aura", displayName = "Storm Aura" },
			},
			Legendary = {
				{ id = "Trail_Galaxy", type = "Trail", displayName = "Galaxy Trail" },
				{ id = "Aura_Godfire", type = "Aura", displayName = "Godfire Aura" },
			},
		},
	},
}

return CrateConfig