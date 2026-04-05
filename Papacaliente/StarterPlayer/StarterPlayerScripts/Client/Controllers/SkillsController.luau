local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local SkillsController = {}

function SkillsController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_Request = remotes:WaitForChild(RemoteNames.SkillsRequest)
	local RE_Update = remotes:WaitForChild(RemoteNames.SkillsUpdate)
	local RE_Equip = remotes:WaitForChild(RemoteNames.SkillsEquip)
	local RE_Use = remotes:WaitForChild(RemoteNames.SkillsUse)

	local screenGui = UITheme.GetScreenGui(player)
	local viewportInfo = UITheme.GetViewportInfo()
	local toggle = UITheme.CreateIconToggle(screenGui, "SkillsToggle", "SKILLS [Q]", UITheme.GetRightTogglePosition(viewportInfo, 6))
	local panelSize, panelPos = UITheme.GetRightPanelRect(viewportInfo, viewportInfo.mobile and 340 or 430, viewportInfo.mobile and 360 or 390, viewportInfo.mobile and 140 or 194)
	local panel = UITheme.CreatePanel(screenGui, "SkillsPanel", panelSize, panelPos)
	panel.Visible = false

	local title = UITheme.CreateSectionTitle(panel, "Skills", UDim2.new(0, 16, 0, 14), UDim2.new(1, -120, 0, 26))
	local subtitle = UITheme.CreateBodyLabel(panel, "Equipa una skill y activala con Q en partida.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -120, 0, 18))
	subtitle.TextSize = 14
	local close = UITheme.CreateButton(panel, "CloseSkills", "Cerrar", UDim2.new(0, 92, 0, 34), UDim2.new(1, -108, 0, 14), false)
	local list, layout = UITheme.CreateScrollFrame(panel, "SkillsList", UDim2.new(0, 14, 0, 80), UDim2.new(1, -28, 1, -94))
	local state = { catalog = {}, unlocked = {}, equipped = "DASH", cooldowns = {} }

	UITheme.RegisterExclusivePanel("skills", panel, function()
		RE_Request:FireServer()
	end)

	local function render()
		UITheme.ClearFrames(list)
		for _, skill in pairs(state.catalog or {}) do
			local row = UITheme.CreateCard(list, UDim2.new(1, -4, 0, 76))
			local name = UITheme.CreateSectionTitle(row, skill.displayName or skill.id, UDim2.new(0, 12, 0, 10), UDim2.new(0.55, -8, 0, 18))
			name.TextSize = 15
			local meta = UITheme.CreateBodyLabel(row, skill.description or "", UDim2.new(0, 12, 0, 32), UDim2.new(0.55, -8, 0, 30))
			meta.TextSize = 13
			local unlocked = state.unlocked and state.unlocked[skill.id] == true
			local equipped = state.equipped == skill.id
			local cooldown = math.ceil(tonumber(state.cooldowns and state.cooldowns[skill.id]) or 0)
			local buttonText = equipped and (cooldown > 0 and ("CD " .. cooldown) or "Equipada") or (unlocked and "Equipar" or "Bloqueada")
			local button = UITheme.CreateButton(row, "SkillEquip", buttonText, UDim2.new(0, 116, 0, 34), UDim2.new(1, -128, 0.5, -17), unlocked and not equipped)
			if unlocked and not equipped then
				button.MouseButton1Click:Connect(function()
					RE_Equip:FireServer(skill.id)
				end)
			else
				button.AutoButtonColor = false
				button.Active = false
			end
		end
		UITheme.RefreshCanvas(list, layout, 10)
	end

	toggle.MouseButton1Click:Connect(function()
		UITheme.ToggleExclusivePanel("skills")
	end)
	close.MouseButton1Click:Connect(function()
		UITheme.SetExclusivePanelOpen("skills", false)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Q then
			RE_Use:FireServer()
		end
	end)

	RE_Update.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		state = payload
		render()
	end)
end

return SkillsController
