-- StarterPlayerScripts/Client/Controllers/ShopController.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ShopController = {}

function ShopController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local Remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)

	local RE_ShopRequest = Remotes:WaitForChild(RemoteNames.ShopRequest)
	local RE_ShopUpdate  = Remotes:WaitForChild(RemoteNames.ShopUpdate)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local openBtn = Instance.new("TextButton")
	openBtn.Size = UDim2.new(0, 160, 0, 44)
	openBtn.Position = UDim2.new(0, 20, 1, -70)
	openBtn.Text = "?? Shop (B)"
	openBtn.Parent = screenGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 560, 0, 380)
	frame.Position = UDim2.new(0.5, -280, 0.5, -190)
	frame.Visible = false
	frame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 0.3
	title.TextScaled = true
	title.Text = "Shop"
	title.Parent = frame

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Size = UDim2.new(0.5, 0, 0, 28)
	coinsLabel.Position = UDim2.new(0, 0, 0, 40)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.TextScaled = true
	coinsLabel.Text = "Coins: -"
	coinsLabel.Parent = frame

	local pointsLabel = Instance.new("TextLabel")
	pointsLabel.Size = UDim2.new(0.5, 0, 0, 28)
	pointsLabel.Position = UDim2.new(0.5, 0, 0, 40)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.TextScaled = true
	pointsLabel.Text = "TotalPoints: -"
	pointsLabel.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 90, 0, 32)
	closeBtn.Position = UDim2.new(1, -98, 0, 4)
	closeBtn.Text = "X"
	closeBtn.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -84)
	list.Position = UDim2.new(0, 8, 0, 76)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ScrollBarThickness = 8
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local state = { catalog={}, owned={}, equipped={}, coins=0, totalPoints=0 }

	local function clearList()
		for _, ch in ipairs(list:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
	end

	local function isEquipped(item)
		if not state.equipped then return false end
		if item.slot == "Aura" then return state.equipped.Aura == item.id end
		if item.slot == "Trail" then return state.equipped.Trail == item.id end
		return false
	end

	local function render()
		coinsLabel.Text = ("Coins: %d"):format(state.coins or 0)
		pointsLabel.Text = ("TotalPoints: %d"):format(state.totalPoints or 0)
		clearList()

		for _, item in ipairs(state.catalog or {}) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -8, 0, 54)
			row.BackgroundTransparency = 0.2
			row.Parent = list

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(0.62, 0, 1, 0)
			name.BackgroundTransparency = 1
			name.TextScaled = true
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Text = ("%s [%s/%s] - %d"):format(item.name, item.slot, item.rarity or "?", item.price)
			name.Parent = row

			local owned = state.owned and state.owned[item.id] == true
			local equipped = isEquipped(item)

			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0.34, 0, 0.72, 0)
			btn.Position = UDim2.new(0.64, 0, 0.14, 0)
			btn.TextScaled = true

			if not owned then
				btn.Text = "Buy"
				btn.MouseButton1Click:Connect(function()
					RE_ShopRequest:FireServer("Buy", item.id)
				end)
			else
				btn.Text = equipped and "Equipped" or "Equip"
				btn.AutoButtonColor = not equipped
				btn.MouseButton1Click:Connect(function()
					if not equipped then
						RE_ShopRequest:FireServer("Equip", item.id)
					end
				end)
			end
			btn.Parent = row
		end

		task.defer(function()
			list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
		end)
	end

	local function toggle(open)
		frame.Visible = open
		if open then
			RE_ShopRequest:FireServer("Get")
		end
	end

	openBtn.MouseButton1Click:Connect(function() toggle(not frame.Visible) end)
	closeBtn.MouseButton1Click:Connect(function() toggle(false) end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.B then
			toggle(not frame.Visible)
		end
	end)

	RE_ShopUpdate.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then return end
		state.catalog = payload.catalog or {}
		state.owned = payload.owned or {}
		state.equipped = payload.equipped or {}
		state.coins = payload.coins or 0
		state.totalPoints = payload.totalPoints or 0
		render()
	end)
end

return ShopController