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

	local screenGui = UITheme.GetScreenGui(player)
	local viewportInfo = UITheme.GetViewportInfo()

	local toggle = UITheme.CreateIconToggle(screenGui, "ShopToggle", "TIENDA  [B]", UITheme.GetLeftBottomTogglePosition(viewportInfo, 0))
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

	local list, layout = UITheme.CreateScrollFrame(panel, "ShopList", UDim2.new(0, 14, 0, 104), UDim2.new(1, -28, 1, -118))
	local state = { catalog = {}, owned = {}, equipped = {}, coins = 0, totalPoints = 0 }

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
		UITheme.ClearFrames(list)

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

		UITheme.RefreshCanvas(list, layout, 10)
	end

	local function togglePanel(open)
		panel.Visible = open
		if open then
			RE_ShopRequest:FireServer("Get")
		end
	end

	toggle.MouseButton1Click:Connect(function()
		togglePanel(not panel.Visible)
	end)
	close.MouseButton1Click:Connect(function()
		togglePanel(false)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.B then
			togglePanel(not panel.Visible)
		end
	end)

	RE_ShopUpdate.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		state.catalog = payload.catalog or state.catalog
		state.owned = payload.owned or {}
		state.equipped = payload.equipped or {}
		state.coins = payload.coins or 0
		state.totalPoints = payload.totalPoints or 0
		render()
	end)
end

return ShopController
