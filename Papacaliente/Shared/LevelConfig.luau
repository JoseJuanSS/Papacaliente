-- ReplicatedStorage/Shared/LevelConfig.lua
-- Configuración de niveles / experiencia.
-- Cambia aquí la curva sin tocar servicios.

local LevelConfig = {}

LevelConfig.MaxLevel = 100

-- XP requerida para pasar del nivel L al L+1
-- Curva simple (ajustable): base + (L-1)*step
LevelConfig.BaseXP = 100
LevelConfig.StepXP = 50

function LevelConfig.XPToNext(level: number): number
	level = math.max(1, math.floor(level))
	return LevelConfig.BaseXP + (level - 1) * LevelConfig.StepXP
end

-- Devuelve: newLevel, remainingXP
function LevelConfig.ApplyLevelUps(level: number, xp: number)
	level = math.max(1, math.floor(level))
	xp = math.max(0, math.floor(xp))

	while level < LevelConfig.MaxLevel do
		local need = LevelConfig.XPToNext(level)
		if xp < need then break end
		xp -= need
		level += 1
	end

	return level, xp
end

return LevelConfig