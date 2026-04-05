local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudienceVoteConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AudienceVoteConfig"))

local AudienceVoteService = {}
AudienceVoteService.__index = AudienceVoteService

function AudienceVoteService.new(remotesService, remoteNames)
	local self = setmetatable({}, AudienceVoteService)
	self.RE_Update = remotesService:GetOrCreateRemoteEvent(remoteNames.AudienceVoteUpdate)
	self.State = {
		enabled = AudienceVoteConfig.Enabled == true,
		candidates = {},
		votes = {},
		durationSeconds = AudienceVoteConfig.DurationSeconds or 12,
	}
	return self
end

function AudienceVoteService:SetCandidates(candidates)
	self.State.candidates = candidates or {}
end

function AudienceVoteService:SendAll()
	self.RE_Update:FireAllClients(self.State)
end

return AudienceVoteService
