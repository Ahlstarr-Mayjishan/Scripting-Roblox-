--!nocheck
-- [[
--  NULLSCAPE - Custom Radar & ESP Logic
--  Vai trò: Chứa toàn bộ lõi logic định vị quà, nhạc cụ Cadence và đàn tế (Altar), các thuật toán tính toán,
--  nhận diện khoảng cách và phân loại. Cung cấp API logic để Executor và Controller sử dụng.
-- ]]

local Logic = {}

local function canSimulate(controller, featureKey)
	return Logic.canSimulateFeature(controller, featureKey)
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

local RADAR_ARROW_COLORS = {
	Altar = Color3.fromRGB(255, 128, 0),
	Cadence = Color3.fromRGB(255, 0, 0),
}

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

local function setArrowColor(arrow, color, forceSolidColor)
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
		if forceSolidColor and arrow:IsA("MeshPart") and arrow.TextureID ~= "" then
			arrow.TextureID = ""
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
			if forceSolidColor and child:IsA("MeshPart") and child.TextureID ~= "" then
				child.TextureID = ""
			end
			local maxDim = math.max(child.Size.X, child.Size.Y, child.Size.Z)
			if maxDim > 4 then
				child.Size = child.Size * (2.5 / maxDim)
			end
		elseif child:IsA("SpecialMesh") then
			child.VertexColor = Vector3.new(color.R, color.G, color.B)
			if forceSolidColor and child.TextureId ~= "" then
				child.TextureId = ""
			end
			local maxScale = math.max(child.Scale.X, child.Scale.Y, child.Scale.Z)
			if maxScale > 4 then
				child.Scale = child.Scale * (2.5 / maxScale)
			end
		elseif forceSolidColor and (child:IsA("Decal") or child:IsA("Texture")) then
			child.Color3 = color
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
	setArrowColor(arrow, color, key == "ArrowCadence" or key == "ArrowAltar")
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

local function isEnemyValidForESP(enemy)
	if not enemy or not enemy.Parent then
		return false
	end

	local name = enemy.Name
	-- Các loại trừ theo logic gốc của game
	if name == "nilEnemy" or name == "nilMirage" or name == "Celestial" or name == "MothSpectator" or name == "CatalystHand" then
		return false
	end

	-- Phải có head
	local head = enemy:FindFirstChild("head") or enemy:FindFirstChild("Head") 
		or (enemy:IsA("BasePart") and enemy) 
		or enemy:FindFirstChildWhichIsA("BasePart")
	if not head then
		return false
	end

	return true
end

local function updateNativeEnemyESPState(controller)
	local shouldEnableNative = canSimulate(controller, "Enemy")

	if shouldEnableNative then
		-- 2. Thử tìm native ESP template để tự vẽ cho các enemy hiện tại
		local espTemplate = nil
		local playerScripts = game.Players.LocalPlayer:FindFirstChild("PlayerScripts")
		local spriteManager = playerScripts and playerScripts:FindFirstChild("spriteManager")
		if spriteManager then
			espTemplate = spriteManager:FindFirstChild("ESP") or spriteManager:FindFirstChild("ESPCrayon")
		end
		if not espTemplate then
			local starterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
			spriteManager = starterPlayerScripts and starterPlayerScripts:FindFirstChild("spriteManager")
			espTemplate = spriteManager and (spriteManager:FindFirstChild("ESP") or spriteManager:FindFirstChild("ESPCrayon"))
		end
		
		-- 3. Quét tất cả enemy hiện có
		local enemyFolder = workspace:FindFirstChild("Enemies")
		if enemyFolder then
			for _, enemy in ipairs(enemyFolder:GetChildren()) do
				if isEnemyValidForESP(enemy) then
					local head = enemy:FindFirstChild("head") or enemy:FindFirstChild("Head") 
						or (enemy:IsA("BasePart") and enemy) 
						or enemy:FindFirstChildWhichIsA("BasePart")
					
					if head then
						-- Tìm tất cả ESP / ESPCrayon con của enemy
						local espInstances = {}
						for _, child in ipairs(enemy:GetChildren()) do
							if child.Name == "ESP" or child.Name == "ESPCrayon" then
								table.insert(espInstances, child)
							end
						end
						
						-- Nếu chưa có ESP của native vẽ, tự clone đè lên
						if #espInstances == 0 and espTemplate then
							local clone = espTemplate:Clone()
							local isCrayon = false
							pcall(function()
								local ReplicatedFirst_ = game:GetService("ReplicatedFirst")
								local ClientModules = ReplicatedFirst_:FindFirstChild("ClientModules")
								local CurseHandlerModule = ClientModules and ClientModules:FindFirstChild("CurseHandler")
								if CurseHandlerModule then
									local CurseHandler = require(CurseHandlerModule)
									isCrayon = CurseHandler.IsCurseEnabled("CrayonEnemies")
								end
							end)
							clone.Name = isCrayon and "ESPCrayon" or "ESP"
							clone.Parent = enemy
							table.insert(espInstances, clone)
						end
						
						-- Nếu trùng lặp (nhiều hơn 1 cái), hủy cái thừa
						if #espInstances > 1 then
							for i = 2, #espInstances do
								pcall(function()
									espInstances[i]:Destroy()
								end)
							end
							espInstances = { espInstances[1] }
						end
						
						local existing = espInstances[1]
						if existing then
							-- Sửa lỗi Adornee của game gốc (gán Model cho BoxHandleAdornment bị lỗi)
							pcall(function()
								existing.Adornee = head
							end)
							pcall(function()
								existing.Visible = true
							end)
							pcall(function()
								existing.Enabled = true
							end)
							
							-- Ẩn chiếc hộp lập phương nhỏ màu xanh của game gốc
							pcall(function()
								existing.Transparency = 1
							end)
							
							-- Tự vẽ SelectionBox ôm sát toàn thân của kẻ địch
							local customBox = enemy:FindFirstChild("NULLSCAPE_CustomESPBox")
							if not customBox then
								customBox = Instance.new("SelectionBox")
								customBox.Name = "NULLSCAPE_CustomESPBox"
								customBox.Adornee = enemy
								customBox.Color3 = Color3.fromRGB(0, 255, 0) -- Xanh lá
								customBox.LineThickness = 0.04
								customBox.AlwaysOnTop = true
								customBox.Parent = enemy
							end
							
							-- Căn chỉnh lại nhãn tên gốc hiển thị ở góc dưới cùng bên phải của SelectionBox
							pcall(function()
								local labelGui = existing:FindFirstChild("Label") or existing
								if labelGui and labelGui:IsA("BillboardGui") then
									local sizeY = 4.0
									if enemy:IsA("Model") then
										local _, size = enemy:GetBoundingBox()
										sizeY = size.Y
									else
										sizeY = enemy.Size.Y
									end
									
									labelGui.Adornee = head
									labelGui.StudsOffset = Vector3.new(0, -(sizeY / 2) - 0.2, 0)
									
									local textLabel = labelGui:FindFirstChildWhichIsA("TextLabel") or labelGui:FindFirstChild("Label")
									if textLabel then
										textLabel.TextXAlignment = Enum.TextXAlignment.Right
										textLabel.TextYAlignment = Enum.TextYAlignment.Bottom
										textLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
									end
								end
							end)
							
							-- Dọn dẹp fallback
							local fallback = enemy:FindFirstChild("NULLSCAPE_CustomESPBoxFallback")
							if fallback then
								pcall(function() fallback:Destroy() end)
							end
						else
							-- Fallback hoàn toàn nếu không tìm thấy template
							local folder = enemy:FindFirstChild("NULLSCAPE_CustomESPBoxFallback")
							if not folder then
								folder = Instance.new("Folder")
								folder.Name = "NULLSCAPE_CustomESPBoxFallback"
								
								local box = Instance.new("SelectionBox")
								box.Name = "Box"
								box.Adornee = enemy
								box.Color3 = Color3.fromRGB(0, 255, 0)
								box.LineThickness = 0.04
								box.AlwaysOnTop = true
								box.Parent = folder
								
								local sizeY = 4.0
								if enemy:IsA("Model") then
									local _, size = enemy:GetBoundingBox()
									sizeY = size.Y
								else
									sizeY = enemy.Size.Y
								end
								
								local billboard = Instance.new("BillboardGui")
								billboard.Name = "LabelGui"
								billboard.Adornee = head
								billboard.Size = UDim2.fromScale(6, 2)
								billboard.AlwaysOnTop = true
								billboard.StudsOffset = Vector3.new(0, -(sizeY / 2) - 0.2, 0)
								
								local label = Instance.new("TextLabel")
								label.Name = "Label"
								label.Size = UDim2.fromScale(1, 1)
								label.BackgroundTransparency = 1
								label.TextColor3 = Color3.fromRGB(0, 255, 0)
								label.TextSize = 12
								label.Font = Enum.Font.RobotoMono
								label.TextXAlignment = Enum.TextXAlignment.Right
								label.TextYAlignment = Enum.TextYAlignment.Bottom
								
								local nameLower = enemy.Name:lower()
								local dispName = nameLower
								if nameLower == "shadowguardian" then
									dispName = "voidboundguardian"
								elseif nameLower == "shadowbaby" then
									dispName = "voidboundbaby"
								elseif nameLower == "skinwalker" then
									dispName = "husk"
								elseif nameLower == "mirage" then
									dispName = "???"
								end
								label.Text = dispName
								label.TextStrokeTransparency = 0.5
								label.TextStrokeColor3 = Color3.new(0, 0, 0)
								label.Parent = billboard
								
								billboard.Parent = folder
								folder.Parent = enemy
							end
						end
					end
				else
					-- Dọn dẹp ESP trên enemy không hợp lệ
					for _, name in ipairs({"ESP", "ESPCrayon", "NULLSCAPE_CustomESPBox", "NULLSCAPE_CustomESPBoxFallback"}) do
						local child = enemy:FindFirstChild(name)
						if child then
							pcall(function()
								child:Destroy()
							end)
						end
					end
				end
			end
		end
	else
		-- Dọn dẹp các visual đã vẽ (icon HUD do syncSimulatedUpgradeHud quản lý)
		local enemyFolder = workspace:FindFirstChild("Enemies")
		if enemyFolder then
			for _, enemy in ipairs(enemyFolder:GetChildren()) do
				for _, name in ipairs({"ESP", "ESPCrayon", "NULLSCAPE_CustomESPBox", "NULLSCAPE_CustomESPBoxFallback"}) do
					local child = enemy:FindFirstChild(name)
					if child then
						pcall(function()
							child:Destroy()
						end)
					end
				end
			end
		end
	end
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
	-- Dọn dẹp native enemy ESP
	pcall(updateNativeEnemyESPState, { EnemyESPEnabled = false, ESPStyle = "None" })

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

local function isVisibleNativePart(instance)
	if instance:IsA("BasePart") then
		return not string.find(instance.Name, "NULLSCAPE_") and instance.Transparency < 0.99
	elseif instance:IsA("Model") then
		if string.find(instance.Name, "NULLSCAPE_") then
			return false
		end
		for _, child in ipairs(instance:GetDescendants()) do
			if child:IsA("BasePart") and child.Transparency < 0.99 then
				return true
			end
		end
	end
	return false
end

local function isNativeGiftRadarActive()
	local giftArrow = workspace:FindFirstChild("GiftArrow")
	if giftArrow and giftArrow:IsA("BasePart") then
		return giftArrow.CFrame.Position.Y < 1e10
	end
	return false
end

local function isNativeCadenceRadarActive()
	local arrowsFolder = workspace:FindFirstChild("Arrows")
	local cadenceArrow = arrowsFolder and arrowsFolder:FindFirstChild("CadenceArrow")
	if cadenceArrow and cadenceArrow:IsA("BasePart") then
		return cadenceArrow.CFrame.Position.Y < 500000 and cadenceArrow.Transparency < 0.99
	end
	return false
end

local function isNativeAltarRadarActive()
	local arrowsFolder = workspace:FindFirstChild("Arrows")
	if not arrowsFolder then
		return false
	end

	for _, child in ipairs(arrowsFolder:GetChildren()) do
		if
			child.Name ~= "CadenceArrow"
			and child.Name ~= "Template"
			and not string.find(child.Name, "NULLSCAPE_")
			and isVisibleNativePart(child)
		then
			return true
		end
	end

	return false
end

local function isNativeGiftHighlightEnabled()
	local origFn = getgenv()._NULLSCAPE_Globals
		and getgenv()._NULLSCAPE_Globals.OriginalIsUpgradeEnabled
	if not origFn then
		return false
	end
	local ok, result = pcall(origFn, "HighlightGifts")
	return ok and result == true
end

local function isNativeTripmineHighlightEnabled()
	local origFn = getgenv()._NULLSCAPE_Globals
		and getgenv()._NULLSCAPE_Globals.OriginalIsUpgradeEnabled
	if not origFn then
		return false
	end
	local ok, result = pcall(origFn, "HighlightTripmines")
	return ok and result == true
end

local function shouldUseNativeRadar(controller, kind)
	if controller and controller.UseNativeRadarWhenAvailable == false then
		return false
	end
	-- Hook đã bật module game gốc khi toggle ON — NULLSCAPE không vẽ trùng ESP/pulse.
	return Logic.isSimulationToggleOn(controller, kind)
end

-- Vòng lặp cập nhật khoảng cách, sắp xếp độ ưu tiên và chuyển đổi visual styles (chạy cực nhanh)
function Logic.updateESPStyles(controller, gc, hrp)
	Logic.syncSimulatedUpgradeHud(controller)

	-- Cập nhật trạng thái native enemy ESP
	pcall(updateNativeEnemyESPState, controller)

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

	local nativeGiftRadar = shouldUseNativeRadar(controller, "Gift")
	local nativeTripmineRadar = shouldUseNativeRadar(controller, "Tripmine")
	local nativeCadenceRadar = shouldUseNativeRadar(controller, "Cadence")
	local nativeAltarRadar = shouldUseNativeRadar(controller, "Altar")

	local instruments = canSimulate(controller, "Cadence") and not nativeCadenceRadar and (controller.ActiveInstruments or {}) or {}
	local altars = canSimulate(controller, "Altar") and not nativeAltarRadar and (controller.ActiveAltars or {}) or {}

	local validGifts = {}
	local validInstruments = {}
	local validAltars = {}
	local validPlayers = {}

	-- Lọc các target hợp lệ và cập nhật khoảng cách (Dùng Vector3 thuần từ RAM để tối ưu hiệu năng cực hạn)
	local rawGifts = controller.ActiveGifts or {}
	for _, t in ipairs(rawGifts) do
		if isGiftValid(t) then
			local isTripmine = t.type == "Tripmine" or t.type == "GoldenTripmine" or t.type == "GoldenTripmines"
			local shouldShow = false
			if isTripmine then
				shouldShow = canSimulate(controller, "Tripmine") and not nativeTripmineRadar
			else
				shouldShow = canSimulate(controller, "Gift") and not nativeGiftRadar
			end

			if shouldShow then
				local pos = (t.rawObj and t.rawObj.Position) or t.part.Position
				t.distance = (hrp.Position - pos).Magnitude
				table.insert(validGifts, t)
			end
		end
	end

	-- Lấy danh sách người chơi khác để vẽ ESP liên tục thời gian thực (chỉ chạy khi style không phải là Ping)
	if canSimulate(controller, "Player") and controller.ESPStyle ~= "Ping" then
		local Players_ = game:GetService("Players")
		local LocalPlayer_ = Players_.LocalPlayer
		for _, player in ipairs(Players_:GetPlayers()) do
			if player ~= LocalPlayer_ then
				local character = player.Character
				local charHRP = character and character:FindFirstChild("HumanoidRootPart")
				if charHRP and character.Parent then
					local dist = (hrp.Position - charHRP.Position).Magnitude
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					local isDead = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Dead or false
					table.insert(validPlayers, {
						part = charHRP,
						model = character,
						color = isDead and Color3.new(1, 0, 0) or (controller.PlayerESPColor or Color3.fromRGB(255, 255, 255)),
						distance = dist,
						isDead = isDead,
					})
				end
			end
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
		elseif controller.ESPStyle == "Dot" then
			currentTargets[t.part] = {
				Style = "Dot",
				Color = t.color,
				ParentObject = t.part,
			}
		end
	end

	-- Phân loại: Nhạc cụ Cadence
	for _, t in ipairs(validInstruments) do
		if controller.ESPStyle == "Highlight" then
			table.insert(highlightTargets, t)
		elseif controller.ESPStyle == "Dot" then
			currentTargets[t.part] = {
				Style = "Dot",
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
			if controller.ESPStyle == "Highlight" or controller.ESPStyle == "Ping" then
				table.insert(highlightTargets, {
					distance = t.distance,
					part = actualPart or highlightObject,
					model = highlightObject,
					color = t.color,
				})
			else
				if actualPart and t.distance <= 1200 then
					currentTargets[actualPart] = {
						Style = "Dot",
						Color = t.color,
						ParentObject = actualPart,
					}
				end
			end
		end
	end

	-- Phân loại: Người chơi khác (Chỉ vẽ liên tục khi style không phải là Ping)
	for _, t in ipairs(validPlayers) do
		if controller.ESPStyle == "Highlight" then
			table.insert(highlightTargets, t)
		elseif controller.ESPStyle == "Dot" then
			currentTargets[t.part] = {
				Style = "Dot",
				Color = t.color,
				ParentObject = t.part,
			}
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
					-- Ping bắt đầu nhỏ, sẽ được tween mỗi render frame theo khoảng cách
					billboard.Size = UDim2.fromOffset(10, 10)
					billboard.AlwaysOnTop = true
					-- Nổi lên trên đỉnh object ~2.5 studs (giống BillboardGui của game gốc)
					billboard.StudsOffset = Vector3.new(0, 2.5, 0)

					-- Diamond (hình thoi xoay 45 độ) - giống ping marker của game gốc
					local frame = Instance.new("Frame")
					frame.Name = "PingFrame"
					frame.Size = UDim2.fromScale(1, 1)
					frame.AnchorPoint = Vector2.new(0.5, 0.5)
					frame.Position = UDim2.fromScale(0.5, 0.5)
					frame.Rotation = 45
					frame.BackgroundColor3 = current.Color
					frame.BackgroundTransparency = 0
					frame.BorderSizePixel = 0

					frame.Parent = billboard
					billboard.Parent = current.ParentObject
					newCache.Dot = billboard
					newCache.Frame = frame

				else
					local billboard = Instance.new("BillboardGui")
					billboard.Name = "NULLSCAPE_ESP_Dot"
					-- Chấm nhỏ 2x2 ở giữa trung tâm hộp quà/thực thể
					billboard.Size = UDim2.fromOffset(2, 2)
					billboard.AlwaysOnTop = true
					billboard.StudsOffset = Vector3.new(0, 0, 0)

					local frame = Instance.new("Frame")
					frame.Size = UDim2.fromScale(1, 1)
					frame.BackgroundColor3 = current.Color
					frame.BorderSizePixel = 0

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
	if canSimulate(controller, "Gift") and #validGifts > 0 then
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
	if canSimulate(controller, "Cadence") and #validInstruments > 0 then
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
	if canSimulate(controller, "Altar") and #validAltars > 0 then
		for _, t in ipairs(validAltars) do
			local dist = t.distance
			if dist < shortestAltarDist then
				shortestAltarDist = dist
				nearestAltarPos = t.part.Position
				nearestAltarColor = RADAR_ARROW_COLORS.Altar
			end
		end
	end
	saved.NearestAltarPos = nearestAltarPos
	saved.NearestAltarDist = shortestAltarDist
	saved.NearestAltarColor = nearestAltarColor

	-- Đảm bảo các mũi tên tồn tại/hủy phù hợp dựa trên số lượng hợp lệ thực tế
	if canSimulate(controller, "Gift") and nearestGiftPos then
		getOrCreateArrow(saved, "ArrowGift", nearestGiftColor)
	else
		if saved.ArrowGift then
			pcall(function()
				saved.ArrowGift:Destroy()
			end)
			saved.ArrowGift = nil
		end
	end

	if canSimulate(controller, "Cadence") and nearestCadencePos then
		getOrCreateArrow(saved, "ArrowCadence", RADAR_ARROW_COLORS.Cadence)
	else
		if saved.ArrowCadence then
			pcall(function()
				saved.ArrowCadence:Destroy()
			end)
			saved.ArrowCadence = nil
		end
	end

	if canSimulate(controller, "Altar") and nearestAltarPos then
		getOrCreateArrow(saved, "ArrowAltar", RADAR_ARROW_COLORS.Altar)
	else
		if saved.ArrowAltar then
			pcall(function()
				saved.ArrowAltar:Destroy()
			end)
			saved.ArrowAltar = nil
		end
	end
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
	local nearestCadenceColor = RADAR_ARROW_COLORS.Cadence
	local nearestCadenceDist = saved.NearestCadenceDist or math.huge
	local nearestAltarPos = saved.NearestAltarPos
	local nearestAltarColor = RADAR_ARROW_COLORS.Altar
	local nearestAltarDist = saved.NearestAltarDist or math.huge
	local nativeGiftRadar = shouldUseNativeRadar(controller, "Gift")
	local nativeCadenceRadar = shouldUseNativeRadar(controller, "Cadence")
	local nativeAltarRadar = shouldUseNativeRadar(controller, "Altar")

	-- Xác định độ cao đầu (Head) của người chơi
	local char = hrp.Parent
	local head = char and char:FindFirstChild("Head")
	local arrowPos = head and head.Position or Vector3.new(hrp.Position.X, hrp.Position.Y + 1.5, hrp.Position.Z)

	-- 2. Cập nhật hiển thị và hướng xoay cho Mũi tên Hộp quà (Trắng / Vàng / Đỏ)
	local arrowGift = saved.ArrowGift
	if arrowGift and arrowGift.Parent then
		if nearestGiftPos and nearestGiftDist > 3.5 and not nativeGiftRadar then
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
		if nearestCadencePos and nearestCadenceDist > 3.5 and not nativeCadenceRadar then
			setArrowTransparency(arrowCadence, 0)
			setArrowColor(arrowCadence, nearestCadenceColor, true)

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
		if nearestAltarPos and nearestAltarDist > 3.5 and not nativeAltarRadar then
			setArrowTransparency(arrowAltar, 0)
			setArrowColor(arrowAltar, nearestAltarColor, true)

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

	-- 5. Cập nhật kích thước và ẩn/hiện chế độ Ping theo khoảng cách (scale động)
	if controller.ESPStyle == "Ping" and saved.ActiveTargets then
		for targetPart, cached in pairs(saved.ActiveTargets) do
			if cached.Style == "Ping" and cached.Dot then
				if targetPart and targetPart.Parent and targetPart:IsDescendantOf(workspace) then
					local dist = (hrp.Position - targetPart.Position).Magnitude
					local frame = cached.Frame
					if frame then
						cached.Dot.Enabled = true
						-- Scale BillboardGui theo khoảng cách: xa hơn → to hơn để dễ thấy trên màn hình
						-- Gần (< 20 studs) = 8px, xa (200+ studs) = 20px
						local size = math.clamp(6 + dist / 25, 8, 22)
						cached.Dot.Size = UDim2.fromOffset(size, size)
						frame.BackgroundTransparency = 0
					end
				end
			end
		end
	end
end

Logic.isInstrument = isInstrument
Logic.getAltarTypeAndColor = getAltarTypeAndColor

-- =============================================================================
-- PLAYER & ENEMY ESP — Phỏng theo cơ chế RadarPlayer (RadarSlop f2) của game gốc:
--   task.delay(dist / 1024)
--   → Instance.new("Highlight") với FillTransparency=1
--   → TweenService Highlight OutlineTransparency → 1 trong 8s (Linear)
--   → Debris:AddItem(hl, 8.1)
-- Tự động "thả ra" khi UpgradeHandler.IsUpgradeEnabled("RadarPlayer") = true thật.
-- =============================================================================

-- Tạo highlight tạm thời cho 1 character (giống hệt RadarSlop f2 của game gốc)
local function spawnCharacterHighlight(character, outlineColor)
	if not character or not character.Parent then
		return
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	-- Nếu character đang Dead thì game gốc đổi màu sang đỏ
	local finalColor = outlineColor
	if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Dead then
		finalColor = Color3.new(1, 0, 0)
	end

	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1            -- Outline only — giống game gốc
	hl.OutlineColor = finalColor
	hl.OutlineTransparency = 0
	-- KHÔNG set DepthMode → default Occluded (rẻ hơn AlwaysOnTop, giống game gốc)
	hl.Parent = character

	local TweenService_ = game:GetService("TweenService")
	local Debris_ = game:GetService("Debris")

	-- Tween fade-out 8s rồi Debris dọn sạch (giống hệt game gốc)
	TweenService_:Create(hl, TweenInfo.new(8, Enum.EasingStyle.Linear), {
		OutlineTransparency = 1,
	}):Play()
	Debris_:AddItem(hl, 8.1)
end

-- API: Pulse ESP cho tất cả player khác trong phạm vi 1024 studs
-- hrp: HumanoidRootPart của local player
-- color: Color3 màu outline (mặc định trắng)
-- Trả về true nếu đã pulse ít nhất một player
function Logic.pulsePlayerESP(hrp, color)
	if not hrp then
		return false
	end

	local outlineColor = color or Color3.fromRGB(255, 255, 255)
	local Players_ = game:GetService("Players")
	local LocalPlayer_ = Players_.LocalPlayer

	for _, player in ipairs(Players_:GetPlayers()) do
		if player == LocalPlayer_ then
			continue
		end

		local character = player.Character
		if not character or not character.Parent then
			continue
		end

		local charHRP = character:FindFirstChild("HumanoidRootPart")
		if not charHRP then
			continue
		end

		local dist = (charHRP.Position - hrp.Position).Magnitude

		-- Giới hạn 1024 studs, delay tỉ lệ khoảng cách (giống game gốc)
		if dist <= 1024 then
			local delayTime = dist / 1024
			task.delay(delayTime, function()
				spawnCharacterHighlight(character, outlineColor)
				pcall(function()
					local sfx = game:GetService("SoundService"):FindFirstChild("SFXFolder")
					local sound = sfx and sfx:FindFirstChild("Radar_Player")
					if sound then
						local rand = Random.new()
						sound.PlaybackSpeed = rand:NextNumber(0.9, 1.1)
						sound:Play()
					end
				end)
			end)
		end
	end

	return true
end

-- API: Pulse ESP cho tất cả enemy trong workspace.Enemies
-- hrp: HumanoidRootPart của local player
-- color: Color3 màu outline (mặc định cam)
function Logic.pulseEnemyESP(hrp, color)
	if not hrp then
		return false
	end

	local outlineColor = color or Color3.fromRGB(255, 128, 0)
	local enemyFolder = workspace:FindFirstChild("Enemies")
	if not enemyFolder then
		return false
	end

	for _, enemyModel in ipairs(enemyFolder:GetChildren()) do
		if isEnemyValidForESP(enemyModel) then
			-- Hỗ trợ cực kỳ mạnh mẽ cả Model và BasePart lẻ làm kẻ địch
			local enemyHRP = enemyModel:IsA("BasePart") and enemyModel
				or enemyModel:FindFirstChild("HumanoidRootPart")
				or enemyModel.PrimaryPart
				or enemyModel:FindFirstChildWhichIsA("BasePart")
			if not enemyHRP then
				continue
			end

			local dist = (enemyHRP.Position - hrp.Position).Magnitude

			if dist <= 1024 then
				local delayTime = dist / 1024
				task.delay(delayTime, function()
					spawnCharacterHighlight(enemyModel, outlineColor)
					pcall(function()
						local sfx = game:GetService("SoundService"):FindFirstChild("SFXFolder")
						local sound = sfx and sfx:FindFirstChild("Radar_Player")
						if sound then
							local rand = Random.new()
							sound.PlaybackSpeed = rand:NextNumber(0.9, 1.1)
							sound:Play()
						end
					end)
				end)
			end
		end
	end

	return true
end

-- =============================================================================
-- RADAR PULSE SYSTEM — Phỏng theo cơ chế RadarSlop của game gốc
-- Cơ chế gốc:
--   task.delay(distance / 2048, function()
--     Clone AltarPing/CadencePing BillboardGui → Tween pulse size 12x12 → Fade 10s
--   end)
-- Chạy mỗi 12 giây từ Controller khi upgrade tương ứng được bật.
-- =============================================================================

-- Tạo một "sóng ping" tạm thời trên 1 object cụ thể
-- Khớp chính xác cấu trúc 3 lớp của AltarPing/CadencePing trong game gốc:
--   v13.Tweened  → pulse ra UDim2.fromScale(12,12) trong 1s → fade ra
--   v13.ImageLabel → shrink + fade trong 10s (linear)
--   v13.Outline   → shrink + fade trong 10s (linear)
--   Debris:AddItem(v13, 10.1)
-- pingType: "Altar" | "Cadence" | "Gift", pingColor: Color3
local function getOriginalTemplate(name)
	local localPlayer = game:GetService("Players").LocalPlayer
	local searchRoots = {
		localPlayer:FindFirstChild("PlayerGui"),
		localPlayer:FindFirstChild("PlayerScripts"),
	}
	if localPlayer.Character then
		table.insert(searchRoots, localPlayer.Character)
	end
	
	for _, root in ipairs(searchRoots) do
		if root then
			for _, desc in ipairs(root:GetDescendants()) do
				if desc.Name == "Radar" and (desc:IsA("LocalScript") or desc:IsA("ModuleScript")) then
					local t = desc:FindFirstChild(name)
					if t and (t:IsA("BillboardGui") or t:IsA("ScreenGui")) then
						return t
					end
				end
			end
		end
	end

	for _, root in ipairs(searchRoots) do
		if root then
			for _, desc in ipairs(root:GetDescendants()) do
				if desc.Name == name and (desc:IsA("BillboardGui") or desc:IsA("ScreenGui")) then
					return desc
				end
			end
		end
	end

	return nil
end

-- pingType: "Altar" | "Cadence" | "Gift", pingColor: Color3
local function createPingEffect(part, pingColor, pingType)
	if not part or not part.Parent then
		return
	end

	-- Game gốc chỉ có hiệu ứng radar ping cho Altar và Cadence
	if pingType ~= "Altar" and pingType ~= "Cadence" then
		return
	end

	local templateName = pingType .. "Ping"
	local originalTemplate = getOriginalTemplate(templateName)

	if originalTemplate then
		local billboard = originalTemplate:Clone()
		billboard.Name = "NULLSCAPE_RadarPing"
		billboard.Parent = part
		billboard.Enabled = true

		local TweenService_ = game:GetService("TweenService")
		local Debris_ = game:GetService("Debris")

		local tweened = billboard:FindFirstChild("Tweened")
		local imageLabel = billboard:FindFirstChild("ImageLabel")
		local outline = billboard:FindFirstChild("Outline")

		-- Đồng bộ các hiệu ứng Tween chính xác như game gốc
		if tweened and tweened:IsA("ImageLabel") then
			tweened.ImageColor3 = pingColor
			TweenService_:Create(
				tweened,
				TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(12, 12), ImageTransparency = 1 }
			):Play()
		end

		if imageLabel and imageLabel:IsA("ImageLabel") then
			imageLabel.ImageColor3 = pingColor
			TweenService_:Create(
				imageLabel,
				TweenInfo.new(10, Enum.EasingStyle.Linear),
				{ ImageTransparency = 1, Size = UDim2.fromScale(0, 0) }
			):Play()
		end

		if outline and outline:IsA("ImageLabel") then
			outline.ImageColor3 = pingColor
			TweenService_:Create(
				outline,
				TweenInfo.new(10, Enum.EasingStyle.Linear),
				{ ImageTransparency = 1, Size = UDim2.fromScale(0, 0) }
			):Play()
		end

		Debris_:AddItem(billboard, 10.1)

		pcall(function()
			local sfx = game:GetService("SoundService"):FindFirstChild("SFXFolder")
			if pingType == "Altar" then
				local sound = sfx and sfx:FindFirstChild("Radar_Altar")
				if sound then
					local rand = Random.new()
					sound.PlaybackSpeed = rand:NextNumber(0.97, 1.03)
					sound:Play()
				end
			elseif pingType == "Cadence" then
				local sound = sfx and sfx:FindFirstChild("Radar_Instruments")
				if sound then
					local rand = Random.new()
					sound.PlaybackSpeed = rand:NextNumber(1.95, 2.05)
					sound:Play()
				end
			end
		end)
	end
end

-- API công khai: gọi từ Controller mỗi 12 giây để trigger pulse radar
-- targets: danh sách { part: BasePart, color: Color3 } (gifts, altars, instruments)
-- hrp: HumanoidRootPart của local player
function Logic.triggerPulseRadar(targets, hrp)
	if not hrp then
		return
	end

	for _, target in ipairs(targets) do
		local part = target.part
		if not part or not part.Parent then
			continue
		end

		local dist = (part.Position - hrp.Position).Magnitude

		-- Giới hạn 1024 studs như game gốc, delay tỉ lệ với khoảng cách
		if dist <= 1024 then
			local delayTime = dist / 2048 -- game gốc dùng dist/2048 cho Altar/Cadence
			local pingColor = target.color or Color3.fromRGB(255, 255, 255)
			local pingType = target.pingType or "Gift"

			task.delay(delayTime, function()
				-- Re-check sau delay (object có thể đã bị destroy)
				if part and part.Parent then
					createPingEffect(part, pingColor, pingType)
				end
			end)
		end
	end
end

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
		indexUpgrade = "HighlightGifts",
		nativeUpgrade = "HighlightGifts",
	},
	Tripmine = {
		toggle = "TripmineESPEnabled",
		indexUpgrade = "HighlightTripmines",
		nativeUpgrade = "HighlightTripmines",
	},
	Cadence = {
		toggle = "CadenceESPEnabled",
		indexUpgrade = "RadarInstruments",
		nativeUpgrade = "RadarInstruments",
	},
	Altar = {
		toggle = "AltarESPEnabled",
		indexUpgrade = "RadarAltars",
		nativeUpgrade = "RadarAltars",
	},
	Player = {
		toggle = "PlayerESPEnabled",
		indexUpgrade = "RadarPlayer",
		nativeUpgrade = "RadarPlayer",
	},
	Enemy = {
		toggle = "EnemyESPEnabled",
		indexUpgrade = "EnemyOnTop",
		nativeUpgrade = "EnemyOnTop",
	},
}

local UPGRADE_TO_FEATURE = {}
for featureKey, cfg in pairs(Logic.FEATURES) do
	UPGRADE_TO_FEATURE[cfg.nativeUpgrade] = featureKey
	if cfg.indexUpgrade ~= cfg.nativeUpgrade then
		UPGRADE_TO_FEATURE[cfg.indexUpgrade] = featureKey
	end
end

local SIM_ATTR = "NULLSCAPE_Simulated"
local hudWatcherBound = false

local bestiaryHandler = nil

local function resolveBestiaryHandler()
	if bestiaryHandler ~= nil then
		return bestiaryHandler
	end

	local ReplicatedFirst = game:GetService("ReplicatedFirst")
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local playerData = clientModules
		and clientModules:FindFirstChild("Core")
		and clientModules.Core:FindFirstChild("PlayerData")
	local moduleScript = playerData and playerData:FindFirstChild("BestiaryHandler")
	if not moduleScript then
		return nil
	end

	local ok, handler = pcall(require, moduleScript)
	if ok and typeof(handler) == "table" then
		bestiaryHandler = handler
		return handler
	end

	return nil
end

function Logic.getFeatureConfig(featureKey)
	return Logic.FEATURES[featureKey]
end

function Logic.getFeatureForUpgrade(upgradeName)
	return UPGRADE_TO_FEATURE[upgradeName]
end

function Logic.isIndexUpgradeOwned(upgradeName)
	local handler = resolveBestiaryHandler()
	if not handler or typeof(handler.IsDiscovered) ~= "function" then
		return nil
	end

	local ok, discovered = pcall(handler.IsDiscovered, "Upgrades", upgradeName)
	if ok and discovered == true then
		return true
	end

	return false
end

function Logic.isNativeUpgradeActive(upgradeName)
	local origFn = getgenv()._NULLSCAPE_Globals
		and getgenv()._NULLSCAPE_Globals.OriginalIsUpgradeEnabled
	if origFn then
		local ok, result = pcall(origFn, upgradeName)
		if ok and result == true then
			return true
		end
	end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local upgradeFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder")
	local upgrades = upgradeFolder and upgradeFolder:FindFirstChild("Upgrades")
	local valueObj = upgrades and upgrades:FindFirstChild(upgradeName)
	if valueObj and valueObj:IsA("IntValue") and valueObj.Value > 0 then
		-- Bỏ qua IntValue do NULLSCAPE inject — tránh vòng lặp tự hủy/tạo lại icon HUD
		if valueObj:GetAttribute(SIM_ATTR) then
			return false
		end
		return true
	end

	return false
end

local function getUpgradesFolder()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local upgradeFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder")
	return upgradeFolder and upgradeFolder:FindFirstChild("Upgrades")
end

local function collectDesiredSimulatedUpgrades(controller)
	local desired = {}
	if not controller then
		return desired
	end

	for featureKey, cfg in pairs(Logic.FEATURES) do
		if Logic.isSimulationToggleOn(controller, featureKey) then
			desired[cfg.nativeUpgrade] = true
		end
	end

	if controller.RadarEnabled then
		desired.RadarPlayer = true
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
	if hudWatcherBound then
		return
	end

	local upgrades = getUpgradesFolder()
	if not upgrades then
		task.defer(function()
			bindSimulatedUpgradeHudWatcher(controller)
		end)
		return
	end

	hudWatcherBound = true
	upgrades.ChildRemoved:Connect(function(child)
		if child:GetAttribute(SIM_ATTR) then
			task.defer(function()
				if controller and not controller.Destroyed then
					Logic.syncSimulatedUpgradeHud(controller)
				end
			end)
		end
	end)
end

function Logic.isSimulationToggleOn(controller, featureKey)
	local cfg = Logic.FEATURES[featureKey]
	if not cfg or not controller then
		return false
	end
	return controller[cfg.toggle] == true
end

function Logic.shouldYieldToNative(_controller, _featureKey)
	return false
end

function Logic.canSimulateFeature(controller, featureKey)
	return Logic.isSimulationToggleOn(controller, featureKey)
end

function Logic.canEnableSimulation(_controller, featureKey)
	if not Logic.FEATURES[featureKey] then
		return false, "unknown_feature"
	end
	return true
end

local function wantsRadarPlayerSimulation(controller)
	if Logic.isSimulationToggleOn(controller, "Player") then
		return true
	end
	return controller.RadarEnabled == true
end

function Logic.shouldSpoofUpgradeEnabled(controller, upgradeName)
	if not controller then
		return false
	end

	local featureKey = UPGRADE_TO_FEATURE[upgradeName]
	if featureKey then
		if Logic.isSimulationToggleOn(controller, featureKey) then
			return true, true
		end
		return false
	end

	if upgradeName == "RadarPlayer" and wantsRadarPlayerSimulation(controller) then
		return true, true
	end

	return false
end

function Logic.shouldSpoofUpgradeStack(controller, upgradeName)
	local shouldSpoof, _ = Logic.shouldSpoofUpgradeEnabled(controller, upgradeName)
	if shouldSpoof then
		return true, 1
	end
	return false
end

function Logic.syncNativeRelease(_controller)
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

		local upgrades = getUpgradesFolder()
		if upgrades then
			upgrades.ChildAdded:Connect(function(child)
				if child:GetAttribute(SIM_ATTR) then
					return
				end
				task.defer(function()
					Logic.syncSimulatedUpgradeHud(controller)
				end)
			end)
		end

		local handler = resolveBestiaryHandler()
		if handler and handler.OnBestiaryChanged then
			pcall(function()
				handler.OnBestiaryChanged:Connect(function()
					if onChanged then
						onChanged()
					end
				end)
			end)
		end
	end)
end

return Logic
