--!nocheck

local Workspace = game:GetService("Workspace")
local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")
local ReleaseTiming = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Timing Helper.luau")
local UpgradeGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Upgrade Gate.luau")

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
	if typeof(hitResult) ~= "table" then
		return false
	end

	if isKillVoidPart(hitResult.Instance) then
		return true
	end

	return isVoidPoint(hitResult.Position)
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

	local hitResult
	if typeof(grapple.Cast) == "function" then
		local success, result = pcall(function()
			return grapple:Cast(true)
		end)
		if success then
			hitResult = result
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

	local success = pcall(function()
		grapple:Start(hitResult)
	end)

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

	if typeof(grapple.End) ~= "function" then
		return false
	end

	local success = pcall(function()
		grapple:End()
	end)

	if success then
		recordMomentum(grapple, "SharkVoidAutoEnd")
	end

	return success
end

local function autoSharkTail(grapple, controller, now)
	if controller.GrappleVoidRescueAutoSharkTail == false then
		return false
	end

	if now - (Logic.LastSharkTailAt or 0) < RESCUE_COOLDOWN then
		return false
	end

	if not (grapple and grapple.allowSharkTail == true and grapple.sharkTailDisable ~= true) then
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
	end

	return success
end

function Logic.step(grapple, _dt, controller, targeting)
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
	autoSharkTail(grapple, controller, now)
	autoEnd(grapple, now)
	autoReel(grapple, controller, now)
	return true
end

function Logic.reset()
	Logic.PendingEndAt = nil
	Logic.LastAutoCastAt = 0
	Logic.LastAutoReelAt = 0
	Logic.LastSharkTailAt = 0
	Logic.LastVoidAnchorAt = 0
	if ReleaseTiming and typeof(ReleaseTiming.cancel) == "function" then
		ReleaseTiming.cancel()
	end
end

return Logic
