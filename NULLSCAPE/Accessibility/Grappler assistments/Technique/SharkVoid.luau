--!nocheck

local Workspace = game:GetService("Workspace")
local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")
local ReleaseTiming = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Timing Helper.luau")
local UpgradeGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Upgrade Gate.luau")
local GrappleRange = getgenv().loadModule("NULLSCAPE/Class Adjustment/Grappler/Grapple Range.luau")
local CastTransaction = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Transaction.luau")
local ReleasePolicy = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Policy.luau")

local DEFAULT_HEIGHT = 45
local DEFAULT_REEL_HOLD = 0.12
local RESCUE_COOLDOWN = 0.55
local VOID_ANCHOR_TOLERANCE = 10

local Logic = {
	PendingEndAt = nil,
	LastAutoCastAt = 0,
	LastAutoReelAt = 0,
	LastSharkTailAt = 0,
	LastVoidAnchorAt = 0,
	SharkTailWindowGrapple = nil,
	SharkTailWindowConsumed = false,
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

local function getKillVoidPart()
	if TerrainMemory and typeof(TerrainMemory.getVoidInfo) == "function" then
		local voidInfo = TerrainMemory.getVoidInfo()
		if voidInfo and voidInfo.Part and voidInfo.Part.Parent then
			return voidInfo.Part
		end
	end

	local killVoid = Workspace:FindFirstChild("KillVoid", true)
	if killVoid and killVoid:IsA("BasePart") then
		return killVoid
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

local function makeVoidHit(part, position, origin)
	return {
		Instance = part,
		Position = position,
		Distance = (position - origin).Magnitude,
		Normal = part.CFrame.UpVector,
		Material = part.Material,
	}
end

local function findEmergencyVoidHit(grapple, controller)
	local rootPart = grapple and grapple.RootPart
	local killVoid = getKillVoidPart()
	if not (rootPart and rootPart.Parent and killVoid) then
		return nil
	end

	local origin = rootPart.Position
	local localOrigin = killVoid.CFrame:PointToObjectSpace(origin)
	local halfSize = killVoid.Size * 0.5
	local localHit = Vector3.new(
		math.clamp(localOrigin.X, -halfSize.X, halfSize.X),
		halfSize.Y,
		math.clamp(localOrigin.Z, -halfSize.Z, halfSize.Z)
	)
	local hitPosition = killVoid.CFrame:PointToWorldSpace(localHit)
	local offset = hitPosition - origin
	local distance = offset.Magnitude

	if distance <= 3 or distance > getEffectiveRange(controller) then
		return nil
	end

	if grapple.grappleParams and offset.Magnitude > 0.001 then
		local rayHit = Workspace:Raycast(origin, offset.Unit * math.max(distance - 1, 1), grapple.grappleParams)
		if rayHit and not isKillVoidPart(rayHit.Instance) then
			return nil
		end
	end

	return makeVoidHit(killVoid, hitPosition, origin)
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

local function canAutoCast(grapple, now)
	if now - (Logic.LastAutoCastAt or 0) < 0.35 then
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

local function hasRequiredUpgrades(grapple)
	local movement = grapple and grapple.Movement
	return UpgradeGate and UpgradeGate.hasAll(movement, { "NinjaBelt", "SharkBelt" })
end

local function autoCast(grapple, targeting, now)
	if not canAutoCast(grapple, now) then
		return false
	end

	local controller = Logic.Controller
	local hitResult = findEmergencyVoidHit(grapple, controller)
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
		return false
	end

	local success = CastTransaction
		and typeof(CastTransaction.start) == "function"
		and CastTransaction.start(grapple, hitResult, controller, "SharkVoid", {
			Technique = "VoidRescue",
			Name = "VoidRescue",
		})

	if success then
		recordMomentum(grapple, "SharkVoidAutoCast")
		Logic.LastAutoCastAt = now
		Logic.LastVoidAnchorAt = now
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

	local movement = grapple and grapple.Movement
	if not (movement and movement.grappling == true) then
		return false
	end

	if grapple.jumpPadReel or grapple.grappleReel or grapple.reelCooldown then
		return false
	end

	if grapple.sharkTailDisable then
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

	grapple.jumpPadReel = true
	grapple.reelStart = now
	grapple.grappleReel = true
	recordMomentum(grapple, "SharkVoidAutoReel")
	Logic.LastAutoReelAt = now
	local holdTime = getNumber(controller.GrappleVoidRescueReelHoldTime, DEFAULT_REEL_HOLD, 0.05, 0.25)
	Logic.PendingEndAt = now + holdTime
	if ReleaseTiming and typeof(ReleaseTiming.schedule) == "function" then
		pcall(function()
			ReleaseTiming.schedule(grapple, "SharkVoid", holdTime, {
				Intent = "VoidRescue",
				EndWasCancelled = false,
			})
		end)
	end
	playReelSound(grapple)
	return true
end

local function autoEnd(grapple, now)
	if not Logic.PendingEndAt or now < Logic.PendingEndAt then
		return false
	end

	Logic.PendingEndAt = nil
	local movement = grapple and grapple.Movement
	if not (movement and movement.grappling == true and grapple.grappleReel == true) then
		return false
	end

	if not (ReleasePolicy and typeof(ReleasePolicy.release) == "function") then
		return false
	end

	local success = ReleasePolicy.release(grapple, "SharkVoid", {
		EndWasCancelled = false,
	})

	if success then
		if ReleaseTiming and typeof(ReleaseTiming.cancel) == "function" then
			ReleaseTiming.cancel(grapple)
		end
		recordMomentum(grapple, "SharkVoidAutoEnd")
	end

	return success
end

local function autoSharkTail(grapple, controller, now)
	if controller.GrappleVoidRescueAutoSharkTail == false then
		return false
	end

	if not (grapple and grapple.allowSharkTail == true) then
		if Logic.SharkTailWindowGrapple == grapple then
			Logic.SharkTailWindowGrapple = nil
			Logic.SharkTailWindowConsumed = false
		end
		return false
	end

	if Logic.SharkTailWindowGrapple ~= grapple then
		Logic.SharkTailWindowGrapple = grapple
		Logic.SharkTailWindowConsumed = false
	elseif Logic.SharkTailWindowConsumed == true then
		return false
	end

	if now - (Logic.LastSharkTailAt or 0) < RESCUE_COOLDOWN then
		return false
	end

	if grapple.sharkTailDisable == true then
		return false
	end

	if not (UpgradeGate and UpgradeGate.has(grapple.Movement, "SharkBelt")) then
		return false
	end

	if typeof(grapple.SharkTail) ~= "function" then
		return false
	end

	local success = pcall(function()
		grapple:SharkTail()
	end)

	if success then
		recordMomentum(grapple, "SharkVoidAutoSharkTail")
		Logic.LastSharkTailAt = now
		Logic.SharkTailWindowConsumed = true
	end

	return success
end

function Logic.step(grapple, _dt, controller, targeting)
	Logic.Controller = controller

	if not (controller and controller.GrappleVoidRescueEnabled == true) then
		Logic.PendingEndAt = nil
		return false
	end

	if not isDangerousFall(grapple, controller) then
		Logic.PendingEndAt = nil
		return false
	end

	if not hasRequiredUpgrades(grapple) then
		Logic.PendingEndAt = nil
		return false
	end

	local now = time()
	autoCast(grapple, targeting, now)
	autoEnd(grapple, now)
	autoSharkTail(grapple, controller, now)
	autoReel(grapple, controller, now)
	return true
end

function Logic.reset()
	Logic.PendingEndAt = nil
	Logic.LastAutoCastAt = 0
	Logic.LastAutoReelAt = 0
	Logic.LastSharkTailAt = 0
	Logic.LastVoidAnchorAt = 0
	Logic.SharkTailWindowGrapple = nil
	Logic.SharkTailWindowConsumed = false
	if ReleaseTiming and typeof(ReleaseTiming.cancel) == "function" then
		ReleaseTiming.cancel()
	end
end

return Logic
