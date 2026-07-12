--!nocheck
--[[
	NULLSCAPE - Grapple State Adapter
	Normalizes native Grapple state before automation attempts an action.
]]

local Adapter = {}

local BLOCKING_STATUSES = { "Flesh", "Medal" }

local function hasStatus(grapple, name)
	local status = grapple and grapple.Status
	if not (status and typeof(status.HasStatus) == "function") then
		return false
	end

	local success, result = pcall(status.HasStatus, name)
	return success and result == true
end

function Adapter.snapshot(grapple)
	local movement = grapple and grapple.Movement
	local rootPart = grapple and grapple.RootPart
	return {
		Grappling = movement and movement.grappling == true,
		OnRail = movement and movement.rail == true,
		HoldingTria = movement and movement.triaHold == true,
		DiveBonked = movement and movement.diveBonked == true,
		Anchored = rootPart and rootPart.Anchored == true or movement and movement.Anchored == true,
		Reeling = grapple and grapple.grappleReel == true,
		JumpPadReel = grapple and grapple.jumpPadReel == true,
		ReelCooldown = grapple and grapple.reelCooldown == true,
		SharkTailReady = grapple and grapple.allowSharkTail == true and grapple.sharkTailDisable ~= true,
		Charges = tonumber(grapple and grapple.Charges) or 0,
		Time = tonumber(grapple and grapple.Time) or 0,
		LastReleaseAt = tonumber(grapple and grapple.lastGrappleRelease) or -1000,
		RecentAimAt = tonumber(grapple and grapple.memoryUpdate) or -1000,
		RecentAimPosition = grapple and grapple.memoryPosition or nil,
	}
end

function Adapter.canStart(grapple, hit)
	if not (grapple and hit and hit.Instance and typeof(grapple.Start) == "function") then
		return false, "missing-grapple"
	end

	local movement = grapple.Movement
	local rootPart = grapple.RootPart
	if not (movement and rootPart and rootPart.Parent) then
		return false, "missing-movement"
	end

	local state = Adapter.snapshot(grapple)
	if state.Grappling then
		return false, "already-grappling"
	end
	if state.DiveBonked or state.OnRail or state.HoldingTria or state.Anchored then
		return false, "movement-blocked"
	end
	if state.Charges <= 0 or state.Time <= 0 then
		return false, "resource-empty"
	end
	for _, statusName in ipairs(BLOCKING_STATUSES) do
		if hasStatus(grapple, statusName) then
			return false, "status-" .. string.lower(statusName)
		end
	end

	local humanoid = grapple.Humanoid
	if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Running and hit.Instance.Name ~= "JumpPad" then
		return false, "grounded-non-jumppad"
	end

	return true, "ready"
end

function Adapter.rememberAim(grapple, hit)
	if not (grapple and hit and typeof(hit.Position) == "Vector3") then
		return false
	end

	grapple.memoryPosition = hit.Position
	grapple.memoryUpdate = time()
	return true
end

function Adapter.clearAim(grapple)
	if grapple then
		grapple.memoryUpdate = -1000
	end
end

return Adapter
