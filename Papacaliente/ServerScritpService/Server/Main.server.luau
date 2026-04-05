-- ServerScriptService/Server/Main.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteNames = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteNames"))

local RemotesService = require(script.Parent.Services.RemotesService)
local EconomyService = require(script.Parent.Services.EconomyService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local CosmeticsService = require(script.Parent.Services.CosmeticsService)
local ShopService = require(script.Parent.Services.ShopService)
local MatchService = require(script.Parent.Services.MatchService)
local XPService = require(script.Parent.Services.XPService)
local MissionService = require(script.Parent.Services.MissionService)
local CrateService = require(script.Parent.Services.CrateService)
local InventoryService = require(script.Parent.Services.InventoryService)
local PremiumService = require(script.Parent.Services.PremiumService)
local PetService = require(script.Parent.Services.PetService)
local BattlePassService = require(script.Parent.Services.BattlePassService)
local SkillService = require(script.Parent.Services.SkillService)
local LeaderboardService = require(script.Parent.Services.LeaderboardService)
local AudienceVoteService = require(script.Parent.Services.AudienceVoteService)

local remotes = RemotesService.new(RemoteNames)

remotes:GetOrCreateRemoteEvent(RemoteNames.UpdateState)
remotes:GetOrCreateRemoteEvent(RemoteNames.UpdateTimer)
remotes:GetOrCreateRemoteEvent(RemoteNames.Announce)
remotes:GetOrCreateRemoteEvent(RemoteNames.MatchResult)
remotes:GetOrCreateRemoteEvent(RemoteNames.RoundEvent)
remotes:GetOrCreateRemoteEvent(RemoteNames.SpectatorAction)
remotes:GetOrCreateRemoteEvent(RemoteNames.ShopRequest)
remotes:GetOrCreateRemoteEvent(RemoteNames.ShopUpdate)
remotes:GetOrCreateRemoteEvent(RemoteNames.PremiumRequest)
remotes:GetOrCreateRemoteEvent(RemoteNames.PremiumUpdate)
remotes:GetOrCreateRemoteEvent(RemoteNames.PetsRequest)
remotes:GetOrCreateRemoteEvent(RemoteNames.PetsUpdate)
remotes:GetOrCreateRemoteEvent(RemoteNames.PetsEquip)
remotes:GetOrCreateRemoteEvent(RemoteNames.BattlePassRequest)
remotes:GetOrCreateRemoteEvent(RemoteNames.BattlePassUpdate)
remotes:GetOrCreateRemoteEvent(RemoteNames.BattlePassClaim)
remotes:GetOrCreateRemoteEvent(RemoteNames.SkillsRequest)
remotes:GetOrCreateRemoteEvent(RemoteNames.SkillsUpdate)
remotes:GetOrCreateRemoteEvent(RemoteNames.SkillsEquip)
remotes:GetOrCreateRemoteEvent(RemoteNames.SkillsUse)
remotes:GetOrCreateRemoteEvent(RemoteNames.LeaderboardUpdate)
remotes:GetOrCreateRemoteEvent(RemoteNames.AudienceVoteUpdate)

-- Missions
remotes:GetOrCreateRemoteEvent(RemoteNames.MissionsUpdate)
remotes:GetOrCreateRemoteEvent(RemoteNames.MissionsClaim)
remotes:GetOrCreateRemoteEvent(RemoteNames.MissionsRequest)

-- Crates
remotes:GetOrCreateRemoteEvent(RemoteNames.CrateOpenRequest)
remotes:GetOrCreateRemoteEvent(RemoteNames.CrateOpenResult)
remotes:GetOrCreateRemoteEvent(RemoteNames.CrateDataRequest)
remotes:GetOrCreateRemoteEvent(RemoteNames.CrateDataUpdate)

remotes:GetOrCreateBindableEvent(RemoteNames.BE_AddCoins)

local economy = EconomyService.new(remotes, RemoteNames)
local data = PlayerDataService.new(economy)
economy:SetDataService(data)

local premium = PremiumService.new(remotes, RemoteNames, data)
local pets = PetService.new(remotes, RemoteNames, data, premium)

local cosmetics = CosmeticsService.new()
ShopService.new(remotes, RemoteNames, economy, data, cosmetics, premium)

local xp = XPService.new(data)
xp:Start()
_G.XPService = xp

local missions = MissionService.new(remotes, RemoteNames, data, economy, xp)
_G.MissionService = missions
missions:Start()

local inventory = InventoryService.new(remotes, RemoteNames, data)
inventory:Start()
_G.InventoryService = inventory

local crates = CrateService.new(remotes, RemoteNames, data, economy)
_G.CrateService = crates
crates:Start()

local battlePass = BattlePassService.new(remotes, RemoteNames, data, premium, economy, pets)
_G.BattlePassService = battlePass

local skills = SkillService.new(remotes, RemoteNames, data)
_G.SkillService = skills

local leaderboards = LeaderboardService.new(remotes, RemoteNames, data)
_G.LeaderboardService = leaderboards

local audienceVote = AudienceVoteService.new(remotes, RemoteNames)
_G.AudienceVoteService = audienceVote

_G.PlayerDataService = data

local match = MatchService.new(remotes, RemoteNames, economy, data)
match:Start()

Players.PlayerAdded:Connect(function(plr)
	task.delay(3, function()
		if _G.XPService then
			_G.XPService:AddXP(plr, 25, "JoinBonus")
		end
		if _G.LeaderboardService then
			_G.LeaderboardService:SendSnapshot(plr)
		end
	end)
end)
