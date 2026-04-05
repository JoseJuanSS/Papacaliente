local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PremiumConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PremiumConfig"))

local PremiumService = {}
PremiumService.__index = PremiumService

function PremiumService.new(remotesService, remoteNames, playerDataService)
	local self = setmetatable({}, PremiumService)
	self.Data = playerDataService
	self.RE_Request = remotesService:GetOrCreateRemoteEvent(remoteNames.PremiumRequest)
	self.RE_Update = remotesService:GetOrCreateRemoteEvent(remoteNames.PremiumUpdate)

	self.RE_Request.OnServerEvent:Connect(function(player, action, premiumKey)
		if action == "Sync" then
			self:SyncPlayer(player)
		elseif action == "Prompt" and typeof(premiumKey) == "string" then
			self:Prompt(player, premiumKey)
		else
			self:Send(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			if player.Parent == Players then
				self:SyncPlayer(player)
			end
		end)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, purchased)
		if purchased and player and player.Parent == Players then
			self:SyncPlayer(player)
		end
	end)

	return self
end

function PremiumService:GetProfile(player)
	return self.Data and self.Data:GetProfile(player) or nil
end

function PremiumService:EnsureProfile(profile)
	profile.Premium = profile.Premium or { Gamepasses = {}, LastSyncAt = 0 }
	profile.Premium.Gamepasses = profile.Premium.Gamepasses or {}
end

function PremiumService:HasGamepass(player, premiumKey)
	local profile = self:GetProfile(player)
	if not profile then
		return false
	end
	self:EnsureProfile(profile)
	return profile.Premium.Gamepasses[premiumKey] == true
end

function PremiumService:BuildPayload(player)
	local profile = self:GetProfile(player)
	if not profile then
		return { catalog = {}, owned = {} }
	end
	self:EnsureProfile(profile)
	return {
		catalog = PremiumConfig.Gamepasses,
		owned = profile.Premium.Gamepasses,
		lastSyncAt = profile.Premium.LastSyncAt or 0,
	}
end

function PremiumService:Send(player)
	self.RE_Update:FireClient(player, self:BuildPayload(player))
end

function PremiumService:Prompt(player, premiumKey)
	local item = PremiumConfig.Gamepasses[premiumKey]
	if not item or not item.id or item.id <= 0 then
		self:Send(player)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, item.id)
end

function PremiumService:SyncPlayer(player)
	local profile = self:GetProfile(player)
	if not profile then
		return
	end
	self:EnsureProfile(profile)

	for premiumKey, item in pairs(PremiumConfig.Gamepasses) do
		if item.id and item.id > 0 then
			local ok, owned = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.id)
			end)
			if ok then
				profile.Premium.Gamepasses[premiumKey] = owned == true
			end
		else
			profile.Premium.Gamepasses[premiumKey] = profile.Premium.Gamepasses[premiumKey] == true
		end
	end

	profile.Premium.LastSyncAt = os.time()
	self:Send(player)
end

return PremiumService
