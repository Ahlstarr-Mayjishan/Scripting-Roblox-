--!nocheck
-- [[
--  NULLSCAPE - Curse Visual Assist
--  Handles curse-driven misleading UI/visuals that are better treated as accessibility noise.
-- ]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Workspace = game:GetService("Workspace")

local Logic = {
	IgnoreFakeCount = false,
	BeaconMirageIdentifier = false,
	HookedCurseHandler = false,
	CallingOriginal = false,
	Connections = {},
	KnownMirages = setmetatable({}, { __mode = "k" }),
	OriginalProperties = setmetatable({}, { __mode = "k" }),
}

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function getCurseHandler()
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local curseHandlerModule = clientModules and clientModules:FindFirstChild("CurseHandler")
	if not (curseHandlerModule and curseHandlerModule:IsA("ModuleScript")) then
		return nil
	end

	local success, CurseHandler = pcall(require, curseHandlerModule)
	if success and typeof(CurseHandler) == "table" then
		return CurseHandler
	end
	return nil
end

local function installCurseHandlerHook()
	local CurseHandler = getCurseHandler()
	if not (CurseHandler and typeof(CurseHandler.IsCurseEnabled) == "function") then
		return false
	end

	local globals = getGlobals()
	local current = CurseHandler.IsCurseEnabled
	if globals.AccessibilityCurseEnabledWrapper and current == globals.AccessibilityCurseEnabledWrapper then
		Logic.HookedCurseHandler = true
		return true
	end

	if
		not globals.AccessibilityOriginalIsCurseEnabled
		or globals.AccessibilityOriginalIsCurseEnabled == globals.AccessibilityCurseEnabledWrapper
	then
		globals.AccessibilityOriginalIsCurseEnabled = current
	end

	local original = globals.AccessibilityOriginalIsCurseEnabled
	local wrapper
	wrapper = function(curseName, ...)
		local firstArg = ...
		local targetCurse = if type(curseName) == "string" then curseName else firstArg
		if Logic.IgnoreFakeCount and tostring(targetCurse) == "FakeCount" then
			return false
		end

		if Logic.CallingOriginal or original == wrapper then
			return false
		end

		Logic.CallingOriginal = true
		local results = table.pack(pcall(original, curseName, ...))
		Logic.CallingOriginal = false

		if not results[1] then
			return false
		end

		return table.unpack(results, 2, results.n)
	end

	local success = pcall(function()
		CurseHandler.IsCurseEnabled = wrapper
	end)
	if not success then
		return false
	end

	globals.AccessibilityCurseEnabledWrapper = wrapper
	Logic.HookedCurseHandler = true
	return true
end

local function disconnectAll()
	for _, conn in ipairs(Logic.Connections) do
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	table.clear(Logic.Connections)
end

local function remember(instance, prop)
	Logic.OriginalProperties[instance] = Logic.OriginalProperties[instance] or {}
	if Logic.OriginalProperties[instance][prop] == nil then
		local success, value = pcall(function()
			return instance[prop]
		end)
		if success then
			Logic.OriginalProperties[instance][prop] = value
		end
	end
end

local function setProperty(instance, prop, value)
	remember(instance, prop)
	pcall(function()
		instance[prop] = value
	end)
end

local function restoreVisuals()
	for instance, props in pairs(Logic.OriginalProperties) do
		if instance and instance.Parent then
			for prop, value in pairs(props) do
				pcall(function()
					instance[prop] = value
				end)
			end
		end
		Logic.OriginalProperties[instance] = nil
	end
end

local function isRealBeacon(instance)
	return instance == Workspace:FindFirstChild("Beacon")
end

local function isBeaconMirage(instance)
	if not instance or isRealBeacon(instance) then
		return false
	end

	local current = instance
	while current and current ~= Workspace do
		local lowerName = string.lower(tostring(current.Name or ""))
		if string.find(lowerName, "beaconmirage", 1, true) or string.find(lowerName, "beaconfeint", 1, true) then
			return true
		end
		current = current.Parent
	end

	if instance:IsA("Model") or instance:IsA("BasePart") then
		local beaconModel = instance:FindFirstChild("BeaconModel")
		local clientEvent = instance:FindFirstChild("ClientEvent")
		local sound = instance:FindFirstChild("Sound")
		return beaconModel ~= nil and clientEvent ~= nil and sound ~= nil and not isRealBeacon(instance)
	end

	return false
end

local function applyMirageVisual(instance)
	if not Logic.BeaconMirageIdentifier or not isBeaconMirage(instance) then
		return
	end
	if Logic.KnownMirages[instance] == true then
		return
	end
	Logic.KnownMirages[instance] = true

	for _, desc in ipairs(instance:GetDescendants()) do
		if desc:IsA("BasePart") then
			setProperty(desc, "CanTouch", false)
			setProperty(desc, "CanQuery", false)
			setProperty(desc, "CanCollide", false)
			setProperty(desc, "Transparency", math.max(desc.Transparency, 0.75))
			setProperty(desc, "Color", Color3.fromRGB(255, 70, 130))
		elseif
			desc:IsA("ParticleEmitter")
			or desc:IsA("Beam")
			or desc:IsA("Trail")
			or desc:IsA("PointLight")
			or desc:IsA("SurfaceLight")
			or desc:IsA("SpotLight")
		then
			setProperty(desc, "Enabled", false)
		end
	end

	if instance:IsA("BasePart") then
		setProperty(instance, "CanTouch", false)
		setProperty(instance, "CanQuery", false)
		setProperty(instance, "CanCollide", false)
		setProperty(instance, "Transparency", math.max(instance.Transparency, 0.75))
		setProperty(instance, "Color", Color3.fromRGB(255, 70, 130))
	end
end

local function ensureRealBeaconMarker()
	local beacon = Workspace:FindFirstChild("Beacon")
	if not (Logic.BeaconMirageIdentifier and beacon and beacon:IsA("BasePart")) then
		return
	end

	local marker = beacon:FindFirstChild("NULLSCAPE_RealBeaconMarker")
	if not marker then
		marker = Instance.new("Highlight")
		marker.Name = "NULLSCAPE_RealBeaconMarker"
		marker.FillColor = Color3.fromRGB(80, 255, 140)
		marker.OutlineColor = Color3.fromRGB(255, 255, 255)
		marker.FillTransparency = 0.65
		marker.OutlineTransparency = 0
		marker.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		marker.Parent = beacon
	end
	marker.Adornee = beacon
	marker.Enabled = true
end

local function scanBeaconMirages()
	ensureRealBeaconMarker()
	for _, child in ipairs(Workspace:GetChildren()) do
		if isBeaconMirage(child) then
			applyMirageVisual(child)
		end
	end
end

local function findMirageRoot(instance)
	local current = instance
	while current and current.Parent and current.Parent ~= Workspace do
		current = current.Parent
	end
	if current and current.Parent == Workspace then
		return current
	end
	return instance
end

local function startBeaconMirageIdentifier()
	if Logic.Connections[1] then
		return
	end

	scanBeaconMirages()
	table.insert(
		Logic.Connections,
		Workspace.DescendantAdded:Connect(function(instance)
			task.defer(function()
				if Logic.BeaconMirageIdentifier and instance and instance.Parent then
					local root = findMirageRoot(instance)
					if isBeaconMirage(root) then
						applyMirageVisual(root)
					elseif instance.Name == "BeaconModel" and instance.Parent then
						applyMirageVisual(findMirageRoot(instance.Parent))
					end
					ensureRealBeaconMarker()
				end
			end)
		end)
	)
end

local function stopBeaconMirageIdentifier()
	disconnectAll()
	Logic.KnownMirages = setmetatable({}, { __mode = "k" })
	local beacon = Workspace:FindFirstChild("Beacon")
	local marker = beacon and beacon:FindFirstChild("NULLSCAPE_RealBeaconMarker")
	if marker then
		pcall(function()
			marker:Destroy()
		end)
	end
	restoreVisuals()
end

function Logic.setIgnoreFakeCount(enabled)
	Logic.IgnoreFakeCount = enabled == true
	if Logic.IgnoreFakeCount then
		return installCurseHandlerHook()
	end
	return true
end

function Logic.setBeaconMirageIdentifier(enabled)
	Logic.BeaconMirageIdentifier = enabled == true
	if Logic.BeaconMirageIdentifier then
		startBeaconMirageIdentifier()
	else
		stopBeaconMirageIdentifier()
	end
	return true
end

function Logic.disable()
	Logic.IgnoreFakeCount = false
	Logic.BeaconMirageIdentifier = false
	Logic.CallingOriginal = false

	local CurseHandler = getCurseHandler()
	local globals = getGlobals()
	if
		CurseHandler
		and globals.AccessibilityCurseEnabledWrapper
		and CurseHandler.IsCurseEnabled == globals.AccessibilityCurseEnabledWrapper
		and globals.AccessibilityOriginalIsCurseEnabled
	then
		pcall(function()
			CurseHandler.IsCurseEnabled = globals.AccessibilityOriginalIsCurseEnabled
		end)
	end
	globals.AccessibilityCurseEnabledWrapper = nil
	globals.AccessibilityOriginalIsCurseEnabled = nil
	Logic.HookedCurseHandler = false

	stopBeaconMirageIdentifier()
end

return Logic
