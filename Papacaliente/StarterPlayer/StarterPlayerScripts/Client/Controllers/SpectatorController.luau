-- StarterPlayerScripts/Client/Controllers/SpectatorController.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SpectatorController = {}

function SpectatorController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local cam = workspace.CurrentCamera

	local Remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_SpectatorAction = Remotes:WaitForChild(RemoteNames.SpectatorAction)

	local SWITCH_EVERY = 4
	local MANUAL_PAUSE = SWITCH_EVERY
	local INPUT_DEBOUNCE = 0.2

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpectatorUI"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 120)
	frame.Position = UDim2.new(0.5, -150, 1, -140)
	frame.BackgroundTransparency = 0.25
	frame.Visible = false
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "Spectator"
	title.Parent = frame

	local targetLabel = Instance.new("TextLabel")
	targetLabel.Size = UDim2.new(1, 0, 0, 26)
	targetLabel.Position = UDim2.new(0, 0, 0, 36)
	targetLabel.BackgroundTransparency = 1
	targetLabel.TextScaled = true
	targetLabel.Text = "Viendo: -"
	targetLabel.Parent = frame

	local prevBtn = Instance.new("TextButton")
	prevBtn.Size = UDim2.new(0.3, 0, 0, 40)
	prevBtn.Position = UDim2.new(0.05, 0, 1, -44)
	prevBtn.Text = "?"
	prevBtn.Parent = frame

	local nextBtn = Instance.new("TextButton")
	nextBtn.Size = UDim2.new(0.3, 0, 0, 40)
	nextBtn.Position = UDim2.new(0.65, 0, 1, -44)
	nextBtn.Text = "?"
	nextBtn.Parent = frame

	local lobbyBtn = Instance.new("TextButton")
	lobbyBtn.Size = UDim2.new(0.25, 0, 0, 40)
	lobbyBtn.Position = UDim2.new(0.375, 0, 1, -44)
	lobbyBtn.Text = "LOBBY"
	lobbyBtn.Parent = frame

	-- =========================
	-- ? NUEVO: FreeRoam local
	-- =========================
	local freeRoamLobby = false

	local function setCameraToSelf()
		local ch = player.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		cam.CameraType = Enum.CameraType.Custom
		if hum then
			cam.CameraSubject = hum
		end
	end

	local alive = {}
	local idx = 1
	local lastInput = 0
	local pauseUntil = 0
	local autoT = 0

	local function rebuildAlive()
		alive = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and not p:GetAttribute("Eliminated") then
				table.insert(alive, p)
			end
		end
		if idx > #alive then idx = 1 end
	end

	local function followTarget()
		if freeRoamLobby then
			targetLabel.Text = "Viendo: (Lobby)"
			setCameraToSelf()
			return
		end

		if #alive == 0 then
			targetLabel.Text = "Viendo: -"
			cam.CameraType = Enum.CameraType.Custom
			return
		end

		local target = alive[idx]
		targetLabel.Text = "Viendo: " .. target.Name

		local ch = target.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraType = Enum.CameraType.Custom
			cam.CameraSubject = hum
		end
	end

	local function manualStep(dir)
		if freeRoamLobby then return end

		local now = os.clock()
		if now - lastInput < INPUT_DEBOUNCE then return end
		lastInput = now

		rebuildAlive()
		if #alive == 0 then return end

		idx += dir
		if idx < 1 then idx = #alive end
		if idx > #alive then idx = 1 end

		pauseUntil = os.clock() + MANUAL_PAUSE
		followTarget()
	end

	prevBtn.MouseButton1Click:Connect(function() manualStep(-1) end)
	nextBtn.MouseButton1Click:Connect(function() manualStep(1) end)

	-- ? LOBBY: cambia a free roam (cliente) + avisa al server
	lobbyBtn.MouseButton1Click:Connect(function()
		freeRoamLobby = true
		frame.Visible = false
		setCameraToSelf()
		RE_SpectatorAction:FireServer("FreeRoamLobby")
	end)

	-- ? Extra: presiona "S" para volver al modo spectate
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end

		if input.KeyCode == Enum.KeyCode.Left then
			if frame.Visible then manualStep(-1) end
		elseif input.KeyCode == Enum.KeyCode.Right then
			if frame.Visible then manualStep(1) end
		elseif input.KeyCode == Enum.KeyCode.V then
			-- volver a spectate si est? eliminado
			if player:GetAttribute("Eliminated") == true then
				freeRoamLobby = false
				frame.Visible = true
				rebuildAlive()
				followTarget()
			end
		end
	end)

	local function onAttr()
		local elim = player:GetAttribute("Eliminated") == true

		if elim then
			-- Cuando te eliminan, siempre arrancas en spectate (no en free roam)
			freeRoamLobby = false
			frame.Visible = true
			rebuildAlive()
			followTarget()
		else
			-- Ya no est?s eliminado: UI fuera y c?mara normal
			freeRoamLobby = false
			frame.Visible = false
			setCameraToSelf()
		end
	end

	player:GetAttributeChangedSignal("Eliminated"):Connect(onAttr)
	onAttr()

	RunService.RenderStepped:Connect(function(dt)
		if freeRoamLobby then
			-- Asegura c?mara al self constantemente
			setCameraToSelf()
			return
		end

		if not frame.Visible then return end
		autoT += dt
		if autoT < SWITCH_EVERY then return end
		autoT = 0

		if os.clock() < pauseUntil then return end

		rebuildAlive()
		if #alive <= 1 then
			followTarget()
			return
		end

		idx += 1
		if idx > #alive then idx = 1 end
		followTarget()
	end)
end

return SpectatorController