--!nocheck
-- [[
--  NULLSCAPE - Grapple Range Adjustment
-- ]]

local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Range = {}

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")
local VoidCastAssist = getgenv().loadModule("NULLSCAPE/Class Adjustment/Grappler/Grapple Void Cast Assist.luau")

local function recordRangeCast(grapple)
	if MomentumMemory and typeof(MomentumMemory.record) == "function" then
		pcall(MomentumMemory.record, grapple and grapple.RootPart, "GrappleRangeCast")
	end
end

function Range.cast(grapple, forceRefresh, originalCast, ...)
	local Control = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	local rangeSetting = Control and tonumber(Control.GrappleMaxRange) or 90
	local maxRange = rangeSetting <= 0 and 5000 or rangeSetting
	local easierVoidCast = Control and Control.GrappleEasierVoidCast == true

	-- If all range/cast assists are at native values, call the original cast function.
	if maxRange <= 90 and not easierVoidCast then
		return originalCast(grapple, forceRefresh, ...)
	end

	grapple.grappleParams.FilterDescendantsInstances = grapple.Movement.moveCastParams.FilterDescendantsInstances

	-- Memory hit check
	if not (time() - grapple.memoryUpdate > 0.25 or forceRefresh) then
		local Position = grapple.RootPart.Position
		local direction = CFrame.lookAt(Position, grapple.memoryPosition).LookVector
		local hit = Workspace:Raycast(Position, direction * maxRange, grapple.grappleParams)
		if hit then
			recordRangeCast(grapple)
			return hit
		end
		if easierVoidCast and VoidCastAssist and typeof(VoidCastAssist.find) == "function" then
			local voidHit = VoidCastAssist.find(grapple, direction, maxRange)
			if voidHit then
				recordRangeCast(grapple)
				return voidHit
			end
		end
		return nil
	end

	local targetPos
	local aimDirection
	local preferredInput = grapple.Movement.preferredInput
	local CurrentCamera = Workspace.CurrentCamera

	local isLockCenter = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		or (preferredInput ~= Enum.PreferredInput.KeyboardAndMouse)

	if isLockCenter then
		-- Shift-Lock, Mobile, or Controller path
		local rayOrigin = (CurrentCamera.CFrame * grapple.cameraOffset).Position
			+ CurrentCamera.CFrame.LookVector
				* (CurrentCamera.CFrame.Position - (grapple.RootPart.Position + grapple.Humanoid.CameraOffset)).Magnitude

		local cameraHit =
			Workspace:Raycast(rayOrigin, CurrentCamera.CFrame.LookVector * maxRange, grapple.grappleParams)
		if cameraHit == nil then
			aimDirection = CurrentCamera.CFrame.LookVector
			if easierVoidCast and VoidCastAssist and typeof(VoidCastAssist.find) == "function" then
				local voidHit = VoidCastAssist.find(grapple, aimDirection, maxRange)
				if voidHit then
					recordRangeCast(grapple)
					return voidHit
				end
			end
			return nil, aimDirection
		end
		targetPos = cameraHit.Position
		aimDirection = CurrentCamera.CFrame.LookVector
	else
		-- Unlocked Mouse pointer path
		local unitRay = LocalPlayer:GetMouse().UnitRay
		local mouseHit =
			Workspace:Raycast(unitRay.Origin, unitRay.Direction.Unit * math.max(2048, maxRange), grapple.grappleParams)

		if mouseHit == nil then
			aimDirection = unitRay.Direction.Unit
			if easierVoidCast and VoidCastAssist and typeof(VoidCastAssist.find) == "function" then
				local voidHit = VoidCastAssist.find(grapple, aimDirection, maxRange)
				if voidHit then
					recordRangeCast(grapple)
					return voidHit
				end
			end
			return nil, aimDirection
		end
		targetPos = mouseHit.Position
		aimDirection = unitRay.Direction.Unit
	end

	local Position = grapple.RootPart.Position
	local castDirection = CFrame.lookAt(Position, targetPos).LookVector
	local hit = Workspace:Raycast(Position, castDirection * maxRange, grapple.grappleParams)
	if hit then
		recordRangeCast(grapple)
		return hit
	end

	if easierVoidCast and VoidCastAssist and typeof(VoidCastAssist.find) == "function" then
		local voidHit = VoidCastAssist.find(grapple, aimDirection or castDirection, maxRange)
		if voidHit then
			recordRangeCast(grapple)
			return voidHit
		end
	end
	return nil
end

return Range
