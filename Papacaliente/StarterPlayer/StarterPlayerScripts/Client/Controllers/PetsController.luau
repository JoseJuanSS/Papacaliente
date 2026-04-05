local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local PetsController = {}

function PetsController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_Request = remotes:WaitForChild(RemoteNames.PetsRequest)
	local RE_Update = remotes:WaitForChild(RemoteNames.PetsUpdate)
	local RE_Equip = remotes:WaitForChild(RemoteNames.PetsEquip)

	local screenGui = UITheme.GetScreenGui(player)
	local viewportInfo = UITheme.GetViewportInfo()
	local toggle = UITheme.CreateIconToggle(screenGui, "PetsToggle", "PETS", UITheme.GetRightTogglePosition(viewportInfo, 3))
	local panelSize, panelPos = UITheme.GetRightPanelRect(viewportInfo, viewportInfo.mobile and 340 or 460, viewportInfo.mobile and 420 or 430, viewportInfo.mobile and 110 or 164)
	local panel = UITheme.CreatePanel(screenGui, "PetsPanel", panelSize, panelPos)
	panel.Visible = false

	local title = UITheme.CreateSectionTitle(panel, "Pets", UDim2.new(0, 16, 0, 14), UDim2.new(1, -120, 0, 26))
	local subtitle = UITheme.CreateBodyLabel(panel, "Companions cosmeticos del lobby.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -120, 0, 18))
	subtitle.TextSize = 14
	local close = UITheme.CreateButton(panel, "ClosePets", "Cerrar", UDim2.new(0, 92, 0, 34), UDim2.new(1, -108, 0, 14), false)
	local list, layout = UITheme.CreateScrollFrame(panel, "PetsList", UDim2.new(0, 14, 0, 80), UDim2.new(1, -28, 1, -94))
	local state = { catalog = {}, owned = {}, equipped = nil }

	UITheme.RegisterExclusivePanel("pets", panel, function()
		RE_Request:FireServer()
	end)

	local function render()
		UITheme.ClearFrames(list)
		for _, pet in pairs(state.catalog or {}) do
			local row = UITheme.CreateCard(list, UDim2.new(1, -4, 0, 70))
			local label = UITheme.CreateSectionTitle(row, pet.displayName or pet.id, UDim2.new(0, 12, 0, 10), UDim2.new(0.62, -8, 0, 18))
			label.TextSize = 15
			local meta = UITheme.CreateBodyLabel(row, (pet.rarity or "?") .. " | " .. (pet.source or "?"), UDim2.new(0, 12, 0, 34), UDim2.new(0.62, -8, 0, 18))
			meta.TextSize = 14
			local owned = state.owned and state.owned[pet.id] == true
			local equipped = state.equipped == pet.id
			local button = UITheme.CreateButton(row, "EquipPet", equipped and "Equipado" or (owned and "Equipar" or "Bloqueado"), UDim2.new(0, 122, 0, 36), UDim2.new(1, -134, 0.5, -18), owned and not equipped)
			if owned and not equipped then
				button.MouseButton1Click:Connect(function()
					RE_Equip:FireServer(pet.id)
				end)
			else
				button.AutoButtonColor = false
				button.Active = false
			end
		end
		UITheme.RefreshCanvas(list, layout, 10)
	end

	toggle.MouseButton1Click:Connect(function()
		UITheme.ToggleExclusivePanel("pets")
	end)
	close.MouseButton1Click:Connect(function()
		UITheme.SetExclusivePanelOpen("pets", false)
	end)

	RE_Update.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		state.catalog = payload.catalog or {}
		state.owned = payload.owned or {}
		state.equipped = payload.equipped
		render()
	end)
end

return PetsController
