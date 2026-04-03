-- ServerScriptService/Server/Services/CosmeticsService.lua
-- Port directo de tus efectos del ShopServer original para que TODO se vea igual.

local CosmeticsService = {}
CosmeticsService.__index = CosmeticsService

function CosmeticsService.new()
	return setmetatable({}, CosmeticsService)
end

function CosmeticsService:ApplyAura(plr, auraId)
	local char = plr.Character
	if not char then return end
	local old = char:FindFirstChild("EquippedAura")
	if old then old:Destroy() end
	if not auraId then return end

	local h = Instance.new("Highlight")
	h.Name = "EquippedAura"
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	if auraId == "AURA_FIRE" then
		h.FillColor = Color3.fromRGB(255,100,0); h.OutlineColor = Color3.fromRGB(255,210,120)
	elseif auraId == "AURA_ICE" then
		h.FillColor = Color3.fromRGB(90,200,255); h.OutlineColor = Color3.fromRGB(220,250,255)
	elseif auraId == "AURA_GOLD" then
		h.FillColor = Color3.fromRGB(255,210,80); h.OutlineColor = Color3.fromRGB(255,245,180)
	elseif auraId == "AURA_VOID" then
		h.FillColor = Color3.fromRGB(80,0,120); h.OutlineColor = Color3.fromRGB(200,120,255)
	else
		return
	end

	h.Parent = char
end

function CosmeticsService:ApplyTrail(plr, trailId)
	local char = plr.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local old = char:FindFirstChild("EquippedTrail")
	if old then old:Destroy() end
	if not trailId then return end

	local folder = Instance.new("Folder"); folder.Name = "EquippedTrail"; folder.Parent = char
	local a0 = Instance.new("Attachment", hrp); a0.Name = "TrailA0"; a0.Position = Vector3.new(0,1,0)
	local a1 = Instance.new("Attachment", hrp); a1.Name = "TrailA1"; a1.Position = Vector3.new(0,-1,0)
	local tr = Instance.new("Trail"); tr.Attachment0 = a0; tr.Attachment1 = a1; tr.Lifetime = 0.25

	if trailId == "TRAIL_SPARK" then
		tr.Color = ColorSequence.new(Color3.new(1,1,1))
	elseif trailId == "TRAIL_SHADOW" then
		tr.Color = ColorSequence.new(Color3.fromRGB(30,30,30))
	elseif trailId == "TRAIL_RAINBOW" then
		tr.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,255)),
		})
	else
		folder:Destroy(); return
	end

	tr.Parent = folder
end

function CosmeticsService:ApplyEquipped(plr, equipped)
	equipped = equipped or { Aura=nil, Trail=nil }
	self:ApplyAura(plr, equipped.Aura)
	self:ApplyTrail(plr, equipped.Trail)
end

return CosmeticsService