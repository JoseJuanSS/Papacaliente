local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local MapManager = require(script.Parent.MatchModules.MapManager)
local PotatoController = require(script.Parent.MatchModules.PotatoController)
local RewardResolver = require(script.Parent.MatchModules.RewardResolver)
local SpectatorManager = require(script.Parent.MatchModules.SpectatorManager)
local MasteryService = require(script.Parent.MatchModules.MasteryService)

local MatchService = {}
MatchService.__index = MatchService

function MatchService.new(remotesService, remoteNames, economyService, playerDataService)
	local self = setmetatable({}, MatchService)
	self.RemotesService = remotesService
	self.RemoteNames = remoteNames
	self.Economy = economyService
	self.Data = playerDataService
	return self
end

function MatchService:Start()
	local Players = game:GetService("Players")

	local MATCH_CFG = GameConfig.Match
	local MODIFIER_CFG = GameConfig.Modifiers
	local REWARD_CFG = GameConfig.Rewards
	local states = MATCH_CFG.States

	local RN = self.RemoteNames
	local remotes = self.RemotesService

	local RE_UpdateState = remotes:GetOrCreateRemoteEvent(RN.UpdateState)
	local RE_UpdateTimer = remotes:GetOrCreateRemoteEvent(RN.UpdateTimer)
	local RE_Announce = remotes:GetOrCreateRemoteEvent(RN.Announce)
	local RE_SpectatorAction = remotes:GetOrCreateRemoteEvent(RN.SpectatorAction)
	local RE_MatchResult = remotes:GetOrCreateRemoteEvent(RN.MatchResult)
	local RE_RoundEvent = remotes:GetOrCreateRemoteEvent(RN.RoundEvent)

	local mapManager = MapManager.new(workspace)
	local rewardResolver = RewardResolver.new(self.Economy, remotes, RN, self.Data)
	local masteryService = MasteryService.new(self.Data)
	local gameState = states.LOBBY
	local activeMapModel = nil
	local activeModifier = MATCH_CFG.DefaultModifier
	local activeModifierConfig = MODIFIER_CFG and MODIFIER_CFG.Configs and MODIFIER_CFG.Configs[MATCH_CFG.DefaultModifier] or nil
	local currentRoundIndex = 0
	local eliminated = {}
	local potatoController
	local modifierActiveThisRound = false
	local matchStartedAt = 0

	local function announce(message)
		RE_Announce:FireAllClients(message)
	end

	local function setTimer(value)
		RE_UpdateTimer:FireAllClients(value)
	end

	local function fireRoundEvent(eventName, payload)
		payload = payload or {}
		payload.event = eventName
		payload.roundIndex = currentRoundIndex
		payload.state = gameState
		RE_RoundEvent:FireAllClients(payload)
	end

	local function getHumanoid(player)
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid") or nil
	end

	local function isEliminated(player)
		return player and eliminated[player.UserId] == true
	end

	local function isAlive(player)
		if not player then return false end
		if player.Parent ~= Players then return false end
		if isEliminated(player) then return false end

		local humanoid = getHumanoid(player)
		return humanoid and humanoid.Health > 0
	end

	local function getAlivePlayers()
		local list = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if isAlive(player) then
				table.insert(list, player)
			end
		end
		return list
	end

	local function getAliveCount()
		return #getAlivePlayers()
	end

	local function buildStatePayload()
		local holder = potatoController:GetHolder()
		return {
			state = gameState,
			holderUserId = holder and holder.UserId or 0,
			holderName = holder and holder.Name or "",
			aliveCount = getAliveCount(),
			roundIndex = currentRoundIndex,
			matchModifier = activeModifier,
			matchModifierLabel = activeModifierConfig and activeModifierConfig.displayName or activeModifier,
			matchModifierDescription = activeModifierConfig and activeModifierConfig.description or "",
		}
	end

	local function pushState()
		RE_UpdateState:FireAllClients(buildStatePayload())
	end

	local spectatorManager = SpectatorManager.new(function()
		return mapManager:GetLobbySpawn()
	end)

	potatoController = PotatoController.new(MATCH_CFG, {
		IsRunning = function()
			return gameState == states.RUNNING
		end,
		GetTouchCooldown = function()
			if activeModifierConfig and activeModifierConfig.type == "TouchCooldown" then
				return activeModifierConfig.touchCooldown or MATCH_CFG.TouchCooldown
			end
			return MATCH_CFG.TouchCooldown
		end,
		IsAlive = isAlive,
		OnStateChanged = pushState,
		OnRoundEvent = fireRoundEvent,
		OnPassRecorded = function(fromPlayer)
			rewardResolver:RecordPass(fromPlayer)
		end,
		OnHolderTime = function(player, seconds)
			rewardResolver:RecordHolderTime(player, seconds)
		end,
	})

	local function setState(state)
		gameState = state
		pushState()
	end

	local function chooseModifier()
		local pool = MODIFIER_CFG and MODIFIER_CFG.Pool or nil
		if type(pool) ~= "table" or #pool == 0 then
			activeModifier = MATCH_CFG.DefaultModifier
		else
			local totalWeight = 0
			for _, modifierId in ipairs(pool) do
				local config = MODIFIER_CFG
					and MODIFIER_CFG.Configs
					and MODIFIER_CFG.Configs[modifierId]
				totalWeight += math.max(1, tonumber(config and config.weight) or 1)
			end

			local roll = math.random(1, math.max(1, totalWeight))
			local cursor = 0
			activeModifier = MATCH_CFG.DefaultModifier

			for _, modifierId in ipairs(pool) do
				local config = MODIFIER_CFG
					and MODIFIER_CFG.Configs
					and MODIFIER_CFG.Configs[modifierId]
				cursor += math.max(1, tonumber(config and config.weight) or 1)
				if roll <= cursor then
					activeModifier = modifierId
					break
				end
			end
		end

		activeModifierConfig = MODIFIER_CFG
			and MODIFIER_CFG.Configs
			and MODIFIER_CFG.Configs[activeModifier]
			or { id = activeModifier, displayName = activeModifier, type = "None", description = "" }
	end

	local function getRewardAmount(reason, category)
		local base = REWARD_CFG[category] and REWARD_CFG[category][reason] or 0
		if not activeModifierConfig or activeModifierConfig.type ~= "RewardMultiplier" then
			return base
		end
		if activeModifierConfig.targetReason ~= reason then
			return base
		end

		local multiplierKey = string.lower(category) .. "Multiplier"
		local multiplier = activeModifierConfig[multiplierKey] or 1
		return math.floor(base * multiplier)
	end

	local function resetModifierEffects()
		modifierActiveThisRound = false
		for _, player in ipairs(Players:GetPlayers()) do
			local humanoid = getHumanoid(player)
			if humanoid then
				if not isEliminated(player) then
					humanoid.WalkSpeed = 16
					pcall(function() humanoid.JumpPower = 50 end)
				end
			end
		end
	end

	local function applySuddenDeathModifier()
		if modifierActiveThisRound then
			return
		end
		modifierActiveThisRound = true

		if not activeModifierConfig or activeModifierConfig.type ~= "SpeedBoostOnSuddenDeath" then
			return
		end

		for _, player in ipairs(getAlivePlayers()) do
			local humanoid = getHumanoid(player)
			if humanoid then
				humanoid.WalkSpeed = activeModifierConfig.boostWalkSpeed or 24
				pcall(function()
					humanoid.JumpPower = activeModifierConfig.boostJumpPower or 60
				end)
			end
		end

		fireRoundEvent("modifier_triggered", {
			modifier = activeModifier,
			modifierLabel = activeModifierConfig.displayName or activeModifier,
			modifierDescription = activeModifierConfig.description or "",
		})
	end

	local function moveCharacter(player, cf, applyNoPassWindow)
		task.spawn(function()
			if not player.Character then
				player:LoadCharacter()
			end

			local character = player.Character or player.CharacterAdded:Wait()
			local hrp = character:WaitForChild("HumanoidRootPart", 5)
			if hrp then
				character:PivotTo(cf)
				if applyNoPassWindow then
					potatoController:SetSpawnTransferBlock(player, MATCH_CFG.SpawnNoPassWindow)
				end
			end
		end)
	end

	local function teleportAllToLobby()
		local lobbySpawn = mapManager:GetLobbySpawn()
		if not lobbySpawn then return end

		for _, player in ipairs(Players:GetPlayers()) do
			moveCharacter(player, lobbySpawn.CFrame + Vector3.new(0, 5, 0), false)
		end
	end

	local function teleportAllToArena()
		local cf, sourceName = mapManager:GetArenaSpawnInfo(activeMapModel)
		if not cf then
			warn("[MatchService] No se encontro ArenaSpawn/MapSpawn.")
			announce("No se encontro un spawn valido para la partida.")
			return false
		end

		if sourceName ~= "ArenaSpawn" and sourceName ~= "MapSpawn" then
			warn("[MatchService] Usando fallback de mapa: " .. tostring(sourceName))
		end

		for _, player in ipairs(Players:GetPlayers()) do
			if not isEliminated(player) then
				moveCharacter(player, cf + Vector3.new(0, 5, 0), true)
			end
		end

		return true
	end

	local function pickRandomAlivePlayer()
		local alivePlayers = getAlivePlayers()
		if #alivePlayers == 0 then
			return nil
		end
		return alivePlayers[math.random(1, #alivePlayers)]
	end

	local function eliminatePlayer(player, reason)
		if not player or isEliminated(player) then
			return
		end

		eliminated[player.UserId] = true
		rewardResolver:RecordElimination()
		spectatorManager:SetSpectator(player, true)
		potatoController:ClearPotatoFx(player)

		if reason then
			announce(reason)
		end

		fireRoundEvent("boom", {
			holderUserId = player.UserId,
			holderName = player.Name,
		})

		if potatoController:GetHolder() == player then
			potatoController:SetHolder(nil)
		end
	end

	local function canStart()
		return #Players:GetPlayers() >= MATCH_CFG.MinPlayers
	end

	local function getRoundDuration()
		if activeModifierConfig and activeModifierConfig.type == "ShorterRound" then
			if getAliveCount() <= MATCH_CFG.FinalRoundPlayerThreshold then
				return activeModifierConfig.finalRoundTime or MATCH_CFG.FinalRoundTime
			end
			return activeModifierConfig.roundTime or MATCH_CFG.RoundTime
		end

		if getAliveCount() <= MATCH_CFG.FinalRoundPlayerThreshold then
			return MATCH_CFG.FinalRoundTime
		end
		return MATCH_CFG.RoundTime
	end

	local function missionRecord(player, eventName, amount)
		local missionService = _G.MissionService
		if missionService and player and player.Parent == Players then
			pcall(function()
				missionService:Record(player, eventName, amount or 1)
			end)
		end
	end

	local function resetMatchState()
		currentRoundIndex = 0
		activeModifier = MATCH_CFG.DefaultModifier
		activeModifierConfig = MODIFIER_CFG and MODIFIER_CFG.Configs and MODIFIER_CFG.Configs[activeModifier] or nil
		eliminated = {}
		modifierActiveThisRound = false
		rewardResolver:Reset()
		potatoController:Reset()

		for _, player in ipairs(Players:GetPlayers()) do
			spectatorManager:SetSpectator(player, false)
		end
	end

	local function prepareParticipationRewards()
		local xpService = _G.XPService
		rewardResolver:CaptureBefore(Players:GetPlayers(), xpService)

		for _, player in ipairs(Players:GetPlayers()) do
			rewardResolver:RecordMatchPlayed(player)
			rewardResolver:AwardXP(player, getRewardAmount("ParticipateMatch", "XP"), "ParticipateMatch", Players)
			rewardResolver:AwardCoins(player, getRewardAmount("ParticipateMatch", "Coins"), "ParticipateMatch", Players)
			missionRecord(player, "PlayMatch", 1)
		end
	end

	local function awardSurvivorsForRound()
		for _, survivor in ipairs(getAlivePlayers()) do
			rewardResolver:RecordRoundSurvived(survivor)
			rewardResolver:AwardXP(survivor, getRewardAmount("SurviveRound", "XP"), "SurviveRound", Players)
			rewardResolver:AwardCoins(survivor, getRewardAmount("SurviveRound", "Coins"), "SurviveRound", Players)
			missionRecord(survivor, "SurviveRound", 1)
		end
	end

	local function resolveBoom()
		potatoController:FlushHolderTime(os.clock())

		local loser = potatoController:GetHolder()
		if loser and isAlive(loser) then
			local passerUserId = potatoController:GetLastPasserUserId(loser.UserId)
			if passerUserId then
				local passer = Players:GetPlayerByUserId(passerUserId)
				if passer and isAlive(passer) then
					rewardResolver:RecordPassKill(passer)
					rewardResolver:AwardXP(passer, getRewardAmount("PassKill", "XP"), "PassKill", Players)
					rewardResolver:AwardCoins(passer, getRewardAmount("PassKill", "Coins"), "PassKill", Players)
					missionRecord(passer, "PassKill", 1)
					if activeModifierConfig and activeModifierConfig.type == "RewardMultiplier" then
						fireRoundEvent("modifier_triggered", {
							modifier = activeModifier,
							modifierLabel = activeModifierConfig.displayName or activeModifier,
							modifierDescription = activeModifierConfig.description or "",
							recipientName = passer.Name,
						})
					end
				end
			end

			eliminatePlayer(loser, "BOOM! " .. loser.Name .. " fue eliminado.")
		else
			announce("BOOM! (sin holder valido)")
			fireRoundEvent("boom", {
				holderName = "",
				holderUserId = 0,
			})
		end
	end

	RE_SpectatorAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "string" then return end
		if not player or player.Parent ~= Players then return end

		if action == "FreeRoamLobby" then
			local lobbySpawn = mapManager:GetLobbySpawn()
			if not player.Character or not lobbySpawn then return end

			pcall(function()
				player.Character:PivotTo(lobbySpawn.CFrame + Vector3.new(0, 5, 0))
			end)

			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 16
				pcall(function() humanoid.JumpPower = 50 end)
				humanoid.AutoRotate = true
			end
		elseif action == "BackToSpectate" then
			if player:GetAttribute("Eliminated") ~= true then return end
			spectatorManager:SetSpectator(player, true)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		potatoController:ConnectTouch(player)

		if gameState == states.RUNNING then
			eliminated[player.UserId] = true
			task.defer(function()
				task.wait(0.2)
				spectatorManager:SetSpectator(player, true)
				pushState()
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		potatoController:DisconnectTouch(player)
		potatoController:ClearTransferBlock(player)

		if potatoController:GetHolder() == player then
			potatoController:SetHolder(nil)
		end

		pushState()
	end)

	task.spawn(function()
		while true do
			if gameState == states.LOBBY then
				setTimer("-")

				if canStart() then
					setState(states.INTERMISSION)
					announce("Intermission...")

					for i = MATCH_CFG.IntermissionTime, 1, -1 do
						setTimer(i)
						task.wait(1)
					end
				else
					task.wait(1)
				end
			elseif gameState == states.INTERMISSION then
				resetMatchState()
				chooseModifier()
				prepareParticipationRewards()
				matchStartedAt = os.clock()

				activeMapModel = mapManager:PickRandomMap()
				if activeMapModel then
					activeMapModel = mapManager:ActivateMap(activeMapModel)
					task.wait(0.1)
				end

				if not teleportAllToArena() then
					setState(states.LOBBY)
					activeMapModel = mapManager:DeactivateMap(activeMapModel)
					task.wait(1)
				else
					potatoController:ConnectAll(Players:GetPlayers())
					task.wait(MATCH_CFG.StartDelay)

					setState(states.RUNNING)
					announce("Hot Potato started! Modifier: " .. tostring(activeModifierConfig and activeModifierConfig.displayName or activeModifier))

					while gameState == states.RUNNING do
						currentRoundIndex += 1
						modifierActiveThisRound = false
						pushState()

						if not potatoController:GetHolder() or not isAlive(potatoController:GetHolder()) then
							potatoController:SetHolder(pickRandomAlivePlayer())
						end

						local roundDuration = getRoundDuration()
						local suddenDeathFired = false
						local roundEnd = os.clock() + roundDuration

						fireRoundEvent("round_started", {
							duration = roundDuration,
							aliveCount = getAliveCount(),
							holderName = potatoController:GetHolder() and potatoController:GetHolder().Name or "",
							modifier = activeModifier,
							modifierLabel = activeModifierConfig and activeModifierConfig.displayName or activeModifier,
							modifierDescription = activeModifierConfig and activeModifierConfig.description or "",
						})

						while os.clock() < roundEnd and gameState == states.RUNNING do
							local remaining = math.max(0, math.ceil(roundEnd - os.clock()))
							setTimer(remaining)

							if not suddenDeathFired and remaining <= MATCH_CFG.SuddenDeathStart then
								suddenDeathFired = true
								applySuddenDeathModifier()
								fireRoundEvent("sudden_death", {
									remaining = remaining,
									holderName = potatoController:GetHolder() and potatoController:GetHolder().Name or "",
									modifier = activeModifier,
									modifierLabel = activeModifierConfig and activeModifierConfig.displayName or activeModifier,
									modifierDescription = activeModifierConfig and activeModifierConfig.description or "",
								})
							end

							task.wait(1)
						end

						resolveBoom()
						resetModifierEffects()
						awardSurvivorsForRound()
						pushState()

						local alive = getAlivePlayers()
						if #alive <= 1 then
							local winner = (#alive == 1) and alive[1] or nil
							setState(states.RESULT)

							if winner then
								rewardResolver:RecordMatchWin(winner)
								announce("Ganador: " .. winner.Name)
								rewardResolver:AwardXP(winner, getRewardAmount("WinMatch", "XP"), "WinMatch", Players)
								rewardResolver:AwardCoins(winner, getRewardAmount("WinMatch", "Coins"), "WinMatch", Players)
								missionRecord(winner, "WinMatch", 1)
							else
								announce("Partida terminada (sin ganador claro).")
							end

							for _, player in ipairs(Players:GetPlayers()) do
								local profile = self.Data and self.Data:GetProfile(player)
								local stats = profile and profile.Stats or nil
								local unlocked = masteryService:Evaluate(player, stats)
								local masterySnapshot = masteryService:BuildSnapshot(player, unlocked)
								rewardResolver:SetMatchTelemetry(
									activeModifierConfig and activeModifierConfig.displayName or activeModifier,
									currentRoundIndex,
									os.clock() - matchStartedAt
								)

								RE_MatchResult:FireClient(
									player,
									rewardResolver:BuildMatchResultPayload(
										player,
										winner,
										activeModifierConfig and activeModifierConfig.displayName or activeModifier,
										currentRoundIndex,
										masterySnapshot
									)
								)
								if #unlocked > 0 then
									fireRoundEvent("mastery_unlocked", {
										playerUserId = player.UserId,
										playerName = player.Name,
										unlocked = unlocked,
									})
								end
							end

							task.wait(MATCH_CFG.ResultDisplayTime)

							potatoController:SetHolder(nil)
							setState(states.LOBBY)
							teleportAllToLobby()
							activeMapModel = mapManager:DeactivateMap(activeMapModel)

							eliminated = {}
							for _, player in ipairs(Players:GetPlayers()) do
								spectatorManager:SetSpectator(player, false)
							end

							break
						else
							resetModifierEffects()
							potatoController:SetHolder(pickRandomAlivePlayer())
							announce("Nueva ronda!")
						end
					end
				end
			end

			task.wait(0.5)
		end
	end)

	teleportAllToLobby()
	setState(states.LOBBY)
end

return MatchService
