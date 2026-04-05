local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local MissionsController = {}

local function fmtProgress(progress, target)
	return string.format("%d / %d", math.floor(tonumber(progress) or 0), math.floor(tonumber(target) or 0))
end

local function isComplete(mission)
	return (tonumber(mission.progress) or 0) >= (tonumber(mission.target) or 0)
end

function MissionsController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_MissionsUpdate = remotes:WaitForChild(RemoteNames.MissionsUpdate)
	local RE_MissionsClaim = remotes:WaitForChild(RemoteNames.MissionsClaim)
	local RE_MissionsRequest = remotes:WaitForChild(RemoteNames.MissionsRequest)

	local screenGui = UITheme.GetScreenGui(player)
	local toggle = UITheme.CreateIconToggle(screenGui, "MissionsToggle", "MISIONES", UDim2.new(1, -202, 0, 18))
	local panel = UITheme.CreatePanel(screenGui, "MissionsPanel", UDim2.new(0, 540, 0, 430), UDim2.new(1, -558, 0, 64))
	panel.Visible = false

	local title = UITheme.CreateSectionTitle(panel, "Misiones", UDim2.new(0, 16, 0, 14), UDim2.new(1, -120, 0, 26))
	local subtitle = UITheme.CreateBodyLabel(panel, "Completa objetivos diarios y semanales.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -120, 0, 18))
	subtitle.TextSize = 14
	local close = UITheme.CreateButton(panel, "CloseMissions", "Cerrar", UDim2.new(0, 92, 0, 34), UDim2.new(1, -108, 0, 14), false)

	local dailyTab = UITheme.CreateButton(panel, "DailyTab", "Daily", UDim2.new(0.5, -18, 0, 34), UDim2.new(0, 14, 0, 74), false)
	local weeklyTab = UITheme.CreateButton(panel, "WeeklyTab", "Weekly", UDim2.new(0.5, -18, 0, 34), UDim2.new(0.5, 4, 0, 74), false)
	local list, layout = UITheme.CreateScrollFrame(panel, "MissionsList", UDim2.new(0, 14, 0, 118), UDim2.new(1, -28, 1, -132))
	local footer = UITheme.CreateBodyLabel(panel, "Reclama cuando el objetivo este completo.", UDim2.new(0, 16, 1, -24), UDim2.new(1, -32, 0, 18))
	footer.TextSize = 13

	local currentTab = "Daily"

	local function requestRefresh()
		RE_MissionsRequest:FireServer()
	end

	local function render(missionsData)
		UITheme.ClearFrames(list)

		local bucket = currentTab == "Daily" and (missionsData and missionsData.Daily) or (missionsData and missionsData.Weekly)
		local entries = {}
		for _, mission in pairs(bucket or {}) do
			table.insert(entries, mission)
		end

		table.sort(entries, function(a, b)
			local function score(m)
				if m.claimed then return 3 end
				if isComplete(m) then return 2 end
				return 1
			end
			local sa, sb = score(a), score(b)
			if sa ~= sb then
				return sa < sb
			end
			return tostring(a.id) < tostring(b.id)
		end)

		if #entries == 0 then
			local empty = UITheme.CreateCard(list, UDim2.new(1, -4, 0, 58))
			local label = UITheme.CreateBodyLabel(empty, "No hay misiones cargadas.", UDim2.new(0, 12, 0, 16), UDim2.new(1, -24, 0, 20))
			label.TextSize = 14
		end

		for _, mission in ipairs(entries) do
			local row = UITheme.CreateCard(list, UDim2.new(1, -4, 0, 92))
			local titleLabel = UITheme.CreateSectionTitle(row, tostring(mission.title or mission.id or "Mision"), UDim2.new(0, 12, 0, 10), UDim2.new(1, -138, 0, 20))
			titleLabel.TextSize = 15
			local progress = UITheme.CreateBodyLabel(row, "Progreso: " .. fmtProgress(mission.progress, mission.target), UDim2.new(0, 12, 0, 36), UDim2.new(1, -138, 0, 18))
			progress.TextSize = 14
			local reward = UITheme.CreateBodyLabel(row, ("Recompensa: +%d Coins, +%d XP"):format(tonumber(mission.rewardCoins) or 0, tonumber(mission.rewardXP) or 0), UDim2.new(0, 12, 0, 58), UDim2.new(1, -138, 0, 18))
			reward.TextSize = 13

			local claimed = mission.claimed == true
			local complete = isComplete(mission)
			local button = UITheme.CreateButton(
				row,
				"ClaimMission",
				claimed and "Reclamada" or (complete and "Reclamar" or "Pendiente"),
				UDim2.new(0, 122, 0, 38),
				UDim2.new(1, -134, 0.5, -19),
				complete and not claimed
			)

			if complete and not claimed then
				button.MouseButton1Click:Connect(function()
					RE_MissionsClaim:FireServer(mission.id)
				end)
			else
				button.AutoButtonColor = false
				button.Active = false
			end
		end

		UITheme.RefreshCanvas(list, layout, 10)
	end

	local function setTab(tabName)
		currentTab = tabName
		dailyTab.BackgroundColor3 = tabName == "Daily" and UITheme.Colors.Accent or UITheme.Colors.PanelStrong
		dailyTab.TextColor3 = tabName == "Daily" and UITheme.Colors.Background or UITheme.Colors.Text
		weeklyTab.BackgroundColor3 = tabName == "Weekly" and UITheme.Colors.Accent or UITheme.Colors.PanelStrong
		weeklyTab.TextColor3 = tabName == "Weekly" and UITheme.Colors.Background or UITheme.Colors.Text
		requestRefresh()
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
	dailyTab.MouseButton1Click:Connect(function()
		setTab("Daily")
	end)
	weeklyTab.MouseButton1Click:Connect(function()
		setTab("Weekly")
	end)

	RE_MissionsUpdate.OnClientEvent:Connect(function(missionsData)
		render(missionsData)
	end)

	setTab("Daily")
end

return MissionsController
