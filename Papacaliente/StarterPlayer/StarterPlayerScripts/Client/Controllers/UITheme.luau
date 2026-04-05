local UITheme = {}

UITheme.Colors = {
	Background = Color3.fromRGB(11, 16, 22),
	Panel = Color3.fromRGB(20, 28, 36),
	PanelSoft = Color3.fromRGB(29, 40, 52),
	PanelStrong = Color3.fromRGB(38, 54, 69),
	Accent = Color3.fromRGB(255, 170, 58),
	AccentSoft = Color3.fromRGB(255, 208, 128),
	Success = Color3.fromRGB(126, 232, 161),
	Warning = Color3.fromRGB(255, 203, 107),
	Danger = Color3.fromRGB(255, 118, 102),
	Info = Color3.fromRGB(122, 208, 255),
	Text = Color3.fromRGB(241, 245, 248),
	TextMuted = Color3.fromRGB(178, 191, 201),
	Stroke = Color3.fromRGB(71, 92, 109),
}

UITheme.Fonts = {
	Title = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
}

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UITheme.Colors.Stroke
	stroke.Transparency = transparency or 0.15
	stroke.Thickness = 1
	stroke.Parent = instance
	return stroke
end

function UITheme.GetScreenGui(player)
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("HotPotatoUI")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "HotPotatoUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function UITheme.CreatePanel(parent, name, size, position)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = UITheme.Colors.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = parent
	addCorner(panel, 14)
	addStroke(panel)
	return panel
end

function UITheme.CreateSectionTitle(parent, text, position, size)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position or UDim2.new(0, 14, 0, 12)
	label.Size = size or UDim2.new(1, -28, 0, 26)
	label.Font = UITheme.Fonts.Title
	label.TextColor3 = UITheme.Colors.Text
	label.TextSize = 20
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text or ""
	label.Parent = parent
	return label
end

function UITheme.CreateBodyLabel(parent, text, position, size)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position or UDim2.new(0, 14, 0, 42)
	label.Size = size or UDim2.new(1, -28, 0, 22)
	label.Font = UITheme.Fonts.Body
	label.TextColor3 = UITheme.Colors.TextMuted
	label.TextSize = 15
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = text or ""
	label.Parent = parent
	return label
end

function UITheme.CreateButton(parent, name, text, size, position, accent)
	local button = Instance.new("TextButton")
	button.Name = name or "Button"
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = accent and UITheme.Colors.Accent or UITheme.Colors.PanelStrong
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Font = UITheme.Fonts.Title
	button.TextColor3 = accent and UITheme.Colors.Background or UITheme.Colors.Text
	button.TextSize = 15
	button.Text = text or ""
	button.Parent = parent
	addCorner(button, 12)
	addStroke(button, accent and UITheme.Colors.AccentSoft or UITheme.Colors.Stroke, 0.35)
	return button
end

function UITheme.CreateIconToggle(parent, name, text, position)
	return UITheme.CreateButton(parent, name, text, UDim2.new(0, 184, 0, 42), position, false)
end

function UITheme.CreateScrollFrame(parent, name, position, size)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.Position = position
	scroll.Size = size
	scroll.BackgroundColor3 = UITheme.Colors.PanelSoft
	scroll.BackgroundTransparency = 0.18
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = parent
	addCorner(scroll, 12)
	addStroke(scroll, UITheme.Colors.Stroke, 0.4)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	return scroll, layout
end

function UITheme.RefreshCanvas(scroll, layout, extra)
	task.defer(function()
		if scroll and layout then
			scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + (extra or 10))
		end
	end)
end

function UITheme.ClearFrames(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

function UITheme.CreateCard(parent, size)
	local card = Instance.new("Frame")
	card.Size = size
	card.BackgroundColor3 = UITheme.Colors.PanelSoft
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = parent
	addCorner(card, 12)
	addStroke(card, UITheme.Colors.Stroke, 0.45)
	return card
end

return UITheme
