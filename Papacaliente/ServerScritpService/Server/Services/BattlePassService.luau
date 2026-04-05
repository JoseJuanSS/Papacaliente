local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattlePassConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BattlePassConfig"))

local BattlePassService = {}
BattlePassService.__index = BattlePassService

function BattlePassService.new(remotesService, remoteNames, playerDataService, premiumService, economyService, petService)
	local self = setmetatable({}, BattlePassService)
	self.Data = playerDataService
	self.Premium = premiumService
	self.Economy = economyService
	self.Pets = petService
	self.RE_Request = remotesService:GetOrCreateRemoteEvent(remoteNames.BattlePassRequest)
	self.RE_Update = remotesService:GetOrCreateRemoteEvent(remoteNames.BattlePassUpdate)
	self.RE_Claim = remotesService:GetOrCreateRemoteEvent(remoteNames.BattlePassClaim)

	self.RE_Request.OnServerEvent:Connect(function(player)
		self:Send(player)
	end)

	self.RE_Claim.OnServerEvent:Connect(function(player, tierIndex, track)
		self:Claim(player, tonumber(tierIndex), tostring(track or "free"))
	end)

	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			if player.Parent == Players then
				self:Send(player)
			end
		end)
	end)

	return self
end

function BattlePassService:GetProfile(player)
	return self.Data and self.Data:GetProfile(player) or nil
end

function BattlePassService:EnsureProfile(profile, player)
	profile.BattlePass = profile.BattlePass or {
		SeasonId = BattlePassConfig.ActiveSeason.id,
		XP = 0,
		ClaimedFree = {},
		ClaimedPremium = {},
		PremiumUnlocked = false,
	}
	if profile.BattlePass.SeasonId ~= BattlePassConfig.ActiveSeason.id then
		profile.BattlePass = {
			SeasonId = BattlePassConfig.ActiveSeason.id,
			XP = 0,
			ClaimedFree = {},
			ClaimedPremium = {},
			PremiumUnlocked = false,
		}
	end
	profile.BattlePass.PremiumUnlocked = self.Premium and self.Premium:HasGamepass(player, "BattlePassPremium") or false
end

function BattlePassService:GetUnlockedTierCount(bp)
	local xp = bp and bp.XP or 0
	local unlocked = 0
	for index, tier in ipairs(BattlePassConfig.Tiers) do
		if xp >= (tier.requiredXP or 0) then
			unlocked = index
		end
	end
	return unlocked
end

function BattlePassService:BuildPayload(player)
	local profile = self:GetProfile(player)
	if not profile then
		return {
			season = BattlePassConfig.ActiveSeason,
			tiers = BattlePassConfig.Tiers,
			xp = 0,
			unlockedTiers = 0,
			claimedFree = {},
			claimedPremium = {},
			premiumUnlocked = false,
		}
	end
	self:EnsureProfile(profile, player)
	return {
		season = BattlePassConfig.ActiveSeason,
		tiers = BattlePassConfig.Tiers,
		xp = profile.BattlePass.XP,
		unlockedTiers = self:GetUnlockedTierCount(profile.BattlePass),
		claimedFree = profile.BattlePass.ClaimedFree,
		claimedPremium = profile.BattlePass.ClaimedPremium,
		premiumUnlocked = profile.BattlePass.PremiumUnlocked,
	}
end

function BattlePassService:Send(player)
	self.RE_Update:FireClient(player, self:BuildPayload(player))
end

function BattlePassService:AwardReward(player, reward)
	if not reward then return end
	if reward.type == "Coins" and self.Economy then
		self.Economy:AddCoins(player, reward.amount or 0)
	elseif (reward.type == "Aura" or reward.type == "Trail") and self.Data then
		local profile = self:GetProfile(player)
		if profile then
			profile.Inventory = profile.Inventory or { Aura = {}, Trail = {} }
			profile.Inventory[reward.type] = profile.Inventory[reward.type] or {}
			profile.Inventory[reward.type][reward.id] = true
			profile.owned = profile.owned or {}
			profile.owned[reward.id] = true
		end
	elseif reward.type == "Pet" and self.Pets then
		self.Pets:GrantPet(player, reward.id)
	end

	if _G.InventoryService then
		_G.InventoryService:Send(player)
	end
	if _G.CrateService and _G.CrateService._pushProgressionUpdates then
		local profile = self:GetProfile(player)
		if profile then
			_G.CrateService:_pushProgressionUpdates(player, profile)
		end
	end
end

function BattlePassService:Claim(player, tierIndex, track)
	local profile = self:GetProfile(player)
	if not profile then return end
	self:EnsureProfile(profile, player)

	local tier = BattlePassConfig.Tiers[tierIndex]
	if not tier then
		self:Send(player)
		return
	end

	local unlocked = self:GetUnlockedTierCount(profile.BattlePass)
	if tierIndex > unlocked then
		self:Send(player)
		return
	end

	if track == "premium" then
		if profile.BattlePass.PremiumUnlocked ~= true then
			self:Send(player)
			return
		end
		if profile.BattlePass.ClaimedPremium[tierIndex] == true then
			self:Send(player)
			return
		end
		profile.BattlePass.ClaimedPremium[tierIndex] = true
		self:AwardReward(player, tier.premium)
	else
		if profile.BattlePass.ClaimedFree[tierIndex] == true then
			self:Send(player)
			return
		end
		profile.BattlePass.ClaimedFree[tierIndex] = true
		self:AwardReward(player, tier.free)
	end

	self:Send(player)
end

function BattlePassService:Record(player, eventName, amount)
	local profile = self:GetProfile(player)
	if not profile then return end
	self:EnsureProfile(profile, player)
	local delta = (BattlePassConfig.XP[eventName] or 0) * (tonumber(amount) or 1)
	if delta <= 0 then return end
	profile.BattlePass.XP = math.max(0, (profile.BattlePass.XP or 0) + delta)
	self:Send(player)
end

return BattlePassService
