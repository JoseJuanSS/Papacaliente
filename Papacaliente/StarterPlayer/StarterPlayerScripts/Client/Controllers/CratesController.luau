local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CratesController = {}

local function safeStr(v)
	if v == nil then return "" end
	return tostring(v)
end

function CratesController.Start(RemoteNames)
	local player = Players.LocalPlayer

	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_CrateOpenRequest = remotes:WaitForChild(RemoteNames.CrateOpenRequest)
	local RE_CrateOpenResult = remotes:WaitForChild(RemoteNames.CrateOpenResult)
	local RE_CrateDataRequest = remotes:WaitForChild(RemoteNames.CrateDataRequest)
	local RE_CrateDataUpdate = remotes:WaitForChild(RemoteNames.CrateDataUpdate)

	local screenGui = player:WaitForChild("PlayerGui"):FindFirstChild("HotPotatoUI")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "HotPotatoUI"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end

	local toggle = Instance.new("TextButton")
	toggle.Name = "CratesToggle"
	toggle.Size = UDim2.new(0, 180, 0, 40)
	toggle.Position = UDim2.new(1, -200, 0, 70)
	toggle.TextScaled = true
	toggle.Text = "?? Cajas"
	toggle.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "CratesPanel"
	panel.Size = UDim2.new(0, 540, 0, 460)
	panel.Position = UDim2.new(1, -560, 0, 120)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "Cajas y Ruleta"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 40, 0, 40)
	close.Position = UDim2.new(1, -50, 0, 10)
	close.TextScaled = true
	close.Text = "X"
	close.Parent = panel

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(1, -20, 1, -130)
	listFrame.Position = UDim2.new(0, 10, 0, 60)
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.ScrollBarThickness = 8
	listFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = listFrame

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Size = UDim2.new(1, -20, 0, 60)
	resultLabel.Position = UDim2.new(0, 10, 1, -65)
	resultLabel.BackgroundTransparency = 0.15
	resultLabel.TextScaled = true
	resultLabel.Text = "Abre una caja para ver tu premio."
	resultLabel.Parent = panel

	local cratesCache = nil
	local isRolling = false

	local function clearList()
		for _, ch in ipairs(listFrame:GetChildren()) do
			if ch:IsA("Frame") then
				ch:Destroy()
			end
		end
	end

	local function resizeCanvas()
		task.wait()
		listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
	end

	local function buildFlatItemPool(crate)
		local pool = {}
		for rarity, items in pairs(crate.items) do
			for _, item in ipairs(items) do
				table.insert(pool, {
					rarity = rarity,
					item = item,
				})
			end
		end
		return pool
	end

	local function playFakeRoll(crate)
		local pool = buildFlatItemPool(crate)
		if #pool == 0 then return end

		isRolling = true
		local duration = 1.8
		local step = 0.08
		local elapsed = 0

		while elapsed < duration do
			local entry = pool[math.random(1, #pool)]
			resultLabel.Text = "Girando... [" .. safeStr(entry.rarity) .. "] " .. safeStr(entry.item.displayName)
			task.wait(step)
			elapsed += step
		end
	end

	local function createCrateRow(crate)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 140)
		row.BackgroundTransparency = 0.2
		row.Parent = listFrame

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -150, 0, 30)
		titleLabel.Position = UDim2.new(0, 10, 0, 8)
		titleLabel.BackgroundTransparency = 1
		titleLabel.TextScaled = true
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Text = safeStr(crate.title) .. " - " .. tostring(crate.priceCoins) .. " Coins"
		titleLabel.Parent = row

		local oddsLabel = Instance.new("TextLabel")
		oddsLabel.Size = UDim2.new(1, -150, 0, 26)
		oddsLabel.Position = UDim2.new(0, 10, 0, 40)
		oddsLabel.BackgroundTransparency = 1
		oddsLabel.TextScaled = true
		oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
		oddsLabel.Text = "Common 60% | Rare 30% | Epic 9% | Legendary 1%"
		oddsLabel.Parent = row

		local itemsLabel = Instance.new("TextLabel")
		itemsLabel.Size = UDim2.new(1, -150, 0, 60)
		itemsLabel.Position = UDim2.new(0, 10, 0, 68)
		itemsLabel.BackgroundTransparency = 1
		itemsLabel.TextWrapped = true
		itemsLabel.TextScaled = false
		itemsLabel.TextXAlignment = Enum.TextXAlignment.Left
		itemsLabel.TextYAlignment = Enum.TextYAlignment.Top

		local lines = {}
		for rarity, items in pairs(crate.items) do
			local names = {}
			for _, item in ipairs(items) do
				table.insert(names, item.displayName)
			end
			table.insert(lines, rarity .. ": " .. table.concat(names, ", "))
		end
		itemsLabel.Text = table.concat(lines, "\n")
		itemsLabel.Parent = row

		local openBtn = Instance.new("TextButton")
		openBtn.Size = UDim2.new(0, 120, 0, 90)
		openBtn.Position = UDim2.new(1, -130, 0, 20)
		openBtn.TextScaled = true
		openBtn.Text = "Abrir"
		openBtn.Parent = row

		openBtn.MouseButton1Click:Connect(function()
			if isRolling then return end

			task.spawn(function()
				playFakeRoll(crate)
			end)

			RE_CrateOpenRequest:FireServer(crate.id)
		end)
	end

	local function renderCrates(data)
		cratesCache = data
		clearList()

		for _, crate in pairs(data) do
			createCrateRow(crate)
		end

		resizeCanvas()
	end

	toggle.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			RE_CrateDataRequest:FireServer()
		end
	end)

	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	RE_CrateDataUpdate.OnClientEvent:Connect(function(data)
		renderCrates(data)
	end)

	RE_CrateOpenResult.OnClientEvent:Connect(function(payload)
		isRolling = false

		if not payload then return end
		if payload.ok ~= true then
			if payload.reason == "NotEnoughCoins" then
				resultLabel.Text = "No tienes Coins suficientes."
			else
				resultLabel.Text = "No se pudo abrir la caja."
			end
			return
		end

		local item = payload.item
		if payload.duplicate then
			resultLabel.Text = "Duplicado: " .. safeStr(item.displayName) .. " | Refund +" .. tostring(payload.refundCoins) .. " Coins"
		else
			resultLabel.Text = "Ganaste [" .. safeStr(payload.rarity) .. "] " .. safeStr(item.displayName)
		end
	end)

	task.delay(1, function()
		RE_CrateDataRequest:FireServer()
	end)
end

return CratesController