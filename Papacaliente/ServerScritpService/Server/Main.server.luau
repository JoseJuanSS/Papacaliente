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

local remotes = RemotesService.new(RemoteNames)

remotes:GetOrCreateRemoteEvent(RemoteNames.UpdateState)
remotes:GetOrCreateRemoteEvent(RemoteNames.UpdateTimer)
remotes:GetOrCreateRemoteEvent(RemoteNames.Announce)
remotes:GetOrCreateRemoteEvent(RemoteNames.MatchResult)
remotes:GetOrCreateRemoteEvent(RemoteNames.RoundEvent)
remotes:GetOrCreateRemoteEvent(RemoteNames.SpectatorAction)
remotes:GetOrCreateRemoteEvent(RemoteNames.ShopRequest)
remotes:GetOrCreateRemoteEvent(RemoteNames.ShopUpdate)

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


local cosmetics = CosmeticsService.new()
ShopService.new(remotes, RemoteNames, economy, data, cosmetics)

local xp = XPService.new(data)
xp:Start()
_G.XPService = xp

local missions = MissionService.new(remotes, RemoteNames, data, economy, xp)
_G.MissionService = missions
missions:Start()

local inventory = InventoryService.new(remotes, RemoteNames, data)
inventory:Start()

local crates = CrateService.new(remotes, RemoteNames, data, economy)
_G.CrateService = crates
crates:Start()

_G.PlayerDataService = data

local match = MatchService.new(remotes, RemoteNames, economy, data)
match:Start()

Players.PlayerAdded:Connect(function(plr)
	task.delay(3, function()
		if _G.XPService then
			_G.XPService:AddXP(plr, 25, "JoinBonus")
		end
	end)
end)
