local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MasteryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MasteryConfig"))

local MasteryService = {}
MasteryService.__index = MasteryService

function MasteryService.new(playerDataService)
	local self = setmetatable({}, MasteryService)
	self.Data = playerDataService
	return self
end

function MasteryService:GetProfile(player)
	return self.Data and self.Data:GetProfile(player) or nil
end

function MasteryService:EnsureMastery(profile)
	if not profile then return nil end

	profile.Mastery = profile.Mastery or {}
	profile.Mastery.Unlocked = profile.Mastery.Unlocked or {}
	profile.Mastery.Progress = profile.Mastery.Progress or {}

	return profile.Mastery
end

function MasteryService:Evaluate(player, stats)
	local profile = self:GetProfile(player)
	local mastery = self:EnsureMastery(profile)
	if not mastery or not stats then
		return {}
	end

	local unlockedNow = {}

	for _, achievement in ipairs(MasteryConfig.Achievements) do
		local current = tonumber(stats[achievement.stat]) or 0
		mastery.Progress[achievement.id] = current

		if current >= achievement.target and mastery.Unlocked[achievement.id] ~= true then
			mastery.Unlocked[achievement.id] = true
			table.insert(unlockedNow, {
				id = achievement.id,
				title = achievement.title,
				target = achievement.target,
				stat = achievement.stat,
			})
		end
	end

	return unlockedNow
end

function MasteryService:BuildSnapshot(player, unlockedNow)
	local profile = self:GetProfile(player)
	local mastery = self:EnsureMastery(profile)
	if not mastery then
		return {
			unlockedNow = unlockedNow or {},
			totalUnlocked = 0,
			totalAchievements = #MasteryConfig.Achievements,
		}
	end

	local totalUnlocked = 0
	for _, achievement in ipairs(MasteryConfig.Achievements) do
		if mastery.Unlocked[achievement.id] == true then
			totalUnlocked += 1
		end
	end

	return {
		unlockedNow = unlockedNow or {},
		totalUnlocked = totalUnlocked,
		totalAchievements = #MasteryConfig.Achievements,
	}
end

return MasteryService
