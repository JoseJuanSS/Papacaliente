local SkillConfig = {}

SkillConfig.Cooldowns = {
	DASH = 12,
	SHIELD = 18,
	SPEED_BURST = 15,
}

SkillConfig.Skills = {
	DASH = {
		id = "DASH",
		displayName = "Dash",
		description = "Impulso corto para reposicionarte.",
		type = "VelocityBurst",
		premium = false,
		duration = 0.2,
		force = 76,
	},
	SHIELD = {
		id = "SHIELD",
		displayName = "Shield",
		description = "Bloquea el pase por un instante.",
		type = "TransferBlock",
		premium = false,
		duration = 1.6,
	},
	SPEED_BURST = {
		id = "SPEED_BURST",
		displayName = "Speed Burst",
		description = "Aumento breve de velocidad.",
		type = "SpeedBurst",
		premium = false,
		duration = 3,
		walkSpeed = 24,
		jumpPower = 60,
	},
}

SkillConfig.DefaultUnlocked = {
	DASH = true,
}

return SkillConfig
