local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
	local viewportInfo = UITheme.GetViewportInfo()
	local toggle = UITheme.CreateIconToggle(screenGui, "CratesToggle", "CAJAS", UITheme.GetRightTogglePosition(viewportInfo, 1))
	local panelSize, panelPos = UITheme.GetRightPanelRect(viewportInfo, viewportInfo.mobile and 350 or 560, viewportInfo.mobile and 500 or 470, viewportInfo.mobile and 64 or 114)
	local panel = UITheme.CreatePanel(screenGui, "CratesPanel", panelSize, panelPos)
	panel.Visible = false

	local title = UITheme.CreateSectionTitle(panel, "Cajas", UDim2.new(0, 16, 0, 14), UDim2.new(1, -120, 0, 26))
	local subtitle = UITheme.CreateBodyLabel(panel, "Abre cajas cosmeticas y revisa sus odds.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -120, 0, 18))
	subtitle.TextSize = 14
	local close = UITheme.CreateButton(panel, "CloseCrates", "Cerrar", UDim2.new(0, 92, 0, 34), UDim2.new(1, -108, 0, 14), false)
	local list, layout = UITheme.CreateScrollFrame(panel, "CratesList", UDim2.new(0, 14, 0, 80), UDim2.new(1, -28, 1, -234))
	local rouletteBox = UITheme.CreatePanel(panel, "CrateRoulette", UDim2.new(1, -28, 0, viewportInfo.mobile and 92 or 104), UDim2.new(0, 14, 1, -146))
	local rouletteTitle = UITheme.CreateBodyLabel(rouletteBox, "Ruleta", UDim2.new(0, 12, 0, 8), UDim2.new(0, 120, 0, 18))
	rouletteTitle.TextSize = 14
	local rouletteStrip = Instance.new("ScrollingFrame")
	rouletteStrip.Name = "RouletteStrip"
	rouletteStrip.Position = UDim2.new(0, 12, 0, 30)
	rouletteStrip.Size = UDim2.new(1, -24, 0, viewportInfo.mobile and 50 or 58)
	rouletteStrip.BackgroundColor3 = UITheme.Colors.PanelSoft
	rouletteStrip.BackgroundTransparency = 0.08
	rouletteStrip.BorderSizePixel = 0
	rouletteStrip.ScrollBarThickness = 0
	rouletteStrip.CanvasSize = UDim2.new(0, 0, 0, 0)
	rouletteStrip.Parent = rouletteBox
	local stripCorner = Instance.new("UICorner")
	stripCorner.CornerRadius = UDim.new(0, 10)
	stripCorner.Parent = rouletteStrip
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.Padding = UDim.new(0, 8)
	stripLayout.Parent = rouletteStrip
	local stripPadding = Instance.new("UIPadding")
	stripPadding.PaddingLeft = UDim.new(0, 10)
	stripPadding.PaddingRight = UDim.new(0, 10)
	stripPadding.PaddingTop = UDim.new(0, 8)
	stripPadding.PaddingBottom = UDim.new(0, 8)
	stripPadding.Parent = rouletteStrip
	local selector = Instance.new("Frame")
	selector.Size = UDim2.new(0, 4, 1, -16)
	selector.Position = UDim2.new(0.5, -2, 0, 8)
	selector.BackgroundColor3 = UITheme.Colors.Accent
	selector.BorderSizePixel = 0
	selector.Parent = rouletteBox
	local resultBox = UITheme.CreatePanel(panel, "CrateResult", UDim2.new(1, -28, 0, 62), UDim2.new(0, 14, 1, -68))
	local resultLabel = UITheme.CreateBodyLabel(resultBox, "Abre una caja para ver tu premio.", UDim2.new(0, 14, 0, 10), UDim2.new(1, -28, 0, 38))
	resultLabel.TextSize = 14

	local isRolling = false

	local function renderRoulette(sequence)
		UITheme.ClearFrames(rouletteStrip)
		for _, entry in ipairs(sequence or {}) do
			local card = UITheme.CreateCard(rouletteStrip, UDim2.new(0, viewportInfo.mobile and 94 or 108, 1, -2))
			card.BackgroundTransparency = 0.02
			local rarityLabel = UITheme.CreateBodyLabel(card, safeStr(entry.rarity), UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 0, 16))
			rarityLabel.TextSize = 12
			local itemLabel = UITheme.CreateSectionTitle(card, safeStr(entry.displayName), UDim2.new(0, 10, 0, 24), UDim2.new(1, -20, 0, 28))
			itemLabel.TextSize = 14
			itemLabel.TextWrapped = true
		end
		task.defer(function()
			rouletteStrip.CanvasSize = UDim2.new(0, stripLayout.AbsoluteContentSize.X + 20, 0, 0)
			rouletteStrip.CanvasPosition = Vector2.new(0, 0)
		end)
	end

	local function playRoulette(payload)
		local sequence = payload.visualRoll or {}
		renderRoulette(sequence)
		task.wait()

		local cardWidth = viewportInfo.mobile and 102 or 116
		local winningIndex = math.min(#sequence, 16)
		local targetX = math.max(0, ((winningIndex - 1) * cardWidth) - math.floor((rouletteStrip.AbsoluteSize.X - cardWidth) / 2))
		local tween = TweenService:Create(rouletteStrip, TweenInfo.new(2.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			CanvasPosition = Vector2.new(targetX, 0),
		})
		tween:Play()
		tween.Completed:Wait()
	end

	UITheme.RegisterExclusivePanel("crates", panel, function()
		RE_CrateDataRequest:FireServer()
	end)

	local function render(data)
		UITheme.ClearFrames(list)

		for _, crate in pairs(data or {}) do
			local row = UITheme.CreateCard(list, UDim2.new(1, -4, 0, viewportInfo.mobile and 184 or 142))
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
			local contents = UITheme.CreateBodyLabel(row, table.concat(lines, "\n"), UDim2.new(0, 12, 0, 78), UDim2.new(1, viewportInfo.mobile and -24 or -156, 0, viewportInfo.mobile and 76 or 52))
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
		UITheme.ToggleExclusivePanel("crates")
	end)
	close.MouseButton1Click:Connect(function()
		UITheme.SetExclusivePanelOpen("crates", false)
	end)

	RE_CrateDataUpdate.OnClientEvent:Connect(function(data)
		render(data)
	end)

	RE_CrateOpenResult.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end

		if payload.ok ~= true then
			isRolling = false
			if payload.reason == "NotEnoughCoins" then
				resultLabel.Text = "No tienes coins suficientes."
			else
				resultLabel.Text = "No se pudo abrir la caja."
			end
			return
		end

		playRoulette(payload)
		isRolling = false
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
