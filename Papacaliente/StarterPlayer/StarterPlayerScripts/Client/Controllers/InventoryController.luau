local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local InventoryController = {}

function InventoryController.Start(RemoteNames)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)
	local RE_Request = remotes:WaitForChild(RemoteNames.InventoryRequest)
	local RE_Update = remotes:WaitForChild(RemoteNames.InventoryUpdate)
	local RE_Equip = remotes:WaitForChild(RemoteNames.InventoryEquip)

	local screenGui = UITheme.GetScreenGui(player)
	local viewportInfo = UITheme.GetViewportInfo()
	local toggle = UITheme.CreateIconToggle(screenGui, "InventoryToggle", "INVENTARIO", UITheme.GetRightTogglePosition(viewportInfo, 2))
	local panelSize, panelPos = UITheme.GetRightPanelRect(viewportInfo, viewportInfo.mobile and 340 or 460, viewportInfo.mobile and 420 or 430, viewportInfo.mobile and 110 or 164)
	local panel = UITheme.CreatePanel(screenGui, "InventoryPanel", panelSize, panelPos)
	panel.Visible = false

	local title = UITheme.CreateSectionTitle(panel, "Inventario", UDim2.new(0, 16, 0, 14), UDim2.new(1, -120, 0, 26))
	local subtitle = UITheme.CreateBodyLabel(panel, "Equipa los cosmeticos que ya desbloqueaste.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -120, 0, 18))
	subtitle.TextSize = 14
	local close = UITheme.CreateButton(panel, "CloseInventory", "Cerrar", UDim2.new(0, 92, 0, 34), UDim2.new(1, -108, 0, 14), false)
	local list, layout = UITheme.CreateScrollFrame(panel, "InventoryList", UDim2.new(0, 14, 0, 80), UDim2.new(1, -28, 1, -94))

	local function render(data)
		UITheme.ClearFrames(list)

		for itemType, items in pairs(data.Inventory or {}) do
			for itemId, owned in pairs(items) do
				if owned == true then
					local row = UITheme.CreateCard(list, UDim2.new(1, -4, 0, viewportInfo.mobile and 78 or 64))
					local titleLabel = UITheme.CreateSectionTitle(row, itemId, UDim2.new(0, 12, 0, 10), UDim2.new(0.62, -8, 0, 18))
					titleLabel.TextSize = 15
					local meta = UITheme.CreateBodyLabel(row, itemType, UDim2.new(0, 12, 0, 34), UDim2.new(0.62, -8, 0, 18))
					meta.TextSize = 14

					local equipped = data.Equipped and data.Equipped[itemType] == itemId
					local button = UITheme.CreateButton(
						row,
						"EquipButton",
						equipped and "Equipado" or "Equipar",
						UDim2.new(0, 122, 0, 36),
						UDim2.new(1, -134, 0.5, -18),
						not equipped
					)
					if not equipped then
						button.MouseButton1Click:Connect(function()
							RE_Equip:FireServer(itemType, itemId)
						end)
					else
						button.AutoButtonColor = false
						button.Active = false
					end
				end
			end
		end

		UITheme.RefreshCanvas(list, layout, 10)
	end

	toggle.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			RE_Request:FireServer()
		end
	end)
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	RE_Update.OnClientEvent:Connect(function(data)
		if typeof(data) ~= "table" then return end
		render(data)
	end)
end

return InventoryController
