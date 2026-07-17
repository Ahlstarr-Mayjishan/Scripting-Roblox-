--!nocheck
-- [[
--  NULLSCAPE - Gift Farm Rule Overlay
--  Displays rule countdown and lifecycle status without owning farm decisions.
-- ]]

local CoreGui = game:GetService("CoreGui")

local RuleOverlay = {}
local screenGui = nil
local textLabel = nil

function RuleOverlay.destroy()
	if screenGui then
		pcall(function()
			screenGui:Destroy()
		end)
	end
	screenGui = nil
	textLabel = nil
end

local function ensure()
	if screenGui and screenGui.Parent and textLabel then
		return textLabel
	end

	RuleOverlay.destroy()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NULLSCAPE_GiftFarmWait"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10000
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local frame = Instance.new("Frame")
	frame.Name = "WaitPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 18)
	frame.Size = UDim2.fromOffset(390, 64)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(95, 201, 156)
	stroke.Transparency = 0.25
	stroke.Thickness = 1
	stroke.Parent = frame

	textLabel = Instance.new("TextLabel")
	textLabel.Name = "Status"
	textLabel.Position = UDim2.fromOffset(14, 8)
	textLabel.Size = UDim2.new(1, -28, 1, -16)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamMedium
	textLabel.TextColor3 = Color3.fromRGB(238, 242, 240)
	textLabel.TextSize = 15
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.Parent = frame

	local parent = CoreGui
	if typeof(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and result then
			parent = result
		end
	end
	if typeof(protectgui) == "function" then
		pcall(protectgui, screenGui)
	end
	screenGui.Parent = parent
	return textLabel
end

function RuleOverlay.show(text)
	local label = ensure()
	label.Text = tostring(text or "")
	screenGui.Enabled = true
end

function RuleOverlay.hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return RuleOverlay
