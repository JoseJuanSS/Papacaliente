-- ServerScriptService/Server/Services/ShopService.lua
-- Mantiene el comportamiento del ShopServer original, pero estructurado.

local Players = game:GetService("Players")

local ShopService = {}
ShopService.__index = ShopService

function ShopService.new(remotesService, remoteNames, economyService, playerDataService, cosmeticsService, premiumService)
	local self = setmetatable({}, ShopService)

	self.Remotes = remotesService
	self.Names = remoteNames
	self.Economy = economyService
	self.Data = playerDataService
	self.Cosmetics = cosmeticsService
	self.Premium = premiumService

	self.RE_ShopRequest = remotesService:GetOrCreateRemoteEvent(remoteNames.ShopRequest)
	self.RE_ShopUpdate = remotesService:GetOrCreateRemoteEvent(remoteNames.ShopUpdate)
	self.RE_InventoryUpdate = remotesService:GetOrCreateRemoteEvent(remoteNames.InventoryUpdate)

	self.CATALOG = {
		{ id="AURA_FIRE", name="Fire Aura", price=50, slot="Aura", rarity="Common" },
		{ id="AURA_ICE", name="Ice Aura", price=90, slot="Aura", rarity="Rare" },
		{ id="AURA_GOLD", name="Gold Aura", price=180, slot="Aura", rarity="Epic" },
		{ id="AURA_VOID", name="Void Aura", price=350, slot="Aura", rarity="Legendary" },
		{ id="TRAIL_SPARK", name="Spark Trail", price=120, slot="Trail", rarity="Rare" },
		{ id="TRAIL_SHADOW", name="Shadow Trail", price=200, slot="Trail", rarity="Epic" },
		{ id="TRAIL_RAINBOW", name="Rainbow Trail", price=500, slot="Trail", rarity="Legendary" },
	}
	self.CatalogById = {}
	for _, item in ipairs(self.CATALOG) do
		self.CatalogById[item.id] = item
	end

	local function hookPlayer(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			local profile = self.Data:GetProfile(player)
			if not profile then return end
			self:MigrateLegacyOwned(profile)
			self.Cosmetics:ApplyEquipped(player, profile.equipped)
			self:PushClientState(player)
		end)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end

	self.RE_ShopRequest.OnServerEvent:Connect(function(player, action, itemId)
		self:HandleRequest(player, action, itemId)
	end)

	return self
end

function ShopService:EnsureInventory(profile)
	profile.Inventory = profile.Inventory or {
		Aura = {},
		Trail = {},
	}
	profile.Inventory.Aura = profile.Inventory.Aura or {}
	profile.Inventory.Trail = profile.Inventory.Trail or {}
	profile.owned = profile.owned or {}
	profile.equipped = profile.equipped or { Aura = nil, Trail = nil }
end

function ShopService:MigrateLegacyOwned(profile)
	self:EnsureInventory(profile)

	for _, item in ipairs(self.CATALOG) do
		if profile.owned[item.id] == true then
			profile.Inventory[item.slot][item.id] = true
		end
		if profile.Inventory[item.slot][item.id] == true then
			profile.owned[item.id] = true
		end
	end
end

function ShopService:BuildOwnedLookup(profile)
	self:MigrateLegacyOwned(profile)

	local owned = {}
	for _, item in ipairs(self.CATALOG) do
		owned[item.id] = profile.Inventory[item.slot][item.id] == true or profile.owned[item.id] == true
	end
	return owned
end

function ShopService:OwnsItem(profile, item)
	self:MigrateLegacyOwned(profile)
	return profile.Inventory[item.slot][item.id] == true or profile.owned[item.id] == true
end

function ShopService:GrantItem(profile, item)
	self:EnsureInventory(profile)
	profile.Inventory[item.slot][item.id] = true
	profile.owned[item.id] = true
end

function ShopService:SerializeInventory(profile)
	self:MigrateLegacyOwned(profile)
	return {
		Inventory = profile.Inventory,
		Equipped = profile.equipped,
	}
end

function ShopService:PushClientState(player)
	if not player or not player.Parent then return end
	local profile = self.Data:GetProfile(player)
	if not profile then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	local totalPoints = leaderstats and leaderstats:FindFirstChild("TotalPoints")

	self.RE_ShopUpdate:FireClient(player, {
		catalog = self.CATALOG,
		owned = self:BuildOwnedLookup(profile),
		equipped = profile.equipped,
		coins = self.Economy:GetCoins(player),
		totalPoints = totalPoints and totalPoints.Value or 0,
		premiumCatalog = self.Premium and self.Premium:BuildPayload(player).catalog or {},
		premiumOwned = self.Premium and self.Premium:BuildPayload(player).owned or {},
	})

	self.RE_InventoryUpdate:FireClient(player, self:SerializeInventory(profile))
end

function ShopService:HandleRequest(player, action, itemId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	local profile = self.Data:GetProfile(player)
	if not profile then return end
	self:MigrateLegacyOwned(profile)

	if action == "Get" then
		self:PushClientState(player)
		return
	end

	local item = self.CatalogById[itemId]
	if not item then
		self:PushClientState(player)
		return
	end

	if action == "Buy" then
		if self:OwnsItem(profile, item) then
			self:PushClientState(player)
			return
		end

		local coins = self.Economy:GetCoins(player)
		if coins < item.price then
			self:PushClientState(player)
			return
		end

		self.Economy:AddCoins(player, -item.price)
		self:GrantItem(profile, item)
		self:PushClientState(player)
		return
	end

	if action == "Equip" then
		if not self:OwnsItem(profile, item) then
			self:PushClientState(player)
			return
		end

		profile.equipped[item.slot] = item.id
		self.Cosmetics:ApplyEquipped(player, profile.equipped)
		self:PushClientState(player)
		return
	end

	self:PushClientState(player)
end

return ShopService
