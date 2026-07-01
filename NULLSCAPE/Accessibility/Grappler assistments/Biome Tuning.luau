--!nocheck
-- [[
--  NULLSCAPE - Grappler Biome Tuning
--  Small map-aware score nudges for biomes with dense rails/towers such as Highrise.
-- ]]

local Workspace = game:GetService("Workspace")

local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")

local BiomeTuning = {
	LastScanAt = -1000,
	Cached = {
		Name = "Generic",
		Confidence = 0,
	},
}

local SCAN_INTERVAL = 2.5

local function nameHasHighrise(instance)
	local name = string.lower(tostring(instance and instance.Name or ""))
	return string.find(name, "highrise", 1, true) ~= nil or string.find(name, "tower", 1, true) ~= nil
end

local function detect()
	local now = time()
	if now - BiomeTuning.LastScanAt < SCAN_INTERVAL then
		return BiomeTuning.Cached
	end
	BiomeTuning.LastScanAt = now

	local highriseSignals = 0
	local railSignals = 0
	local roots = {
		Workspace:FindFirstChild("CurrentRooms"),
		Workspace:FindFirstChild("JumpPads"),
	}

	for _, root in ipairs(roots) do
		if root then
			if nameHasHighrise(root) then
				highriseSignals += 2
			end
			for _, descendant in ipairs(root:GetDescendants()) do
				if nameHasHighrise(descendant) then
					highriseSignals += 1
				end
				if descendant.Name == "_RailPart" then
					railSignals += 1
				end
				if highriseSignals >= 3 and railSignals >= 3 then
					break
				end
			end
		end
	end

	if highriseSignals >= 2 or railSignals >= 5 then
		BiomeTuning.Cached = {
			Name = "Highrise",
			Confidence = math.clamp(0.45 + railSignals * 0.05 + highriseSignals * 0.08, 0.45, 1),
		}
	else
		BiomeTuning.Cached = {
			Name = "Generic",
			Confidence = 0,
		}
	end

	return BiomeTuning.Cached
end

function BiomeTuning.score(part, hit, controller, intent)
	if controller and controller.GrappleAssistBiomeTuningEnabled == false then
		return 0
	end

	local biome = detect()
	if biome.Name ~= "Highrise" then
		return 0
	end

	local score = 0
	if RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part) then
		score += 10 + biome.Confidence * 8
	end
	if part and part.Name == "JumpPad" then
		score += 6
	end
	if hit and hit.Normal and math.abs(hit.Normal.Y) < 0.35 then
		score += 4
	end
	if intent and intent.Name == "ReelSaver" then
		score += 4
	end

	return score
end

function BiomeTuning.getCurrent()
	return detect()
end

return BiomeTuning
