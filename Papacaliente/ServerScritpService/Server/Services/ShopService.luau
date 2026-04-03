-- ServerScriptService/Server/Services/ShopService.lua
-- Mantiene el comportamiento del ShopServer original, pero estructurado.

local Players = game:GetService("Players")

local ShopService = {}
ShopService.__index = ShopService

function ShopService.new(remotesService, remoteNames, economyService, playerDataService, cosmeticsService)
	local self = setmetatable({}, ShopService)

	self.Remotes = remotesService
	self.Names = remoteNames
	self.Economy = economyService
	self.Data = playerDataService
	self.Cosmetics = cosmeticsService

	self.RE_ShopRequest = remotesService:GetOrCreateRemoteEvent(remoteNames.ShopRequest)
	self.RE_ShopUpdate  = remotesService:GetOrCreateRemoteEvent(remoteNames.ShopUpdate)

	-- CATALOGO ORIGINAL
	self.CATALOG = {
		{ id="AURA_FIRE",   name="Fire Aura",   price=50,  slot="Aura",  rarity="Common" },
		{ id="AURA_ICE",    name="Ice Aura",    price=90,  slot="Aura",  rarity="Rare" },
		{ id="AURA_GOLD",   name="Gold Aura",   price=180, slot="Aura",  rarity="Epic" },
		{ id="AURA_VOID",   name="Void Aura",   price=350, slot="Aura",  rarity="Legendary" },

		{ id="TRAIL_SPARK",   name="Spark Trail",   price=120, slot="Trail", rarity="Rare" },
		{ id="TRAIL_SHADOW",  name="Shadow Trail",  price=200, slot="Trail", rarity="Epic" },
		{ id="TRAIL_RAINBOW", name="Rainbow Trail", price=500, slot="Trail", rarity="Legendary" },
	}
	self.CatalogById = {}
	for _, it in ipairs(self.CATALOG) do self.CatalogById[it.id] = it end

	local function getTotalPoints(plr)
		local ls = plr:FindFirstChild("leaderstats")
		local tp = ls and ls:FindFirstChild("TotalPoints")
		return tp and tp.Value or 0
	end

	function self:SendUpdate(plr)
		if not plr or not plr.Parent then return end
		local data = self.Data:GetSession(plr)
		self.RE_ShopUpdate:FireClient(plr, {
			catalog = self.CATALOG,
			owned = data.owned,
			equipped = data.equipped,
			coins = self.Economy:GetCoins(plr),
			totalPoints = getTotalPoints(plr),
		})
	end

	-- aplicar cosmetics al respawn (igual que antes)
	local function hookPlayer(plr)
		plr.CharacterAdded:Connect(function()
			task.wait(0.1)
			local data = self.Data:GetSession(plr)
			self.Cosmetics:ApplyEquipped(plr, data.equipped)
			self:SendUpdate(plr)
		end)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end

	self.RE_ShopRequest.OnServerEvent:Connect(function(plr, action, itemId)
		self:HandleRequest(plr, action, itemId)
	end)

	return self
end

function ShopService:HandleRequest(plr, action, itemId)
	if typeof(plr) ~= "Instance" or not plr:IsA("Player") then return end
	local data = self.Data:GetSession(plr)

	if action == "Get" then
		self:SendUpdate(plr)
		return
	end

	local item = self.CatalogById[itemId]
	if not item then
		self:SendUpdate(plr)
		return
	end

	if action == "Buy" then
		if data.owned[itemId] then
			self:SendUpdate(plr)
			return
		end
		local coins = self.Economy:GetCoins(plr)
		if coins < item.price then
			self:SendUpdate(plr)
			return
		end
		self.Economy:AddCoins(plr, -item.price)
		data.owned[itemId] = true
		self:SendUpdate(plr)
		return
	end

	if action == "Equip" then
		if not data.owned[itemId] then
			self:SendUpdate(plr)
			return
		end

		if item.slot == "Aura" then
			data.equipped.Aura = itemId
			self.Cosmetics:ApplyAura(plr, itemId)
		elseif item.slot == "Trail" then
			data.equipped.Trail = itemId
			self.Cosmetics:ApplyTrail(plr, itemId)
		end

		self:SendUpdate(plr)
		return
	end

	self:SendUpdate(plr)
end

return ShopService