local MatchBotService = {}
MatchBotService.__index = MatchBotService

local function makePart(name, size, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = true
	part.CanTouch = true
	part.Anchored = false
	part.Parent = parent
	return part
end

local function weldParts(part0, part1, c0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
	if c0 then
		part1.CFrame = part0.CFrame * c0
	end
end

function MatchBotService.new(config)
	local self = setmetatable({}, MatchBotService)
	self.Config = config or {}
	self.Participant = {
		UserId = self.Config.BotUserId or -1001,
		Name = self.Config.BotName or "BOT",
		DisplayName = self.Config.BotName or "BOT",
		IsBot = true,
		Character = nil,
	}
	self.BotModel = nil
	self.Active = false
	self.ArenaOrigin = nil
	self.ThinkThread = nil
	self.Callbacks = nil
	return self
end

function MatchBotService:GetParticipant()
	return self.Active and self.Participant or nil
end

function MatchBotService:IsActive()
	return self.Active == true and self.Participant.Character ~= nil
end

function MatchBotService:CreateCharacter()
	self:DestroyCharacter()

	local model = Instance.new("Model")
	model.Name = self.Participant.Name

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.fromRGB(42, 54, 74), model)
	root.Transparency = 1

	local torso = makePart("Torso", Vector3.new(2, 2, 1), Color3.fromRGB(45, 72, 102), model)
	local head = makePart("Head", Vector3.new(2, 1, 1), Color3.fromRGB(255, 221, 183), model)

	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.DisplayName = self.Participant.Name
	humanoid.WalkSpeed = self.Config.BotWalkSpeed or self.Config.BaseWalkSpeed or 18
	humanoid.JumpPower = self.Config.BotJumpPower or self.Config.BaseJumpPower or 55
	humanoid.AutoRotate = true
	humanoid.Parent = model

	weldParts(root, torso, CFrame.new(0, 0, 0))
	weldParts(root, head, CFrame.new(0, 1.5, 0))

	head.Position = root.Position + Vector3.new(0, 1.5, 0)
	torso.Position = root.Position

	model:PivotTo(CFrame.new(0, 6, 0))
	model.Parent = workspace

	self.BotModel = model
	self.Participant.Character = model
	return model
end

function MatchBotService:DestroyCharacter()
	if self.BotModel then
		self.BotModel:Destroy()
	end
	self.BotModel = nil
	self.Participant.Character = nil
end

function MatchBotService:EnsurePresence(enabled, spawnCFrame)
	if enabled then
		self.Active = true
		if not self.Participant.Character then
			self:CreateCharacter()
		end
		if spawnCFrame and self.Participant.Character then
			self.Participant.Character:PivotTo(spawnCFrame)
		end
		if self.Callbacks then
			self:StartThinking(self.Callbacks)
		end
	else
		self.Active = false
		self:DestroyCharacter()
	end
end

function MatchBotService:GetHumanoid()
	local character = self.Participant.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

function MatchBotService:GetRoot()
	local character = self.Participant.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

function MatchBotService:IsAlive(participant)
	if participant ~= self.Participant then
		return false
	end
	local humanoid = self:GetHumanoid()
	return humanoid and humanoid.Health > 0 and self.Participant.Character ~= nil
end

function MatchBotService:MoveTo(cframe)
	if not self.Participant.Character or not cframe then
		return
	end
	self.Participant.Character:PivotTo(cframe)
end

function MatchBotService:SetArenaOrigin(cframe)
	self.ArenaOrigin = cframe and cframe.Position or nil
end

function MatchBotService:SetMovement(walkSpeed, jumpPower)
	local humanoid = self:GetHumanoid()
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = walkSpeed or humanoid.WalkSpeed
	humanoid.JumpPower = jumpPower or humanoid.JumpPower
end

function MatchBotService:StartThinking(callbacks)
	self.Callbacks = callbacks
	if self.ThinkThread then
		return
	end

	self.ThinkThread = task.spawn(function()
		while self.Active do
			local participant = self.Participant
			local humanoid = self:GetHumanoid()
			local root = self:GetRoot()
			if humanoid and root and callbacks and callbacks.IsRunning and callbacks.IsRunning() then
				local holder = callbacks.GetHolder and callbacks.GetHolder() or nil
				local aliveParticipants = callbacks.GetAliveParticipants and callbacks.GetAliveParticipants() or {}
				local targetPosition = nil

				if holder == participant then
					local nearestDistance = math.huge
					for _, other in ipairs(aliveParticipants) do
						if other ~= participant and other.Character then
							local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
							if otherRoot then
								local distance = (otherRoot.Position - root.Position).Magnitude
								if distance < nearestDistance then
									nearestDistance = distance
									targetPosition = otherRoot.Position
								end
							end
						end
					end
				elseif holder and holder.Character then
					local holderRoot = holder.Character:FindFirstChild("HumanoidRootPart")
					if holderRoot then
						local away = root.Position - holderRoot.Position
						if away.Magnitude < 1 then
							away = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
						end
						targetPosition = root.Position + away.Unit * (self.Config.BotEscapeDistance or 24)
					end
				end

				if not targetPosition and self.ArenaOrigin then
					targetPosition = self.ArenaOrigin + Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
				end

				if targetPosition and self.ArenaOrigin then
					local offset = targetPosition - self.ArenaOrigin
					local maxRadius = self.Config.BotArenaRadius or 48
					if offset.Magnitude > maxRadius then
						targetPosition = self.ArenaOrigin + offset.Unit * maxRadius
					end
				end

				if targetPosition then
					humanoid:MoveTo(targetPosition)
				end
			end

			task.wait(self.Config.BotThinkInterval or 0.35)
		end

		self.ThinkThread = nil
	end)
end

function MatchBotService:StopThinking()
	self.Active = false
end

function MatchBotService:Reset()
	self:DestroyCharacter()
	self.Active = false
	self.ArenaOrigin = nil
end

return MatchBotService
