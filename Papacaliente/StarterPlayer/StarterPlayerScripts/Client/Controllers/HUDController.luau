local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HUDController = {}

function HUDController.Start(RemoteNames)
	local player = Players.LocalPlayer

	local remotesFolderName = RemoteNames.RemotesFolder
	local Remotes = ReplicatedStorage:FindFirstChild(remotesFolderName)
	while not Remotes do
		task.wait(0.1)
		Remotes = ReplicatedStorage:FindFirstChild(remotesFolderName)
	end

	local RE_UpdateState = Remotes:WaitForChild(RemoteNames.UpdateState)
	local RE_UpdateTimer = Remotes:WaitForChild(RemoteNames.UpdateTimer)
	local RE_Announce = Remotes:WaitForChild(RemoteNames.Announce)
	local RE_RoundEvent = Remotes:FindFirstChild(RemoteNames.RoundEvent)
	local RE_MatchResult = Remotes:FindFirstChild(RemoteNames.MatchResult)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HotPotatoUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local function makeLabel(size, pos, text)
		local l = Instance.new("TextLabel")
		l.Size = size
		l.Position = pos
		l.BackgroundTransparency = 0.3
		l.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		l.TextColor3 = Color3.fromRGB(255, 255, 255)
		l.TextScaled = true
		l.Font = Enum.Font.GothamBold
		l.Text = text or ""
		l.Parent = screenGui
		return l
	end

	local stateLabel = makeLabel(UDim2.new(0, 360, 0, 42), UDim2.new(0.5, -180, 0, 20), "Estado: -")
	local holderLabel = makeLabel(UDim2.new(0, 360, 0, 42), UDim2.new(0.5, -180, 0, 70), "Holder: -")
	local timerLabel = makeLabel(UDim2.new(0, 220, 0, 64), UDim2.new(0.5, -110, 0, 124), "Timer: -")
	local metaLabel = makeLabel(UDim2.new(0, 420, 0, 40), UDim2.new(0.5, -210, 0, 198), "Vivos: - | Ronda: - | Mod: -")
	local announceLabel = makeLabel(UDim2.new(0, 600, 0, 42), UDim2.new(0.5, -300, 0, 248), "")
	local eventLabel = makeLabel(UDim2.new(0, 420, 0, 38), UDim2.new(0.5, -210, 0, 296), "")
	local spectatorLabel = makeLabel(UDim2.new(0, 260, 0, 36), UDim2.new(1, -280, 0, 20), "")
	local masteryLabel = makeLabel(UDim2.new(0, 500, 0, 42), UDim2.new(0.5, -250, 0, 342), "")

	local coinsLabel = makeLabel(UDim2.new(0, 220, 0, 40), UDim2.new(0, 20, 0, 20), "Coins: -")
	local pointsLabel = makeLabel(UDim2.new(0, 220, 0, 40), UDim2.new(0, 20, 0, 70), "Points: -")
	local levelLabel = makeLabel(UDim2.new(0, 220, 0, 40), UDim2.new(0, 20, 0, 120), "Level: -")

	local resultFrame = Instance.new("Frame")
	resultFrame.Size = UDim2.new(0, 620, 0, 360)
	resultFrame.Position = UDim2.new(0.5, -310, 0.5, -180)
	resultFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	resultFrame.BackgroundTransparency = 0.15
	resultFrame.Visible = false
	resultFrame.Parent = screenGui

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Size = UDim2.new(1, -24, 1, -24)
	resultLabel.Position = UDim2.new(0, 12, 0, 12)
	resultLabel.BackgroundTransparency = 1
	resultLabel.TextWrapped = true
	resultLabel.TextXAlignment = Enum.TextXAlignment.Left
	resultLabel.TextYAlignment = Enum.TextYAlignment.Top
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.TextScaled = false
	resultLabel.TextSize = 20
	resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	resultLabel.Text = ""
	resultLabel.Parent = resultFrame

	local flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.Position = UDim2.fromScale(0, 0)
	flashFrame.BackgroundColor3 = Color3.fromRGB(255, 120, 60)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 50
	flashFrame.Parent = screenGui

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

	local function refreshHUD()
		stateLabel.Text = ("Estado: %s"):format(tostring(stateData.state or "-"))
		holderLabel.Text = ("Holder: %s"):format((stateData.holderName and stateData.holderName ~= "") and stateData.holderName or "-")
		metaLabel.Text = ("Vivos: %s | Ronda: %s | Mapa: %s | Mod: %s"):format(
			tostring(stateData.aliveCount or "-"),
			tostring(stateData.roundIndex or "-"),
			tostring((stateData.mapName and stateData.mapName ~= "") and stateData.mapName or "-"),
			tostring(stateData.matchModifierLabel or stateData.matchModifier or "Classic")
		)
		timerLabel.Text = ("Timer: %s"):format(tostring(currentTimer))

		if tostring(currentTimer) ~= "-" and tonumber(currentTimer) and tonumber(currentTimer) <= 3 and stateData.state == "RUNNING" then
			timerLabel.BackgroundColor3 = Color3.fromRGB(140, 25, 25)
			timerLabel.TextColor3 = Color3.fromRGB(255, 235, 120)
			holderLabel.BackgroundColor3 = Color3.fromRGB(120, 40, 15)
		else
			timerLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
			timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			holderLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		end

		if player:GetAttribute("Eliminated") == true then
			spectatorLabel.Text = "Modo espectador"
			spectatorLabel.Visible = true
		else
			spectatorLabel.Text = ""
			spectatorLabel.Visible = false
		end
	end

	local function hookLeaderstats()
		local ls = player:FindFirstChild("leaderstats")
		if not ls then return end

		local function bindValue(name, label, prefix)
			local value = ls:FindFirstChild(name)
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

	player.ChildAdded:Connect(function(ch)
		if ch.Name == "leaderstats" then
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
			stateData.matchModifier = payload.matchModifier or "Classic"
			stateData.matchModifierLabel = payload.matchModifierLabel or stateData.matchModifier
			stateData.matchModifierDescription = payload.matchModifierDescription or ""
		else
			stateData.state = tostring(payload or "-")
			stateData.holderName = tostring(legacyHolderName or "")
		end
		refreshHUD()
	end)

	RE_UpdateTimer.OnClientEvent:Connect(function(t)
		currentTimer = t
		refreshHUD()
	end)

	RE_Announce.OnClientEvent:Connect(function(text)
		announceLabel.Text = tostring(text or "")
	end)

	local function pulseLabel(label, color)
		local originalSize = label.Size
		local originalColor = label.BackgroundColor3
		if color then
			label.BackgroundColor3 = color
		end

		local grow = TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(
				originalSize.X.Scale,
				originalSize.X.Offset + 18,
				originalSize.Y.Scale,
				originalSize.Y.Offset + 8
			),
		})
		local shrink = TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = originalSize,
		})

		grow:Play()
		grow.Completed:Connect(function()
			shrink:Play()
		end)

		task.delay(0.4, function()
			label.BackgroundColor3 = originalColor
		end)
	end

	local function flashScreen(color, peakTransparency)
		flashFrame.BackgroundColor3 = color or Color3.fromRGB(255, 120, 60)
		flashFrame.BackgroundTransparency = 1

		local show = TweenService:Create(flashFrame, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {
			BackgroundTransparency = peakTransparency or 0.78,
		})
		local hide = TweenService:Create(flashFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})

		show:Play()
		show.Completed:Connect(function()
			hide:Play()
		end)
	end

	local function showEvent(text, color)
		eventLabel.Text = text or ""
		eventLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
		pulseLabel(eventLabel, Color3.fromRGB(45, 45, 55))

		task.delay(1.5, function()
			if eventLabel.Text == text then
				eventLabel.Text = ""
				eventLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end)
	end

	local function showMastery(text)
		masteryLabel.Text = text or ""
		masteryLabel.TextColor3 = Color3.fromRGB(255, 232, 140)
		pulseLabel(masteryLabel, Color3.fromRGB(90, 72, 20))

		task.delay(3, function()
			if masteryLabel.Text == text then
				masteryLabel.Text = ""
			end
		end)
	end

	local function bindRoundEvent(remote)
		if not remote then return end

		remote.OnClientEvent:Connect(function(payload)
			if typeof(payload) ~= "table" then return end

			if payload.event == "potato_passed" then
				showEvent(("Pase: %s -> %s"):format(tostring(payload.fromName or "?"), tostring(payload.toName or "?")), Color3.fromRGB(130, 230, 255))
				pulseLabel(holderLabel, Color3.fromRGB(35, 75, 95))
			elseif payload.event == "sudden_death" then
				showEvent("Sudden death!", Color3.fromRGB(255, 180, 80))
				pulseLabel(timerLabel, Color3.fromRGB(145, 40, 25))
				flashScreen(Color3.fromRGB(255, 160, 50), 0.88)
			elseif payload.event == "boom" then
				showEvent(("BOOM: %s"):format(tostring(payload.holderName or "")), Color3.fromRGB(255, 110, 110))
				flashScreen(Color3.fromRGB(255, 90, 70), 0.72)
			elseif payload.event == "holder_assigned" then
				showEvent(("Papa caliente: %s"):format(tostring(payload.holderName or "")), Color3.fromRGB(255, 220, 120))
				pulseLabel(holderLabel, Color3.fromRGB(130, 70, 20))
			elseif payload.event == "round_started" then
				showEvent(("Ronda %s"):format(tostring(payload.roundIndex or "?")), Color3.fromRGB(180, 255, 180))
				pulseLabel(stateLabel, Color3.fromRGB(35, 70, 35))
			elseif payload.event == "modifier_triggered" then
				local label = tostring(payload.modifierLabel or payload.modifier or "?")
				local description = tostring(payload.modifierDescription or "")
				local text = description ~= "" and ("Modifier: %s | %s"):format(label, description) or ("Modifier: %s"):format(label)
				showEvent(text, Color3.fromRGB(255, 210, 120))
				pulseLabel(metaLabel, Color3.fromRGB(95, 70, 25))
				flashScreen(Color3.fromRGB(255, 220, 120), 0.9)
			elseif payload.event == "mastery_unlocked" then
				if payload.playerUserId == player.UserId and type(payload.unlocked) == "table" and payload.unlocked[1] then
					showMastery("Hito desbloqueado: " .. tostring(payload.unlocked[1].title or ""))
				end
			end
		end)
	end

	local function safeNum(x)
		return tonumber(x) or 0
	end

	local function showResult(payload)
		if typeof(payload) ~= "table" then return end

		local winnerName = tostring(payload.winnerName or "")
		local wasWinner = payload.wasWinner == true
		local coinsTotal = (payload.coins and safeNum(payload.coins.total)) or safeNum(payload.coinsEarned)
		local xpTotal = (payload.xp and safeNum(payload.xp.total)) or safeNum(payload.xpEarned)
		local matchStats = payload.stats and payload.stats.match or {}
		local lifetimeStats = payload.stats and payload.stats.lifetime or {}
		local coinBreakdown = payload.coins and payload.coins.breakdown or {}
		local xpBreakdown = payload.xp and payload.xp.breakdown or {}
		local modifierLabel = payload.progression and payload.progression.modifier or stateData.matchModifierLabel or "Classic"
		local modifierDescription = stateData.matchModifierDescription or ""
		local telemetry = payload.telemetry or {}
		local mastery = payload.mastery or {}
		local liveOps = payload.liveOps or {}
		local unlockedNow = mastery.unlockedNow or {}
		local unlockedTitle = (type(unlockedNow) == "table" and unlockedNow[1] and unlockedNow[1].title) or ""

		local title = wasWinner and ("GANASTE " .. winnerName) or ("Gano: " .. winnerName)
		local lines = {
			title,
			("Mapa: %s"):format(tostring(telemetry.mapName or stateData.mapName or "-")),
			("Modifier: %s"):format(tostring(modifierLabel)),
			modifierDescription ~= "" and ("Efecto: " .. modifierDescription) or "",
			"",
			"Recompensas",
			("Coins ganadas: +%d"):format(coinsTotal),
			("XP ganada: +%d"):format(xpTotal),
			("Nivel: %s -> %s"):format(
				tostring(payload.level and payload.level.before or "-"),
				tostring(payload.level and payload.level.after or "-")
			),
			("XP actual: %s / %s"):format(
				tostring(payload.xpAfter or "-"),
				tostring(payload.xpForNext or "-")
			),
			"",
			"Desglose",
			("Coins detalle: P:%d S:%d W:%d PK:%d"):format(
				safeNum(coinBreakdown.ParticipateMatch),
				safeNum(coinBreakdown.SurviveRound),
				safeNum(coinBreakdown.WinMatch),
				safeNum(coinBreakdown.PassKill)
			),
			("XP detalle: P:%d S:%d W:%d PK:%d"):format(
				safeNum(xpBreakdown.ParticipateMatch),
				safeNum(xpBreakdown.SurviveRound),
				safeNum(xpBreakdown.WinMatch),
				safeNum(xpBreakdown.PassKill)
			),
			"",
			"Tu partida",
			("Pases: %d"):format(safeNum(matchStats.passesMade)),
			("Pass-kills: %d"):format(safeNum(matchStats.passKills)),
			("Rondas sobrevividas: %d"):format(safeNum(matchStats.roundsSurvived)),
			("Tiempo con la papa: %.1fs"):format(tonumber(matchStats.timeAsHolder) or 0),
			"",
			"Progreso",
			("Lifetime wins: %d | matches: %d"):format(
				safeNum(lifetimeStats.matchesWon),
				safeNum(lifetimeStats.matchesPlayed)
			),
			("Lifetime passes: %d | pass-kills: %d"):format(
				safeNum(lifetimeStats.passesMade),
				safeNum(lifetimeStats.passKills)
			),
			("Telemetria: rondas %d | pases %d | eliminaciones %d"):format(
				safeNum(telemetry.roundsPlayed),
				safeNum(telemetry.passesTotal),
				safeNum(telemetry.eliminations)
			),
			("Duracion match: %.1fs"):format(tonumber(telemetry.durationSeconds) or 0),
			("Hitos: %d/%d"):format(
				safeNum(mastery.totalUnlocked),
				safeNum(mastery.totalAchievements)
			),
			unlockedTitle ~= "" and ("Nuevo hito: " .. unlockedTitle) or "",
			("Sesion: %d min | partidas: %d | abandons: %d"):format(
				safeNum(liveOps.sessionMinutes),
				safeNum(liveOps.matchesPlayed),
				safeNum(liveOps.abandons)
			),
			("Media reciente: %.1fs | rondas %.1f | abandons %.1f"):format(
				tonumber(liveOps.averageDurationSeconds) or 0,
				tonumber(liveOps.averageRounds) or 0,
				tonumber(liveOps.averageAbandons) or 0
			),
		}

		resultLabel.Text = table.concat(lines, "\n")
		resultFrame.Visible = true

		task.delay(6, function()
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
			local r = Remotes:WaitForChild(RemoteNames.RoundEvent, 10)
			if r then bindRoundEvent(r) end
		end)
	end

	if RE_MatchResult then
		bindMatchResult(RE_MatchResult)
	else
		task.spawn(function()
			local r = Remotes:WaitForChild(RemoteNames.MatchResult, 10)
			if r then bindMatchResult(r) end
		end)
	end
end

return HUDController
