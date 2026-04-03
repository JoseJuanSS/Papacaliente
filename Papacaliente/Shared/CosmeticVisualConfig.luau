-- ReplicatedStorage/Shared/CosmeticVisualConfig.luau
local CosmeticVisualConfig = {}

CosmeticVisualConfig.Aura = {
	Aura_Spark = {
		Type = "Highlight",
		FillColor = Color3.fromRGB(170, 220, 255),
		OutlineColor = Color3.fromRGB(255, 255, 255),
		FillTransparency = 0.35,
	},
	Aura_Flame = {
		Type = "Highlight",
		FillColor = Color3.fromRGB(255, 120, 40),
		OutlineColor = Color3.fromRGB(255, 220, 120),
		FillTransparency = 0.3,
	},
	Aura_Storm = {
		Type = "Highlight",
		FillColor = Color3.fromRGB(120, 120, 255),
		OutlineColor = Color3.fromRGB(220, 220, 255),
		FillTransparency = 0.28,
	},
	Aura_Godfire = {
		Type = "Highlight",
		FillColor = Color3.fromRGB(255, 70, 70),
		OutlineColor = Color3.fromRGB(255, 255, 120),
		FillTransparency = 0.2,
	},
}

CosmeticVisualConfig.Trail = {
	Trail_Blue = {
		Color = ColorSequence.new(Color3.fromRGB(70, 170, 255)),
		LightEmission = 0.35,
		Lifetime = 0.35,
		MinLength = 0.1,
		WidthScale = NumberSequence.new(0.8),
	},
	Trail_Red = {
		Color = ColorSequence.new(Color3.fromRGB(255, 80, 80)),
		LightEmission = 0.35,
		Lifetime = 0.35,
		MinLength = 0.1,
		WidthScale = NumberSequence.new(0.8),
	},
	Trail_Purple = {
		Color = ColorSequence.new(Color3.fromRGB(180, 80, 255)),
		LightEmission = 0.4,
		Lifetime = 0.4,
		MinLength = 0.1,
		WidthScale = NumberSequence.new(0.9),
	},
	Trail_Neon = {
		Color = ColorSequence.new(Color3.fromRGB(80, 255, 220)),
		LightEmission = 0.6,
		Lifetime = 0.45,
		MinLength = 0.1,
		WidthScale = NumberSequence.new(1),
	},
	Trail_Galaxy = {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 200, 255)),
		}),
		LightEmission = 0.75,
		Lifetime = 0.55,
		MinLength = 0.1,
		WidthScale = NumberSequence.new(1.1),
	},
}

return CosmeticVisualConfig