--!nocheck
-- [[
--  NULLSCAPE - Custom Radar & ESP Logic
--  Vai trò: Chứa toàn bộ lõi logic định vị quà, nhạc cụ Cadence và đàn tế (Altar), các thuật toán tính toán,
--  nhận diện khoảng cách và phân loại. Cung cấp API logic để Executor và Controller sử dụng.
-- ]]

local Logic = {}

local function canSimulate(controller, featureKey)
	if not controller or controller.RadarEnabled ~= true then
		return false
	end
	return Logic.isSimulationToggleOn(controller, featureKey)
end

-- Bảng màu dùng chung cho các Highlight/Dot (Định nghĩa tập trung)
local ESPColors = {
	-- 1. Gifts & Mines
	Gift = Color3.fromRGB(255, 255, 255), -- Trắng
	GoldenGift = Color3.fromRGB(255, 215, 0), -- Vàng Gold
	PassageGift = Color3.fromRGB(135, 206, 250), -- Light Sky Blue
	Tripmine = Color3.fromRGB(255, 0, 0), -- Đỏ
	GoldenTripmine = Color3.fromRGB(255, 0, 0), -- Đỏ

	-- 2. Cadence Instruments
	Cadence = Color3.fromRGB(255, 0, 0), -- Màu đỏ theo yêu cầu

	-- 3. Altars
	Altar = {
		Purgatory = Color3.new(1, 0.5, 0),
		Chance = Color3.new(1, 1, 0.7),
		Chaos = Color3.new(0.1, 0, 0),
		Echo = Color3.new(0.5, 0.33333, 1),
		Passage = Color3.new(0.7, 0, 0),
		Protection = Color3.fromRGB(0, 255, 255),
		Purification = Color3.fromRGB(255, 0, 255),
		Unknown = Color3.fromRGB(255, 128, 0),
	},
}
Logic.ESPColors = ESPColors


-- Nhận diện loại Altar dựa vào tên đối tượng hoặc cha/con của nó
local function getAltarTypeAndColor(altarObj)
	-- Ưu tiên 1: Attribute "Name" theo ref.lua ArrowHandler (AltarAdded dùng GetAttribute("Name"))
	local attrName = altarObj:GetAttribute("Name")
	if attrName and attrName ~= "" then
		local nameLower = attrName:lower()
		for name, color in pairs(ESPColors.Altar) do
			if string.find(nameLower, name:lower()) then
				return name, color
			end
		end
	end

	-- Ưu tiên 2: StringValue "RealName" (cách cũ từ radar script)
	local realNameVal = altarObj:FindFirstChild("RealName")
	local realName = realNameVal and realNameVal:IsA("StringValue") and realNameVal.Value
	if realName and realName ~= "" then
		local nameLower = realName:lower()
		for name, color in pairs(ESPColors.Altar) do
			if string.find(nameLower, name:lower()) then
				return name, color
			end
		end
	end

	-- Ưu tiên 3: Tên object
	local objName = altarObj.Name:lower()
	for name, color in pairs(ESPColors.Altar) do
		local nameLower = name:lower()
		if string.find(objName, nameLower) then
			return name, color
		end
	end

	-- Ưu tiên 4: Tên parent
	local parentName = altarObj.Parent and altarObj.Parent.Name:lower() or ""
	for name, color in pairs(ESPColors.Altar) do
		local nameLower = name:lower()
		if string.find(parentName, nameLower) then
			return name, color
		end
	end

	-- Ưu tiên 5: Tên con
	for _, child in ipairs(altarObj:GetChildren()) do
		local childName = child.Name:lower()
		for name, color in pairs(ESPColors.Altar) do
			local nameLower = name:lower()
			if string.find(childName, nameLower) then
				return name, color
			end
		end
	end

	return "Unknown", ESPColors.Altar.Unknown
end

-- Bộ lọc nhận dạng nhạc cụ Cadence
local instrumentKeywords = { "harp", "violin", "guitar", "flute", "drum", "piano", "trumpet", "instrument" }

local function isInstrument(name)
	if not name then
		return false
	end
	local nameLower = name:lower()
	for _, keyword in ipairs(instrumentKeywords) do
		if string.find(nameLower, keyword) then
			return true
		end
	end
	return false
end

local function isGiftValid(t)
	if t.rawObj then
		if t.rawObj.Collected or t.rawObj.Destroyed then
			return false
		end
		return t.rawObj.Position ~= nil
	end

	local part = t.part
	if not part or not part.Parent or not part:IsDescendantOf(workspace) then
		return false
	end
	local targetModel = t.model or part

	-- Nếu được tag là Gift thì luôn hợp lệ
	if part:HasTag("Gift") or targetModel:HasTag("Gift") then
		if part.Transparency >= 0.99 then
			return false
		end
		return true
	end

	local nameLower = part.Name:lower()
	local parentNameLower = part.Parent and part.Parent.Name:lower() or ""
	local modelNameLower = targetModel.Name:lower()

	if
		not (
			string.find(nameLower, "gift")
			or string.find(nameLower, "present")
			or string.find(nameLower, "tripmine")
			or string.find(parentNameLower, "gift")
			or string.find(parentNameLower, "present")
			or string.find(parentNameLower, "tripmine")
			or string.find(modelNameLower, "gift")
			or string.find(modelNameLower, "present")
			or string.find(modelNameLower, "tripmine")
		)
	then
		return false
	end

	if part.Transparency >= 0.99 then
		return false
	end

	return true
end

local function isInstrumentValid(t)
	local part = t.part
	if not part or not part.Parent or not part:IsDescendantOf(workspace) then
		return false
	end
	local model = t.model or part

	-- Nếu được tag là CadenceOrb thì luôn hợp lệ
	if part:HasTag("CadenceOrb") or model:HasTag("CadenceOrb") then
		return true
	end

	if not isInstrument(model.Name) and not isInstrument(part.Name) then
		return false
	end
	return true
end

local function isAltarValid(t)
	local part = t.part
	if not part or not part.Parent or not part:IsDescendantOf(workspace) then
		return false
	end
	return true
end
local springerCache = setmetatable({}, { __mode = "k" })
local visualPartCache = setmetatable({}, { __mode = "k" })

local function isSpringerEnemy(enemy)
	if not enemy then
		return false
	end
	if springerCache[enemy] ~= nil then
		return springerCache[enemy]
	end
	local res = string.find(enemy.Name:lower(), "springer") ~= nil
	springerCache[enemy] = res
	return res
end

local function hasWorkingNativeEnemyESP(enemy)
	local child = enemy:FindFirstChild("ESP") or enemy:FindFirstChild("ESPCrayon")
	if child and child:IsA("BillboardGui") then
		local enabledOk = child.Enabled ~= false
		local adornee = child.Adornee
		local adorneeOk = adornee ~= nil and adornee.Parent ~= nil
		if not adorneeOk and child.Parent and child.Parent:IsA("BasePart") then
			adorneeOk = true
		end
		if enabledOk and adorneeOk then
			return true
		end
	end
	return false
end

local function shouldFallbackEnemyESP(enemy)
	if not enemy or not enemy.Parent then
		return false
	end

	if isSpringerEnemy(enemy) then
		return true
	end

	if hasWorkingNativeEnemyESP(enemy) then
		return false
	end

	local ignoredNames = {
		nilEnemy = true,
		nilMirage = true,
		Celestial = true,
		MothSpectator = true,
		CatalystHand = true,
	}
	if ignoredNames[enemy.Name] then
		return false
	end

	return enemy:IsA("Model") or enemy:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function findEnemyVisualPart(enemy, hrp)
	if not enemy or not enemy.Parent then
		return nil
	end
	if visualPartCache[enemy] then
		return visualPartCache[enemy]
	end

	if enemy:IsA("BasePart") then
		visualPartCache[enemy] = enemy
		return enemy
	end

	local resolved = nil

	-- Springer keeps its visual head under horse.Head while the root model holds shockwaves/collision.
	if isSpringerEnemy(enemy) then
		local horse = enemy:FindFirstChild("horse")
		local springerHead = horse and horse:FindFirstChild("Head")
		if springerHead and springerHead:IsA("BasePart") then
			resolved = springerHead
		end
	end

	if not resolved then
		-- Search for Head/head (case-insensitive and recursive if nested inside sub-models), resolving BillboardGuis if needed
		local head = enemy:FindFirstChild("Head") or enemy:FindFirstChild("head")
		if head then
			if head:IsA("BasePart") then
				resolved = head
			elseif head:IsA("BillboardGui") then
				local ad = head.Adornee or head.Parent
				if ad and ad:IsA("BasePart") then
					resolved = ad
				end
			end
		end
	end

	if not resolved then
		for _, child in ipairs(enemy:GetDescendants()) do
			if child.Name == "Head" or child.Name == "head" then
				if child:IsA("BasePart") then
					resolved = child
					break
				elseif child:IsA("BillboardGui") then
					local ad = child.Adornee or child.Parent
					if ad and ad:IsA("BasePart") then
						resolved = ad
						break
					end
				end
			end
		end
	end

	if not resolved then
		-- Fallback to PrimaryPart
		if enemy:IsA("Model") and enemy.PrimaryPart then
			resolved = enemy.PrimaryPart
		end
	end

	if not resolved then
		-- Fallback: Tìm bất kỳ BasePart nào trong mô hình
		local firstPart = enemy:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then
			resolved = firstPart
		end
	end

	if not resolved then
		-- Try to find HumanoidRootPart or Torso (recursive)
		local root = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Torso")
		if not root then
			root = enemy:FindFirstChild("HumanoidRootPart", true) or enemy:FindFirstChild("Torso", true)
		end
		if root and root:IsA("BasePart") then
			resolved = root
		end
	end

	if not resolved then
		-- Shockwave fallback for Springer
		local shockwave = enemy:FindFirstChild("SpringerShockwave", true)
		if shockwave and shockwave:IsA("BasePart") then
			resolved = shockwave
		end
	end

	if not resolved then
		local closestPart = nil
		local closestDistance = math.huge
		for _, descendant in ipairs(enemy:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local distance = hrp and (hrp.Position - descendant.Position).Magnitude or 0
				if distance < closestDistance then
					closestDistance = distance
					closestPart = descendant
				end
			end
		end
		resolved = closestPart
	end

	if resolved then
		visualPartCache[enemy] = resolved
	end
	return resolved
end

local function isSafeEnemyVisualPart(part, hrp)
	if not part or not part.Parent or not part:IsDescendantOf(workspace) then
		return false
	end

	local pos = part.Position
	if math.abs(pos.X) > 100000 or math.abs(pos.Y) > 100000 or math.abs(pos.Z) > 100000 then
		return false
	end

	-- Hide custom ESP if the enemy is currently in the void/lobby/spawning state (Y < -50)
	if pos.Y < -50 then
		return false
	end

	local size = part.Size
	if size.X > 1000 or size.Y > 1000 or size.Z > 1000 then
		return false
	end

	if hrp and (hrp.Position - pos).Magnitude > 5000 then
		return false
	end

	return true
end

-- Dọn dẹp toàn bộ Highlight, Beam, Dot và các đối tượng lưu đệm
function Logic.clearVisuals(gc, keepArrows)
	-- Dọn dẹp native enemy ESP
	local saved = gc.SavedVisuals
	if not saved then
		return
	end

	if saved.ActiveTargets then
		for _, cached in pairs(saved.ActiveTargets) do
			if cached.Dot then
				pcall(function()
					cached.Dot:Destroy()
				end)
			end
		end
		table.clear(saved.ActiveTargets)
	else
		saved.ActiveTargets = {}
	end

	-- Vô hiệu hóa và dọn dẹp Highlight Pool
	if saved.HighlightPool then
		for _, hl in ipairs(saved.HighlightPool) do
			hl.Adornee = nil
			hl.Enabled = false
		end
	end

	if saved.Highlights then
		for _, hl in pairs(saved.Highlights) do
			pcall(function()
				hl:Destroy()
			end)
		end
		table.clear(saved.Highlights)
	end

	if saved.NativeEnemyFallbacks then
		for _, gui in pairs(saved.NativeEnemyFallbacks) do
			pcall(function()
				gui:Destroy()
			end)
		end
		table.clear(saved.NativeEnemyFallbacks)
	end
	if saved.Beams then
		table.clear(saved.Beams)
	end
	if saved.Attachments then
		table.clear(saved.Attachments)
	end
	if saved.Dots then
		table.clear(saved.Dots)
	end

	if saved.Barriers then
		for _, barrier in pairs(saved.Barriers) do
			pcall(function()
				barrier:Destroy()
			end)
		end
		table.clear(saved.Barriers)
	end

	if not keepArrows then
		if hudRemovedConnection then
			pcall(function()
				hudRemovedConnection:Disconnect()
			end)
			hudRemovedConnection = nil
		end

		if saved.HighlightPoolFolder then
			pcall(function()
				saved.HighlightPoolFolder:Destroy()
			end)
			saved.HighlightPoolFolder = nil
		end
		saved.HighlightPool = nil

		for _, key in ipairs({ "ArrowGift", "ArrowCadence", "ArrowAltar" }) do
			if saved[key] then
				pcall(function()
					saved[key]:Destroy()
				end)
				saved[key] = nil
			end
		end
	end
end


-- Vòng lặp cập nhật khoảng cách, sắp xếp độ ưu tiên và chuyển đổi visual styles (chạy cực nhanh)
local function customBillboardName(style)
	return style == "Ping" and "NULLSCAPE_CustomESP_Ping" or "NULLSCAPE_CustomESP_Dot"
end

local function ensureCustomBillboard(parentObject, style, color)
	if not parentObject or not parentObject.Parent then
		return nil
	end

	local billboard = parentObject:FindFirstChild(customBillboardName(style))
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = customBillboardName(style)
		billboard.AlwaysOnTop = true
		billboard.Size = style == "Ping" and UDim2.fromOffset(14, 14) or UDim2.fromOffset(2, 2)
		billboard.StudsOffset = style == "Ping" and Vector3.new(0, 2.5, 0) or Vector3.new(0, 0, 0)

		local marker = Instance.new("Frame")
		marker.Name = "Marker"
		marker.Size = UDim2.fromScale(1, 1)
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.Position = UDim2.fromScale(0.5, 0.5)
		marker.Rotation = style == "Ping" and 45 or 0
		marker.BorderSizePixel = 0
		marker.Parent = billboard
		billboard.Parent = parentObject
	end

	local marker = billboard:FindFirstChild("Marker")
	if marker and marker:IsA("Frame") then
		marker.BackgroundColor3 = color
	end
	billboard.Enabled = true
	return billboard
end

local function applyCustomBillboards(saved, desired)
	if not saved.ActiveTargets then
		saved.ActiveTargets = {}
	end

	for targetPart, cached in pairs(saved.ActiveTargets) do
		if not desired[targetPart] or not targetPart.Parent or not targetPart:IsDescendantOf(workspace) then
			if cached.Dot then
				pcall(function()
					cached.Dot:Destroy()
				end)
			end
			saved.ActiveTargets[targetPart] = nil
		end
	end

	for targetPart, current in pairs(desired) do
		local cached = saved.ActiveTargets[targetPart]
		if cached and cached.Dot and cached.Style == current.Style and cached.Dot.Parent then
			local marker = cached.Dot:FindFirstChild("Marker")
			if marker and marker:IsA("Frame") then
				marker.BackgroundColor3 = current.Color
			end
		else
			if cached and cached.Dot then
				pcall(function()
					cached.Dot:Destroy()
				end)
			end
			saved.ActiveTargets[targetPart] = {
				Style = current.Style,
				Dot = ensureCustomBillboard(current.ParentObject, current.Style, current.Color),
			}
		end
	end
end

local function applyCustomHighlights(saved, desired)
	if not saved.Highlights then
		saved.Highlights = {}
	end

	for targetObject, hl in pairs(saved.Highlights) do
		if not desired[targetObject] or not targetObject.Parent then
			pcall(function()
				hl:Destroy()
			end)
			saved.Highlights[targetObject] = nil
		end
	end

	for targetObject, color in pairs(desired) do
		local hl = saved.Highlights[targetObject]
		if not hl or not hl.Parent then
			local adornee = targetObject
			if targetObject:IsA("BasePart") then
				local model = targetObject:FindFirstAncestorOfClass("Model")
				if model then
					adornee = model
				end
			end

			hl = Instance.new("Highlight")
			hl.Name = "NULLSCAPE_CustomHighlight"
			hl.FillTransparency = 1
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = adornee
			hl.Parent = adornee
			saved.Highlights[targetObject] = hl
		end
		hl.OutlineColor = color
		hl.Enabled = true
	end
end

local function getEnemyDisplayName(enemy)
	local nameLower = enemy.Name:lower()
	if nameLower == "shadowguardian" then
		return "voidboundguardian"
	elseif nameLower == "shadowbaby" then
		return "voidboundbaby"
	elseif nameLower == "skinwalker" then
		return "husk"
	elseif nameLower == "mirage" then
		return "???"
	end
	return nameLower
end

local function findNativeEnemyESPTemplate()
	local globals = getgenv()._NULLSCAPE_Globals
	if globals and globals.NativeEnemyESPTemplate and globals.NativeEnemyESPTemplate.Parent then
		return globals.NativeEnemyESPTemplate
	end
	if globals and globals.NativeEnemyESPTemplateMissAt and time() - globals.NativeEnemyESPTemplateMissAt < 2 then
		return nil
	end

	local function searchDescendantsBudgeted(root, maxDescendants)
		if not root then
			return nil
		end

		local stack = root:GetChildren()
		local scanned = 0
		while #stack > 0 and scanned < maxDescendants do
			local inst = table.remove(stack)
			if inst and inst.Parent then
				scanned = scanned + 1
				if (inst.Name == "ESP" or inst.Name == "ESPCrayon") and inst:IsA("BillboardGui") then
					return inst
				end

				local children = inst:GetChildren()
				for i = #children, 1, -1 do
					table.insert(stack, children[i])
				end
			end
		end

		return nil
	end

	local players = game:GetService("Players")
	local localPlayer = players.LocalPlayer
	local playerScripts = localPlayer and localPlayer:FindFirstChild("PlayerScripts")
	local template = searchDescendantsBudgeted(playerScripts, 2500)
	if not template then
		template = searchDescendantsBudgeted(workspace:FindFirstChild("Enemies"), 2500)
	end
	if not template then
		local starterPlayer = game:GetService("StarterPlayer")
		template = searchDescendantsBudgeted(starterPlayer and starterPlayer:FindFirstChild("StarterPlayerScripts"), 2500)
	end
	if template then
		if globals then
			globals.NativeEnemyESPTemplate = template
		end
		return template
	end

	if globals then
		globals.NativeEnemyESPTemplateMissAt = time()
	end
	return nil
end

local function createFallbackEnemyESP()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NULLSCAPE_NativeEnemyESP"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(110, 24)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.TextColor3 = Color3.fromRGB(255, 180, 80)
	label.Parent = billboard

	return billboard
end

local function setEnemyESPLabel(gui, text, color)
	local label = gui:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
		label.TextColor3 = color
	end
end

local function getEnemyFallbackParent(enemy, part)
	if isSpringerEnemy(enemy) then
		local horse = enemy:FindFirstChild("horse")
		if horse then
			return horse
		end
	end

	return enemy or (part and part.Parent)
end

local function getEnemyFallbackSize(enemy, gui)
	if isSpringerEnemy(enemy) then
		return UDim2.fromOffset(180, 44)
	end

	local headGui = enemy and (enemy:FindFirstChild("head", true) or enemy:FindFirstChild("Head", true))
	if headGui and headGui:IsA("BillboardGui") then
		return headGui.Size
	end

	if gui and gui:IsA("BillboardGui") and typeof(gui.Size) == "UDim2" then
		return gui.Size
	end

	return UDim2.fromScale(4, 4)
end

local function configureEnemyFallbackGui(enemy, gui)
	if not (gui and gui:IsA("BillboardGui")) then
		return
	end

	gui.AlwaysOnTop = true
	gui.MaxDistance = 1200

	if isSpringerEnemy(enemy) then
		gui.Size = UDim2.fromOffset(180, 44)
		gui.StudsOffset = Vector3.new(0, 6.5, 0)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)

		local label = gui:FindFirstChild("Label", true)
		if label and label:IsA("TextLabel") then
			label.TextScaled = false
			label.TextSize = 24
			label.Font = Enum.Font.Code
			label.TextStrokeTransparency = 0.15
			label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		end
	end
end

local function updateNativeLikeEnemyFallbacks(saved, desired)
	if not saved.NativeEnemyFallbacks then
		saved.NativeEnemyFallbacks = {}
	end

	for enemy, gui in pairs(saved.NativeEnemyFallbacks) do
		if not desired[enemy] or not enemy.Parent or not gui.Parent then
			pcall(function()
				gui:Destroy()
			end)
			saved.NativeEnemyFallbacks[enemy] = nil
		end
	end

	for enemy, data in pairs(desired) do
		local gui = saved.NativeEnemyFallbacks[enemy]
		if not gui or not gui.Parent then
			local template = saved.NativeEnemyESPTemplate
			if not (template and template.Parent) then
				template = findNativeEnemyESPTemplate()
				saved.NativeEnemyESPTemplate = template
			end
			if template then
				gui = template:Clone()
				gui.Name = "NULLSCAPE_NativeEnemyESP"
			else
				gui = createFallbackEnemyESP()
			end
			gui.Parent = getEnemyFallbackParent(enemy, data.Part)
			saved.NativeEnemyFallbacks[enemy] = gui
		end

		pcall(function()
			gui.Adornee = data.Part
		end)
		pcall(function()
			gui.Enabled = true
		end)
		pcall(function()
			gui.Size = getEnemyFallbackSize(enemy, gui)
		end)
		configureEnemyFallbackGui(enemy, gui)
		setEnemyESPLabel(gui, getEnemyDisplayName(enemy), data.Color)
	end
end

local function addCustomVisual(style, highlights, billboards, part, model, color)
	local targetObject = model or part
	if not part or not part.Parent or not targetObject or not targetObject.Parent then
		return
	end

	if style == "Highlight" then
		highlights[targetObject] = color
	elseif style == "Dot" or style == "Ping" then
		billboards[part] = {
			Style = style,
			Color = color,
			ParentObject = part,
		}
	end
end

local function addModelEnemyFallback(controller, enemyFallbacks, hrp)
	if not canSimulate(controller, "Enemy") then
		return
	end

	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		return
	end

	local color = controller.EnemyESPColor or Color3.fromRGB(255, 128, 0)
	for _, enemy in ipairs(enemies:GetChildren()) do
		if shouldFallbackEnemyESP(enemy) then
			local part = findEnemyVisualPart(enemy, hrp)
			if isSafeEnemyVisualPart(part, hrp) then
				enemyFallbacks[enemy] = {
					Part = part,
					Color = color,
				}
			end
		end
	end
end

local function altarMatchesFilter(controller, altarName)
	local filter = controller.AltarFilter
	if typeof(filter) == "table" then
		return table.find(filter, "All") ~= nil
			or table.find(filter, "Tất cả") ~= nil
			or #filter == 0
			or table.find(filter, altarName) ~= nil
	end

	local filterStr = tostring(filter or "All")
	return filterStr == "All" or filterStr == "Tất cả" or filterStr == altarName
end

local function getUpgradesFolder()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local upgradeFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder")
	return upgradeFolder and upgradeFolder:FindFirstChild("Upgrades")
end

local function isNativelyOwned(upgradeName)
	local orig = getgenv()._NULLSCAPE_Globals.OriginalIsUpgradeEnabled
	if typeof(orig) == "function" then
		local success, result = pcall(orig, upgradeName)
		if success then
			return result == true
		end
	end

	local upgradesFolder = getUpgradesFolder()
	if upgradesFolder then
		local val = upgradesFolder:FindFirstChild(upgradeName)
		if val and (val:IsA("ValueObject") or val:IsA("Attribute") or val:IsA("IntValue") or val:IsA("BoolValue")) then
			local value = 0
			pcall(function() value = val.Value or 0 end)
			if value > 0 or value == true then
				return true
			end
		end
	end

	return false
end

Logic.isNativelyOwned = isNativelyOwned

local function canSimulate(controller, featureKey)
	local cfg = Logic.FEATURES[featureKey]
	if not cfg or not controller then
		return false
	end
	return controller[cfg.toggle] == true
end

local function updateCustomESPStyles(controller, gc, hrp)
	Logic.syncSimulatedUpgradeHud(controller)

	local saved = gc.SavedVisuals
	if not saved.ActiveTargets then
		saved.ActiveTargets = {}
	end
	if not saved.Highlights then
		saved.Highlights = {}
	end

	if not hrp then
		applyCustomBillboards(saved, {})
		applyCustomHighlights(saved, {})
		updateNativeLikeEnemyFallbacks(saved, {})
		return
	end

	local style = controller.ESPStyle or "Highlight"
	local billboards = {}
	local highlights = {}
	local enemyFallbacks = {}

	for _, t in ipairs(controller.ActiveGifts or {}) do
		if isGiftValid(t) then
			local isTripmine = t.type == "Tripmine" or t.type == "GoldenTripmine" or t.type == "GoldenTripmines"
			local featureKey = isTripmine and "Tripmine" or "Gift"
			
			-- Bỏ qua vẽ ESP nếu người chơi đã mua tính năng này trong game
			local nativeUpgrade = Logic.FEATURES[featureKey].upgrade
			if canSimulate(controller, featureKey) and not isNativelyOwned(nativeUpgrade) then
				local model = t.rawObj and t.rawObj.Model and typeof(t.rawObj.Model) == "Instance" and t.rawObj.Model.Parent and t.rawObj.Model or t.model
				local part = t.part
				if (not part or not part.Parent) and model then
					part = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart")
				end
				addCustomVisual(style, highlights, billboards, part, model or part, t.color or ESPColors.Gift)
			end
		end
	end

	if canSimulate(controller, "Cadence") and not isNativelyOwned("RadarInstruments") then
		for _, t in ipairs(controller.ActiveInstruments or {}) do
			if isInstrumentValid(t) then
				addCustomVisual(style, highlights, billboards, t.part, t.model or t.part, t.color or ESPColors.Cadence)
			end
		end
	end

	if canSimulate(controller, "Altar") and not isNativelyOwned("RadarAltars") then
		for _, t in ipairs(controller.ActiveAltars or {}) do
			if isAltarValid(t) and altarMatchesFilter(controller, t.altarName or "Unknown") then
				addCustomVisual(style, highlights, billboards, t.part, t.model or t.part, t.color or ESPColors.Altar.Unknown)
			end
		end
	end

	if style ~= "Ping" and canSimulate(controller, "Player") and not isNativelyOwned("RadarPlayer") then
		local Players_ = game:GetService("Players")
		local LocalPlayer_ = Players_.LocalPlayer
		for _, player in ipairs(Players_:GetPlayers()) do
			if player ~= LocalPlayer_ then
				local character = player.Character
				local charHRP = character and character:FindFirstChild("HumanoidRootPart")
				if charHRP and character and character.Parent then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					local color = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Dead
						and Color3.new(1, 0, 0)
						or (controller.PlayerESPColor or Color3.fromRGB(255, 255, 255))
					addCustomVisual(style, highlights, billboards, charHRP, character, color)
				end
			end
		end
	end

	if not isNativelyOwned("EnemyOnTop") then
		addModelEnemyFallback(controller, enemyFallbacks, hrp)
	end

	applyCustomBillboards(saved, billboards)
	applyCustomHighlights(saved, highlights)
	updateNativeLikeEnemyFallbacks(saved, enemyFallbacks)
end

function Logic.updateESPStyles(controller, gc, hrp)
	updateCustomESPStyles(controller, gc, hrp)
end

Logic.isInstrument = isInstrument
Logic.getAltarTypeAndColor = getAltarTypeAndColor

-- =============================================================================
-- FULL CLIENT BYPASS
-- Toggle ON → hook IsUpgradeEnabled + inject HUD icon cho toàn bộ module radar gốc.
-- Không kiểm tra Index, không nhường native trong run.
-- =============================================================================

Logic.RADAR_UPGRADES = {
	"HighlightGifts",
	"HighlightTripmines",
	"RadarInstruments",
	"RadarAltars",
	"RadarPlayer",
	"EnemyOnTop",
}

Logic.FEATURES = {
	Gift = {
		toggle = "GiftESPEnabled",
		upgrade = "HighlightGifts",
	},
	Tripmine = {
		toggle = "TripmineESPEnabled",
		upgrade = "HighlightTripmines",
	},
	Cadence = {
		toggle = "CadenceESPEnabled",
		upgrade = "RadarInstruments",
	},
	Altar = {
		toggle = "AltarESPEnabled",
		upgrade = "RadarAltars",
	},
	Player = {
		toggle = "PlayerESPEnabled",
		upgrade = "RadarPlayer",
	},
	Enemy = {
		toggle = "EnemyESPEnabled",
		upgrade = "EnemyOnTop",
	},
}

local UPGRADE_TO_FEATURE = {}
for featureKey, cfg in pairs(Logic.FEATURES) do
	UPGRADE_TO_FEATURE[cfg.upgrade] = featureKey
end

local SIM_ATTR = "NULLSCAPE_Simulated"
local hudRemovedConnection = nil

local function collectDesiredSimulatedUpgrades(controller)
	local desired = {}
	if not controller then
		return desired
	end
	if controller.RadarEnabled ~= true then
		return desired
	end

	for featureKey, cfg in pairs(Logic.FEATURES) do
		if Logic.isSimulationToggleOn(controller, featureKey) then
			desired[cfg.upgrade] = true
		end
	end

	return desired
end

local function ensureSimulatedUpgradeInt(upgrades, upgradeName)
	local existing = upgrades:FindFirstChild(upgradeName)
	if existing then
		if existing:GetAttribute(SIM_ATTR) then
			if existing.Value ~= 1 then
				existing.Value = 1
			end
			return existing
		end
		return nil
	end

	local simulated = Instance.new("IntValue")
	simulated.Name = upgradeName
	simulated.Value = 1
	simulated:SetAttribute(SIM_ATTR, true)
	simulated.Parent = upgrades
	return simulated
end

local function removeSimulatedUpgradeInt(upgrades, upgradeName)
	local existing = upgrades:FindFirstChild(upgradeName)
	if existing and existing:GetAttribute(SIM_ATTR) then
		pcall(function()
			existing:Destroy()
		end)
	end
end

function Logic.syncSimulatedUpgradeHud(controller)
	if not controller or controller.Destroyed then
		return
	end

	local upgrades = getUpgradesFolder()
	if not upgrades then
		return
	end

	local desired = collectDesiredSimulatedUpgrades(controller)

	for _, child in ipairs(upgrades:GetChildren()) do
		if child:GetAttribute(SIM_ATTR) and not desired[child.Name] then
			removeSimulatedUpgradeInt(upgrades, child.Name)
		end
	end

	for upgradeName in pairs(desired) do
		ensureSimulatedUpgradeInt(upgrades, upgradeName)
	end
end

local function bindSimulatedUpgradeHudWatcher(controller)
	-- No-op to prevent infinite creation-destruction loops with game anti-cheat/UI scripts
end

function Logic.isSimulationToggleOn(controller, featureKey)
	local cfg = Logic.FEATURES[featureKey]
	if not cfg or not controller then
		return false
	end
	return controller[cfg.toggle] == true
end

function Logic.shouldSpoofUpgradeEnabled(controller, upgradeName)
	if not controller then
		return false
	end

	-- Nếu người dùng đã thực sự mua nâng cấp này, nhường quyền kiểm soát lại cho game
	if isNativelyOwned(upgradeName) then
		return false
	end

	local featureKey = UPGRADE_TO_FEATURE[upgradeName]
	if featureKey then
		if controller.RadarEnabled ~= true then
			return true, false
		end
		return true, Logic.isSimulationToggleOn(controller, featureKey)
	end

	return false
end

function Logic.shouldSpoofUpgradeStack(controller, upgradeName)
	local shouldSpoof, enabled = Logic.shouldSpoofUpgradeEnabled(controller, upgradeName)
	if shouldSpoof then
		return true, enabled and 1 or 0
	end
	return false
end

function Logic.bindUpgradeWatcher(controller, onChanged)
	bindSimulatedUpgradeHudWatcher(controller)

	task.spawn(function()
		local ReplicatedFirst = game:GetService("ReplicatedFirst")
		local clientModules = ReplicatedFirst:WaitForChild("ClientModules", 15)
		local upgradeModule = clientModules and clientModules:WaitForChild("UpgradeHandler", 15)
		if upgradeModule then
			local ok, UpgradeHandler = pcall(require, upgradeModule)
			if ok and typeof(UpgradeHandler) == "table" and UpgradeHandler.UpgradesChanged then
				UpgradeHandler.UpgradesChanged:Connect(function()
					Logic.syncSimulatedUpgradeHud(controller)
					if onChanged then
						onChanged()
					end
				end)
			end
		end
	end)
end

return Logic
