local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillConfig"))

local SkillService = {}
SkillService.__index = SkillService

function SkillService.new(remotesService, remoteNames, playerDataService)
	local self = setmetatable({}, SkillService)
	self.Data = playerDataService
	self.RE_Request = remotesService:GetOrCreateRemoteEvent(remoteNames.SkillsRequest)
	self.RE_Update = remotesService:GetOrCreateRemoteEvent(remoteNames.SkillsUpdate)
	self.RE_Equip = remotesService:GetOrCreateRemoteEvent(remoteNames.SkillsEquip)
	self.RE_Use = remotesService:GetOrCreateRemoteEvent(remoteNames.SkillsUse)
	self.Cooldowns = {}

	self.RE_Request.OnServerEvent:Connect(function(player)
		self:Send(player)
	end)

	self.RE_Equip.OnServerEvent:Connect(function(player, skillId)
		if typeof(skillId) ~= "string" then return end
		self:Equip(player, skillId)
	end)

	self.RE_Use.OnServerEvent:Connect(function(player)
		self:UseEquipped(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			if player.Parent == Players then
				self:Send(player)
			end
		end)
	end)

	return self
end

function SkillService:GetProfile(player)
	return self.Data and self.Data:GetProfile(player) or nil
end

function SkillService:EnsureProfile(profile)
	profile.Skills = profile.Skills or { Unlocked = {}, Equipped = "DASH" }
	profile.Skills.Unlocked = profile.Skills.Unlocked or {}
	for skillId, owned in pairs(SkillConfig.DefaultUnlocked) do
		if owned == true then
			profile.Skills.Unlocked[skillId] = true
		end
	end
	if not profile.Skills.Equipped or profile.Skills.Unlocked[profile.Skills.Equipped] ~= true then
		profile.Skills.Equipped = "DASH"
	end
end

function SkillService:GetCooldownState(player, skillId)
	local playerCooldowns = self.Cooldowns[player.UserId] or {}
	local readyAt = playerCooldowns[skillId] or 0
	return math.max(0, readyAt - os.clock())
end

function SkillService:BuildPayload(player)
	local profile = self:GetProfile(player)
	if not profile then
		return { catalog = SkillConfig.Skills, unlocked = SkillConfig.DefaultUnlocked, equipped = "DASH", cooldowns = {} }
	end
	self:EnsureProfile(profile)
	local cooldowns = {}
	for skillId in pairs(SkillConfig.Skills) do
		cooldowns[skillId] = self:GetCooldownState(player, skillId)
	end
	return {
		catalog = SkillConfig.Skills,
		unlocked = profile.Skills.Unlocked,
		equipped = profile.Skills.Equipped,
		cooldowns = cooldowns,
	}
end

function SkillService:Send(player)
	self.RE_Update:FireClient(player, self:BuildPayload(player))
end

function SkillService:Equip(player, skillId)
	local profile = self:GetProfile(player)
	if not profile then return end
	self:EnsureProfile(profile)
	if profile.Skills.Unlocked[skillId] ~= true then
		self:Send(player)
		return
	end
	profile.Skills.Equipped = skillId
	self:Send(player)
end

function SkillService:UseEquipped(player)
	local profile = self:GetProfile(player)
	if not profile then return end
	self:EnsureProfile(profile)

	local skillId = profile.Skills.Equipped
	local skill = SkillConfig.Skills[skillId]
	if not skill then
		self:Send(player)
		return
	end

	local remaining = self:GetCooldownState(player, skillId)
	if remaining > 0 then
		self:Send(player)
		return
	end

	local runtime = _G.MatchRuntime
	if not runtime or not runtime.IsRunning or runtime.IsRunning() ~= true then
		self:Send(player)
		return
	end
	if runtime.IsAlive(player) ~= true then
		self:Send(player)
		return
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		self:Send(player)
		return
	end

	if skill.type == "VelocityBurst" then
		root.AssemblyLinearVelocity = root.CFrame.LookVector * (skill.force or 76) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	elseif skill.type == "TransferBlock" then
		local potatoController = runtime.GetPotatoController and runtime.GetPotatoController() or nil
		if potatoController then
			potatoController:SetSpawnTransferBlock(player, skill.duration or 1.6)
		end
	elseif skill.type == "SpeedBurst" then
		local originalWalkSpeed = humanoid.WalkSpeed
		local originalJumpPower = humanoid.JumpPower
		humanoid.WalkSpeed = skill.walkSpeed or 24
		humanoid.JumpPower = skill.jumpPower or 60
		task.delay(skill.duration or 3, function()
			if humanoid.Parent and runtime.IsAlive(player) then
				humanoid.WalkSpeed = math.max(originalWalkSpeed, 18)
				humanoid.JumpPower = math.max(originalJumpPower, 55)
			end
		end)
	end

	self.Cooldowns[player.UserId] = self.Cooldowns[player.UserId] or {}
	self.Cooldowns[player.UserId][skillId] = os.clock() + (SkillConfig.Cooldowns[skillId] or 10)
	self:Send(player)
end

return SkillService
