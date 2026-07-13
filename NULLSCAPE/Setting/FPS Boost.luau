--!nocheck
--[[
	NULLSCAPE - FPS Boost
	Event-driven render culling that restores every client-side property it changes.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FPSBoost = {
	Selections = {},
	Connections = {},
	OriginalVFX = setmetatable({}, { __mode = "k" }),
	OriginalEnemyVisuals = setmetatable({}, { __mode = "k" }),
	OriginalMapVisuals = setmetatable({}, { __mode = "k" }),
	GuardedVFX = setmetatable({}, { __mode = "k" }),
	VisualGuards = setmetatable({}, { __mode = "k" }),
	MapRootConnections = setmetatable({}, { __mode = "k" }),
	OriginalLighting = nil,
	OriginalQuality = nil,
	ScanToken = 0,
}

local MAP_ROOT_NAMES = {
	Map = true,
	MapGeometry = true,
	CurrentRooms = true,
	Level = true,
	Environment = true,
	Geometry = true,
	World = true,
}

local ENEMY_ROOT_NAMES = {
	Enemies = true,
	Skinwalkers = true,
}

local CHARACTER_ENEMY_NAMES = {
	Blazebloom = true,
	Razorbloom = true,
}

local VOID_GUARDIAN_PROJECTILE_POOLS = {
	Homer = true,
	HomerLaser = true,
	HomerInverted = true,
	OldHomer = true,
}

local REASSERTED_VFX_ROOT_NAMES = {
	Beacons = true,
	CatalystDebris = true,
	DemonShockwave = true,
	FireArea = true,
	OblivionAmbient = true,
	OblivionAttack = true,
	VoidboundNeck = true,
	VoidboundSlam = true,
}

local function optionSelected(options, option)
	if typeof(options) ~= "table" then
		return false
	end
	if options[option] == true then
		return true
	end
	for _, value in pairs(options) do
		if value == option then
			return true
		end
	end
	return false
end

local function disconnectConnections()
	for key, connection in pairs(FPSBoost.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
		FPSBoost.Connections[key] = nil
	end
	for instance, guards in pairs(FPSBoost.VisualGuards) do
		for _, connection in pairs(guards) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		FPSBoost.VisualGuards[instance] = nil
	end
	for root, connections in pairs(FPSBoost.MapRootConnections) do
		for _, connection in pairs(connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		FPSBoost.MapRootConnections[root] = nil
	end
	table.clear(FPSBoost.GuardedVFX)
end

local function restoreVisuals(store)
	for instance, original in pairs(store) do
		if instance and instance.Parent then
			pcall(function()
				if original.LocalTransparencyModifier ~= nil then
					instance.LocalTransparencyModifier = original.LocalTransparencyModifier
				end
				if original.Transparency ~= nil then
					instance.Transparency = original.Transparency
				end
				if original.Visible ~= nil then
					instance.Visible = original.Visible
				end
				if original.Density ~= nil then
					instance.Density = original.Density
					instance.Glare = original.Glare
					instance.Haze = original.Haze
				end
				if original.Enabled ~= nil then
					instance.Enabled = original.Enabled
				end
			end)
		end
	end
	table.clear(store)
end

local hideVisual

local function hasReassertedVFXAncestor(instance)
	local current = instance
	while current and current ~= Workspace do
		if REASSERTED_VFX_ROOT_NAMES[current.Name] or string.match(current.Name, "_Afterimages$") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isOblivionPostEffect(instance)
	return instance.Parent == Lighting and instance.Name == "Oblivion" and instance:IsA("PostEffect")
end

local function hasVoidbreakerAncestor(instance)
	local current = instance
	while current and current ~= Workspace do
		if current.Name == "Voidbreaker" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function findVoidbreakerSword(instance)
	local current = instance
	while current and current ~= Workspace do
		if
			current:IsA("BasePart")
			and current:FindFirstChild("Model1")
			and current:FindFirstChild("Model2")
			and hasVoidbreakerAncestor(current.Parent)
		then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function guardVisualProperty(instance, property, hiddenValue, selection)
	local guards = FPSBoost.VisualGuards[instance]
	if guards and guards[property] then
		return
	end

	FPSBoost.GuardedVFX[instance] = true
	if not guards then
		guards = {}
		FPSBoost.VisualGuards[instance] = guards
		guards.Destroying = instance.Destroying:Connect(function()
			FPSBoost.GuardedVFX[instance] = nil
			FPSBoost.VisualGuards[instance] = nil
			for key, connection in pairs(guards) do
				if key ~= "Destroying" then
					connection:Disconnect()
				end
			end
		end)
	end
	guards[property] = instance:GetPropertyChangedSignal(property):Connect(function()
		if optionSelected(FPSBoost.Selections, selection) and instance[property] ~= hiddenValue then
			instance[property] = hiddenValue
		end
	end)
end

local function guardReassertedVFX(instance)
	if
		not (hasReassertedVFXAncestor(instance) or hasVoidbreakerAncestor(instance) or isOblivionPostEffect(instance))
	then
		return
	end

	if instance:IsA("Decal") or instance:IsA("Texture") then
		guardVisualProperty(instance, "Transparency", 1, "VFX")
	elseif instance:IsA("ParticleEmitter") then
		guardVisualProperty(instance, "Enabled", false, "VFX")
		guardVisualProperty(instance, "Transparency", NumberSequence.new(1), "VFX")
	elseif
		instance:IsA("Trail")
		or instance:IsA("Beam")
		or instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight")
		or instance:IsA("PostEffect")
	then
		guardVisualProperty(instance, "Enabled", false, "VFX")
	end
end

local function suppressPlayerGuiVFX(instance)
	if not optionSelected(FPSBoost.Selections, "VFX") then
		return
	end
	if not instance:IsA("BillboardGui") or (instance.Name ~= "splode" and instance.Name ~= "splode_crayon") then
		return
	end

	hideVisual(instance, FPSBoost.OriginalVFX)
	guardVisualProperty(instance, "Enabled", false, "VFX")
end

local function suppressVFX(instance)
	if not optionSelected(FPSBoost.Selections, "VFX") then
		return
	end

	pcall(function()
		local sword = findVoidbreakerSword(instance)
		if
			hasReassertedVFXAncestor(instance)
			or hasVoidbreakerAncestor(instance) and (instance:IsA("Decal") or instance:IsA("Texture"))
		then
			hideVisual(instance, FPSBoost.OriginalVFX)
		end
		guardReassertedVFX(instance)
		if sword and instance:IsA("BasePart") then
			if FPSBoost.OriginalVFX[instance] == nil then
				FPSBoost.OriginalVFX[instance] = { Transparency = instance.Transparency }
			end
			instance.Transparency = 1
			guardVisualProperty(instance, "Transparency", 1, "VFX")
		end

		if instance:IsA("ParticleEmitter") then
			if FPSBoost.OriginalVFX[instance] == nil then
				FPSBoost.OriginalVFX[instance] = {
					Enabled = instance.Enabled,
					Transparency = instance.Transparency,
				}
			end
			instance.Enabled = false
			instance.Transparency = NumberSequence.new(1)
		elseif
			instance:IsA("Trail")
			or instance:IsA("Beam")
			or instance:IsA("PostEffect")
			or instance:IsA("PointLight")
			or instance:IsA("SpotLight")
			or instance:IsA("SurfaceLight")
		then
			if FPSBoost.OriginalVFX[instance] == nil then
				FPSBoost.OriginalVFX[instance] = { Enabled = instance.Enabled }
			end
			instance.Enabled = false
		elseif instance:IsA("Atmosphere") then
			if FPSBoost.OriginalVFX[instance] == nil then
				FPSBoost.OriginalVFX[instance] = {
					Density = instance.Density,
					Glare = instance.Glare,
					Haze = instance.Haze,
				}
			end
			instance.Density = 0
			instance.Glare = 0
			instance.Haze = 0
		end
	end)
end

hideVisual = function(instance, store)
	pcall(function()
		if instance:IsA("BasePart") then
			if store[instance] == nil then
				store[instance] = { LocalTransparencyModifier = instance.LocalTransparencyModifier }
			end
			instance.LocalTransparencyModifier = 1
		elseif instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
			if store[instance] == nil then
				store[instance] = { Enabled = instance.Enabled }
			end
			instance.Enabled = false
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			if store[instance] == nil then
				store[instance] = { Transparency = instance.Transparency }
			end
			instance.Transparency = 1
		elseif instance:IsA("GuiObject") then
			if store[instance] == nil then
				store[instance] = { Visible = instance.Visible }
			end
			instance.Visible = false
		end
	end)
end

local function scan(root, callback, token)
	task.spawn(function()
		callback(root)
		for index, instance in ipairs(root:GetDescendants()) do
			if FPSBoost.ScanToken ~= token then
				return
			end
			callback(instance)
			if index % 300 == 0 then
				task.wait()
			end
		end
	end)
end

local function applyLowGraphics()
	if FPSBoost.OriginalLighting == nil then
		FPSBoost.OriginalLighting = {
			GlobalShadows = Lighting.GlobalShadows,
		}
	end

	pcall(function()
		local rendering = settings().Rendering
		if FPSBoost.OriginalQuality == nil then
			FPSBoost.OriginalQuality = rendering.QualityLevel
		end
		rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
	Lighting.GlobalShadows = false
end

local function restoreLowGraphics()
	if FPSBoost.OriginalLighting then
		Lighting.GlobalShadows = FPSBoost.OriginalLighting.GlobalShadows
		FPSBoost.OriginalLighting = nil
	end
	if FPSBoost.OriginalQuality ~= nil then
		pcall(function()
			settings().Rendering.QualityLevel = FPSBoost.OriginalQuality
		end)
		FPSBoost.OriginalQuality = nil
	end
end

local function bindVFX(token)
	FPSBoost.Connections.WorkspaceVFX = Workspace.DescendantAdded:Connect(suppressVFX)
	FPSBoost.Connections.LightingVFX = Lighting.DescendantAdded:Connect(suppressVFX)
	scan(Workspace, suppressVFX, token)
	scan(Lighting, suppressVFX, token)

	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, child in ipairs(playerGui:GetChildren()) do
			suppressPlayerGuiVFX(child)
		end
		FPSBoost.Connections.PlayerGuiVFX = playerGui.ChildAdded:Connect(suppressPlayerGuiVFX)
	end
end

local function bindEnemies(token)
	local function isVoidGuardianProjectile(instance, itemPools)
		local current = instance
		while current and current ~= itemPools do
			if VOID_GUARDIAN_PROJECTILE_POOLS[current.Name] then
				return true
			end
			current = current.Parent
		end
		return false
	end

	local function attach(folder)
		if not (folder and ENEMY_ROOT_NAMES[folder.Name]) then
			return
		end
		local function hideEnemyVisual(instance)
			if not hasVoidbreakerAncestor(instance) then
				hideVisual(instance, FPSBoost.OriginalEnemyVisuals)
			end
		end
		scan(folder, function(instance)
			hideEnemyVisual(instance)
		end, token)
		FPSBoost.Connections[folder] = folder.DescendantAdded:Connect(function(instance)
			hideEnemyVisual(instance)
		end)
	end

	local function attachProjectilePools(itemPools)
		if not (itemPools and itemPools.Name == "Item_Pools") then
			return
		end
		local function hideProjectileVisual(instance)
			if isVoidGuardianProjectile(instance, itemPools) then
				hideVisual(instance, FPSBoost.OriginalEnemyVisuals)
			end
		end
		scan(itemPools, hideProjectileVisual, token)
		FPSBoost.Connections[itemPools] = itemPools.DescendantAdded:Connect(hideProjectileVisual)
	end

	local function attachVoidbreakerGui(gui)
		if not (gui and gui.Name == "Voidbreaker" and gui:IsA("LayerCollector")) then
			return
		end
		hideVisual(gui, FPSBoost.OriginalEnemyVisuals)
		guardVisualProperty(gui, "Enabled", false, "Enemies")
	end

	local function attachCharacter(character)
		if not character then
			return
		end
		if FPSBoost.Connections.CharacterEnemyAdded then
			FPSBoost.Connections.CharacterEnemyAdded:Disconnect()
			FPSBoost.Connections.CharacterEnemyAdded = nil
		end

		local function attachCharacterEnemy(enemy)
			if not (enemy and CHARACTER_ENEMY_NAMES[enemy.Name]) then
				return
			end
			scan(enemy, function(instance)
				hideVisual(instance, FPSBoost.OriginalEnemyVisuals)
			end, token)
			FPSBoost.Connections[enemy] = enemy.DescendantAdded:Connect(function(instance)
				hideVisual(instance, FPSBoost.OriginalEnemyVisuals)
			end)
			enemy.Destroying:Once(function()
				local connection = FPSBoost.Connections[enemy]
				if connection then
					connection:Disconnect()
					FPSBoost.Connections[enemy] = nil
				end
			end)
		end

		for _, child in ipairs(character:GetChildren()) do
			attachCharacterEnemy(child)
		end
		FPSBoost.Connections.CharacterEnemyAdded = character.ChildAdded:Connect(attachCharacterEnemy)
	end

	for rootName in pairs(ENEMY_ROOT_NAMES) do
		attach(Workspace:FindFirstChild(rootName))
	end
	attachProjectilePools(Workspace:FindFirstChild("Item_Pools"))
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		attachVoidbreakerGui(playerGui:FindFirstChild("Voidbreaker"))
		FPSBoost.Connections.VoidbreakerGuiAdded = playerGui.ChildAdded:Connect(attachVoidbreakerGui)
	end
	attachCharacter(Players.LocalPlayer and Players.LocalPlayer.Character)
	FPSBoost.Connections.CharacterAdded = Players.LocalPlayer.CharacterAdded:Connect(attachCharacter)
	FPSBoost.Connections.EnemiesFolderAdded = Workspace.ChildAdded:Connect(function(child)
		if ENEMY_ROOT_NAMES[child.Name] then
			attach(child)
		elseif child.Name == "Item_Pools" then
			attachProjectilePools(child)
		end
	end)
end

local function bindMap(token)
	local function attach(root)
		if not (root and MAP_ROOT_NAMES[root.Name]) or FPSBoost.MapRootConnections[root] then
			return
		end

		local connections = {}
		FPSBoost.MapRootConnections[root] = connections
		scan(root, function(instance)
			hideVisual(instance, FPSBoost.OriginalMapVisuals)
		end, token)
		connections.DescendantAdded = root.DescendantAdded:Connect(function(instance)
			hideVisual(instance, FPSBoost.OriginalMapVisuals)
		end)
		connections.AncestryChanged = root.AncestryChanged:Connect(function()
			if root:IsDescendantOf(Workspace) then
				return
			end
			for _, connection in pairs(connections) do
				connection:Disconnect()
			end
			FPSBoost.MapRootConnections[root] = nil
		end)
	end

	for _, child in ipairs(Workspace:GetChildren()) do
		attach(child)
	end
	FPSBoost.Connections.MapRootAdded = Workspace.ChildAdded:Connect(attach)
end

function FPSBoost.setSelections(selections)
	if typeof(selections) ~= "table" then
		selections = {}
	end

	FPSBoost.ScanToken += 1
	disconnectConnections()
	restoreVisuals(FPSBoost.OriginalVFX)
	restoreVisuals(FPSBoost.OriginalEnemyVisuals)
	restoreVisuals(FPSBoost.OriginalMapVisuals)
	restoreLowGraphics()
	table.clear(FPSBoost.Selections)

	for key, value in pairs(selections) do
		local option = value == true and key or value
		if option == "Low Graphics" or option == "VFX" or option == "Enemies" or option == "Map" then
			FPSBoost.Selections[option] = true
		end
	end

	local token = FPSBoost.ScanToken
	if optionSelected(FPSBoost.Selections, "Low Graphics") then
		applyLowGraphics()
	end
	if optionSelected(FPSBoost.Selections, "VFX") then
		bindVFX(token)
	end
	if optionSelected(FPSBoost.Selections, "Enemies") then
		bindEnemies(token)
	end
	if optionSelected(FPSBoost.Selections, "Map") then
		bindMap(token)
	end
	return next(FPSBoost.Selections) ~= nil
end

function FPSBoost.getSelections()
	local selections = {}
	for option in pairs(FPSBoost.Selections) do
		table.insert(selections, option)
	end
	return selections
end

function FPSBoost.CleanUp()
	FPSBoost.setSelections({})
end

return FPSBoost
