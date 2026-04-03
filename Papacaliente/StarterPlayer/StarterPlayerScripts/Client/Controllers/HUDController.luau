-- StarterPlayerScripts/Client/Controllers/HUDController.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	-- MatchResult es opcional (no bloquea)
	local RE_MatchResult = Remotes:FindFirstChild(RemoteNames.MatchResult)

	-- =========================
	-- UI
	-- =========================
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HotPotatoUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local function makeLabel(size, pos, text)
		local l = Instance.new("TextLabel")
		l.Size = size
		l.Position = pos
		l.BackgroundTransparency = 0.35
		l.TextScaled = true
		l.Text = text or ""
		l.Parent = screenGui
		return l
	end

	local stateLabel = makeLabel(UDim2.new(0, 520, 0, 40), UDim2.new(0.5, -260, 0, 20), "Estado: -")
	local timerLabel = makeLabel(UDim2.new(0, 220, 0, 60), UDim2.new(0.5, -110, 0, 70), "Timer: -")
	local announceLabel = makeLabel(UDim2.new(0, 520, 0, 40), UDim2.new(0.5, -260, 0, 140), "")

	local coinsLabel = makeLabel(UDim2.new(0, 220, 0, 40), UDim2.new(0, 20, 0, 20), "Coins: -")
	local pointsLabel = makeLabel(UDim2.new(0, 220, 0, 40), UDim2.new(0, 20, 0, 70), "Points: -")

	-- EndScreen simple
	local resultFrame = Instance.new("Frame")
	resultFrame.Size = UDim2.new(0, 520, 0, 180)
	resultFrame.Position = UDim2.new(0.5, -260, 0.5, -90)
	resultFrame.BackgroundTransparency = 0.25
	resultFrame.Visible = false
	resultFrame.Parent = screenGui

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Size = UDim2.new(1, -20, 1, -20)
	resultLabel.Position = UDim2.new(0, 10, 0, 10)
	resultLabel.BackgroundTransparency = 1
	resultLabel.TextScaled = true
	resultLabel.Text = ""
	resultLabel.Parent = resultFrame

	-- =========================
	-- Leaderstats hook
	-- =========================
	local function hookLeaderstats()
		local ls = player:FindFirstChild("leaderstats")
		if not ls then return end

		local coins = ls:FindFirstChild("Coins")
		local points = ls:FindFirstChild("Points")

		if coins then
			coinsLabel.Text = "Coins: " .. tostring(coins.Value)
			coins.Changed:Connect(function()
				coinsLabel.Text = "Coins: " .. tostring(coins.Value)
			end)
		end

		if points then
			pointsLabel.Text = "Points: " .. tostring(points.Value)
			points.Changed:Connect(function()
				pointsLabel.Text = "Points: " .. tostring(points.Value)
			end)
		end
	end

	player.ChildAdded:Connect(function(ch)
		if ch.Name == "leaderstats" then
			hookLeaderstats()
		end
	end)
	hookLeaderstats()

	-- =========================
	-- Core Remotes
	-- =========================
	RE_UpdateState.OnClientEvent:Connect(function(state, holderName)
		stateLabel.Text = ("Estado: %s | Holder: %s"):format(tostring(state), tostring(holderName or ""))
	end)

	RE_UpdateTimer.OnClientEvent:Connect(function(t)
		timerLabel.Text = ("Timer: %s"):format(tostring(t))
	end)

	RE_Announce.OnClientEvent:Connect(function(text)
		announceLabel.Text = tostring(text or "")
	end)

	-- =========================
	-- MatchResult (Payload SIMPLE + compat PRO)
	-- =========================
	local function safeNum(x)
		return tonumber(x) or 0
	end

	local function showResult(payload)
		if typeof(payload) ~= "table" then return end

		local winnerName = tostring(payload.winnerName or "")
		local wasWinner = payload.wasWinner == true

		-- SIMPLE:
		-- payload.coinsEarned, payload.xpEarned
		-- PRO (si existe):
		-- payload.coins.total, payload.xp.total
		local coinsTotal = 0
		local xpTotal = 0

		if payload.coins and typeof(payload.coins) == "table" then
			coinsTotal = safeNum(payload.coins.total)
		else
			coinsTotal = safeNum(payload.coinsEarned)
		end

		if payload.xp and typeof(payload.xp) == "table" then
			xpTotal = safeNum(payload.xp.total)
		else
			xpTotal = safeNum(payload.xpEarned)
		end

		local title = wasWinner and ("?? GANASTE! " .. winnerName) or ("?? Ganó: " .. winnerName)

		local lines = {
			title,
			"",
			("Coins ganadas: +%d"):format(coinsTotal),
			("XP ganada: +%d"):format(xpTotal),
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