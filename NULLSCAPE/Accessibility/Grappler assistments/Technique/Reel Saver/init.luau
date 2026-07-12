--!nocheck
-- [[
--  NULLSCAPE - Grappler Reel Saver
--  Orchestrates the upper-wall cast, NinjaBelt reel, and release timing.
-- ]]

local Probe =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique/Reel Saver/Terrain Query.luau")
local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")
local ReleaseTiming = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Timing Helper.luau")
local UpgradeGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Upgrade Gate.luau")
local CastTransaction = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Transaction.luau")
local ReleasePolicy = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Policy.luau")
local ReleasePlanner = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Planner.luau")

local DEFAULT_REEL_HOLD = 0.16
local START_COOLDOWN = 0.7
local CAST_ACTIVE_WINDOW = 1.25

local Logic = {
	LastCastAt = -1000,
	PendingEndAt = nil,
	ActiveTarget = nil,
}

local function getNumber(value, fallback, minimum, maximum)
	local numberValue = tonumber(value) or fallback
	return math.clamp(numberValue, minimum, maximum)
end

local function isAirborne(grapple)
	local humanoid = grapple and grapple.Humanoid
	if not humanoid then
		return true
	end

	if humanoid.FloorMaterial ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air then
		return false
	end

	local state = humanoid:GetState()
	return state ~= Enum.HumanoidStateType.Running and state ~= Enum.HumanoidStateType.Landed
end

local function hasNinjaBelt(movement)
	return UpgradeGate and UpgradeGate.has(movement, "NinjaBelt")
end

local function canStartCast(grapple, controller, now)
	if not (controller and controller.GrappleReelSaverEnabled == true) then
		return false
	end

	if now - (Logic.LastCastAt or -1000) < START_COOLDOWN then
		return false
	end

	local movement = grapple and grapple.Movement
	local rootPart = grapple and grapple.RootPart
	if not (movement and rootPart and rootPart.Parent) then
		return false
	end

	if movement.grappling or movement.diveBonked or movement.rail or movement.triaHold or rootPart.Anchored then
		return false
	end

	if grapple.Time == 0 or grapple.Charges == 0 then
		return false
	end

	return hasNinjaBelt(movement) and isAirborne(grapple) and typeof(grapple.Start) == "function"
end

local function castToTarget(grapple, controller, target, now)
	if not (target and target.Hit) then
		return false
	end

	local success = CastTransaction
		and typeof(CastTransaction.start) == "function"
		and CastTransaction.start(grapple, target.Hit, controller, "ReelSaver", {
			Technique = "ReelSaver",
		})

	if success then
		if MomentumMemory and typeof(MomentumMemory.record) == "function" then
			pcall(MomentumMemory.record, grapple.RootPart, "ReelSaverCast")
		end
		target.StartedAt = now
		Logic.ActiveTarget = target
		Logic.LastCastAt = now
	end

	return success
end

local function playReelSound(grapple)
	local movement = grapple and grapple.Movement
	local sfx = movement and movement.SFX
	local reel = sfx and sfx:FindFirstChild("GrapplerReel")
	if reel and typeof(reel.Play) == "function" then
		pcall(function()
			reel:Play()
		end)
	end
end

local function startReel(grapple, controller, now)
	local movement = grapple and grapple.Movement
	if not (movement and movement.grappling == true) then
		return false
	end

	if grapple.jumpPadReel or grapple.grappleReel or grapple.reelCooldown then
		return false
	end

	if not (UpgradeGate and UpgradeGate.has(movement, "NinjaBelt")) then
		return false
	end

	grapple.jumpPadReel = true
	grapple.reelStart = now
	grapple.grappleReel = true
	if MomentumMemory and typeof(MomentumMemory.record) == "function" then
		pcall(MomentumMemory.record, grapple.RootPart, "ReelSaverAutoReel")
	end
	local holdTime = getNumber(controller.GrappleReelSaverReelHoldTime, DEFAULT_REEL_HOLD, 0.06, 0.35)
	Logic.PendingEndAt = now + holdTime
	if ReleaseTiming and typeof(ReleaseTiming.schedule) == "function" then
		pcall(function()
			ReleaseTiming.schedule(grapple, "ReelSaver", holdTime, {
				Intent = "ReelSaver",
			})
		end)
	end
	playReelSound(grapple)
	return true
end

local function shouldRelease(grapple, now)
	if not Logic.PendingEndAt then
		return false
	end

	local target = Logic.ActiveTarget
	if target and target.Floor and grapple and grapple.RootPart then
		if grapple.RootPart.Position.Y >= target.Floor.Position.Y - 2 then
			return true
		end
	end

	return now >= Logic.PendingEndAt
end

local function releaseReel(grapple, controller)
	local movement = grapple and grapple.Movement
	if not (movement and movement.grappling == true and grapple.grappleReel == true) then
		return false
	end
	if ReleasePlanner and typeof(ReleasePlanner.shouldRelease) == "function" then
		local canRelease = ReleasePlanner.shouldRelease(grapple, "ReelSaver", { Intent = "ReelSaver" }, controller)
		if not canRelease then
			return false
		end
	end

	if not (ReleasePolicy and typeof(ReleasePolicy.release) == "function") then
		return false
	end

	local success = ReleasePolicy.release(grapple, "ReelSaver")
	if success then
		Logic.PendingEndAt = nil
		Logic.ActiveTarget = nil
	end
	if success and MomentumMemory and typeof(MomentumMemory.record) == "function" then
		pcall(MomentumMemory.record, grapple.RootPart, "ReelSaverRelease")
	end

	return success
end

function Logic.step(grapple, _dt, controller)
	if not (controller and controller.GrappleReelSaverEnabled == true) then
		Logic.PendingEndAt = nil
		Logic.ActiveTarget = nil
		return false
	end

	local now = time()
	if shouldRelease(grapple, now) then
		return releaseReel(grapple, controller)
	end

	if Logic.ActiveTarget and now - (Logic.ActiveTarget.StartedAt or now) <= CAST_ACTIVE_WINDOW then
		startReel(grapple, controller, now)
		return true
	end

	return false
end

function Logic.trigger(grapple, controller, targeting)
	local now = time()

	if not (controller and controller.GrappleReelSaverEnabled == true) then
		return false
	end

	local movement = grapple and grapple.Movement
	if movement and movement.grappling == true then
		if grapple.grappleReel == true or grapple.jumpPadReel == true then
			return true
		end

		return startReel(grapple, controller, now)
	end

	if not canStartCast(grapple, controller, now) then
		return false
	end

	local aimDirection = targeting
			and typeof(targeting.getAimDirection) == "function"
			and targeting.getAimDirection(grapple)
		or nil
	local target = Probe.find(grapple, controller, aimDirection)
	if not (target and target.Hit) and targeting and typeof(targeting.findBestAssistHit) == "function" then
		local hit = targeting.findBestAssistHit(grapple, controller, {
			Technique = "ReelSaver",
			ManualCast = true,
		})
		if hit then
			target = {
				Hit = hit,
			}
		end
	end

	return castToTarget(grapple, controller, target, now)
end

function Logic.reset()
	Logic.LastCastAt = -1000
	Logic.PendingEndAt = nil
	Logic.ActiveTarget = nil
	if ReleaseTiming and typeof(ReleaseTiming.cancel) == "function" then
		ReleaseTiming.cancel()
	end
end

return Logic
