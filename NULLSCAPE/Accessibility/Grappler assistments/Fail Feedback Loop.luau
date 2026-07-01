--!nocheck
-- [[
--  NULLSCAPE - Grappler Fail Feedback Loop
--  Learns from assisted casts that immediately lead to drops or wall traps.
-- ]]

local Workspace = game:GetService("Workspace")

local BadAnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Bad Anchor Memory.luau")

local Feedback = {
	Pending = setmetatable({}, { __mode = "k" }),
}

local EVALUATION_WINDOW = 1.05

local function getVelocity(rootPart)
	return rootPart and (rootPart.AssemblyLinearVelocity or rootPart.Velocity) or Vector3.zero
end

local function getPart(hit)
	return hit and hit.Instance
end

function Feedback.noteAssistCast(grapple, hit, controller)
	if controller and controller.GrappleAssistFailFeedbackEnabled == false then
		return false
	end
	local rootPart = grapple and grapple.RootPart
	local part = getPart(hit)
	if not (rootPart and part) then
		return false
	end

	Feedback.Pending[grapple] = {
		Part = part,
		HitPosition = hit.Position,
		StartedAt = time(),
		StartY = rootPart.Position.Y,
		LastVelocity = getVelocity(rootPart),
		Noted = false,
	}
	return true
end

local function noteBad(entry, reason, severity)
	if entry.Noted then
		return
	end
	entry.Noted = true
	if BadAnchorMemory and typeof(BadAnchorMemory.note) == "function" then
		BadAnchorMemory.note(entry.Part, reason, severity or 24, 9)
	end
end

local function noteGood(entry)
	if BadAnchorMemory and typeof(BadAnchorMemory.noteGood) == "function" then
		BadAnchorMemory.noteGood(entry.Part)
	end
end

function Feedback.step(grapple, dt, controller)
	if controller and controller.GrappleAssistFailFeedbackEnabled == false then
		Feedback.Pending[grapple] = nil
		return false
	end

	local entry = Feedback.Pending[grapple]
	local rootPart = grapple and grapple.RootPart
	if not (entry and rootPart and rootPart.Parent) then
		return false
	end

	local now = time()
	local elapsed = now - entry.StartedAt
	if elapsed > EVALUATION_WINDOW then
		noteGood(entry)
		Feedback.Pending[grapple] = nil
		return true
	end

	local velocity = getVelocity(rootPart)
	local yDrop = entry.StartY - rootPart.Position.Y
	if elapsed >= 0.18 and velocity.Y < -82 and yDrop > 10 then
		noteBad(entry, "post-cast-drop", 28)
		Feedback.Pending[grapple] = nil
		return true
	end

	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if elapsed >= 0.12 and horizontal.Magnitude > 45 then
		local hit = Workspace:Raycast(rootPart.Position, horizontal.Unit * 5, grapple.grappleParams)
		if hit and hit.Instance ~= entry.Part then
			noteBad(entry, "post-cast-wall-trap", 22)
			Feedback.Pending[grapple] = nil
			return true
		end
	end

	entry.LastVelocity = velocity
	return false
end

function Feedback.reset()
	table.clear(Feedback.Pending)
end

return Feedback
