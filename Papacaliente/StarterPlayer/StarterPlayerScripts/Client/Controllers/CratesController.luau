local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local CratesController = {}

local function safeStr(value)
	if value == nil then return "" end
	return tostring(value)
end

function CratesController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_CrateOpenRequest = remotes:WaitForChild(RemoteNames.CrateOpenRequest)
	local RE_CrateOpenResult = remotes:WaitForChild(RemoteNames.CrateOpenResult)
	local RE_CrateDataRequest = remotes:WaitForChild(RemoteNames.CrateDataRequest)
	local RE_CrateDataUpdate = remotes:WaitForChild(RemoteNames.CrateDataUpdate)

	local screenGui = UITheme.GetScreenGui(player)
	local toggle = UITheme.CreateIconToggle(screenGui, "CratesToggle", "CAJAS", UDim2.new(1, -202, 0, 68))
	local panel = UITheme.CreatePanel(screenGui, "CratesPanel", UDim2.new(0, 560, 0, 470), UDim2.new(1, -578, 0, 114))
	panel.Visible = false

	local title = UITheme.CreateSectionTitle(panel, "Cajas", UDim2.new(0, 16, 0, 14), UDim2.new(1, -120, 0, 26))
	local subtitle = UITheme.CreateBodyLabel(panel, "Abre cajas cosmeticas y revisa sus odds.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -120, 0, 18))
	subtitle.TextSize = 14
	local close = UITheme.CreateButton(panel, "CloseCrates", "Cerrar", UDim2.new(0, 92, 0, 34), UDim2.new(1, -108, 0, 14), false)
	local list, layout = UITheme.CreateScrollFrame(panel, "CratesList", UDim2.new(0, 14, 0, 80), UDim2.new(1, -28, 1, -146))
	local resultBox = UITheme.CreatePanel(panel, "CrateResult", UDim2.new(1, -28, 0, 54), UDim2.new(0, 14, 1, -68))
	local resultLabel = UITheme.CreateBodyLabel(resultBox, "Abre una caja para ver tu premio.", UDim2.new(0, 14, 0, 10), UDim2.new(1, -28, 0, 30))
	resultLabel.TextSize = 14

	local isRolling = false

	local function render(data)
		UITheme.ClearFrames(list)

		for _, crate in pairs(data or {}) do
			local row = UITheme.CreateCard(list, UDim2.new(1, -4, 0, 142))
			local crateTitle = UITheme.CreateSectionTitle(row, safeStr(crate.title), UDim2.new(0, 12, 0, 10), UDim2.new(1, -156, 0, 20))
			crateTitle.TextSize = 16
			local price = UITheme.CreateBodyLabel(row, ("%d coins"):format(tonumber(crate.priceCoins) or 0), UDim2.new(0, 12, 0, 34), UDim2.new(1, -156, 0, 18))
			price.TextSize = 14
			local odds = UITheme.CreateBodyLabel(row, "Common 60% | Rare 30% | Epic 9% | Legendary 1%", UDim2.new(0, 12, 0, 54), UDim2.new(1, -156, 0, 18))
			odds.TextSize = 13

			local lines = {}
			for rarity, items in pairs(crate.items or {}) do
				local names = {}
				for _, item in ipairs(items) do
					table.insert(names, safeStr(item.displayName))
				end
				table.insert(lines, rarity .. ": " .. table.concat(names, ", "))
			end
			local contents = UITheme.CreateBodyLabel(row, table.concat(lines, "\n"), UDim2.new(0, 12, 0, 78), UDim2.new(1, -156, 0, 52))
			contents.TextYAlignment = Enum.TextYAlignment.Top
			contents.TextSize = 13

			local openButton = UITheme.CreateButton(row, "OpenCrate", "Abrir", UDim2.new(0, 124, 0, 40), UDim2.new(1, -136, 0.5, -20), true)
			openButton.MouseButton1Click:Connect(function()
				if isRolling then return end
				isRolling = true
				resultLabel.Text = "Abriendo caja..."
				RE_CrateOpenRequest:FireServer(crate.id)
			end)
		end

		UITheme.RefreshCanvas(list, layout, 10)
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
		render(data)
	end)

	RE_CrateOpenResult.OnClientEvent:Connect(function(payload)
		isRolling = false
		if typeof(payload) ~= "table" then return end

		if payload.ok ~= true then
			if payload.reason == "NotEnoughCoins" then
				resultLabel.Text = "No tienes coins suficientes."
			else
				resultLabel.Text = "No se pudo abrir la caja."
			end
			return
		end

		local item = payload.item
		if payload.duplicate then
			resultLabel.Text = ("Duplicado: %s | Refund +%d coins"):format(safeStr(item and item.displayName), tonumber(payload.refundCoins) or 0)
		else
			resultLabel.Text = ("Ganaste [%s] %s"):format(safeStr(payload.rarity), safeStr(item and item.displayName))
		end
	end)

	task.delay(1, function()
		RE_CrateDataRequest:FireServer()
	end)
end

return CratesController
