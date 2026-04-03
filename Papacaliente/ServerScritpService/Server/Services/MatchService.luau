-- ServerScriptService/Server/Services/MatchService.lua
-- Hot Potato - MatchService (POO)
-- ? RemotesService asegura RemoteEvents
-- ? Teleport robusto: ArenaSpawn/MapSpawn + fallback
-- ? Potato FX visible (Highlight)
-- ? PASS de la papa por touch (HRP.Touched) con cooldown + debounce
-- ? Eliminación por BOOM al final de cada ronda (solo holder pierde)
-- ? Spectator: eliminado queda en lobby y puede FreeRoamLobby / BackToSpectate
-- ? Recompensas: XP + Coins por participar, sobrevivir rondas, pass-kill, ganar match
-- ? EndScreen payload compatible con HUDController PRO
-- ? Hooks MissionService: PlayMatch / SurviveRound / PassKill / WinMatch

local MatchService = {}
MatchService.__index = MatchService

function MatchService.new(remotesService, remoteNames, economyService)
	local self = setmetatable({}, MatchService)
	self.RemotesService = remotesService
	self.RemoteNames = remoteNames
	self.Economy = economyService
	return self
end

function MatchService:Start()
	local Players = game:GetService("Players")

	-- =========================
	-- CONFIG (ajusta aquí)
	-- =========================
	local ROUND_TIME = 10
	local INTERMISSION = 10
	local START_DELAY = 2
	local MIN_PLAYERS_TO_START = 2

	local TOUCH_COOLDOWN = 1.2

	-- XP
	local XP_PARTICIPATE_MATCH = 10
	local XP_SURVIVE_ROUND = 10
	local XP_PASS_KILL = 25
	local XP_WIN_MATCH = 50

	-- COINS
	local COINS_PARTICIPATE_MATCH = 10
	local COINS_SURVIVE_ROUND = 5
	local COINS_PASS_KILL = 10
	local COINS_WIN_MATCH = 25

	-- =========================
	-- REMOTES
	-- =========================
	local RN = self.RemoteNames
	local RemotesService = self.RemotesService

	local RE_UpdateState = RemotesService:GetOrCreateRemoteEvent(RN.UpdateState)
	local RE_UpdateTimer = RemotesService:GetOrCreateRemoteEvent(RN.UpdateTimer)
	local RE_Announce = RemotesService:GetOrCreateRemoteEvent(RN.Announce)
	local RE_SpectatorAction = RemotesService:GetOrCreateRemoteEvent(RN.SpectatorAction)
	local RE_MatchResult = RemotesService:GetOrCreateRemoteEvent(RN.MatchResult)

	-- =========================
	-- WORLD HELPERS
	-- =========================
	local function findPartAnywhere(name)
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("BasePart") and inst.Name == name then
				return inst
			end
		end
		return nil
	end

	local function findPartDeep(model, name)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == name then
				return d
			end
		end
		return nil
	end

	local LobbySpawn = findPartAnywhere("LobbySpawn")
	local MapsFolder = workspace:FindFirstChild("Maps")

	if not LobbySpawn then warn("[MatchService] LobbySpawn no encontrado.") end
	if not MapsFolder then warn("[MatchService] Carpeta 'Maps' no encontrada en Workspace.") end

	-- =========================
	-- STATE
	-- =========================
	local gameState = "LOBBY"
	local activeMapModel = nil
	local potatoHolder = nil

	local potatoTouchedAt = 0
	local touchDebounce = {}
	local touchConnections = {}

	local eliminated = {}
	local lastPasserOf = {} -- [loserUserId] = passerUserId

	-- Rewards acumulados por match (EndScreen)
	local coinsEarned = {}
	local xpEarned = {}

	local levelBefore = {}
	local xpBefore = {}
	local coinsBreakdown = {}
	local xpBreakdown = {}

	local function ensureBD(tbl, userId)
		tbl[userId] = tbl[userId] or { ParticipateMatch = 0, SurviveRound = 0, WinMatch = 0, PassKill = 0 }
		return tbl[userId]
	end

	-- =========================
	-- MISSION HOOK (safe)
	-- =========================
	local function missionRecord(plr, eventName, amount)
		local ms = _G.MissionService
		if ms and plr and plr.Parent == Players then
			pcall(function()
				ms:Record(plr, eventName, amount or 1)
			end)
		end
	end

	-- =========================
	-- REMOTE HELPERS
	-- =========================
	local function announce(msg)
		RE_Announce:FireAllClients(msg)
	end

	local function setTimer(v)
		RE_UpdateTimer:FireAllClients(v)
	end

	local function setState(state)
		gameState = state
		RE_UpdateState:FireAllClients(gameState, potatoHolder and potatoHolder.Name or "")
	end

	-- =========================
	-- AWARDS
	-- =========================
	local function awardXP(plr, amount, reason)
		amount = tonumber(amount) or 0
		if amount <= 0 then return end

		local xpService = _G.XPService
		if xpService and plr and plr.Parent == Players then
			xpEarned[plr.UserId] = (xpEarned[plr.UserId] or 0) + math.floor(amount)

			local bd = ensureBD(xpBreakdown, plr.UserId)
			if reason == "ParticipateMatch" then bd.ParticipateMatch += amount end
			if reason == "SurviveRound" then bd.SurviveRound += amount end
			if reason == "WinMatch" then bd.WinMatch += amount end
			if reason == "PassKill" then bd.PassKill += amount end

			pcall(function()
				xpService:AddXP(plr, amount, reason)
			end)
		end
	end

	local function awardCoins(plr, amount, reason)
		amount = tonumber(amount) or 0
		if amount == 0 then return end
		if not plr or plr.Parent ~= Players then return end

		coinsEarned[plr.UserId] = (coinsEarned[plr.UserId] or 0) + math.floor(amount)

		local bd = ensureBD(coinsBreakdown, plr.UserId)
		if reason == "ParticipateMatch" then bd.ParticipateMatch += amount end
		if reason == "SurviveRound" then bd.SurviveRound += amount end
		if reason == "WinMatch" then bd.WinMatch += amount end
		if reason == "PassKill" then bd.PassKill += amount end

		local econ = self.Economy
		if econ and econ.BE_AddCoins then
			econ.BE_AddCoins:Fire(plr, amount)
		else
			local b = RemotesService:GetOrCreateBindableEvent(RN.BE_AddCoins)
			b:Fire(plr, amount)
		end
	end

	-- =========================
	-- CHARACTER HELPERS
	-- =========================
	local function getHRP(plr)
		local ch = plr.Character
		return ch and ch:FindFirstChild("HumanoidRootPart") or nil
	end

	local function getHumanoid(plr)
		local ch = plr.Character
		return ch and ch:FindFirstChildOfClass("Humanoid") or nil
	end

	local function isEliminated(plr)
		return plr and eliminated[plr.UserId] == true
	end

	local function isAlive(plr)
		if not plr then return false end
		if plr.Parent ~= Players then return false end
		if isEliminated(plr) then return false end
		local hum = getHumanoid(plr)
		return hum and hum.Health > 0
	end

	local function getAlivePlayers()
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if isAlive(p) then
				table.insert(list, p)
			end
		end
		return list
	end

	-- =========================
	-- MAP SPAWN
	-- =========================
	local function getArenaSpawnCFrame()
		if activeMapModel then
			local arena = findPartDeep(activeMapModel, "ArenaSpawn")
			if arena then return arena.CFrame end

			local mapSpawn = findPartDeep(activeMapModel, "MapSpawn")
			if mapSpawn then return mapSpawn.CFrame end

			return activeMapModel:GetPivot()
		end

		local globalArena = findPartAnywhere("ArenaSpawn")
		return globalArena and globalArena.CFrame or nil
	end

	-- =========================
	-- TELEPORT
	-- =========================
	local function moveCharacter(plr, cf)
		task.spawn(function()
			if not plr.Character then
				plr:LoadCharacter()
			end
			local ch = plr.Character or plr.CharacterAdded:Wait()
			local hrp = ch:WaitForChild("HumanoidRootPart", 5)
			if hrp then
				ch:PivotTo(cf)
			end
		end)
	end

	local function teleportAllToLobby()
		if not LobbySpawn then return end
		for _, plr in ipairs(Players:GetPlayers()) do
			moveCharacter(plr, LobbySpawn.CFrame + Vector3.new(0, 5, 0))
		end
	end

	local function teleportAllToArena()
		local cf = getArenaSpawnCFrame()
		if not cf then
			warn("[MatchService] No se encontró ArenaSpawn/MapSpawn.")
			announce("?? No se encontró ArenaSpawn/MapSpawn.")
			return
		end

		for _, plr in ipairs(Players:GetPlayers()) do
			if not isEliminated(plr) then
				moveCharacter(plr, cf + Vector3.new(0, 5, 0))
			end
		end
	end

	-- =========================
	-- SPECTATOR MODE
	-- =========================
	local function setSpectator(plr, enabled)
		if not plr then return end
		enabled = (enabled == true)

		pcall(function()
			plr:SetAttribute("Eliminated", enabled)
		end)

		local ch = plr.Character
		if ch then
			local hum = ch:FindFirstChildOfClass("Humanoid")
			if hum then
				if enabled then
					hum.WalkSpeed = 0
					hum.JumpPower = 0
					hum.AutoRotate = false
				else
					hum.WalkSpeed = 16
					pcall(function() hum.JumpPower = 50 end)
					hum.AutoRotate = true
				end
			end
		end

		-- eliminado queda en lobby
		if enabled and LobbySpawn and plr.Character then
			pcall(function()
				plr.Character:PivotTo(LobbySpawn.CFrame + Vector3.new(0, 5, 0))
			end)
		end
	end

	-- =========================
	-- POTATO FX
	-- =========================
	local function clearPotatoFx(plr)
		local ch = plr and plr.Character
		if not ch then return end
		local old = ch:FindFirstChild("PotatoFX")
		if old then old:Destroy() end
	end

	local function applyPotatoFx(plr)
		local ch = plr and plr.Character
		if not ch then return end

		clearPotatoFx(plr)

		local highlight = Instance.new("Highlight")
		highlight.Name = "PotatoFX"
		highlight.FillColor = Color3.fromRGB(255, 180, 0)
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.FillTransparency = 0.25
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = ch
	end

	local function pickRandomAlivePlayer()
		local alive = getAlivePlayers()
		if #alive == 0 then return nil end
		return alive[math.random(1, #alive)]
	end

	local function setPotatoHolder(plr)
		if potatoHolder == plr then return end

		if potatoHolder then
			clearPotatoFx(potatoHolder)
		end

		potatoHolder = plr

		if potatoHolder then
			task.defer(function()
				task.wait(0.1)
				applyPotatoFx(potatoHolder)
			end)
		end

		RE_UpdateState:FireAllClients(gameState, potatoHolder and potatoHolder.Name or "")
	end

	local function transferPotato(fromPlayer, toPlayer)
		if not fromPlayer or not toPlayer then return end
		if fromPlayer == toPlayer then return end

		lastPasserOf[toPlayer.UserId] = fromPlayer.UserId
		setPotatoHolder(toPlayer)
	end

	local function eliminatePlayer(plr, reason)
		if not plr then return end
		if isEliminated(plr) then return end

		eliminated[plr.UserId] = true
		setSpectator(plr, true)
		clearPotatoFx(plr)

		if reason then
			announce(reason)
		end

		if potatoHolder == plr then
			potatoHolder = nil
			RE_UpdateState:FireAllClients(gameState, "")
		end
	end

	-- =========================
	-- TOUCH TRANSFER
	-- =========================
	local function disconnectTouch(plr)
		local id = plr.UserId
		if touchConnections[id] then
			touchConnections[id]:Disconnect()
			touchConnections[id] = nil
		end
	end

	local function connectTouch(plr)
		if not plr or not plr:IsA("Player") then return end
		disconnectTouch(plr)

		local function tryBind()
			if not plr.Character then return end
			local hrp = getHRP(plr)
			if not hrp then return end

			pcall(function() hrp.CanTouch = true end)

			touchConnections[plr.UserId] = hrp.Touched:Connect(function(hit)
				if gameState ~= "RUNNING" then return end
				if not potatoHolder then return end
				if plr == potatoHolder then return end
				if not isAlive(plr) then return end
				if not isAlive(potatoHolder) then return end

				local now = os.clock()
				if now - potatoTouchedAt < TOUCH_COOLDOWN then return end

				local last = touchDebounce[plr.UserId] or 0
				if now - last < TOUCH_COOLDOWN then return end

				local holderChar = potatoHolder.Character
				if not holderChar then return end
				if not hit or not hit:IsDescendantOf(holderChar) then return end

				touchDebounce[plr.UserId] = now
				touchDebounce[potatoHolder.UserId] = now
				potatoTouchedAt = now

				local fromPlayer = potatoHolder
				transferPotato(fromPlayer, plr)
			end)
		end

		if plr.Character then
			tryBind()
		end

		plr.CharacterAdded:Connect(function()
			task.wait(0.2)
			tryBind()
			if potatoHolder == plr then
				task.defer(function()
					task.wait(0.1)
					applyPotatoFx(plr)
				end)
			end
		end)
	end

	local function connectAllTouches()
		for _, plr in ipairs(Players:GetPlayers()) do
			connectTouch(plr)
		end
	end

	Players.PlayerAdded:Connect(function(plr)
		connectTouch(plr)

		if gameState == "RUNNING" then
			eliminated[plr.UserId] = true
			task.defer(function()
				task.wait(0.2)
				setSpectator(plr, true)
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(plr)
		disconnectTouch(plr)
		if potatoHolder == plr then
			setPotatoHolder(nil)
		end
	end)

	-- =========================
	-- MAP SYSTEM
	-- =========================
	local function pickRandomMap()
		if not MapsFolder then return nil end
		local maps = {}
		for _, m in ipairs(MapsFolder:GetChildren()) do
			if m:IsA("Model") then table.insert(maps, m) end
		end
		if #maps == 0 then return nil end
		return maps[math.random(1, #maps)]
	end

	local function deactivateMap()
		if activeMapModel and MapsFolder then
			pcall(function()
				activeMapModel.Parent = MapsFolder
			end)
		end
		activeMapModel = nil
	end

	local function activateMap(map)
		activeMapModel = map
		if activeMapModel then
			activeMapModel.Parent = workspace
		end
	end

	-- =========================
	-- SPECTATOR ACTION
	-- =========================
	RE_SpectatorAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "string" then return end
		if not player or player.Parent ~= Players then return end

		if action == "FreeRoamLobby" then
			if not player.Character or not LobbySpawn then return end

			pcall(function()
				player.Character:PivotTo(LobbySpawn.CFrame + Vector3.new(0, 5, 0))
			end)

			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 16
				pcall(function() hum.JumpPower = 50 end)
				hum.AutoRotate = true
			end

		elseif action == "BackToSpectate" then
			if player:GetAttribute("Eliminated") ~= true then return end
			setSpectator(player, true)
		end
	end)

	-- =========================
	-- ROUND LOOP
	-- =========================
	local function canStart()
		return #Players:GetPlayers() >= MIN_PLAYERS_TO_START
	end

	task.spawn(function()
		while true do
			if gameState == "LOBBY" then
				setTimer("-")

				if canStart() then
					setState("INTERMISSION")
					announce("Intermission...")

					for i = INTERMISSION, 1, -1 do
						setTimer(i)
						task.wait(1)
					end
				else
					task.wait(1)
				end

			elseif gameState == "INTERMISSION" then
				-- reset match
				touchDebounce = {}
				potatoTouchedAt = 0
				lastPasserOf = {}
				setPotatoHolder(nil)

				eliminated = {}
				for _, p in ipairs(Players:GetPlayers()) do
					setSpectator(p, false)
				end

				coinsEarned = {}
				xpEarned = {}
				coinsBreakdown = {}
				xpBreakdown = {}
				levelBefore = {}
				xpBefore = {}

				-- capture BEFORE (EndScreen)
				local xpService = _G.XPService
				if xpService and xpService.GetLevelXP then
					for _, pp in ipairs(Players:GetPlayers()) do
						local lv, xv = xpService:GetLevelXP(pp)
						levelBefore[pp.UserId] = lv
						xpBefore[pp.UserId] = xv
					end
				end

				-- Participate reward + mission
				for _, p in ipairs(Players:GetPlayers()) do
					awardXP(p, XP_PARTICIPATE_MATCH, "ParticipateMatch")
					awardCoins(p, COINS_PARTICIPATE_MATCH, "ParticipateMatch")
					missionRecord(p, "PlayMatch", 1)
				end

				local map = pickRandomMap()
				if map then
					activateMap(map)
					task.wait(0.1)
				end

				teleportAllToArena()
				connectAllTouches()

				task.wait(START_DELAY)

				setState("RUNNING")
				announce("?? Hot Potato started!")

				while gameState == "RUNNING" do
					if not potatoHolder or not isAlive(potatoHolder) then
						setPotatoHolder(pickRandomAlivePlayer())
					end

					local roundEnd = os.clock() + ROUND_TIME
					while os.clock() < roundEnd and gameState == "RUNNING" do
						setTimer(math.floor(roundEnd - os.clock()))
						task.wait(1)
					end

					-- BOOM: holder pierde
					local loser = potatoHolder
					if loser and isAlive(loser) then
						local passerUserId = lastPasserOf[loser.UserId]
						if passerUserId then
							local passer = Players:GetPlayerByUserId(passerUserId)
							if passer and isAlive(passer) then
								awardXP(passer, XP_PASS_KILL, "PassKill")
								awardCoins(passer, COINS_PASS_KILL, "PassKill")
								missionRecord(passer, "PassKill", 1)
							end
						end

						eliminatePlayer(loser, "?? BOOM! " .. loser.Name .. " fue eliminado.")
					else
						announce("?? BOOM! (sin holder válido)")
					end

					-- sobrevivir ronda (vivos después del boom)
					for _, surv in ipairs(getAlivePlayers()) do
						awardXP(surv, XP_SURVIVE_ROUND, "SurviveRound")
						awardCoins(surv, COINS_SURVIVE_ROUND, "SurviveRound")
						missionRecord(surv, "SurviveRound", 1)
					end

					-- ¿ganador?
					local alive = getAlivePlayers()
					if #alive <= 1 then
						local winner = (#alive == 1) and alive[1] or nil

						if winner then
							announce("?? Ganador: " .. winner.Name)

							awardXP(winner, XP_WIN_MATCH, "WinMatch")
							awardCoins(winner, COINS_WIN_MATCH, "WinMatch")
							missionRecord(winner, "WinMatch", 1)
						else
							announce("Partida terminada (sin ganador claro).")
						end

						-- EndScreen PRO payload
						for _, p in ipairs(Players:GetPlayers()) do
							local xpService2 = _G.XPService
							local lvAfter, xpAfter = 1, 0
							local xpForNext = 100

							if xpService2 and xpService2.GetLevelXP then
								lvAfter, xpAfter = xpService2:GetLevelXP(p)
								if xpService2.GetXPToNext then
									xpForNext = xpService2:GetXPToNext(lvAfter)
								end
							end

							local payload = {
								winnerName = winner and winner.Name or "",
								wasWinner = (winner == p),

								coins = {
									total = coinsEarned[p.UserId] or 0,
									breakdown = coinsBreakdown[p.UserId] or {ParticipateMatch=0,SurviveRound=0,WinMatch=0,PassKill=0},
								},
								xp = {
									total = xpEarned[p.UserId] or 0,
									breakdown = xpBreakdown[p.UserId] or {ParticipateMatch=0,SurviveRound=0,WinMatch=0,PassKill=0},
								},

								level = {
									before = levelBefore[p.UserId] or lvAfter,
									after = lvAfter,
								},
								xpBefore = xpBefore[p.UserId] or 0,
								xpAfter = xpAfter,
								xpForNext = xpForNext,
							}

							RE_MatchResult:FireClient(p, payload)
						end

						-- cleanup
						setPotatoHolder(nil)
						setState("LOBBY")
						teleportAllToLobby()
						deactivateMap()

						eliminated = {}
						for _, p in ipairs(Players:GetPlayers()) do
							setSpectator(p, false)
						end

						break
					else
						setPotatoHolder(pickRandomAlivePlayer())
						announce("?? Nueva ronda!")
					end
				end
			end

			task.wait(0.5)
		end
	end)

	-- Init
	teleportAllToLobby()
	setState("LOBBY")
end

return MatchService