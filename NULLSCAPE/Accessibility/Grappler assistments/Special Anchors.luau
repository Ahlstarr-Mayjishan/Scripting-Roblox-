--!nocheck
-- [[
--  NULLSCAPE - Grappler Special Anchors
--  Shared knowledge for native/special grapple targets.
-- ]]

local SpecialAnchors = {}

local DEFINITIONS = {
	JumpPad = {
		Field = "GrappleAnchorPriorityJumpPad",
		Priority = 650,
		CaptureAngle = 82,
		Tags = { "JumpPad" },
	},
	GrapplePoint = {
		Field = "GrappleAnchorPriorityGrapplePoint",
		Priority = 700,
		CaptureAngle = 70,
	},
	TriaOrb = {
		Field = "GrappleAnchorPriorityTriaOrb",
		Priority = 620,
		CaptureAngle = 70,
	},
	Bell = {
		Field = "GrappleAnchorPriorityBell",
		Priority = 550,
		CaptureAngle = 70,
	},
}

local function hasTag(instance, tagName)
	if not (instance and typeof(instance.HasTag) == "function") then
		return false
	end

	local success, result = pcall(function()
		return instance:HasTag(tagName)
	end)

	return success and result == true
end

function SpecialAnchors.getName(part)
	if not (part and part:IsA("BasePart")) then
		return nil
	end

	if DEFINITIONS[part.Name] then
		return part.Name
	end

	for name, definition in pairs(DEFINITIONS) do
		for _, tagName in ipairs(definition.Tags or {}) do
			if hasTag(part, tagName) then
				return name
			end
		end
	end

	return nil
end

function SpecialAnchors.isSpecial(part)
	return SpecialAnchors.getName(part) ~= nil
end

function SpecialAnchors.getDefinition(anchorName)
	return DEFINITIONS[anchorName]
end

function SpecialAnchors.getPriority(anchorName, controller)
	local definition = DEFINITIONS[anchorName]
	if not definition then
		return 0
	end

	local value = controller and tonumber(controller[definition.Field])
	return math.clamp(value or definition.Priority, 0, 1000)
end

function SpecialAnchors.getCaptureAngle(anchorName)
	local definition = DEFINITIONS[anchorName]
	return definition and definition.CaptureAngle or 45
end

function SpecialAnchors.getField(anchorName)
	local definition = DEFINITIONS[anchorName]
	return definition and definition.Field or nil
end

return SpecialAnchors
