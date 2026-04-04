-- ServerScriptService/Server/Services/CrateService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CrateConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CrateConfig"))

local CrateService = {}
CrateService.__index = CrateService

function CrateService.new(remotesService, remoteNames, playerDataService, economyService)
	local self = setmetatable({}, CrateService)

	self.RemotesService = remotesService
	self.RemoteNames = remoteNames
	self.Data = playerDataService
	self.Economy = economyService

	self.RE_CrateOpenRequest = remotesService:GetOrCreateRemoteEvent(remoteNames.CrateOpenRequest)
	self.RE_CrateOpenResult = remotesService:GetOrCreateRemoteEvent(remoteNames.CrateOpenResult)
	self.RE_CrateDataRequest = remotesService:GetOrCreateRemoteEvent(remoteNames.CrateDataRequest)
	self.RE_CrateDataUpdate = remotesService:GetOrCreateRemoteEvent(remoteNames.CrateDataUpdate)
	self.RE_InventoryUpdate = remotesService:GetOrCreateRemoteEvent(remoteNames.InventoryUpdate)

	self._lastOpenAt = {}

	return self
end

local function getRandomRarity(weights)
	local total = 0
	for _, weight in pairs(weights) do
		total += weight
	end

	local roll = math.random() * total
	local acc = 0
	for rarity, weight in pairs(weights) do
		acc += weight
		if roll <= acc then
			return rarity
		end
	end

	return "Common"
end

local function pickRandomItem(list)
	if not list or #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

function CrateService:_ensureInventory(profile)
	profile.Inventory = profile.Inventory or {
		Aura = {},
		Trail = {},
	}
	profile.Inventory.Aura = profile.Inventory.Aura or {}
	profile.Inventory.Trail = profile.Inventory.Trail or {}
	profile.equipped = profile.equipped or { Aura = nil, Trail = nil }
end

function CrateService:_ownsItem(profile, itemType, itemId)
	self:_ensureInventory(profile)
	local bucket = profile.Inventory[itemType]
	if not bucket then return false end
	return bucket[itemId] == true
end

function CrateService:_grantItem(profile, itemType, itemId)
	self:_ensureInventory(profile)
	profile.Inventory[itemType][itemId] = true
end

function CrateService:_serializeCrates()
	local out = {}
	for crateId, crate in pairs(CrateConfig.Crates) do
		out[crateId] = {
			id = crate.id,
			title = crate.title,
			priceCoins = crate.priceCoins,
			dupeRefundPercent = crate.dupeRefundPercent,
			items = crate.items,
		}
	end
	return out
end

function CrateService:_serializeInventory(profile)
	self:_ensureInventory(profile)
	return {
		Inventory = profile.Inventory,
		Equipped = profile.equipped,
	}
end

function CrateService:_pushProgressionUpdates(player, profile)
	if not player or player.Parent ~= Players or not profile then return end
	self.RE_InventoryUpdate:FireClient(player, self:_serializeInventory(profile))
end

function CrateService:SendCrateData(player)
	if not player or player.Parent ~= Players then return end
	self.RE_CrateDataUpdate:FireClient(player, self:_serializeCrates())
end

function CrateService:_openCrate(player, crateId)
	local now = os.clock()
	local userId = player.UserId
	local last = self._lastOpenAt[userId] or 0
	if now - last < 0.75 then
		return
	end
	self._lastOpenAt[userId] = now

	local profile = self.Data:GetProfile(player)
	if not profile then
		return
	end

	local crate = CrateConfig.Crates[crateId]
	if not crate then
		return
	end

	local coins = self.Economy:GetCoins(player)
	if coins < crate.priceCoins then
		self.RE_CrateOpenResult:FireClient(player, {
			ok = false,
			reason = "NotEnoughCoins",
			crateId = crateId,
		})
		return
	end

	local rarity = getRandomRarity(CrateConfig.RarityWeights)
	local rarityItems = crate.items[rarity]
	if not rarityItems or #rarityItems == 0 then
		self.RE_CrateOpenResult:FireClient(player, {
			ok = false,
			reason = "NoItemsForRarity",
			crateId = crateId,
		})
		return
	end

	local item = pickRandomItem(rarityItems)
	if not item then
		self.RE_CrateOpenResult:FireClient(player, {
			ok = false,
			reason = "NoItem",
			crateId = crateId,
		})
		return
	end

	self.Economy:SetCoins(player, coins - crate.priceCoins)

	self:_ensureInventory(profile)

	local duplicate = self:_ownsItem(profile, item.type, item.id)
	local refundCoins = 0
	if duplicate then
		refundCoins = math.floor(crate.priceCoins * (crate.dupeRefundPercent or 0))
		if refundCoins > 0 then
			self.Economy:SetCoins(player, self.Economy:GetCoins(player) + refundCoins)
		end
	else
		self:_grantItem(profile, item.type, item.id)
	end

	self:_pushProgressionUpdates(player, profile)

	self.RE_CrateOpenResult:FireClient(player, {
		ok = true,
		crateId = crateId,
		rarity = rarity,
		item = item,
		duplicate = duplicate,
		refundCoins = refundCoins,
		coinsAfter = self.Economy:GetCoins(player),
	})
end

function CrateService:Start()
	self.RE_CrateDataRequest.OnServerEvent:Connect(function(player)
		self:SendCrateData(player)
	end)

	self.RE_CrateOpenRequest.OnServerEvent:Connect(function(player, crateId)
		if typeof(crateId) ~= "string" then return end
		self:_openCrate(player, crateId)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SendCrateData(player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			if player.Parent == Players then
				self:SendCrateData(player)
			end
		end)
	end)
end

return CrateService
