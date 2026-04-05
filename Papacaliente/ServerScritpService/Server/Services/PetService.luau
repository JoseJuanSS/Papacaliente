local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetConfig"))

local PetService = {}
PetService.__index = PetService

function PetService.new(remotesService, remoteNames, playerDataService, premiumService)
	local self = setmetatable({}, PetService)
	self.Data = playerDataService
	self.Premium = premiumService
	self.RE_Request = remotesService:GetOrCreateRemoteEvent(remoteNames.PetsRequest)
	self.RE_Update = remotesService:GetOrCreateRemoteEvent(remoteNames.PetsUpdate)
	self.RE_Equip = remotesService:GetOrCreateRemoteEvent(remoteNames.PetsEquip)

	self.RE_Request.OnServerEvent:Connect(function(player)
		self:EnsureStarterPets(player)
		self:Send(player)
	end)

	self.RE_Equip.OnServerEvent:Connect(function(player, petId)
		if typeof(petId) ~= "string" then return end
		self:Equip(player, petId)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			if player.Parent == Players then
				self:EnsureStarterPets(player)
				self:Send(player)
			end
		end)
	end)

	return self
end

function PetService:GetProfile(player)
	return self.Data and self.Data:GetProfile(player) or nil
end

function PetService:EnsureProfile(profile)
	profile.Pets = profile.Pets or { Owned = {}, Equipped = nil, Slots = PetConfig.DefaultEquippedSlots or 1 }
	profile.Pets.Owned = profile.Pets.Owned or {}
	profile.Pets.Slots = profile.Pets.Slots or (PetConfig.DefaultEquippedSlots or 1)
end

function PetService:EnsureStarterPets(player)
	local profile = self:GetProfile(player)
	if not profile then return end
	self:EnsureProfile(profile)

	if self.Premium and self.Premium:HasGamepass(player, "PetStarter") then
		profile.Pets.Owned.PUPPY = true
	end
end

function PetService:BuildPayload(player)
	local profile = self:GetProfile(player)
	if not profile then
		return { catalog = PetConfig.Pets, owned = {}, equipped = nil, slots = 1 }
	end
	self:EnsureProfile(profile)
	return {
		catalog = PetConfig.Pets,
		owned = profile.Pets.Owned,
		equipped = profile.Pets.Equipped,
		slots = profile.Pets.Slots,
	}
end

function PetService:Send(player)
	self.RE_Update:FireClient(player, self:BuildPayload(player))
end

function PetService:Equip(player, petId)
	local profile = self:GetProfile(player)
	if not profile then return end
	self:EnsureProfile(profile)
	if profile.Pets.Owned[petId] ~= true then
		self:Send(player)
		return
	end
	profile.Pets.Equipped = petId
	self:Send(player)
end

function PetService:GrantPet(player, petId)
	local profile = self:GetProfile(player)
	if not profile then return end
	self:EnsureProfile(profile)
	profile.Pets.Owned[petId] = true
	self:Send(player)
end

return PetService
