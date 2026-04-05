local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local BattlePassController = {}

function BattlePassController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_Request = remotes:WaitForChild(RemoteNames.BattlePassRequest)
	local RE_Update = remotes:WaitForChild(RemoteNames.BattlePassUpdate)
	local RE_Claim = remotes:WaitForChild(RemoteNames.BattlePassClaim)

	local screenGui = UITheme.GetScreenGui(player)
	local viewportInfo = UITheme.GetViewportInfo()
	local toggle = UITheme.CreateIconToggle(screenGui, "BattlePassToggle", "PASE", UITheme.GetRightTogglePosition(viewportInfo, 5))
	local panelSize, panelPos = UITheme.GetCenteredPanelRect(viewportInfo, viewportInfo.mobile and 360 or 640, viewportInfo.mobile and 500 or 460)
	local panel = UITheme.CreatePanel(screenGui, "BattlePassPanel", panelSize, panelPos)
	panel.Visible = false

	local title = UITheme.CreateSectionTitle(panel, "Battle Pass", UDim2.new(0, 16, 0, 14), UDim2.new(1, -120, 0, 26))
	local subtitle = UITheme.CreateBodyLabel(panel, "Temporada activa y recompensas.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -120, 0, 18))
	subtitle.TextSize = 14
	local close = UITheme.CreateButton(panel, "CloseBattlePass", "Cerrar", UDim2.new(0, 92, 0, 34), UDim2.new(1, -108, 0, 14), false)
	local progressLabel = UITheme.CreateBodyLabel(panel, "XP: 0", UDim2.new(0, 16, 0, 72), UDim2.new(1, -32, 0, 18))
	progressLabel.TextSize = 15
	local list, layout = UITheme.CreateScrollFrame(panel, "BattlePassList", UDim2.new(0, 14, 0, 104), UDim2.new(1, -28, 1, -118))
	local state = { season = {}, tiers = {}, xp = 0, unlockedTiers = 0, claimedFree = {}, claimedPremium = {}, premiumUnlocked = false }

	UITheme.RegisterExclusivePanel("battlepass", panel, function()
		RE_Request:FireServer()
	end)

	local function rewardText(reward)
		if not reward then return "-" end
		if reward.amount then
			return ("%s %d"):format(tostring(reward.type), tonumber(reward.amount) or 0)
		end
		return ("%s %s"):format(tostring(reward.type), tostring(reward.id or ""))
	end

	local function render()
		progressLabel.Text = ("%s | XP %d | Premium %s"):format(tostring(state.season.displayName or "Season"), tonumber(state.xp) or 0, state.premiumUnlocked and "Si" or "No")
		UITheme.ClearFrames(list)
		for index, tier in ipairs(state.tiers or {}) do
			local row = UITheme.CreateCard(list, UDim2.new(1, -4, 0, 84))
			local titleLabel = UITheme.CreateSectionTitle(row, ("Tier %d"):format(index), UDim2.new(0, 12, 0, 10), UDim2.new(0.3, 0, 0, 18))
			titleLabel.TextSize = 15
			local requirement = UITheme.CreateBodyLabel(row, ("Req: %d XP"):format(tonumber(tier.requiredXP) or 0), UDim2.new(0, 12, 0, 32), UDim2.new(0.3, 0, 0, 16))
			requirement.TextSize = 13
			local rewards = UITheme.CreateBodyLabel(row, ("Free: %s\nPremium: %s"):format(rewardText(tier.free), rewardText(tier.premium)), UDim2.new(0.3, 0, 0, 12), UDim2.new(0.42, -8, 0, 46))
			rewards.TextSize = 13
			rewards.TextYAlignment = Enum.TextYAlignment.Top
			local freeButton = UITheme.CreateButton(row, "ClaimFree", state.claimedFree[index] and "Free OK" or "Claim Free", UDim2.new(0, 110, 0, 32), UDim2.new(1, -236, 0.5, -16), not state.claimedFree[index] and index <= state.unlockedTiers)
			local premiumButton = UITheme.CreateButton(row, "ClaimPremium", state.claimedPremium[index] and "Premium OK" or "Claim Premium", UDim2.new(0, 110, 0, 32), UDim2.new(1, -118, 0.5, -16), state.premiumUnlocked and not state.claimedPremium[index] and index <= state.unlockedTiers)

			if not state.claimedFree[index] and index <= state.unlockedTiers then
				freeButton.MouseButton1Click:Connect(function()
					RE_Claim:FireServer(index, "free")
				end)
			else
				freeButton.AutoButtonColor = false
				freeButton.Active = false
			end

			if state.premiumUnlocked and not state.claimedPremium[index] and index <= state.unlockedTiers then
				premiumButton.MouseButton1Click:Connect(function()
					RE_Claim:FireServer(index, "premium")
				end)
			else
				premiumButton.AutoButtonColor = false
				premiumButton.Active = false
			end
		end
		UITheme.RefreshCanvas(list, layout, 10)
	end

	toggle.MouseButton1Click:Connect(function()
		UITheme.ToggleExclusivePanel("battlepass")
	end)
	close.MouseButton1Click:Connect(function()
		UITheme.SetExclusivePanelOpen("battlepass", false)
	end)

	RE_Update.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		state = payload
		render()
	end)
end

return BattlePassController
