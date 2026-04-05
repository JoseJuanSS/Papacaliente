local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local ShopController = {}

function ShopController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_ShopRequest = remotes:WaitForChild(RemoteNames.ShopRequest)
	local RE_ShopUpdate = remotes:WaitForChild(RemoteNames.ShopUpdate)
	local RE_PremiumRequest = remotes:WaitForChild(RemoteNames.PremiumRequest)

	local screenGui = UITheme.GetScreenGui(player)
	local viewportInfo = UITheme.GetViewportInfo()

	local toggle = UITheme.CreateIconToggle(screenGui, "ShopToggle", "TIENDA [B]", UITheme.GetRightTogglePosition(viewportInfo, 4))
	local panelSize, panelPos = UITheme.GetCenteredPanelRect(viewportInfo, viewportInfo.mobile and 360 or 620, viewportInfo.mobile and 500 or 440)
	local panel = UITheme.CreatePanel(screenGui, "ShopPanel", panelSize, panelPos)
	panel.Visible = false

	local title = UITheme.CreateSectionTitle(panel, "Tienda", UDim2.new(0, 16, 0, 14), UDim2.new(1, -120, 0, 26))
	local subtitle = UITheme.CreateBodyLabel(panel, "Cosmeticos por coins. Compra y equipa desde aqui.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -140, 0, viewportInfo.mobile and 30 or 18))
	subtitle.TextSize = 14
	local close = UITheme.CreateButton(panel, "CloseShop", "Cerrar", UDim2.new(0, 92, 0, 34), UDim2.new(1, -108, 0, 14), false)

	local coinsLabel = UITheme.CreateBodyLabel(panel, "Coins: -", UDim2.new(0, 16, 0, 72), UDim2.new(0.5, -20, 0, 20))
	local pointsLabel = UITheme.CreateBodyLabel(panel, "TotalPoints: -", UDim2.new(0.5, 4, 0, 72), UDim2.new(0.5, -20, 0, 20))
	coinsLabel.TextSize = 15
	pointsLabel.TextSize = 15

	local coinsTab = UITheme.CreateButton(panel, "CoinsTab", "Coins", UDim2.new(0.5, -18, 0, 34), UDim2.new(0, 14, 0, 100), true)
	local premiumTab = UITheme.CreateButton(panel, "PremiumTab", "Premium", UDim2.new(0.5, -18, 0, 34), UDim2.new(0.5, 4, 0, 100), false)
	local list, layout = UITheme.CreateScrollFrame(panel, "ShopList", UDim2.new(0, 14, 0, 142), UDim2.new(1, -28, 1, -156))
	local state = { catalog = {}, owned = {}, equipped = {}, coins = 0, totalPoints = 0, premiumCatalog = {}, premiumOwned = {} }
	local currentTab = "coins"

	UITheme.RegisterExclusivePanel("shop", panel, function()
		RE_ShopRequest:FireServer("Get")
	end)

	local function isEquipped(item)
		if item.slot == "Aura" then
			return state.equipped and state.equipped.Aura == item.id
		end
		if item.slot == "Trail" then
			return state.equipped and state.equipped.Trail == item.id
		end
		return false
	end

	local function render()
		coinsLabel.Text = ("Coins: %d"):format(state.coins or 0)
		pointsLabel.Text = ("TotalPoints: %d"):format(state.totalPoints or 0)
		coinsTab.BackgroundColor3 = currentTab == "coins" and UITheme.Colors.Accent or UITheme.Colors.PanelStrong
		coinsTab.TextColor3 = currentTab == "coins" and UITheme.Colors.Background or UITheme.Colors.Text
		premiumTab.BackgroundColor3 = currentTab == "premium" and UITheme.Colors.Accent or UITheme.Colors.PanelStrong
		premiumTab.TextColor3 = currentTab == "premium" and UITheme.Colors.Background or UITheme.Colors.Text
		UITheme.ClearFrames(list)

		if currentTab == "coins" then
			for _, item in ipairs(state.catalog or {}) do
				local row = UITheme.CreateCard(list, UDim2.new(1, -4, 0, viewportInfo.mobile and 92 or 74))
				local name = UITheme.CreateSectionTitle(row, item.name or item.id, UDim2.new(0, 12, 0, 10), UDim2.new(0.62, -8, 0, 20))
				name.TextSize = 16
				local meta = UITheme.CreateBodyLabel(
					row,
					("%s | %s | %d coins"):format(tostring(item.slot or "?"), tostring(item.rarity or "?"), tonumber(item.price) or 0),
					UDim2.new(0, 12, 0, 36),
					UDim2.new(viewportInfo.mobile and 1 or 0.62, viewportInfo.mobile and -24 or -8, 0, viewportInfo.mobile and 34 or 18)
				)
				meta.TextSize = 14

				local owned = state.owned and state.owned[item.id] == true
				local equipped = isEquipped(item)
				local buttonText = "Comprar"
				local accent = true

				if owned then
					buttonText = equipped and "Equipado" or "Equipar"
					accent = not equipped
				end

				local action = UITheme.CreateButton(row, "Action", buttonText, UDim2.new(0, viewportInfo.mobile and 110 or 132, 0, 38), UDim2.new(1, viewportInfo.mobile and -122 or -144, 0.5, -19), accent)
				if not owned then
					action.MouseButton1Click:Connect(function()
						RE_ShopRequest:FireServer("Buy", item.id)
					end)
				elseif not equipped then
					action.MouseButton1Click:Connect(function()
						RE_ShopRequest:FireServer("Equip", item.id)
					end)
				else
					action.AutoButtonColor = false
					action.Active = false
				end
			end
		elseif next(state.premiumCatalog or {}) then
			local premiumHeader = UITheme.CreateCard(list, UDim2.new(1, -4, 0, 46))
			local premiumTitle = UITheme.CreateSectionTitle(premiumHeader, "Pases y Premium", UDim2.new(0, 12, 0, 10), UDim2.new(1, -24, 0, 22))
			premiumTitle.TextSize = 16
			local helper = UITheme.CreateBodyLabel(premiumHeader, "Compra acceso premium, pets y battle pass.", UDim2.new(0, 12, 0, 24), UDim2.new(1, -24, 0, 16))
			helper.TextSize = 12

			for _, premium in pairs(state.premiumCatalog or {}) do
				local row = UITheme.CreateCard(list, UDim2.new(1, -4, 0, viewportInfo.mobile and 92 or 74))
				local name = UITheme.CreateSectionTitle(row, premium.displayName or premium.key, UDim2.new(0, 12, 0, 10), UDim2.new(0.62, -8, 0, 20))
				name.TextSize = 16
				local meta = UITheme.CreateBodyLabel(row, premium.description or "", UDim2.new(0, 12, 0, 34), UDim2.new(viewportInfo.mobile and 1 or 0.62, viewportInfo.mobile and -24 or -8, 0, viewportInfo.mobile and 34 or 18))
				meta.TextSize = 14
				local ownedPremium = state.premiumOwned and state.premiumOwned[premium.key] == true
				local action = UITheme.CreateButton(row, "PremiumAction", ownedPremium and "Activo" or "Robux", UDim2.new(0, viewportInfo.mobile and 110 or 132, 0, 38), UDim2.new(1, viewportInfo.mobile and -122 or -144, 0.5, -19), not ownedPremium)
				if ownedPremium then
					action.AutoButtonColor = false
					action.Active = false
				else
					action.MouseButton1Click:Connect(function()
						RE_PremiumRequest:FireServer("Prompt", premium.key)
					end)
				end
			end
		end

		UITheme.RefreshCanvas(list, layout, 10)
	end

	coinsTab.MouseButton1Click:Connect(function()
		currentTab = "coins"
		render()
	end)
	premiumTab.MouseButton1Click:Connect(function()
		currentTab = "premium"
		render()
	end)

	toggle.MouseButton1Click:Connect(function()
		UITheme.ToggleExclusivePanel("shop")
	end)
	close.MouseButton1Click:Connect(function()
		UITheme.SetExclusivePanelOpen("shop", false)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.B then
			UITheme.ToggleExclusivePanel("shop")
		end
	end)

	RE_ShopUpdate.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		state.catalog = payload.catalog or state.catalog
		state.owned = payload.owned or {}
		state.equipped = payload.equipped or {}
		state.coins = payload.coins or 0
		state.totalPoints = payload.totalPoints or 0
		state.premiumCatalog = payload.premiumCatalog or {}
		state.premiumOwned = payload.premiumOwned or {}
		render()
	end)
end

return ShopController
