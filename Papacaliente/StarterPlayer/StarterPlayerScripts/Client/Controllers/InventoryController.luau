local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryController = {}

function InventoryController.Start(RemoteNames)

	local player = Players.LocalPlayer

	local remotes = ReplicatedStorage:WaitForChild(RemoteNames.RemotesFolder)

	local RE_Request = remotes:WaitForChild(RemoteNames.InventoryRequest)
	local RE_Update = remotes:WaitForChild(RemoteNames.InventoryUpdate)
	local RE_Equip = remotes:WaitForChild(RemoteNames.InventoryEquip)


	local screenGui = player.PlayerGui:FindFirstChild("HotPotatoUI")

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(0,180,0,40)
	toggle.Position = UDim2.new(1,-200,0,120)
	toggle.Text = "?? Inventario"
	toggle.Parent = screenGui


	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0,500,0,450)
	panel.Position = UDim2.new(1,-520,0,170)
	panel.Visible = false
	panel.Parent = screenGui


	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1,-20,1,-20)
	list.Position = UDim2.new(0,10,0,10)
	list.Parent = panel


	local layout = Instance.new("UIListLayout")
	layout.Parent = list


	toggle.MouseButton1Click:Connect(function()

		panel.Visible = not panel.Visible

		if panel.Visible then
			RE_Request:FireServer()
		end

	end)


	local function clear()

		for _,v in ipairs(list:GetChildren()) do
			if v:IsA("Frame") then
				v:Destroy()
			end
		end

	end


	local function createItem(itemType,itemId,equipped)

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1,-10,0,60)
		frame.Parent = list

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0.6,0,1,0)
		name.Text = itemId
		name.Parent = frame

		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0.3,0,1,0)
		button.Position = UDim2.new(0.65,0,0,0)
		button.Text = equipped and "Equipped" or "Equip"
		button.Parent = frame


		if not equipped then

			button.MouseButton1Click:Connect(function()

				RE_Equip:FireServer(itemType,itemId)

			end)

		end

	end


	RE_Update.OnClientEvent:Connect(function(data)

		clear()

		for itemType,items in pairs(data.Inventory) do

			for itemId,_ in pairs(items) do

				local equipped = data.Equipped[itemType] == itemId

				createItem(itemType,itemId,equipped)

			end

		end

	end)


end


return InventoryController