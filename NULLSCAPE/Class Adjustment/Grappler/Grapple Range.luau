--!nocheck
-- [[
--  NULLSCAPE - Grapple Range Adjustment
-- ]]

local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Range = {}

function Range.cast(grapple, forceRefresh, originalCast, ...)
	local Control = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	local maxRange = Control and Control.GrappleMaxRange or 90

	-- If range is set to default (90), call the original cast function
	if maxRange <= 90 then
		return originalCast(grapple, forceRefresh, ...)
	end

	grapple.grappleParams.FilterDescendantsInstances = grapple.Movement.moveCastParams.FilterDescendantsInstances

	-- Memory hit check
	if not (time() - grapple.memoryUpdate > 0.25 or forceRefresh) then
		local Position = grapple.RootPart.Position
		return Workspace:Raycast(Position, CFrame.lookAt(Position, grapple.memoryPosition).LookVector * maxRange, grapple.grappleParams)
	end

	local targetPos
	local preferredInput = grapple.Movement.preferredInput
	local CurrentCamera = Workspace.CurrentCamera

	local isLockCenter = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		or (preferredInput ~= Enum.PreferredInput.KeyboardAndMouse)

	if isLockCenter then
		-- Shift-Lock, Mobile, or Controller path
		local rayOrigin = (CurrentCamera.CFrame * grapple.cameraOffset).Position
			+ CurrentCamera.CFrame.LookVector * (CurrentCamera.CFrame.Position - (grapple.RootPart.Position + grapple.Humanoid.CameraOffset)).Magnitude
		
		local cameraHit = Workspace:Raycast(rayOrigin, CurrentCamera.CFrame.LookVector * maxRange, grapple.grappleParams)
		if cameraHit == nil then
			return nil
		end
		targetPos = cameraHit.Position
	else
		-- Unlocked Mouse pointer path
		local unitRay = LocalPlayer:GetMouse().UnitRay
		local mouseHit = Workspace:Raycast(unitRay.Origin, unitRay.Direction.Unit * 2048, grapple.grappleParams)
		
		if mouseHit == nil then
			return nil, unitRay.Direction.Unit
		end
		targetPos = mouseHit.Position
	end

	local Position = grapple.RootPart.Position
	return Workspace:Raycast(Position, CFrame.lookAt(Position, targetPos).LookVector * maxRange, grapple.grappleParams)
end

return Range
