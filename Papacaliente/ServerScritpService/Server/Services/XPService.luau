-- ServerScriptService/Server/Services/XPService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LevelConfig"))

local XPService = {}
XPService.__index = XPService

function XPService.new(playerDataService)
	local self = setmetatable({}, XPService)
	self.Data = playerDataService
	return self
end

local function ensureLeaderstats(plr: Player)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = plr
	end

	local function ensureInt(name)
		local v = ls:FindFirstChild(name)
		if not v then
			v = Instance.new("IntValue")
			v.Name = name
			v.Value = 0
			v.Parent = ls
		end
		return v
	end

	local levelV = ensureInt("Level")
	local xpV = ensureInt("XP")
	return levelV, xpV
end

function XPService:GetLevelXP(plr: Player)
	local profile = self.Data and self.Data:GetProfile(plr)
	if not profile then return 1, 0 end
	return profile.Level or 1, profile.XP or 0
end

function XPService:GetXPToNext(level: number)
	return LevelConfig.XPToNext(level)
end

function XPService:Sync(plr: Player)
	local profile = self.Data and self.Data:GetProfile(plr)
	if not profile then return end

	profile.Level = profile.Level or 1
	profile.XP = profile.XP or 0

	local levelV, xpV = ensureLeaderstats(plr)
	levelV.Value = profile.Level
	xpV.Value = profile.XP
end

function XPService:InitPlayer(plr: Player)
	-- PlayerDataService carga en PlayerAdded; esperamos un poco por seguridad
	task.delay(0.2, function()
		if plr.Parent ~= Players then return end
		self:Sync(plr)
	end)
	task.delay(1.0, function()
		if plr.Parent ~= Players then return end
		self:Sync(plr)
	end)
end

function XPService:AddXP(plr: Player, amount: number, reason: string?)
	if not plr or plr.Parent ~= Players then return end
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return end

	local profile = self.Data and self.Data:GetProfile(plr)
	if not profile then return end

	profile.Level = profile.Level or 1
	profile.XP = profile.XP or 0

	profile.XP += amount
	profile.Level, profile.XP = LevelConfig.ApplyLevelUps(profile.Level, profile.XP)

	self:Sync(plr)
end

function XPService:Start()
	Players.PlayerAdded:Connect(function(plr)
		self:InitPlayer(plr)
	end)
end

return XPService
