local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local SpectatorController = {}

function SpectatorController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_SpectatorAction = remotes:WaitForChild(RemoteNames.SpectatorAction)

	local screenGui = UITheme.GetScreenGui(player)
	local viewportInfo = UITheme.GetViewportInfo()
	local panelSize, panelPos = UITheme.GetBottomCenterRect(viewportInfo, viewportInfo.mobile and 320 or 360, viewportInfo.mobile and 126 or 118, 18)
	local panel = UITheme.CreatePanel(screenGui, "SpectatorPanel", panelSize, panelPos)
	panel.Visible = false
	local title = UITheme.CreateSectionTitle(panel, "Espectador", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 22))
	title.TextSize = 18
	local targetLabel = UITheme.CreateBodyLabel(panel, "Viendo: -", UDim2.new(0, 14, 0, 40), UDim2.new(1, -28, 0, 18))
	targetLabel.TextSize = 15
	local hintLabel = UITheme.CreateBodyLabel(panel, "Izq/Der para cambiar. V para volver.", UDim2.new(0, 14, 0, 62), UDim2.new(1, -28, 0, 18))
	hintLabel.TextSize = 13
	local prevButton = UITheme.CreateButton(panel, "PrevTarget", "<", UDim2.new(0, 64, 0, 34), UDim2.new(0, 14, 1, -46), false)
	local lobbyButton = UITheme.CreateButton(panel, "LobbyFreeRoam", "Lobby", UDim2.new(0, 102, 0, 34), UDim2.new(0.5, -51, 1, -46), true)
	local nextButton = UITheme.CreateButton(panel, "NextTarget", ">", UDim2.new(0, 64, 0, 34), UDim2.new(1, -78, 1, -46), false)

	local switchEvery = 4
	local manualPause = 4
	local inputDebounce = 0.2

	local freeRoamLobby = false
	local alive = {}
	local index = 1
	local lastInput = 0
	local pauseUntil = 0
	local autoTimer = 0

	local function setCameraToSelf()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	local function rebuildAlive()
		alive = {}
		for _, target in ipairs(Players:GetPlayers()) do
			if target ~= player and not target:GetAttribute("Eliminated") then
				table.insert(alive, target)
			end
		end
		if index > #alive then
			index = 1
		end
	end

	local function followTarget()
		if freeRoamLobby then
			targetLabel.Text = "Viendo: Lobby"
			setCameraToSelf()
			return
		end

		if #alive == 0 then
			targetLabel.Text = "Viendo: -"
			camera.CameraType = Enum.CameraType.Custom
			return
		end

		local target = alive[index]
		targetLabel.Text = "Viendo: " .. target.Name

		local character = target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end

	local function manualStep(direction)
		if freeRoamLobby then return end

		local now = os.clock()
		if now - lastInput < inputDebounce then return end
		lastInput = now

		rebuildAlive()
		if #alive == 0 then return end

		index += direction
		if index < 1 then
			index = #alive
		elseif index > #alive then
			index = 1
		end

		pauseUntil = os.clock() + manualPause
		followTarget()
	end

	prevButton.MouseButton1Click:Connect(function()
		manualStep(-1)
	end)
	nextButton.MouseButton1Click:Connect(function()
		manualStep(1)
	end)
	lobbyButton.MouseButton1Click:Connect(function()
		freeRoamLobby = true
		panel.Visible = false
		setCameraToSelf()
		RE_SpectatorAction:FireServer("FreeRoamLobby")
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Left then
			if panel.Visible then
				manualStep(-1)
			end
		elseif input.KeyCode == Enum.KeyCode.Right then
			if panel.Visible then
				manualStep(1)
			end
		elseif input.KeyCode == Enum.KeyCode.V then
			if player:GetAttribute("Eliminated") == true then
				freeRoamLobby = false
				panel.Visible = true
				rebuildAlive()
				followTarget()
			end
		end
	end)

	local function onEliminatedChanged()
		local eliminated = player:GetAttribute("Eliminated") == true
		if eliminated then
			freeRoamLobby = false
			panel.Visible = true
			rebuildAlive()
			followTarget()
		else
			freeRoamLobby = false
			panel.Visible = false
			setCameraToSelf()
		end
	end

	player:GetAttributeChangedSignal("Eliminated"):Connect(onEliminatedChanged)
	onEliminatedChanged()

	RunService.RenderStepped:Connect(function(deltaTime)
		if freeRoamLobby then
			setCameraToSelf()
			return
		end

		if not panel.Visible then return end

		autoTimer += deltaTime
		if autoTimer < switchEvery then return end
		autoTimer = 0
		if os.clock() < pauseUntil then return end

		rebuildAlive()
		if #alive <= 1 then
			followTarget()
			return
		end

		index += 1
		if index > #alive then
			index = 1
		end
		followTarget()
	end)
end

return SpectatorController
