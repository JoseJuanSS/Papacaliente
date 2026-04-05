local PotatoController = {}
PotatoController.__index = PotatoController

function PotatoController.new(config, callbacks)
	local self = setmetatable({}, PotatoController)
	self.Config = config
	self.Callbacks = callbacks or {}
	self:Reset()
	return self
end

function PotatoController:Reset()
	for _, connection in pairs(self.TouchConnections or {}) do
		connection:Disconnect()
	end
	for _, connection in pairs(self.CharacterConnections or {}) do
		connection:Disconnect()
	end
	self.Holder = nil
	self.HolderAssignedAt = nil
	self.PotatoTouchedAt = 0
	self.TouchDebounce = {}
	self.TouchConnections = {}
	self.CharacterConnections = {}
	self.TransferBlockedUntil = {}
	self.LastPasserOf = {}
end

function PotatoController:GetHolder()
	return self.Holder
end

function PotatoController:GetLastPasserUserId(userId)
	return self.LastPasserOf[userId]
end

function PotatoController:ClearPotatoFx(player)
	local character = player and player.Character
	if not character then return end
	local old = character:FindFirstChild("PotatoFX")
	if old then
		old:Destroy()
	end
end

function PotatoController:ApplyPotatoFx(player)
	local character = player and player.Character
	if not character then return end

	self:ClearPotatoFx(player)

	local highlight = Instance.new("Highlight")
	highlight.Name = "PotatoFX"
	highlight.FillColor = Color3.fromRGB(255, 180, 0)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.15
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
end

function PotatoController:FlushHolderTime(now)
	if not self.Holder or not self.HolderAssignedAt then
		return
	end

	local elapsed = math.max(0, (now or os.clock()) - self.HolderAssignedAt)
	if elapsed <= 0 then
		return
	end

	if self.Callbacks.OnHolderTime then
		self.Callbacks.OnHolderTime(self.Holder, elapsed)
	end

	self.HolderAssignedAt = now or os.clock()
end

function PotatoController:SetHolder(player)
	if self.Holder == player then
		return
	end

	local now = os.clock()
	self:FlushHolderTime(now)

	if self.Holder then
		self:ClearPotatoFx(self.Holder)
	end

	self.Holder = player
	self.HolderAssignedAt = player and now or nil

	if self.Holder then
		task.defer(function()
			task.wait(0.1)
			self:ApplyPotatoFx(self.Holder)
		end)

		if self.Callbacks.OnRoundEvent then
			self.Callbacks.OnRoundEvent("holder_assigned", {
				holderUserId = self.Holder.UserId,
				holderName = self.Holder.Name,
			})
		end
	end

	if self.Callbacks.OnStateChanged then
		self.Callbacks.OnStateChanged()
	end
end

function PotatoController:SetSpawnTransferBlock(player, duration)
	if not player then return end
	self.TransferBlockedUntil[player.UserId] = os.clock() + (duration or self.Config.SpawnNoPassWindow)
end

function PotatoController:ClearTransferBlock(player)
	if not player then return end
	self.TransferBlockedUntil[player.UserId] = nil
end

function PotatoController:TransferTo(player)
	local fromPlayer = self.Holder
	if not fromPlayer or not player or fromPlayer == player then
		return
	end

	self.LastPasserOf[player.UserId] = fromPlayer.UserId
	if self.Callbacks.OnPassRecorded then
		self.Callbacks.OnPassRecorded(fromPlayer, player)
	end

	self:SetHolder(player)

	if self.Callbacks.OnRoundEvent then
		self.Callbacks.OnRoundEvent("potato_passed", {
			fromUserId = fromPlayer.UserId,
			fromName = fromPlayer.Name,
			toUserId = player.UserId,
			toName = player.Name,
		})
	end
end

function PotatoController:GetHRP(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

function PotatoController:DisconnectTouch(player)
	if not player then
		return
	end
	local userId = player.UserId

	if self.TouchConnections[userId] then
		self.TouchConnections[userId]:Disconnect()
		self.TouchConnections[userId] = nil
	end

	if self.CharacterConnections[userId] then
		self.CharacterConnections[userId]:Disconnect()
		self.CharacterConnections[userId] = nil
	end
end

function PotatoController:ConnectTouch(player)
	if not player or type(player.UserId) ~= "number" then
		return
	end

	self:DisconnectTouch(player)

	local function tryBind()
		if not player.Character then return end
		local hrp = self:GetHRP(player)
		if not hrp then return end

		pcall(function()
			hrp.CanTouch = true
		end)

		self.TouchConnections[player.UserId] = hrp.Touched:Connect(function(hit)
			if not self.Callbacks.IsRunning or not self.Callbacks.IsRunning() then return end
			if not self.Holder then return end
			if player == self.Holder then return end
			if not self.Callbacks.IsAlive or not self.Callbacks.IsAlive(player) then return end
			if not self.Callbacks.IsAlive(self.Holder) then return end

			local now = os.clock()
			local touchCooldown = self.Config.TouchCooldown
			if self.Callbacks.GetTouchCooldown then
				touchCooldown = self.Callbacks.GetTouchCooldown() or touchCooldown
			end

			if now - self.PotatoTouchedAt < touchCooldown then return end
			if now < (self.TransferBlockedUntil[player.UserId] or 0) then return end
			if now < (self.TransferBlockedUntil[self.Holder.UserId] or 0) then return end

			local last = self.TouchDebounce[player.UserId] or 0
			if now - last < touchCooldown then return end

			local holderCharacter = self.Holder.Character
			if not holderCharacter then return end
			if not hit or not hit:IsDescendantOf(holderCharacter) then return end

			self.TouchDebounce[player.UserId] = now
			self.TouchDebounce[self.Holder.UserId] = now
			self.PotatoTouchedAt = now

			self:TransferTo(player)
		end)
	end

	if player.Character then
		tryBind()
	end

	if player.CharacterAdded and typeof(player.CharacterAdded.Connect) == "function" then
		self.CharacterConnections[player.UserId] = player.CharacterAdded:Connect(function()
			task.wait(0.2)
			tryBind()

			if self.Callbacks.IsRunning and self.Callbacks.IsRunning() then
				self:SetSpawnTransferBlock(player, self.Config.SpawnNoPassWindow)
			end

			if self.Holder == player then
				task.defer(function()
					task.wait(0.1)
					self:ApplyPotatoFx(player)
				end)
			end
		end)
	end
end

function PotatoController:ConnectAll(players)
	for _, player in ipairs(players) do
		self:ConnectTouch(player)
	end
end

return PotatoController
