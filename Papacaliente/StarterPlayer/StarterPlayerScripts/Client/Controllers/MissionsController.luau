-- StarterPlayerScripts/Client/Controllers/MissionsController.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionsController = {}

local function fmtProgress(p, t)
	p = tonumber(p) or 0
	t = tonumber(t) or 0
	return string.format("%d / %d", math.floor(p), math.floor(t))
end

local function isComplete(m)
	return (tonumber(m.progress) or 0) >= (tonumber(m.target) or 0)
end

local function safeStr(s)
	if s == nil then return "" end
	return tostring(s)
end

function MissionsController.Start(RemoteNames)
	local player = Players.LocalPlayer

	local RemotesFolderName = RemoteNames.RemotesFolder
	local Remotes = ReplicatedStorage:FindFirstChild(RemotesFolderName)
	while not Remotes do
		task.wait(0.1)
		Remotes = ReplicatedStorage:FindFirstChild(RemotesFolderName)
	end

	local RE_MissionsUpdate = Remotes:WaitForChild(RemoteNames.MissionsUpdate)
	local RE_MissionsClaim = Remotes:WaitForChild(RemoteNames.MissionsClaim)
	local RE_MissionsRequest = Remotes:WaitForChild(RemoteNames.MissionsRequest)

	local screenGui = player:WaitForChild("PlayerGui"):FindFirstChild("HotPotatoUI")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "HotPotatoUI"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end

	local toggle = Instance.new("TextButton")
	toggle.Name = "MissionsToggle"
	toggle.Size = UDim2.new(0, 180, 0, 40)
	toggle.Position = UDim2.new(1, -200, 0, 20)
	toggle.TextScaled = true
	toggle.Text = "?? Misiones"
	toggle.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "MissionsPanel"
	panel.Size = UDim2.new(0, 520, 0, 420)
	panel.Position = UDim2.new(1, -540, 0, 70)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Text = "Misiones (Daily / Weekly)"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 40, 0, 40)
	close.Position = UDim2.new(1, -50, 0, 10)
	close.TextScaled = true
	close.Text = "X"
	close.Parent = panel

	local tabs = Instance.new("Frame")
	tabs.Size = UDim2.new(1, -20, 0, 40)
	tabs.Position = UDim2.new(0, 10, 0, 60)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel

	local tabDaily = Instance.new("TextButton")
	tabDaily.Size = UDim2.new(0.5, -5, 1, 0)
	tabDaily.Position = UDim2.new(0, 0, 0, 0)
	tabDaily.TextScaled = true
	tabDaily.Text = "Daily"
	tabDaily.Parent = tabs

	local tabWeekly = Instance.new("TextButton")
	tabWeekly.Size = UDim2.new(0.5, -5, 1, 0)
	tabWeekly.Position = UDim2.new(0.5, 5, 0, 0)
	tabWeekly.TextScaled = true
	tabWeekly.Text = "Weekly"
	tabWeekly.Parent = tabs

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "List"
	listFrame.Size = UDim2.new(1, -20, 1, -120)
	listFrame.Position = UDim2.new(0, 10, 0, 110)
	listFrame.BackgroundTransparency = 0.1
	listFrame.ScrollBarThickness = 8
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -20, 0, 30)
	hint.Position = UDim2.new(0, 10, 1, -35)
	hint.BackgroundTransparency = 1
	hint.TextScaled = true
	hint.Text = "Completa y reclama tus recompensas."
	hint.Parent = panel

	local currentTab = "Daily"

	local function requestRefresh()
		RE_MissionsRequest:FireServer()
	end

	toggle.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			requestRefresh()
		end
	end)

	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	tabDaily.MouseButton1Click:Connect(function()
		currentTab = "Daily"
		requestRefresh()
	end)

	tabWeekly.MouseButton1Click:Connect(function()
		currentTab = "Weekly"
		requestRefresh()
	end)

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

	local function createMissionRow(m)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 92)
		row.BackgroundTransparency = 0.2
		row.Parent = listFrame

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, -140, 0, 30)
		t.Position = UDim2.new(0, 10, 0, 8)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = safeStr(m.title)
		t.Parent = row

		local prog = Instance.new("TextLabel")
		prog.Size = UDim2.new(1, -140, 0, 26)
		prog.Position = UDim2.new(0, 10, 0, 40)
		prog.BackgroundTransparency = 1
		prog.TextScaled = true
		prog.TextXAlignment = Enum.TextXAlignment.Left
		prog.Text = "Progreso: " .. fmtProgress(m.progress, m.target)
		prog.Parent = row

		local rw = Instance.new("TextLabel")
		rw.Size = UDim2.new(1, -140, 0, 22)
		rw.Position = UDim2.new(0, 10, 0, 66)
		rw.BackgroundTransparency = 1
		rw.TextScaled = true
		rw.TextXAlignment = Enum.TextXAlignment.Left
		rw.Text = string.format("Recompensa: +%d Coins, +%d XP", tonumber(m.rewardCoins) or 0, tonumber(m.rewardXP) or 0)
		rw.Parent = row

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 110, 0, 70)
		btn.Position = UDim2.new(1, -120, 0, 11)
		btn.TextScaled = true
		btn.Parent = row

		local complete = isComplete(m)
		local claimed = (m.claimed == true)

		if claimed then
			btn.Text = "? Claimed"
			btn.AutoButtonColor = false
			btn.Active = false
		elseif complete then
			btn.Text = "?? Claim"
			btn.Active = true
		else
			btn.Text = "?..."
			btn.AutoButtonColor = false
			btn.Active = false
		end

		btn.MouseButton1Click:Connect(function()
			if claimed then return end
			if not isComplete(m) then return end
			RE_MissionsClaim:FireServer(m.id)
		end)

		return row
	end

	local function render(missionsData)
		clearList()

		local dailyBucket = missionsData and (missionsData.Daily or missionsData.daily)
		local weeklyBucket = missionsData and (missionsData.Weekly or missionsData.weekly)

		local bucket = (currentTab == "Daily") and dailyBucket or weeklyBucket

		if not bucket then
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -10, 0, 60)
			row.BackgroundTransparency = 0.2
			row.Parent = listFrame

			local txt = Instance.new("TextLabel")
			txt.Size = UDim2.new(1, -20, 1, -20)
			txt.Position = UDim2.new(0, 10, 0, 10)
			txt.BackgroundTransparency = 1
			txt.TextScaled = true
			txt.Text = "No hay misiones cargadas."
			txt.Parent = row

			resizeCanvas()
			return
		end

		local arr = {}
		for _, m in pairs(bucket) do
			table.insert(arr, m)
		end

		table.sort(arr, function(a, b)
			local function score(m)
				if m.claimed == true then return 3 end
				if isComplete(m) then return 2 end
				return 1
			end
			local sa, sb = score(a), score(b)
			if sa ~= sb then return sa < sb end
			return safeStr(a.id) < safeStr(b.id)
		end)

		for i, m in ipairs(arr) do
			m.LayoutOrder = i
			createMissionRow(m)
		end

		resizeCanvas()
	end

	RE_MissionsUpdate.OnClientEvent:Connect(function(missionsData)
		render(missionsData)
	end)

	task.delay(1, function()
		requestRefresh()
	end)
end

return MissionsController