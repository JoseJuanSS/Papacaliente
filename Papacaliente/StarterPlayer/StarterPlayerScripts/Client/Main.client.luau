-- StarterPlayerScripts/Client/Main.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


print("[Main.client] INIT - Player:", Players.LocalPlayer and Players.LocalPlayer.Name)

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not Shared then
	warn("[Main.client] No existe ReplicatedStorage/Shared")
	return
end

local RemoteNamesModule = Shared:WaitForChild("RemoteNames", 10)
if not RemoteNamesModule then
	warn("[Main.client] No existe ReplicatedStorage/Shared/RemoteNames")
	return
end

local RemoteNames = require(RemoteNamesModule)
print("[Main.client] RemoteNames loaded. RemotesFolder =", RemoteNames.RemotesFolder)

local ClientFolder = script.Parent
local Controllers = ClientFolder:WaitForChild("Controllers", 10)
if not Controllers then
	warn("[Main.client] No existe Client/Controllers")
	return
end

local function safeRequire(name)
	local mod = Controllers:FindFirstChild(name)
	if not mod then
		warn("[Main.client] Falta ModuleScript:", name)
		return nil
	end
	local ok, result = pcall(require, mod)
	if not ok then
		warn("[Main.client] Error require(", name, "):", result)
		return nil
	end
	return result
end

local HUDController = safeRequire("HUDController")
local ShopController = safeRequire("ShopController")
local SpectatorController = safeRequire("SpectatorController")
local MissionsController = safeRequire("MissionsController")
local CratesController = safeRequire("CratesController")
local InventoryController = safeRequire("InventoryController")

if HUDController and HUDController.Start then
	print("[Main.client] Starting HUDController")
	HUDController.Start(RemoteNames)
end

if ShopController and ShopController.Start then
	print("[Main.client] Starting ShopController")
	ShopController.Start(RemoteNames)
end

if SpectatorController and SpectatorController.Start then
	print("[Main.client] Starting SpectatorController")
	SpectatorController.Start(RemoteNames)
end

if MissionsController and MissionsController.Start then
	print("[Main.client] Starting MissionsController")
	MissionsController.Start(RemoteNames)
end

if InventoryController then
	InventoryController.Start(RemoteNames)
end

if CratesController and CratesController.Start then
	print("[Main.client] Starting CratesController")
	CratesController.Start(RemoteNames)
end

print("[Main.client] DONE")