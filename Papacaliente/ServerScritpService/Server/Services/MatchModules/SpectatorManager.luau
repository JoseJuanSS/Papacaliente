local SpectatorManager = {}
SpectatorManager.__index = SpectatorManager

function SpectatorManager.new(getLobbySpawn)
	local self = setmetatable({}, SpectatorManager)
	self.GetLobbySpawn = getLobbySpawn
	return self
end

function SpectatorManager:SetSpectator(player, enabled)
	if not player then return end
	enabled = enabled == true

	pcall(function()
		player:SetAttribute("Eliminated", enabled)
	end)

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if enabled then
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
				humanoid.AutoRotate = false
			else
				humanoid.WalkSpeed = 16
				pcall(function() humanoid.JumpPower = 50 end)
				humanoid.AutoRotate = true
			end
		end
	end

	local lobbySpawn = self.GetLobbySpawn and self.GetLobbySpawn() or nil
	if enabled and lobbySpawn and character then
		pcall(function()
			character:PivotTo(lobbySpawn.CFrame + Vector3.new(0, 5, 0))
		end)
	end
end

return SpectatorManager
