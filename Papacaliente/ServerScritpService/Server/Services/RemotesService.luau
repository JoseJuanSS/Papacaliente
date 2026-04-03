-- ServerScriptService/Server/Services/RemotesService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesService = {}
RemotesService.__index = RemotesService

function RemotesService.new(remoteNames)
	local self = setmetatable({}, RemotesService)
	self.Names = remoteNames

	local folder = ReplicatedStorage:FindFirstChild(remoteNames.RemotesFolder)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = remoteNames.RemotesFolder
		folder.Parent = ReplicatedStorage
	end

	self.Folder = folder
	return self
end

function RemotesService:GetOrCreateRemoteEvent(name)
	local r = self.Folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = self.Folder
	end
	return r
end

function RemotesService:GetOrCreateBindableEvent(name)
	local b = self.Folder:FindFirstChild(name)
	if not b then
		b = Instance.new("BindableEvent")
		b.Name = name
		b.Parent = self.Folder
	end
	return b
end

function RemotesService:GetFolder()
	return self.Folder
end

return RemotesService