local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticVisualConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticVisualConfig"))

local InventoryService = {}
InventoryService.__index = InventoryService

function InventoryService.new(remotesService, remoteNames, playerDataService)
	local self = setmetatable({}, InventoryService)

	self.Remotes = remotesService
	self.Names = remoteNames
	self.Data = playerDataService

	self.RE_Request = remotesService:GetOrCreateRemoteEvent(remoteNames.InventoryRequest)
	self.RE_Update = remotesService:GetOrCreateRemoteEvent(remoteNames.InventoryUpdate)
	self.RE_Equip = remotesService:GetOrCreateRemoteEvent(remoteNames.InventoryEquip)

	return self
end

local function serializeInventory(profile)
	return {
		Inventory = profile.Inventory,
		Equipped = profile.equipped,
	}
end

local function getCharacter(player)
	return player.Character
end

local function getHRP(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function clearAuraFX(character)
	if not character then return end
	local old = character:FindFirstChild("EquippedAuraFX")
	if old then
		old:Destroy()
	end
end

local function clearTrailFX(character)
	if not character then return end

	local oldTrail = character:FindFirstChild("EquippedTrailFX")
	if oldTrail then
		oldTrail:Destroy()
	end

	local a0 = character:FindFirstChild("TrailAttachment0")
	if a0 then
		a0:Destroy()
	end

	local a1 = character:FindFirstChild("TrailAttachment1")
	if a1 then
		a1:Destroy()
	end
end

local function applyAuraFX(character, auraId)
	clearAuraFX(character)
	if not character or not auraId then return end

	local auraCfg = CosmeticVisualConfig.Aura[auraId]
	if not auraCfg then return end

	if auraCfg.Type == "Highlight" then
		local h = Instance.new("Highlight")
		h.Name = "EquippedAuraFX"
		h.FillColor = auraCfg.FillColor or Color3.new(1,1,1)
		h.OutlineColor = auraCfg.OutlineColor or Color3.new(1,1,1)
		h.FillTransparency = auraCfg.FillTransparency or 0.3
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = character
	end
end

local function applyTrailFX(character, trailId)
	clearTrailFX(character)
	if not character or not trailId then return end

	local trailCfg = CosmeticVisualConfig.Trail[trailId]
	if not trailCfg then return end

	local hrp = getHRP(character)
	if not hrp then return end

	local a0 = Instance.new("Attachment")
	a0.Name = "TrailAttachment0"
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = hrp

	local a1 = Instance.new("Attachment")
	a1.Name = "TrailAttachment1"
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = hrp

	local trail = Instance.new("Trail")
	trail.Name = "EquippedTrailFX"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = trailCfg.Color
	trail.LightEmission = trailCfg.LightEmission or 0.3
	trail.Lifetime = trailCfg.Lifetime or 0.35
	trail.MinLength = trailCfg.MinLength or 0.1
	trail.WidthScale = trailCfg.WidthScale or NumberSequence.new(1)
	trail.FaceCamera = true
	trail.Parent = character
end

function InventoryService:ApplyEquippedVisuals(player)
	local profile = self.Data:GetProfile(player)
	if not profile then return end

	local character = getCharacter(player)
	if not character then return end

	applyAuraFX(character, profile.equipped.Aura)
	applyTrailFX(character, profile.equipped.Trail)
end

function InventoryService:Send(player)
	local profile = self.Data:GetProfile(player)
	if not profile then return end
	self.RE_Update:FireClient(player, serializeInventory(profile))
end

function InventoryService:_equip(player, itemType, itemId)
	local profile = self.Data:GetProfile(player)
	if not profile then return end

	local inventory = profile.Inventory[itemType]
	if not inventory then return end
	if inventory[itemId] ~= true then return end

	profile.equipped[itemType] = itemId

	self:ApplyEquippedVisuals(player)
	self:Send(player)
end

function InventoryService:Start()
	self.RE_Request.OnServerEvent:Connect(function(player)
		self:Send(player)
	end)

	self.RE_Equip.OnServerEvent:Connect(function(player, itemType, itemId)
		if typeof(itemType) ~= "string" then return end
		if typeof(itemId) ~= "string" then return end
		self:_equip(player, itemType, itemId)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.delay(0.5, function()
				if player.Parent == Players then
					self:ApplyEquippedVisuals(player)
					self:Send(player)
				end
			end)
		end)

		task.delay(1, function()
			if player.Parent == Players then
				self:Send(player)
				self:ApplyEquippedVisuals(player)
			end
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function()
			task.delay(0.5, function()
				if player.Parent == Players then
					self:ApplyEquippedVisuals(player)
					self:Send(player)
				end
			end)
		end)

		task.delay(1, function()
			if player.Parent == Players then
				self:Send(player)
				self:ApplyEquippedVisuals(player)
			end
		end)
	end
end

return InventoryService