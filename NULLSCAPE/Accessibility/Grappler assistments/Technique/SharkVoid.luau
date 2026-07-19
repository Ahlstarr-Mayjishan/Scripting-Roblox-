--!nocheck

local Workspace = game:GetService("Workspace")
local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")
local ReleaseTiming = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Timing Helper.luau")
local UpgradeGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Upgrade Gate.luau")
local GrappleRange = getgenv().loadModule("NULLSCAPE/Class Adjustment/Grappler/Grapple Range.luau")
local VoidCastAssist = getgenv().loadModule("NULLSCAPE/Class Adjustment/Grappler/Grapple Void Cast Assist.luau")
local CastTransaction = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Transaction.luau")
local SharkTailWindow = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/SharkTail Window.luau")

local DEFAULT_HEIGHT = 45
local DEFAULT_REEL_HOLD = 0.12
local RESCUE_COOLDOWN = 0.55
local VOID_ANCHOR_TOLERANCE = 10
local VOID_REEL_LATERAL_OFFSET = 64

local Logic = {
	LastAutoCastAt = 0,
	LastAutoCastAttemptAt = 0,
	LastAutoReelAt = 0,
	LastSharkTailAt = 0,
	LastSharkTailAttemptAt = 0,
	LastVoidAnchorAt = 0,
	LastTransactionAt = 0,
	RetryAfter = 0,
	ConsecutiveCastFailures = 0,
	ReelOwned = false,
	ActiveGrapple = nil,
	MaxRescueHorizontalSpeed = 0,
	HookOwned = false,
	HookConfirmedAt = 0,
	ReelStartedAt = 0,
}

local function getNumber(value, fallback, minimum, maximum)
	local numberValue = tonumber(value) or fallback
	return math.clamp(numberValue, minimum, maximum)
end

local function recordMomentum(grapple, source)
	if MomentumMemory and typeof(MomentumMemory.record) == "function" then
		pcall(MomentumMemory.record, grapple and grapple.RootPart, source)
	end
end

local function getVelocity(rootPart)
	return rootPart and (rootPart.AssemblyLinearVelocity or rootPart.Velocity) or Vector3.zero
end

local function trackRescueMomentum(grapple)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and rootPart.Parent) then
		return 0
	end

	local velocity = getVelocity(rootPart)
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	Logic.MaxRescueHorizontalSpeed = math.max(Logic.MaxRescueHorizontalSpeed or 0, horizontalSpeed)
	return Logic.MaxRescueHorizontalSpeed
end

local function applyMaximumVerticalMomentum(grapple, controller)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and rootPart.Parent) then
		return false
	end

	local beforeVelocity = getVelocity(rootPart)
	local maximumHorizontalSpeed = math.max(trackRescueMomentum(grapple), 0)
	local nativeVerticalVelocity = maximumHorizontalSpeed ^ 0.95 * 1.3
	local verticalLimit = math.clamp(tonumber(controller and controller.MomentumMaxVerticalSpeed) or 500, 100, 500)
	local targetVerticalVelocity = math.min(nativeVerticalVelocity, verticalLimit)
	if targetVerticalVelocity <= beforeVelocity.Y then
		return false
	end

	local afterVelocity = Vector3.new(beforeVelocity.X, targetVerticalVelocity, beforeVelocity.Z)
	rootPart.AssemblyLinearVelocity = afterVelocity
	rootPart.Velocity = afterVelocity
	if MomentumMemory and typeof(MomentumMemory.noteImpulse) == "function" then
		pcall(MomentumMemory.noteImpulse, rootPart, "SharkVoidVerticalConversion", beforeVelocity, afterVelocity, afterVelocity - beforeVelocity, {
			CapturedHorizontalSpeed = maximumHorizontalSpeed,
			NativeFormula = true,
		})
	end
	return true
end

local function getKillVoidY()
	if TerrainMemory and typeof(TerrainMemory.getVoidInfo) == "function" then
		local voidInfo = TerrainMemory.getVoidInfo()
		if voidInfo then
			return voidInfo.Y
		end
	end

	local killVoid = Workspace:FindFirstChild("KillVoid", true)
	if killVoid and killVoid:IsA("BasePart") then
		return killVoid.Position.Y
	end

	return nil
end

local function isKillVoidPart(part)
	return typeof(part) == "Instance" and part:IsA("BasePart") and part.Name == "KillVoid"
end

local function isVoidPoint(position)
	local killVoidY = getKillVoidY()
	return typeof(position) == "Vector3"
		and killVoidY ~= nil
		and math.abs(position.Y - killVoidY) <= VOID_ANCHOR_TOLERANCE
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

local function isDangerousFall(grapple, controller)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and rootPart.Parent) then
		return false
	end

	if not isAirborne(grapple) then
		return false
	end
	if rootPart.AssemblyLinearVelocity.Y >= 0 then
		return false
	end

	local heightThreshold = getNumber(controller.GrappleVoidRescueHeight, DEFAULT_HEIGHT, 10, 160)
	local killVoidY = getKillVoidY()
	if not killVoidY then
		return false
	end

	local distanceToVoid = rootPart.Position.Y - killVoidY
	if distanceToVoid < 0 or distanceToVoid > heightThreshold then
		return false
	end

	return true
end

local function isVoidHit(hitResult)
	if not hitResult then
		return false
	end

	if isKillVoidPart(hitResult.Instance) then
		return true
	end

	return isVoidPoint(hitResult.Position)
end

local function getEffectiveRange(controller)
	if GrappleRange and typeof(GrappleRange.getEffectiveRange) == "function" then
		local success, range = pcall(GrappleRange.getEffectiveRange)
		if success and tonumber(range) then
			return math.clamp(tonumber(range), 30, 5000)
		end
	end

	return math.clamp(tonumber(controller and controller.GrappleAssistRange) or 90, 30, 500)
end

local function findEmergencyVoidHit(grapple, controller)
	local effectiveRange = getEffectiveRange(controller)
	if not (VoidCastAssist and typeof(VoidCastAssist.findEmergency) == "function") then
		return nil, false
	end

	local success, voidHit = pcall(VoidCastAssist.findEmergency, grapple, effectiveRange, {
		Force = true,
		LateralOffset = VOID_REEL_LATERAL_OFFSET,
	})
	if success and voidHit then
		return voidHit, true
	end

	return nil, false
end

local function canAutoCast(grapple, now)
	if now < (Logic.RetryAfter or 0) or now - (Logic.LastAutoCastAttemptAt or 0) < 0.35 then
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

	return typeof(grapple.Start) == "function"
end

local function clearOwnedReel(grapple)
	if Logic.ReelOwned and grapple then
		grapple.grappleReel = false
		grapple.jumpPadReel = false
	end
	Logic.ReelOwned = false
	Logic.ReelStartedAt = 0
end

local function cancelRescueHook(grapple)
	if Logic.HookOwned and grapple then
		local movement = grapple.Movement
		if movement and movement.grappling == true and typeof(grapple.End) == "function" then
			pcall(function()
				grapple:End(true)
			end)
		end
	end
	clearOwnedReel(grapple)
	Logic.HookOwned = false
	Logic.HookConfirmedAt = 0
end

local function noteCastFailure(grapple, now)
	Logic.ConsecutiveCastFailures = (Logic.ConsecutiveCastFailures or 0) + 1
	Logic.RetryAfter = now + math.min(1.5, 0.35 + Logic.ConsecutiveCastFailures * 0.25)
	Logic.LastVoidAnchorAt = 0
	Logic.MaxRescueHorizontalSpeed = 0
	if ReleaseTiming and typeof(ReleaseTiming.cancelReason) == "function" then
		ReleaseTiming.cancelReason(grapple, "SharkVoid")
	end
	cancelRescueHook(grapple)
end

local function syncCastTransaction(grapple, now)
	if not (CastTransaction and typeof(CastTransaction.getLast) == "function") then
		return false
	end

	local transaction = CastTransaction.getLast(grapple)
	if
		typeof(transaction) ~= "table"
		or transaction.Source ~= "SharkVoid"
		or (tonumber(transaction.At) or 0) <= (Logic.LastTransactionAt or 0)
	then
		return false
	end

	Logic.LastTransactionAt = tonumber(transaction.At) or now
	if transaction.State == "confirmed" then
		Logic.ConsecutiveCastFailures = 0
		Logic.RetryAfter = 0
		Logic.LastVoidAnchorAt = now
		Logic.HookOwned = true
		Logic.HookConfirmedAt = now
		return true
	end
	if transaction.State ~= "pending" then
		noteCastFailure(grapple, now)
	end
	return false
end

local function hasRequiredUpgrades(grapple)
	local movement = grapple and grapple.Movement
	return UpgradeGate and UpgradeGate.hasAll(movement, { "NinjaBelt", "SharkBelt" })
end

local function armSharkTailWindow(grapple, now)
	if SharkTailWindow and typeof(SharkTailWindow.arm) == "function" then
		SharkTailWindow.arm(grapple, "SharkVoid", now or time())
	end
end

local function autoCast(grapple, targeting, now)
	if not canAutoCast(grapple, now) then
		return false
	end
	Logic.LastAutoCastAttemptAt = now
	Logic.MaxRescueHorizontalSpeed = 0
	trackRescueMomentum(grapple)

	local controller = Logic.Controller
	local hitResult, usedEasierVoidCast = findEmergencyVoidHit(grapple, controller)
	if typeof(grapple.Cast) == "function" then
		if not hitResult then
			local success, result = pcall(function()
				return grapple:Cast(true)
			end)
			if success then
				hitResult = result
			end
		end
	end

	if not hitResult and targeting and typeof(targeting.findBestAssistHit) == "function" then
		local success, result = pcall(function()
			return targeting.findBestAssistHit(grapple, nil, {
				Technique = "SharkVoid",
				PilotMode = "Emergency",
			})
		end)
		if success then
			hitResult = result
		end
	end

	if not isVoidHit(hitResult) then
		noteCastFailure(grapple, now)
		return false
	end

	local success = CastTransaction
		and typeof(CastTransaction.start) == "function"
		and CastTransaction.start(grapple, hitResult, controller, "SharkVoid", {
			Technique = "VoidRescue",
			Name = "VoidRescue",
			EasierVoidCast = usedEasierVoidCast == true,
		})

	if success then
		recordMomentum(grapple, "SharkVoidAutoCast")
		Logic.LastAutoCastAt = now
	else
		noteCastFailure(grapple, now)
	end

	return success
end

local function hasVoidAnchor(grapple, now)
	local movement = grapple and grapple.Movement
	if movement and isVoidPoint(movement.grapplePoint) then
		Logic.LastVoidAnchorAt = now
		return true
	end

	return now - (Logic.LastVoidAnchorAt or 0) <= 0.25
end

local function canAutoReel(grapple, controller, now)
	if controller.GrappleVoidRescueAutoReel == false then
		return false
	end
	if now < (Logic.RetryAfter or 0) then
		return false
	end

	local movement = grapple and grapple.Movement
	if not (movement and movement.grappling == true) then
		return false
	end

	if grapple.jumpPadReel or grapple.grappleReel or grapple.reelCooldown then
		return false
	end

	if not hasVoidAnchor(grapple, now) then
		return false
	end

	return UpgradeGate and UpgradeGate.has(movement, "NinjaBelt")
end

local function autoReel(grapple, controller, now)
	if not canAutoReel(grapple, controller, now) then
		return false
	end

	if now - (Logic.LastAutoReelAt or 0) < RESCUE_COOLDOWN then
		return false
	end

	if typeof(grapple.AltSpecialAction) ~= "function" then
		noteCastFailure(grapple, now)
		return false
	end

	local invoked = pcall(function()
		grapple:AltSpecialAction(Enum.UserInputState.Begin)
	end)
	if not (invoked and grapple.jumpPadReel == true and grapple.grappleReel == true) then
		noteCastFailure(grapple, now)
		return false
	end

	recordMomentum(grapple, "SharkVoidAutoReel")
	Logic.LastAutoReelAt = now
	Logic.ReelOwned = true
	Logic.ReelStartedAt = now
	local holdTime = getNumber(controller.GrappleVoidRescueReelHoldTime, DEFAULT_REEL_HOLD, 0.05, 0.25)
	local scheduled = false
	if ReleaseTiming and typeof(ReleaseTiming.schedule) == "function" then
		local scheduleSuccess, scheduleResult = pcall(function()
			return ReleaseTiming.schedule(grapple, "SharkVoid", holdTime, {
				Intent = "VoidRescue",
				EndWasCancelled = false,
				OnReleased = function(releasedGrapple)
					Logic.ReelOwned = false
					Logic.ReelStartedAt = 0
					Logic.HookOwned = false
					Logic.HookConfirmedAt = 0
					recordMomentum(releasedGrapple, "SharkVoidAutoEnd")
					armSharkTailWindow(releasedGrapple)
				end,
				OnReleaseFailed = function(failedGrapple)
					clearOwnedReel(failedGrapple)
					noteCastFailure(failedGrapple, time())
				end,
			})
		end)
		scheduled = scheduleSuccess and scheduleResult ~= false
	end
	if not scheduled then
		noteCastFailure(grapple, now)
		return false
	end
	return true
end

local function maintainRescueHook(grapple, controller, now)
	if not Logic.HookOwned then
		return false
	end

	local movement = grapple and grapple.Movement
	if not (movement and movement.grappling == true) then
		Logic.HookOwned = false
		Logic.HookConfirmedAt = 0
		clearOwnedReel(grapple)
		return false
	end

	if not hasVoidAnchor(grapple, now) then
		noteCastFailure(grapple, now)
		return false
	end

	local pending = ReleaseTiming and typeof(ReleaseTiming.get) == "function" and ReleaseTiming.get(grapple)
	local ownsPendingRelease = pending and pending.Reason == "SharkVoid"
	if Logic.ReelOwned then
		if grapple.jumpPadReel ~= true or grapple.grappleReel ~= true then
			noteCastFailure(grapple, now)
			return false
		end

		local holdTime = getNumber(controller.GrappleVoidRescueReelHoldTime, DEFAULT_REEL_HOLD, 0.05, 0.25)
		if not ownsPendingRelease and now - (Logic.ReelStartedAt or now) > holdTime + 0.12 then
			noteCastFailure(grapple, now)
			return false
		end
	elseif now - (Logic.HookConfirmedAt or now) > 0.25 then
		noteCastFailure(grapple, now)
		return false
	end

	if now - (Logic.HookConfirmedAt or now) > 0.9 then
		noteCastFailure(grapple, now)
		return false
	end
	return true
end

local function autoSharkTail(grapple, controller, now)
	if controller.GrappleVoidRescueAutoSharkTail == false then
		if SharkTailWindow and typeof(SharkTailWindow.cancel) == "function" then
			SharkTailWindow.cancel(grapple, "SharkVoid")
		end
		return false
	end

	if not (SharkTailWindow and typeof(SharkTailWindow.isArmed) == "function") then
		return false
	end
	if not SharkTailWindow.isArmed(grapple, "SharkVoid", now) then
		return false
	end

	if
		now - (Logic.LastSharkTailAt or 0) < RESCUE_COOLDOWN
		or now - (Logic.LastSharkTailAttemptAt or 0) < 0.08
	then
		return false
	end

	if grapple.sharkTailDisable == true then
		return false
	end

	if not (UpgradeGate and UpgradeGate.has(grapple.Movement, "SharkBelt")) then
		return false
	end

	Logic.LastSharkTailAttemptAt = now
	local success = SharkTailWindow.trigger(grapple, "SharkVoid", now)

	if success then
		applyMaximumVerticalMomentum(grapple, controller)
		recordMomentum(grapple, "SharkVoidAutoSharkTail")
		Logic.LastSharkTailAt = now
		Logic.MaxRescueHorizontalSpeed = 0
	end

	return success
end

function Logic.step(grapple, _dt, controller, targeting)
	Logic.Controller = controller
	if Logic.ActiveGrapple and Logic.ActiveGrapple ~= grapple then
		cancelRescueHook(Logic.ActiveGrapple)
		if ReleaseTiming and typeof(ReleaseTiming.cancelReason) == "function" then
			ReleaseTiming.cancelReason(Logic.ActiveGrapple, "SharkVoid")
		end
	end
	Logic.ActiveGrapple = grapple

	if not (controller and controller.GrappleVoidRescueEnabled == true) then
		Logic.LastVoidAnchorAt = 0
		cancelRescueHook(grapple)
		if SharkTailWindow and typeof(SharkTailWindow.cancel) == "function" then
			SharkTailWindow.cancel(grapple, "SharkVoid")
		end
		if ReleaseTiming and typeof(ReleaseTiming.cancelReason) == "function" then
			ReleaseTiming.cancelReason(grapple, "SharkVoid")
		end
		return false
	end

	local now = time()
	syncCastTransaction(grapple, now)
	local pendingRelease = ReleaseTiming and typeof(ReleaseTiming.get) == "function" and ReleaseTiming.get(grapple)
	local ownsPendingRelease = pendingRelease and pendingRelease.Reason == "SharkVoid"
	local hookActive = maintainRescueHook(grapple, controller, now)
	if Logic.ReelOwned or ownsPendingRelease then
		trackRescueMomentum(grapple)
	end
	local sharkTailTriggered = autoSharkTail(grapple, controller, now)
	local upgradesReady = hasRequiredUpgrades(grapple)
	local reelStarted = false
	if hookActive and upgradesReady and not Logic.ReelOwned then
		reelStarted = autoReel(grapple, controller, now)
		hookActive = maintainRescueHook(grapple, controller, now)
	end

	if not isDangerousFall(grapple, controller) then
		return sharkTailTriggered or reelStarted or hookActive or ownsPendingRelease == true
	end

	if not upgradesReady then
		return false
	end

	local castStarted = autoCast(grapple, targeting, now)
	local movement = grapple and grapple.Movement
	local rescueAttached = movement and movement.grappling == true and hasVoidAnchor(grapple, now)
	if rescueAttached then
		trackRescueMomentum(grapple)
	end
	return castStarted or reelStarted or sharkTailTriggered or rescueAttached == true or ownsPendingRelease == true
end

function Logic.reset()
	cancelRescueHook(Logic.ActiveGrapple)
	Logic.LastAutoCastAt = 0
	Logic.LastAutoCastAttemptAt = 0
	Logic.LastAutoReelAt = 0
	Logic.LastSharkTailAt = 0
	Logic.LastSharkTailAttemptAt = 0
	Logic.LastVoidAnchorAt = 0
	Logic.LastTransactionAt = 0
	Logic.RetryAfter = 0
	Logic.ConsecutiveCastFailures = 0
	Logic.ActiveGrapple = nil
	Logic.MaxRescueHorizontalSpeed = 0
	Logic.HookOwned = false
	Logic.HookConfirmedAt = 0
	Logic.ReelStartedAt = 0
	if SharkTailWindow and typeof(SharkTailWindow.reset) == "function" then
		SharkTailWindow.reset("SharkVoid")
	end
	if ReleaseTiming and typeof(ReleaseTiming.cancel) == "function" then
		ReleaseTiming.cancel()
	end
end

return Logic
