--!nocheck
--[[ NULLSCAPE - Compact multi-row Cadence status view. ]]

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local View = {
	Gui = nil,
	Frame = nil,
	Title = nil,
	Rows = {},
}

local PANEL_WIDTH = 440
local HEADER_HEIGHT = 34
local ROW_HEIGHT = 28
local PANEL_PADDING = 6

local function getPanelWidth()
	local camera = workspace.CurrentCamera
	local viewportWidth = camera and camera.ViewportSize.X or PANEL_WIDTH + 32
	return math.min(PANEL_WIDTH, math.max(240, viewportWidth - 32))
end

local function ensureGui()
	if View.Gui and View.Gui.Parent then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "NULLSCAPE_CadenceStatus"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local frame = Instance.new("Frame")
	frame.Name = "MainFrame"
	frame.Size = UDim2.fromOffset(getPanelWidth(), HEADER_HEIGHT + PANEL_PADDING)
	frame.Position = UDim2.fromOffset(16, 115)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(85, 85, 90)
	stroke.Thickness = 1
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 24)
	title.Position = UDim2.fromOffset(10, 5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(240, 240, 245)
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local parented = pcall(function()
		gui.Parent = CoreGui
	end)
	if not parented then
		local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		gui.Parent = playerGui
	end

	View.Gui = gui
	View.Frame = frame
	View.Title = title
end

local function ensureRow(index)
	local row = View.Rows[index]
	if row and row.Parent then
		return row
	end

	row = Instance.new("TextLabel")
	row.Name = "CadenceRow" .. tostring(index)
	row.Size = UDim2.new(1, -12, 0, ROW_HEIGHT - 3)
	row.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	row.BackgroundTransparency = index % 2 == 0 and 0.2 or 0.35
	row.BorderSizePixel = 0
	row.Font = Enum.Font.GothamMedium
	row.TextSize = 12
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextTruncate = Enum.TextTruncate.AtEnd
	row.Parent = View.Frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = row

	View.Rows[index] = row
	return row
end

function View.render(rows, instrumentCount)
	if #rows == 0 then
		if View.Gui then
			View.Gui.Enabled = false
		end
		return
	end

	ensureGui()
	View.Gui.Enabled = true
	View.Frame.Size = UDim2.fromOffset(getPanelWidth(), HEADER_HEIGHT + #rows * ROW_HEIGHT + PANEL_PADDING)
	View.Title.Text = string.format("CADENCE %d   |   INSTRUMENTS %d", #rows, instrumentCount)

	for index, data in ipairs(rows) do
		local row = ensureRow(index)
		row.Visible = true
		row.Position = UDim2.fromOffset(6, HEADER_HEIGHT + (index - 1) * ROW_HEIGHT)
		row.Text = data.Text
		row.TextColor3 = data.Color
	end
	for index = #rows + 1, #View.Rows do
		View.Rows[index].Visible = false
	end
end

function View.clear()
	table.clear(View.Rows)
	View.Frame = nil
	View.Title = nil
	if View.Gui then
		View.Gui:Destroy()
		View.Gui = nil
	end
end

return View
