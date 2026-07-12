--!nocheck
--[[
	NULLSCAPE - Anchor Action Profiles
	Scores anchors by their native movement consequence, not only by their position.
]]

local Workspace = game:GetService("Workspace")

local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")
local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")
local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")

local Profiles = {}

local function horizontal(vector)
	if typeof(vector) ~= "Vector3" then
		return Vector3.zero
	end
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return flat.Magnitude > 0.001 and flat.Unit or Vector3.zero
end

local function getVelocity(rootPart)
	return rootPart and (rootPart.AssemblyLinearVelocity or rootPart.Velocity) or Vector3.zero
end

local function isRail(part)
	return RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part)
end

local function voidY()
	local info = TerrainMemory and TerrainMemory.getVoidInfo and TerrainMemory.getVoidInfo()
	return info and info.Y or nil
end

local function triaScore(grapple, part, controller)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and part) then
		return -40, "TriaLaunch"
	end

	local moveDirection = grapple.Humanoid and grapple.Humanoid.MoveDirection or Vector3.zero
	local exitDirection = horizontal(moveDirection)
	if exitDirection.Magnitude <= 0.001 then
		exitDirection = horizontal(part.CFrame.LookVector)
	end
	local origin = part.Position + Vector3.new(0, 3, 0)
	local blocked = exitDirection.Magnitude > 0
		and Workspace:Raycast(origin, exitDirection * 18, grapple.grappleParams) ~= nil
	local score = blocked and -42 or 26

	local y = voidY()
	if y and part.Position.Y - y < (tonumber(controller and controller.GrappleVoidProtectionHeight) or 24) then
		score -= 24
	end
	return score, "TriaLaunch"
end

function Profiles.score(grapple, hit, part, controller, intent)
	if not (part and hit) then
		return 0, "Unknown"
	end

	local anchorName = SpecialAnchors and SpecialAnchors.getName(part) or nil
	local velocity = getVelocity(grapple and grapple.RootPart)
	local speed = velocity.Magnitude
	local brakeThreshold = math.clamp(tonumber(controller and controller.GrappleBrakeProfileSpeed) or 300, 200, 500)
	local toTarget = grapple and grapple.RootPart and horizontal(hit.Position - grapple.RootPart.Position)
		or Vector3.zero
	local velocityDirection = horizontal(velocity)
	local score = 0
	local profile = "TerrainFallback"

	if anchorName == "TriaOrb" then
		score, profile = triaScore(grapple, part, controller)
		if speed >= brakeThreshold then
			score -= 24
		end
		if intent and intent.Name == "VoidRescue" then
			score += 18
		end
	elseif anchorName == "JumpPad" then
		profile = "JumpPadLaunch"
		score += 18
	elseif anchorName == "GrapplePoint" then
		profile = "GrapplePointFlow"
		score += 14
	elseif anchorName == "Bell" then
		profile = "BellContact"
		score += 7
	elseif isRail(part) then
		profile = "RailEntry"
		score += 16
	end

	if speed >= brakeThreshold and velocityDirection.Magnitude > 0 and toTarget.Magnitude > 0 then
		local alignment = velocityDirection:Dot(toTarget)
		profile = "HighSpeedFlow"
		if alignment >= 0.45 then
			score += 28
		elseif alignment < 0.1 then
			score -= 32
		end
	end

	if intent and intent.Name == "VoidRescue" and hit.Position.Y >= (grapple.RootPart.Position.Y - 4) then
		score += 14
	end

	return score, profile
end

return Profiles
