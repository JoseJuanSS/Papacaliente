local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local HUDController = {}

function HUDController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local screenGui = UITheme.GetScreenGui(player)
	local viewportInfo = UITheme.GetViewportInfo()

	local remotesFolderName = RemoteNames.RemotesFolder
	local remotes = ReplicatedStorage:FindFirstChild(remotesFolderName)
	while not remotes do
		task.wait(0.1)
		remotes = ReplicatedStorage:FindFirstChild(remotesFolderName)
	end

	local RE_UpdateState = remotes:WaitForChild(RemoteNames.UpdateState)
	local RE_UpdateTimer = remotes:WaitForChild(RemoteNames.UpdateTimer)
	local RE_Announce = remotes:WaitForChild(RemoteNames.Announce)
	local RE_RoundEvent = remotes:FindFirstChild(RemoteNames.RoundEvent)
	local RE_MatchResult = remotes:FindFirstChild(RemoteNames.MatchResult)

	local palette = UITheme.Colors
	local stateData = {
		state = "-",
		holderName = "",
		aliveCount = 0,
		roundIndex = 0,
		mapName = "",
		matchModifier = "Classic",
		matchModifierLabel = "Classic",
		matchModifierDescription = "",
	}
	local currentTimer = "-"
	local logEntries = {}
	local maxLogEntries = 5

	local topBarWidth = UITheme.Scale(viewportInfo.mobile and 240 or 290, viewportInfo)
	local topBarHeight = UITheme.Scale(viewportInfo.mobile and 112 or 122, viewportInfo)
	local topBar = UITheme.CreatePanel(screenGui, "HUDTopBar", UDim2.new(0, topBarWidth, 0, topBarHeight), UDim2.new(0, UITheme.Scale(18, viewportInfo), 0, UITheme.Scale(18, viewportInfo)))
	local coinsLabel = UITheme.CreateSectionTitle(topBar, "Coins: -", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 22))
	coinsLabel.TextSize = 18
	local pointsLabel = UITheme.CreateBodyLabel(topBar, "Points: -", UDim2.new(0, 14, 0, 42), UDim2.new(1, -28, 0, 20))
	pointsLabel.TextSize = 15
	local levelLabel = UITheme.CreateBodyLabel(topBar, "Level: -", UDim2.new(0, 14, 0, 66), UDim2.new(1, -28, 0, 20))
	levelLabel.TextSize = 15
	local spectatorLabel = UITheme.CreateBodyLabel(topBar, "", UDim2.new(0, 14, 0, 90), UDim2.new(1, -28, 0, 18))
	spectatorLabel.TextSize = 14
	spectatorLabel.TextColor3 = palette.Warning

	local centerSize, centerPos = UITheme.GetCenteredPanelRect(viewportInfo, viewportInfo.mobile and 360 or 430, viewportInfo.mobile and 148 or 164)
	centerPos = UDim2.new(centerPos.X.Scale, centerPos.X.Offset, 0, UITheme.Scale(18, viewportInfo))
	local centerCard = UITheme.CreatePanel(screenGui, "HUDCenterCard", centerSize, centerPos)
	local stateLabel = UITheme.CreateSectionTitle(centerCard, "Estado: -", UDim2.new(0, 16, 0, 12), UDim2.new(1, -32, 0, 24))
	local timerLabel = UITheme.CreateSectionTitle(centerCard, "00", UDim2.new(0, 16, 0, 42), UDim2.new(0, 126, 0, 56))
	timerLabel.TextSize = 40
	timerLabel.TextColor3 = palette.AccentSoft
	local holderLabel = UITheme.CreateBodyLabel(centerCard, "Holder: -", UDim2.new(0, 150, 0, 52), UDim2.new(1, -166, 0, 22))
	holderLabel.TextSize = 17
	holderLabel.TextColor3 = palette.Text
	local metaLabel = UITheme.CreateBodyLabel(centerCard, "Vivos: -", UDim2.new(0, 150, 0, 78), UDim2.new(1, -166, 0, 22))
	metaLabel.TextSize = 15
	local mapLabel = UITheme.CreateBodyLabel(centerCard, "Mapa: -", UDim2.new(0, 16, 0, 112), UDim2.new(1, -32, 0, 18))
	mapLabel.TextSize = 14
	local modLabel = UITheme.CreateBodyLabel(centerCard, "Modifier: -", UDim2.new(0, 16, 0, 132), UDim2.new(1, -32, 0, 18))
	modLabel.TextSize = 14

	local logWidth = viewportInfo.mobile and 300 or 360
	local logHeight = viewportInfo.mobile and 132 or 176
	local logSize = UDim2.new(0, UITheme.Scale(logWidth, viewportInfo), 0, UITheme.Scale(logHeight, viewportInfo))
	local logPos
	logPos = UDim2.new(0, UITheme.Scale(18, viewportInfo), 1, -(logSize.Y.Offset + UITheme.Scale(18, viewportInfo)))
	local logPanel = UITheme.CreatePanel(screenGui, "HUDLogPanel", logSize, logPos)
	local logTitle = UITheme.CreateSectionTitle(logPanel, "Bitacora", UDim2.new(0, 14, 0, 10), UDim2.new(1, -28, 0, 22))
	logTitle.TextSize = 18
	local logList, logLayout = UITheme.CreateScrollFrame(logPanel, "LogList", UDim2.new(0, 12, 0, 38), UDim2.new(1, -24, 1, -50))
	logList.BackgroundTransparency = 1
	logList.ScrollBarThickness = 4

	local masterySize, masteryPos = UITheme.GetCenteredPanelRect(viewportInfo, viewportInfo.mobile and 320 or 360, 44)
	masteryPos = UDim2.new(masteryPos.X.Scale, masteryPos.X.Offset, 0, UITheme.Scale(viewportInfo.mobile and 174 or 194, viewportInfo))
	local masteryToast = UITheme.CreatePanel(screenGui, "MasteryToast", masterySize, masteryPos)
	masteryToast.Visible = false
	local masteryLabel = UITheme.CreateBodyLabel(masteryToast, "", UDim2.new(0, 14, 0, 10), UDim2.new(1, -28, 0, 24))
	masteryLabel.TextSize = 15
	masteryLabel.TextColor3 = palette.Warning

	local resultSize, resultPos = UITheme.GetCenteredPanelRect(viewportInfo, viewportInfo.mobile and 360 or 650, viewportInfo.mobile and 420 or 390)
	local resultFrame = UITheme.CreatePanel(screenGui, "ResultPanel", resultSize, resultPos)
	resultFrame.Visible = false
	local resultTitle = UITheme.CreateSectionTitle(resultFrame, "Resumen", UDim2.new(0, 16, 0, 12), UDim2.new(1, -32, 0, 28))
	resultTitle.TextSize = 22
	local resultLabel = UITheme.CreateBodyLabel(resultFrame, "", UDim2.new(0, 16, 0, 48), UDim2.new(1, -32, 1, -64))
	resultLabel.TextWrapped = true
	resultLabel.TextYAlignment = Enum.TextYAlignment.Top
	resultLabel.TextSize = 16
	resultLabel.TextColor3 = palette.Text

	local flashFrame = Instance.new("Frame")
	flashFrame.Name = "HUDFlash"
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = palette.Accent
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 50
	flashFrame.Parent = screenGui

	local function pulseFrame(frame, tint)
		local original = frame.BackgroundColor3
		local originalSize = frame.Size
		local grow = TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset + 8, originalSize.Y.Scale, originalSize.Y.Offset + 6),
		})
		local shrink = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = originalSize,
		})
		if tint then
			frame.BackgroundColor3 = tint
		end
		grow:Play()
		grow.Completed:Connect(function()
			shrink:Play()
		end)
		task.delay(0.28, function()
			frame.BackgroundColor3 = original
		end)
	end

	local function flashScreen(color, peakTransparency)
		flashFrame.BackgroundColor3 = color or palette.Accent
		flashFrame.BackgroundTransparency = 1
		local fadeIn = TweenService:Create(flashFrame, TweenInfo.new(0.08), {
			BackgroundTransparency = peakTransparency or 0.84,
		})
		local fadeOut = TweenService:Create(flashFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		fadeIn:Play()
		fadeIn.Completed:Connect(function()
			fadeOut:Play()
		end)
	end

	local function renderLog()
		UITheme.ClearFrames(logList)
		for _, item in ipairs(logEntries) do
			local row = UITheme.CreateCard(logList, UDim2.new(1, -4, 0, 26))
			row.BackgroundTransparency = 0.2

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 8, 0, 8)
			dot.Position = UDim2.new(0, 8, 0.5, -4)
			dot.BackgroundColor3 = item.color
			dot.BorderSizePixel = 0
			dot.Parent = row
			local dotCorner = Instance.new("UICorner")
			dotCorner.CornerRadius = UDim.new(1, 0)
			dotCorner.Parent = dot

			local label = UITheme.CreateBodyLabel(row, item.text, UDim2.new(0, 24, 0, 4), UDim2.new(1, -32, 1, -8))
			label.TextSize = 13
			label.TextColor3 = palette.Text
		end
		UITheme.RefreshCanvas(logList, logLayout, 8)
	end

	local function pushLog(text, color, ttl)
		if not text or text == "" then
			return
		end

		local entry = {
			id = tostring(os.clock()) .. tostring(math.random(1000, 9999)),
			text = tostring(text),
			color = color or palette.Info,
		}
		table.insert(logEntries, 1, entry)
		while #logEntries > maxLogEntries do
			table.remove(logEntries)
		end
		renderLog()

		task.delay(ttl or 5, function()
			for index, item in ipairs(logEntries) do
				if item.id == entry.id then
					table.remove(logEntries, index)
					renderLog()
					break
				end
			end
		end)
	end

	local function showMastery(text)
		masteryLabel.Text = text or ""
		masteryToast.Visible = true
		pulseFrame(masteryToast, palette.PanelStrong)
		task.delay(3, function()
			if masteryLabel.Text == text then
				masteryToast.Visible = false
				masteryLabel.Text = ""
			end
		end)
	end

	local function refreshHUD()
		stateLabel.Text = ("Estado: %s"):format(tostring(stateData.state or "-"))
		timerLabel.Text = tostring(currentTimer)
		holderLabel.Text = ("Holder: %s"):format((stateData.holderName ~= "" and stateData.holderName) or "-")
		metaLabel.Text = ("Vivos %s | Ronda %s"):format(
			tostring(stateData.aliveCount or "-"),
			tostring(stateData.roundIndex or "-")
		)
		mapLabel.Text = ("Mapa: %s"):format((stateData.mapName ~= "" and stateData.mapName) or "-")
		modLabel.Text = ("Modifier: %s"):format(tostring(stateData.matchModifierLabel or "-"))

		if tonumber(currentTimer) and tonumber(currentTimer) <= 3 and stateData.state == "RUNNING" then
			centerCard.BackgroundColor3 = palette.PanelStrong
			timerLabel.TextColor3 = palette.Warning
			holderLabel.TextColor3 = palette.Warning
		else
			centerCard.BackgroundColor3 = palette.Panel
			timerLabel.TextColor3 = palette.AccentSoft
			holderLabel.TextColor3 = palette.Text
		end

		if player:GetAttribute("Eliminated") == true then
			spectatorLabel.Text = "Modo espectador activo"
		else
			spectatorLabel.Text = ""
		end
	end

	local function hookLeaderstats()
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then return end

		local function bindValue(name, label, prefix)
			local value = leaderstats:FindFirstChild(name)
			if not value then return end
			local function update()
				label.Text = prefix .. tostring(value.Value)
			end
			update()
			value.Changed:Connect(update)
		end

		bindValue("Coins", coinsLabel, "Coins: ")
		bindValue("Points", pointsLabel, "Points: ")
		bindValue("Level", levelLabel, "Level: ")
	end

	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			hookLeaderstats()
		end
	end)
	player:GetAttributeChangedSignal("Eliminated"):Connect(refreshHUD)
	hookLeaderstats()
	refreshHUD()

	RE_UpdateState.OnClientEvent:Connect(function(payload, legacyHolderName)
		if typeof(payload) == "table" then
			stateData.state = payload.state or stateData.state
			stateData.holderName = payload.holderName or ""
			stateData.aliveCount = payload.aliveCount or 0
			stateData.roundIndex = payload.roundIndex or 0
			stateData.mapName = payload.mapName or ""
			stateData.matchModifier = payload.matchModifier or stateData.matchModifier
			stateData.matchModifierLabel = payload.matchModifierLabel or stateData.matchModifier
			stateData.matchModifierDescription = payload.matchModifierDescription or ""
		else
			stateData.state = tostring(payload or "-")
			stateData.holderName = tostring(legacyHolderName or "")
		end
		refreshHUD()
	end)

	RE_UpdateTimer.OnClientEvent:Connect(function(value)
		currentTimer = value
		refreshHUD()
	end)

	RE_Announce.OnClientEvent:Connect(function(text)
		pushLog(text, palette.Info, 4)
	end)

	local function bindRoundEvent(remote)
		if not remote then return end

		remote.OnClientEvent:Connect(function(payload)
			if typeof(payload) ~= "table" then return end

			if payload.event == "potato_passed" then
				pushLog(("Pase: %s -> %s"):format(tostring(payload.fromName or "?"), tostring(payload.toName or "?")), palette.Info, 4)
			elseif payload.event == "sudden_death" then
				pushLog("Sudden death", palette.Warning, 5)
				flashScreen(palette.Warning, 0.9)
			elseif payload.event == "boom" then
				pushLog(("BOOM: %s"):format(tostring(payload.holderName or "-")), palette.Danger, 5)
				flashScreen(palette.Danger, 0.78)
			elseif payload.event == "holder_assigned" then
				pushLog(("Papa caliente: %s"):format(tostring(payload.holderName or "-")), palette.AccentSoft, 4)
			elseif payload.event == "round_started" then
				pushLog(("Ronda %s iniciada"):format(tostring(payload.roundIndex or stateData.roundIndex or "?")), palette.Success, 4)
			elseif payload.event == "modifier_triggered" then
				local label = tostring(payload.modifierLabel or payload.modifier or "?")
				pushLog("Modifier activo: " .. label, palette.AccentSoft, 4)
			elseif payload.event == "mastery_unlocked" then
				if payload.playerUserId == player.UserId and type(payload.unlocked) == "table" and payload.unlocked[1] then
					local title = tostring(payload.unlocked[1].title or "")
					showMastery("Hito desbloqueado: " .. title)
					pushLog("Nuevo hito: " .. title, palette.Warning, 6)
				end
			end
		end)
	end

	local function safeNum(value)
		return tonumber(value) or 0
	end

	local function showResult(payload)
		if typeof(payload) ~= "table" then return end

		local wasWinner = payload.wasWinner == true
		local telemetry = payload.telemetry or {}
		local matchStats = payload.stats and payload.stats.match or {}
		local coinBreakdown = payload.coins and payload.coins.breakdown or {}
		local xpBreakdown = payload.xp and payload.xp.breakdown or {}
		local mastery = payload.mastery or {}
		local liveOps = payload.liveOps or {}
		local unlockedNow = mastery.unlockedNow or {}
		local unlockedTitle = unlockedNow[1] and unlockedNow[1].title or ""

		resultTitle.Text = wasWinner and "Victoria" or ("Ganador: " .. tostring(payload.winnerName or "-"))
		resultTitle.TextColor3 = wasWinner and palette.Success or palette.Text
		resultLabel.Text = table.concat({
			("Mapa: %s"):format(tostring(telemetry.mapName or stateData.mapName or "-")),
			("Modifier: %s"):format(tostring(payload.progression and payload.progression.modifier or stateData.matchModifierLabel or "-")),
			"",
			("Coins +%d | XP +%d"):format(safeNum(payload.coins and payload.coins.total), safeNum(payload.xp and payload.xp.total)),
			("Nivel %s -> %s | XP %s / %s"):format(
				tostring(payload.level and payload.level.before or "-"),
				tostring(payload.level and payload.level.after or "-"),
				tostring(payload.xpAfter or "-"),
				tostring(payload.xpForNext or "-")
			),
			"",
			("Pases %d | Pass-kills %d | Rondas %d"):format(
				safeNum(matchStats.passesMade),
				safeNum(matchStats.passKills),
				safeNum(matchStats.roundsSurvived)
			),
			("Tiempo con la papa %.1fs"):format(tonumber(matchStats.timeAsHolder) or 0),
			"",
			("Coins detalle  P:%d  S:%d  W:%d  PK:%d"):format(
				safeNum(coinBreakdown.ParticipateMatch),
				safeNum(coinBreakdown.SurviveRound),
				safeNum(coinBreakdown.WinMatch),
				safeNum(coinBreakdown.PassKill)
			),
			("XP detalle  P:%d  S:%d  W:%d  PK:%d"):format(
				safeNum(xpBreakdown.ParticipateMatch),
				safeNum(xpBreakdown.SurviveRound),
				safeNum(xpBreakdown.WinMatch),
				safeNum(xpBreakdown.PassKill)
			),
			"",
			("Telemetry  rondas:%d  pases:%d  elim:%d  duracion:%.1fs"):format(
				safeNum(telemetry.roundsPlayed),
				safeNum(telemetry.passesTotal),
				safeNum(telemetry.eliminations),
				tonumber(telemetry.durationSeconds) or 0
			),
			viewportInfo.mobile and "" or ("Sesion  min:%d  partidas:%d  abandons:%d"):format(
				safeNum(liveOps.sessionMinutes),
				safeNum(liveOps.matchesPlayed),
				safeNum(liveOps.abandons)
			),
			viewportInfo.mobile and "" or ("Media reciente  %.1fs  rondas:%.1f  abandons:%.1f"):format(
				tonumber(liveOps.averageDurationSeconds) or 0,
				tonumber(liveOps.averageRounds) or 0,
				tonumber(liveOps.averageAbandons) or 0
			),
			("Hitos %d/%d%s"):format(
				safeNum(mastery.totalUnlocked),
				safeNum(mastery.totalAchievements),
				unlockedTitle ~= "" and (" | Nuevo: " .. tostring(unlockedTitle)) or ""
			),
		}, "\n")

		resultFrame.Visible = true
		task.delay(7, function()
			if resultFrame then
				resultFrame.Visible = false
			end
		end)
	end

	local function bindMatchResult(remote)
		if not remote then return end
		remote.OnClientEvent:Connect(showResult)
	end

	if RE_RoundEvent then
		bindRoundEvent(RE_RoundEvent)
	else
		task.spawn(function()
			local remote = remotes:WaitForChild(RemoteNames.RoundEvent, 10)
			if remote then
				bindRoundEvent(remote)
			end
		end)
	end

	if RE_MatchResult then
		bindMatchResult(RE_MatchResult)
	else
		task.spawn(function()
			local remote = remotes:WaitForChild(RemoteNames.MatchResult, 10)
			if remote then
				bindMatchResult(remote)
			end
		end)
	end
end

return HUDController
