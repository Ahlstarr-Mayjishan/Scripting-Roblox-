--!nocheck
--[[
	NULLSCAPE - Grappler Deferred Aim Cast
	Temporarily remembers a precise out-of-range aim target and fires when it enters range.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GrappleRange = getgenv().loadModule("NULLSCAPE/Class Adjustment/Grappler/Grapple Range.luau")
local CastTransaction = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Transaction.luau")
local PerformanceBudget = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Performance Budget.luau")

local LocalPlayer = Players.LocalPlayer
local DeferredAim = {}

local PENDING_TTL = 1.15
local MAX_EXTRA_RANGE = 220
local MIN_OUT_OF_RANGE = 4
local START_COOLDOWN = 0.08

local Pending = nil

local function getRange(controller)
	if GrappleRange and typeof(GrappleRange.getEffectiveRange) == "function" then
		local range = tonumber(GrappleRange.getEffectiveRange())
		if range then
			return math.clamp(range, 30, 5000)
		end
	end

	return math.clamp(tonumber(controller and controller.GrappleAssistRange) or 500, 30, 500)
end

local function syncGrappleFilter(grapple)
	if
		grapple
		and grapple.grappleParams
		and grapple.Movement
		and grapple.Movement.moveCastParams
		and grapple.Movement.moveCastParams.FilterDescendantsInstances
	then
		grapple.grappleParams.FilterDescendantsInstances = grapple.Movement.moveCastParams.FilterDescendantsInstances
	end
end

local function getAimRay(grapple)
	local camera = Workspace.CurrentCamera
	local rootPart = grapple and grapple.RootPart
	local movement = grapple and grapple.Movement
	if not (camera and rootPart and movement) then
		return nil
	end

	local preferredInput = movement.preferredInput
	local usesCamera = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		or preferredInput ~= Enum.PreferredInput.KeyboardAndMouse

	if usesCamera then
		local humanoid = grapple.Humanoid
		local cameraOffset = grapple.cameraOffset
		if not (humanoid and cameraOffset) then
			return {
				Origin = rootPart.Position,
				Direction = camera.CFrame.LookVector,
			}
		end

		return {
			Origin = (camera.CFrame * cameraOffset).Position + camera.CFrame.LookVector * (
				camera.CFrame.Position - (rootPart.Position + humanoid.CameraOffset)
			).Magnitude,
			Direction = camera.CFrame.LookVector,
		}
	end

	local mouse = LocalPlayer and LocalPlayer:GetMouse()
	local unitRay = mouse and mouse.UnitRay
	if not unitRay then
		return {
			Origin = rootPart.Position,
			Direction = camera.CFrame.LookVector,
		}
	end

	return {
		Origin = unitRay.Origin,
		Direction = unitRay.Direction.Unit,
	}
end

local function canUseGrapple(grapple)
	local movement = grapple and grapple.Movement
	local rootPart = grapple and grapple.RootPart
	if not (movement and rootPart and rootPart.Parent) then
		return false
	end

	if movement.grappling or movement.diveBonked or movement.rail or movement.triaHold or rootPart.Anchored then
		return false
	end

	return grapple.Time ~= 0 and grapple.Charges ~= 0 and typeof(grapple.Start) == "function"
end

local function sameTarget(hit, pending)
	if not (hit and pending and pending.Instance) then
		return false
	end

	local instance = hit.Instance
	return instance == pending.Instance
		or instance:IsDescendantOf(pending.Instance)
		or pending.Instance:IsDescendantOf(instance)
end

function DeferredAim.note(grapple, controller)
	if not canUseGrapple(grapple) then
		Pending = nil
		return false
	end

	local rootPart = grapple.RootPart
	local maxRange = getRange(controller)
	local aimRay = getAimRay(grapple)
	if not aimRay then
		return false
	end

	syncGrappleFilter(grapple)

	local probeRange = maxRange + MAX_EXTRA_RANGE
	local aimHit = Workspace:Raycast(aimRay.Origin, aimRay.Direction * probeRange, grapple.grappleParams)
	if not aimHit then
		return false
	end

	local distance = (aimHit.Position - rootPart.Position).Magnitude
	if distance <= maxRange + MIN_OUT_OF_RANGE or distance > probeRange then
		return false
	end

	Pending = {
		Instance = aimHit.Instance,
		Position = aimHit.Position,
		CreatedAt = time(),
		ExpiresAt = time() + PENDING_TTL,
		MaxRange = maxRange,
	}

	return true
end

function DeferredAim.step(grapple, controller)
	if not Pending then
		return false
	end

	local now = time()
	if
		PerformanceBudget
		and typeof(PerformanceBudget.shouldRun) == "function"
		and not PerformanceBudget.shouldRun(grapple, "DeferredAim", 0.06)
	then
		return false
	end
	if now > Pending.ExpiresAt then
		Pending = nil
		return false
	end

	if now - (Pending.LastAttemptAt or 0) < START_COOLDOWN then
		return false
	end
	Pending.LastAttemptAt = now

	if not canUseGrapple(grapple) then
		Pending = nil
		return false
	end

	local rootPart = grapple.RootPart
	local maxRange = getRange(controller)
	local offset = Pending.Position - rootPart.Position
	local distance = offset.Magnitude
	if distance > maxRange or distance <= 3 then
		return false
	end

	syncGrappleFilter(grapple)

	local hit = Workspace:Raycast(rootPart.Position, offset.Unit * (distance + 2), grapple.grappleParams)
	if not sameTarget(hit, Pending) then
		return false
	end

	local success = CastTransaction
		and typeof(CastTransaction.start) == "function"
		and CastTransaction.start(grapple, hit, controller, "DeferredAim", {
			ManualCast = true,
			AssistiveManual = true,
		})

	if success then
		Pending = nil
	end

	return success
end

function DeferredAim.reset()
	Pending = nil
end

return DeferredAim
