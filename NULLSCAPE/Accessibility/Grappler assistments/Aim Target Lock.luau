--!nocheck
--[[
	NULLSCAPE - Aim Target Lock
	Stabilizes a deliberate aim briefly without overriding a meaningful retarget.
]]

local Workspace = game:GetService("Workspace")

local StateAdapter = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Grapple State Adapter.luau")

local Lock = {
	Entries = setmetatable({}, { __mode = "k" }),
}

local LOCK_TTL = 0.24
local MIN_AIM_DOT = math.cos(math.rad(18))

local function sameInstance(a, b)
	return a == b or a:IsDescendantOf(b) or b:IsDescendantOf(a)
end

function Lock.remember(grapple, hit)
	if not (grapple and hit and hit.Instance and typeof(hit.Position) == "Vector3") then
		return false
	end

	Lock.Entries[grapple] = {
		Instance = hit.Instance,
		Position = hit.Position,
		ExpiresAt = time() + LOCK_TTL,
	}
	if StateAdapter and typeof(StateAdapter.rememberAim) == "function" then
		StateAdapter.rememberAim(grapple, hit)
	end
	return true
end

function Lock.resolve(grapple, aimDirection)
	local entry = Lock.Entries[grapple]
	local rootPart = grapple and grapple.RootPart
	if not (entry and rootPart and grapple.grappleParams) then
		return nil
	end

	if time() > entry.ExpiresAt or not entry.Instance.Parent then
		Lock.Entries[grapple] = nil
		return nil
	end

	local offset = entry.Position - rootPart.Position
	if offset.Magnitude <= 3 or aimDirection:Dot(offset.Unit) < MIN_AIM_DOT then
		return nil
	end

	local hit = Workspace:Raycast(rootPart.Position, offset.Unit * (offset.Magnitude + 2), grapple.grappleParams)
	if not (hit and hit.Instance and sameInstance(hit.Instance, entry.Instance)) then
		Lock.Entries[grapple] = nil
		return nil
	end

	entry.Position = hit.Position
	entry.ExpiresAt = time() + LOCK_TTL
	return hit
end

function Lock.clear(grapple)
	if grapple then
		Lock.Entries[grapple] = nil
	else
		table.clear(Lock.Entries)
	end
end

return Lock
