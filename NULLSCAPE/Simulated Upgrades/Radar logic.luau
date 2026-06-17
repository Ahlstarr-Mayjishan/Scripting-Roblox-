--!nocheck
-- [[
--  NULLSCAPE - Custom Radar & ESP Logic
--  Vai trò: Chứa toàn bộ lõi logic định vị quà, nhạc cụ Cadence và đàn tế (Altar), các thuật toán tính toán,
--  nhận diện khoảng cách và phân loại. Cung cấp API logic để Executor và Controller sử dụng.
-- ]]

local Logic = {}

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
local FALLBACK_ARROW_MESH_ID = "rbxassetid://118015691029311"
local FALLBACK_ARROW_SCALE = Vector3.new(1.35, 1.35, 1.35)

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

local function setArrowTransparency(arrow, transparency)
	if not arrow then
		return
	end
	if arrow:IsA("BasePart") then
		arrow.Transparency = transparency
	else
		for _, child in ipairs(arrow:GetDescendants()) do
			if child:IsA("BasePart") then
				child.Transparency = transparency
			end
		end
	end
end

local function findTemplate(key)
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	local ReplicatedFirst = game:GetService("ReplicatedFirst")

	if key == "ArrowGift" then
		-- 1. Thử tìm trong ReplicatedFirst
		local giftClient = ReplicatedFirst:FindFirstChild("ClientModules")
			and ReplicatedFirst.ClientModules:FindFirstChild("GiftClient")
		local giftClientHandler = giftClient and giftClient:FindFirstChild("GiftClientHandler")
		local assets = giftClientHandler and giftClientHandler:FindFirstChild("Assets")
		local template = assets and assets:FindFirstChild("GiftArrow")
		if template then
			return template
		end

		-- 2. Thử tìm trong workspace
		template = workspace:FindFirstChild("GiftArrow")
		if template then
			return template
		end
	elseif key == "ArrowCadence" then
		-- 1. Thử tìm trong PlayerScripts
		local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
		local arrowHandler = playerScripts and playerScripts:FindFirstChild("ArrowHandler")
		local arrowsFolder = arrowHandler and arrowHandler:FindFirstChild("Arrows")
		local template = arrowsFolder and arrowsFolder:FindFirstChild("CadenceArrow")
		if template then
			return template
		end

		-- 2. Thử tìm trong workspace.Arrows
		local wArrows = workspace:FindFirstChild("Arrows")
		template = wArrows and wArrows:FindFirstChild("CadenceArrow")
		if template then
			return template
		end
	elseif key == "ArrowAltar" then
		-- 1. Thử tìm trong PlayerScripts
		local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
		local arrowHandler = playerScripts and playerScripts:FindFirstChild("ArrowHandler")
		local template = arrowHandler and arrowHandler:FindFirstChild("Template")
		if template then
			return template
		end

		-- 2. Thử tìm trong workspace.Arrows
		local wArrows = workspace:FindFirstChild("Arrows")
		if wArrows then
			template = wArrows:FindFirstChild("Template")
			if template then
				return template
			end

			for _, child in ipairs(wArrows:GetChildren()) do
				if
					child.Name ~= "CadenceArrow"
					and not string.find(child.Name, "NULLSCAPE_")
					and (child:IsA("BasePart") or child:IsA("Model"))
				then
					return child
				end
			end
		end
	end
	return nil
end

local function setArrowColor(arrow, color)
	if not arrow then
		return
	end

	-- Đảm bảo màu sắc/vật liệu mà không phá texture hoặc scale mesh gốc của game.
	if arrow:IsA("BasePart") then
		if arrow.Color ~= color then
			arrow.Color = color
		end
		if arrow.Material ~= Enum.Material.Neon then
			arrow.Material = Enum.Material.Neon
		end
		local maxDim = math.max(arrow.Size.X, arrow.Size.Y, arrow.Size.Z)
		if maxDim > 4 then
			arrow.Size = arrow.Size * (2.5 / maxDim)
		end
	end

	for _, child in ipairs(arrow:GetDescendants()) do
		if child:IsA("BasePart") then
			if child.Color ~= color then
				child.Color = color
			end
			if child.Material ~= Enum.Material.Neon then
				child.Material = Enum.Material.Neon
			end
			local maxDim = math.max(child.Size.X, child.Size.Y, child.Size.Z)
			if maxDim > 4 then
				child.Size = child.Size * (2.5 / maxDim)
			end
		elseif child:IsA("SpecialMesh") then
			child.VertexColor = Vector3.new(color.R, color.G, color.B)
			local maxScale = math.max(child.Scale.X, child.Scale.Y, child.Scale.Z)
			if maxScale > 4 then
				child.Scale = child.Scale * (2.5 / maxScale)
			end
		end
	end
end

local function setArrowCFrame(arrow, cf)
	if not arrow then
		return
	end
	if arrow:IsA("Model") then
		arrow:PivotTo(cf)
	else
		arrow.CFrame = cf
	end
end

local function setArrowPhysics(arrow)
	if not arrow then
		return
	end
	if arrow:IsA("BasePart") then
		arrow.CanCollide = false
		arrow.CanQuery = false
		arrow.CanTouch = false
		arrow.CastShadow = false
		arrow.Anchored = true
	else
		for _, child in ipairs(arrow:GetDescendants()) do
			if child:IsA("BasePart") then
				child.CanCollide = false
				child.CanQuery = false
				child.CanTouch = false
				child.CastShadow = false
				child.Anchored = true
			end
		end
	end
end

-- Helper để lấy hoặc tạo mũi tên chỉ hướng (đặc, không trong suốt)
local function getOrCreateArrow(saved, key, color)
	local arrow = saved[key]
	if not arrow or not arrow.Parent then
		local template = findTemplate(key)

		if template then
			arrow = template:Clone()
			arrow.Name = "NULLSCAPE_" .. key
			arrow.Parent = workspace
		else
			-- Fallback tạo thủ công nếu không tìm thấy mẫu của game
			arrow = Instance.new("Part")
			arrow.Name = "NULLSCAPE_" .. key

			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId = FALLBACK_ARROW_MESH_ID
			mesh.Scale = FALLBACK_ARROW_SCALE
			mesh.Parent = arrow

			arrow.Material = Enum.Material.Neon
			arrow.Size = Vector3.new(1, 1, 1)
			arrow.Parent = workspace
		end

		setArrowPhysics(arrow)
		setArrowTransparency(arrow, 0)
		saved[key] = arrow
	end
	setArrowColor(arrow, color)
	return arrow
end

-- Các hàm helper kiểm tra tính hợp lệ thời gian thực (lọc các đối tượng đã bị nhặt/ẩn/đổi tên)
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

-- Dọn dẹp toàn bộ Highlight, Beam, Dot và các đối tượng lưu đệm
function Logic.clearVisuals(gc, keepArrows)
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
		table.clear(saved.Highlights)
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
function Logic.updateESPStyles(controller, gc, hrp)
	local saved = gc.SavedVisuals
	if not saved.ActiveTargets then
		saved.ActiveTargets = {}
	end
	if not hrp then
		return
	end

	-- Khởi tạo bể chứa Highlight (Highlight Pool) cố định nếu chưa có
	if not saved.HighlightPool then
		saved.HighlightPool = {}
		local folder = Instance.new("Folder")
		folder.Name = "NULLSCAPE_HighlightPool"
		folder.Parent = workspace
		saved.HighlightPoolFolder = folder

		-- Tạo sẵn 15 Highlight dùng chung để tối ưu hóa hiệu năng render
		for _ = 1, 15 do
			local hl = Instance.new("Highlight")
			hl.FillColor = Color3.fromRGB(255, 255, 255)
			hl.FillTransparency = 1.0
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Enabled = false
			hl.Parent = folder
			table.insert(saved.HighlightPool, hl)
		end
	end

	local gifts = controller.GiftESPEnabled and (controller.ActiveGifts or {}) or {}
	local instruments = controller.CadenceESPEnabled and (controller.ActiveInstruments or {}) or {}
	local altars = controller.AltarESPEnabled and (controller.ActiveAltars or {}) or {}

	local validGifts = {}
	local validInstruments = {}
	local validAltars = {}

	-- Lọc các target hợp lệ và cập nhật khoảng cách (Dùng Vector3 thuần từ RAM để tối ưu hiệu năng cực hạn)
	for _, t in ipairs(gifts) do
		if isGiftValid(t) then
			local pos = (t.rawObj and t.rawObj.Position) or t.part.Position
			t.distance = (hrp.Position - pos).Magnitude
			table.insert(validGifts, t)
		end
	end

	for _, t in ipairs(instruments) do
		if isInstrumentValid(t) then
			t.distance = (hrp.Position - t.part.Position).Magnitude
			table.insert(validInstruments, t)
		end
	end

	for _, t in ipairs(altars) do
		if isAltarValid(t) then
			local altarName = t.altarName or "Unknown"
			local filter = controller.AltarFilter
			local matchesFilter = false

			if typeof(filter) == "table" then
				if table.find(filter, "All") or table.find(filter, "Tất cả") or #filter == 0 then
					matchesFilter = true
				else
					matchesFilter = table.find(filter, altarName) ~= nil
				end
			else
				local filterStr = tostring(filter or "All")
				matchesFilter = (filterStr == "All" or filterStr == "Tất cả" or filterStr == altarName)
			end

			if matchesFilter then
				t.distance = (hrp.Position - t.part.Position).Magnitude
				table.insert(validAltars, t)
			end
		end
	end

	local currentTargets = {} -- Chứa các mục tiêu vẽ 2D Dot/Ping
	local highlightTargets = {} -- Chứa các mục tiêu vẽ Highlight

	-- Phân loại: Altars
	for _, t in ipairs(validAltars) do
		if controller.ESPStyle == "Highlight" then
			table.insert(highlightTargets, t)
		else
			local style = controller.ESPStyle == "Ping" and "Ping" or "Dot"
			currentTargets[t.part] = {
				Style = style,
				Color = t.color,
				ParentObject = t.part,
			}
		end
	end

	-- Phân loại: Nhạc cụ Cadence
	for _, t in ipairs(validInstruments) do
		if controller.ESPStyle == "Highlight" then
			table.insert(highlightTargets, t)
		else
			local style = controller.ESPStyle == "Ping" and "Ping" or "Dot"
			currentTargets[t.part] = {
				Style = style,
				Color = t.color,
				ParentObject = t.part,
			}
		end
	end

	-- Phân loại: Quà & Bẫy mìn. Raw gifts without a rendered instance still support arrows.
	for _, t in ipairs(validGifts) do
		local actualModel = (
			t.rawObj
			and t.rawObj.Model
			and typeof(t.rawObj.Model) == "Instance"
			and t.rawObj.Model.Parent
			and t.rawObj.Model:IsDescendantOf(workspace)
		)
				and t.rawObj.Model
			or nil
		local actualPart = t.part and t.part.Parent and t.part:IsDescendantOf(workspace) and t.part or nil
		if not actualPart and actualModel then
			if actualModel:IsA("BasePart") then
				actualPart = actualModel
			elseif actualModel:IsA("Model") then
				actualPart = actualModel.PrimaryPart or actualModel:FindFirstChildWhichIsA("BasePart")
			end
		end
		local highlightObject = actualModel or actualPart
		local isGolden = t.type == "GoldenGift"
			or (highlightObject and string.find(highlightObject.Name:lower(), "golden") ~= nil)

		if not highlightObject then
			continue
		elseif isGolden then
			-- Quà vàng/Mìn vàng luôn vẽ chấm Dot để không chiếm dụng Highlight pool (Giới hạn 1200 studs để tối ưu hiệu năng)
			if actualPart and t.distance <= 1200 then
				currentTargets[actualPart] = {
					Style = "Dot",
					Color = t.color,
					ParentObject = actualPart,
				}
			end
		else
			if controller.ESPStyle == "Highlight" then
				table.insert(highlightTargets, {
					distance = t.distance,
					part = actualPart or highlightObject,
					model = highlightObject,
					color = t.color,
				})
			else
				local style = controller.ESPStyle == "Ping" and "Ping" or "Dot"
				if actualPart and t.distance <= 1200 then
					currentTargets[actualPart] = {
						Style = style,
						Color = t.color,
						ParentObject = actualPart,
					}
				end
			end
		end
	end

	-- Phân bổ Highlight Pool cho tối đa 15 mục tiêu gần nhất sử dụng stable mapping để tránh lag giật FPS
	if not saved.Highlights then
		saved.Highlights = {}
	end
	local activeHighlights = saved.Highlights

	local desiredSet = {}
	local closestTargets = {}
	local numHighlights = math.min(#highlightTargets, 15)

	if #highlightTargets > 0 then
		table.sort(highlightTargets, function(a, b)
			return a.distance < b.distance
		end)

		for i = 1, numHighlights do
			local t = highlightTargets[i]
			local targetObject = t.model or t.part
			desiredSet[targetObject] = t
			table.insert(closestTargets, t)
		end

		-- Bất kỳ mục tiêu nào ngoài 15 mục tiêu gần nhất đều chuyển sang Dot
		for i = numHighlights + 1, #highlightTargets do
			local t = highlightTargets[i]
			currentTargets[t.part] = {
				Style = "Dot",
				Color = t.color,
				ParentObject = t.part,
			}
		end
	end

	-- 1. Giải phóng các Highlight của các mục tiêu không còn trong top 15 nữa
	for targetObject, hl in pairs(activeHighlights) do
		if not desiredSet[targetObject] then
			hl.Adornee = nil
			hl.Enabled = false
			activeHighlights[targetObject] = nil
		end
	end

	-- 2. Tìm danh sách các Highlight đang rảnh trong pool
	local usedSet = {}
	for _, usedHl in pairs(activeHighlights) do
		usedSet[usedHl] = true
	end

	local freeHighlights = {}
	local pool = saved.HighlightPool
	for _, hl in ipairs(pool) do
		if not usedSet[hl] then
			table.insert(freeHighlights, hl)
		end
	end

	-- 3. Phân bổ Highlight cho các mục tiêu mới hoặc cập nhật thuộc tính
	for _, t in ipairs(closestTargets) do
		local targetObject = t.model or t.part
		local hl = activeHighlights[targetObject]

		if hl then
			-- Giữ nguyên Adornee để game engine không phải tính toán lại hình học (tránh drop FPS)
			if hl.OutlineColor ~= t.color then
				hl.OutlineColor = t.color
			end
			if not hl.Enabled then
				hl.Enabled = true
			end
		else
			-- Phân bổ một cái rảnh từ pool
			if #freeHighlights > 0 then
				local newHl = table.remove(freeHighlights)
				newHl.Adornee = targetObject
				newHl.OutlineColor = t.color
				newHl.Enabled = true
				activeHighlights[targetObject] = newHl
			else
				-- Fallback sang Dot
				currentTargets[t.part] = {
					Style = "Dot",
					Color = t.color,
					ParentObject = t.part,
				}
			end
		end
	end

	local scanTime = os.clock()

	-- 1. Xóa các BillboardGui (Dot/Ping) không còn tồn tại
	for targetPart, cached in pairs(saved.ActiveTargets) do
		local current = currentTargets[targetPart]
		if not current or not targetPart:IsDescendantOf(workspace) then
			if cached.Dot then
				pcall(function()
					cached.Dot:Destroy()
				end)
			end
			saved.ActiveTargets[targetPart] = nil
		end
	end

	-- 2. Tạo hoặc cập nhật BillboardGui (Dot/Ping)
	for targetPart, current in pairs(currentTargets) do
		local cached = saved.ActiveTargets[targetPart]

		if not cached or cached.Style ~= current.Style then
			local oldDot = cached and cached.Dot

			local newCache = {
				Style = current.Style,
				Color = current.Color,
				LastSeen = scanTime,
				Dot = nil,
				Frame = nil,
			}
			saved.ActiveTargets[targetPart] = newCache
			if oldDot then
				pcall(function()
					oldDot:Destroy()
				end)
			end

			pcall(function()
				if current.Style == "Ping" then
					local billboard = Instance.new("BillboardGui")
					billboard.Name = "NULLSCAPE_ESP_Ping"
					billboard.Size = UDim2.fromOffset(16, 16)
					billboard.AlwaysOnTop = true

					local frame = Instance.new("Frame")
					frame.Name = "PingFrame"
					frame.Size = UDim2.fromOffset(10, 10)
					frame.AnchorPoint = Vector2.new(0.5, 0.5)
					frame.Position = UDim2.fromScale(0.5, 0.5)
					frame.Rotation = 45
					frame.BackgroundColor3 = current.Color
					frame.BorderSizePixel = 0

					frame.Parent = billboard
					billboard.Parent = current.ParentObject
					newCache.Dot = billboard
					newCache.Frame = frame
				else
					local billboard = Instance.new("BillboardGui")
					billboard.Name = "NULLSCAPE_ESP_Dot"
					billboard.Size = UDim2.fromOffset(1, 1)
					billboard.AlwaysOnTop = true

					local frame = Instance.new("Frame")
					frame.Size = UDim2.fromScale(1, 1)
					frame.BackgroundColor3 = current.Color
					frame.BorderSizePixel = 0

					local uiCorner = Instance.new("UICorner")
					uiCorner.CornerRadius = UDim.new(1, 0)
					uiCorner.Parent = frame

					frame.Parent = billboard
					billboard.Parent = current.ParentObject
					newCache.Dot = billboard
					newCache.Frame = frame
				end
			end)
		else
			cached.LastSeen = scanTime
			local frame = cached.Frame
			if frame and frame.Parent and frame.Parent.Parent then
				if frame.BackgroundColor3 ~= current.Color then
					frame.BackgroundColor3 = current.Color
				end
			else
				saved.ActiveTargets[targetPart] = nil
			end
		end
	end

	-- 3. Xóa các BillboardGui (Dot/Ping) bị bỏ quên
	for targetPart, cached in pairs(saved.ActiveTargets) do
		if cached.LastSeen ~= scanTime then
			if cached.Dot then
				pcall(function()
					cached.Dot:Destroy()
				end)
			end
			saved.ActiveTargets[targetPart] = nil
		end
	end

	-- Tìm các vị trí và khoảng cách gần nhất để render mũi tên trong RenderStepped (O(1))
	local nearestGiftPos = nil
	local nearestGiftColor = ESPColors.Gift
	local shortestGiftDist = math.huge
	if controller.GiftESPEnabled and #validGifts > 0 then
		for _, t in ipairs(validGifts) do
			-- Chỉ chỉ hướng tới quà thật (Gift, GoldenGift, PassageGift), tuyệt đối không chỉ vào mìn (Tripmine)
			if t.type and not string.find(t.type:lower(), "tripmine") then
				local dist = t.distance
				if dist < shortestGiftDist then
					shortestGiftDist = dist
					nearestGiftPos = (t.rawObj and t.rawObj.Position) or t.part.Position
					nearestGiftColor = t.color
				end
			end
		end
	end
	saved.NearestGiftPos = nearestGiftPos
	saved.NearestGiftDist = shortestGiftDist
	saved.NearestGiftColor = nearestGiftColor

	local nearestCadencePos = nil
	local shortestCadenceDist = math.huge
	local nearestCadenceColor = ESPColors.Cadence
	if controller.CadenceESPEnabled and #validInstruments > 0 then
		for _, t in ipairs(validInstruments) do
			local dist = t.distance
			if dist < shortestCadenceDist then
				shortestCadenceDist = dist
				nearestCadencePos = t.part.Position
				nearestCadenceColor = t.color
			end
		end
	end
	saved.NearestCadencePos = nearestCadencePos
	saved.NearestCadenceDist = shortestCadenceDist
	saved.NearestCadenceColor = nearestCadenceColor

	local nearestAltarPos = nil
	local shortestAltarDist = math.huge
	local nearestAltarColor = ESPColors.Altar.Unknown
	if controller.AltarESPEnabled and #validAltars > 0 then
		for _, t in ipairs(validAltars) do
			local dist = t.distance
			if dist < shortestAltarDist then
				shortestAltarDist = dist
				nearestAltarPos = t.part.Position
				nearestAltarColor = t.color
			end
		end
	end
	saved.NearestAltarPos = nearestAltarPos
	saved.NearestAltarDist = shortestAltarDist
	saved.NearestAltarColor = nearestAltarColor

	-- Đảm bảo các mũi tên tồn tại/hủy phù hợp dựa trên số lượng hợp lệ thực tế
	if controller.GiftESPEnabled and nearestGiftPos then
		getOrCreateArrow(saved, "ArrowGift", nearestGiftColor)
	else
		if saved.ArrowGift then
			pcall(function()
				saved.ArrowGift:Destroy()
			end)
			saved.ArrowGift = nil
		end
	end

	if controller.CadenceESPEnabled and nearestCadencePos then
		getOrCreateArrow(saved, "ArrowCadence", nearestCadenceColor)
	else
		if saved.ArrowCadence then
			pcall(function()
				saved.ArrowCadence:Destroy()
			end)
			saved.ArrowCadence = nil
		end
	end

	if controller.AltarESPEnabled and nearestAltarPos then
		getOrCreateArrow(saved, "ArrowAltar", nearestAltarColor)
	else
		if saved.ArrowAltar then
			pcall(function()
				saved.ArrowAltar:Destroy()
			end)
			saved.ArrowAltar = nil
		end
	end
end

local function isGameGiftArrowActive()
	local giftArrow = workspace:FindFirstChild("GiftArrow")
	if giftArrow and giftArrow:IsA("BasePart") then
		return giftArrow.CFrame.Position.Y < 1e10
	end
	return false
end

-- Cập nhật chuyển động thời gian thực của các mũi tên và Ping
function Logic.updateRender(controller, gc, hrp)
	local saved = gc.SavedVisuals
	if not hrp then
		for _, name in ipairs({ "ArrowGift", "ArrowCadence", "ArrowAltar" }) do
			local arrow = saved[name]
			if arrow then
				setArrowTransparency(arrow, 1)
			end
		end
		return
	end

	local nearestGiftPos = saved.NearestGiftPos
	local nearestGiftColor = saved.NearestGiftColor or ESPColors.Gift
	local nearestGiftDist = saved.NearestGiftDist or math.huge
	local nearestCadencePos = saved.NearestCadencePos
	local nearestCadenceColor = saved.NearestCadenceColor or ESPColors.Cadence
	local nearestCadenceDist = saved.NearestCadenceDist or math.huge
	local nearestAltarPos = saved.NearestAltarPos
	local nearestAltarColor = saved.NearestAltarColor or ESPColors.Altar.Unknown
	local nearestAltarDist = saved.NearestAltarDist or math.huge

	-- Xác định độ cao đầu (Head) của người chơi
	local char = hrp.Parent
	local head = char and char:FindFirstChild("Head")
	local arrowPos = head and head.Position or Vector3.new(hrp.Position.X, hrp.Position.Y + 1.5, hrp.Position.Z)

	-- 2. Cập nhật hiển thị và hướng xoay cho Mũi tên Hộp quà (Trắng / Vàng / Đỏ)
	local arrowGift = saved.ArrowGift
	if arrowGift and arrowGift.Parent then
		if nearestGiftPos and nearestGiftDist > 3.5 and not isGameGiftArrowActive() then
			setArrowTransparency(arrowGift, 0)
			setArrowColor(arrowGift, nearestGiftColor)

			local dir = nearestGiftPos - arrowPos
			local targetRot = CFrame.lookAt(Vector3.zero, dir)
			if saved.ArrowGiftRot then
				saved.ArrowGiftRot = saved.ArrowGiftRot:Lerp(targetRot, 0.15)
			else
				saved.ArrowGiftRot = targetRot
			end

			local offsetDist = 2 + math.min(1, nearestGiftDist / 9)
			local targetCF = saved.ArrowGiftRot * CFrame.new(0, 0, -offsetDist) + arrowPos
			setArrowCFrame(arrowGift, targetCF)
		else
			setArrowTransparency(arrowGift, 1)
			saved.ArrowGiftRot = nil
		end
	end

	-- 3. Cập nhật hiển thị và hướng xoay cho Mũi tên Nhạc cụ (Đỏ - Cadence)
	local arrowCadence = saved.ArrowCadence
	if arrowCadence and arrowCadence.Parent then
		if nearestCadencePos and nearestCadenceDist > 3.5 then
			setArrowTransparency(arrowCadence, 0)
			setArrowColor(arrowCadence, nearestCadenceColor)

			local dir = nearestCadencePos - arrowPos
			local targetRot = CFrame.lookAt(Vector3.zero, dir)
			if saved.ArrowCadenceRot then
				saved.ArrowCadenceRot = saved.ArrowCadenceRot:Lerp(targetRot, 0.15)
			else
				saved.ArrowCadenceRot = targetRot
			end

			local offsetDist = 2 + math.min(1, nearestCadenceDist / 9)
			local targetCF = saved.ArrowCadenceRot * CFrame.new(0, 0, -offsetDist) + arrowPos
			setArrowCFrame(arrowCadence, targetCF)
		else
			setArrowTransparency(arrowCadence, 1)
			saved.ArrowCadenceRot = nil
		end
	end

	-- 4. Cập nhật hiển thị và hướng xoay cho Mũi tên Đàn tế (Màu tương ứng của Altar)
	local arrowAltar = saved.ArrowAltar
	if arrowAltar and arrowAltar.Parent then
		if nearestAltarPos and nearestAltarDist > 3.5 then
			setArrowTransparency(arrowAltar, 0)
			setArrowColor(arrowAltar, nearestAltarColor)

			local dir = nearestAltarPos - arrowPos
			local targetRot = CFrame.lookAt(Vector3.zero, dir)
			if saved.ArrowAltarRot then
				saved.ArrowAltarRot = saved.ArrowAltarRot:Lerp(targetRot, 0.15)
			else
				saved.ArrowAltarRot = targetRot
			end

			local offsetDist = 2 + math.min(1, nearestAltarDist / 9)
			local targetCF = saved.ArrowAltarRot * CFrame.new(0, 0, -offsetDist) + arrowPos
			setArrowCFrame(arrowAltar, targetCF)
		else
			setArrowTransparency(arrowAltar, 1)
			saved.ArrowAltarRot = nil
		end
	end

	-- 5. Cập nhật kích thước và ẩn/hiện chế độ Ping
	if controller.ESPStyle == "Ping" and saved.ActiveTargets then
		for targetPart, cached in pairs(saved.ActiveTargets) do
			if cached.Style == "Ping" and cached.Dot then
				if targetPart and targetPart.Parent and targetPart:IsDescendantOf(workspace) then
					local dist = (hrp.Position - targetPart.Position).Magnitude
					local frame = cached.Frame
					if frame then
						cached.Dot.Enabled = true
						local size = math.clamp(dist / 20, 6, 10)
						frame.Size = UDim2.fromOffset(size, size)
						frame.BackgroundTransparency = 0
					end
				end
			end
		end
	end
end

Logic.isInstrument = isInstrument
Logic.getAltarTypeAndColor = getAltarTypeAndColor

return Logic
