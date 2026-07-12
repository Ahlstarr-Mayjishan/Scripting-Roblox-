--!nocheck
--[[
	NULLSCAPE - FPS Boost
	Event-driven render culling that restores every client-side property it changes.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local FPSBoost = {
	Selections = {},
	Connections = {},
	OriginalVFX = setmetatable({}, { __mode = "k" }),
	OriginalEnemyVisuals = setmetatable({}, { __mode = "k" }),
	OriginalMapVisuals = setmetatable({}, { __mode = "k" }),
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

local VOID_GUARDIAN_PROJECTILE_POOLS = {
	Homer = true,
	HomerLaser = true,
	HomerInverted = true,
	OldHomer = true,
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
end

local function restoreVisuals(store)
	for instance, original in pairs(store) do
		if instance and instance.Parent then
			pcall(function()
				if original.LocalTransparencyModifier ~= nil then
					instance.LocalTransparencyModifier = original.LocalTransparencyModifier
				elseif original.Transparency ~= nil then
					instance.Transparency = original.Transparency
				elseif original.Visible ~= nil then
					instance.Visible = original.Visible
				elseif original.Density ~= nil then
					instance.Density = original.Density
					instance.Glare = original.Glare
					instance.Haze = original.Haze
				else
					instance.Enabled = original.Enabled
				end
			end)
		end
	end
	table.clear(store)
end

local function suppressVFX(instance)
	if not optionSelected(FPSBoost.Selections, "VFX") then
		return
	end

	pcall(function()
		if
			instance:IsA("ParticleEmitter")
			or instance:IsA("Trail")
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

local function hideVisual(instance, store)
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
		scan(folder, function(instance)
			hideVisual(instance, FPSBoost.OriginalEnemyVisuals)
		end, token)
		FPSBoost.Connections[folder] = folder.DescendantAdded:Connect(function(instance)
			hideVisual(instance, FPSBoost.OriginalEnemyVisuals)
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

	for rootName in pairs(ENEMY_ROOT_NAMES) do
		attach(Workspace:FindFirstChild(rootName))
	end
	attachProjectilePools(Workspace:FindFirstChild("Item_Pools"))
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
		if not MAP_ROOT_NAMES[root.Name] then
			return
		end
		scan(root, function(instance)
			hideVisual(instance, FPSBoost.OriginalMapVisuals)
		end, token)
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
