--!nocheck
--[[
	NULLSCAPE - Gift Farm Transport
	Replication-aware character transport with adaptive waypoint spacing.
]]

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local Transport = {}

local DEFAULT_STEP = 96
local MIN_STEP = 72
local MAX_STEP = 120
local DIRECT_DISTANCE = 64
local WAYPOINT_TOLERANCE = 6
local MAX_WAYPOINT_FAILURES = 2

local stepDistance = DEFAULT_STEP
local cleanBatches = 0

local function shouldStop(abortCheck)
	return typeof(abortCheck) == "function" and abortCheck() == true
end

local function moveOnce(cframe)
	if not Context.moveCharacterTo(cframe) then
		return false
	end

	local hrp = Context.getRootPart()
	return hrp ~= nil and hrp.Parent ~= nil
end

function Transport.moveTo(cframe, abortCheck)
	if typeof(cframe) == "Vector3" then
		cframe = CFrame.new(cframe)
	end
	if typeof(cframe) ~= "CFrame" or shouldStop(abortCheck) then
		return false
	end

	local hrp = Context.getRootPart()
	if not (hrp and hrp.Parent) then
		return false
	end

	local targetPosition = cframe.Position
	local remaining = targetPosition - hrp.Position
	if remaining.Magnitude <= DIRECT_DISTANCE then
		return moveOnce(cframe)
	end

	local failedWaypoints = 0
	while remaining.Magnitude > stepDistance do
		if shouldStop(abortCheck) then
			return false
		end

		hrp = Context.getRootPart()
		if not (hrp and hrp.Parent) then
			return false
		end

		local waypoint = hrp.Position + remaining.Unit * stepDistance
		if not moveOnce(CFrame.new(waypoint)) then
			return false
		end

		hrp = Context.getRootPart()
		if not (hrp and hrp.Parent) then
			return false
		end

		if (hrp.Position - waypoint).Magnitude > WAYPOINT_TOLERANCE then
			failedWaypoints += 1
			stepDistance = math.max(MIN_STEP, stepDistance * 0.8)
			if failedWaypoints >= MAX_WAYPOINT_FAILURES then
				return false
			end
		else
			failedWaypoints = 0
		end

		remaining = targetPosition - hrp.Position
	end

	if shouldStop(abortCheck) then
		return false
	end
	return moveOnce(cframe)
end

function Transport.reportCollectResult(attempted, rejected)
	local attempts = math.max(0, tonumber(attempted) or 0)
	local rejects = math.clamp(tonumber(rejected) or 0, 0, attempts)
	if attempts <= 0 then
		return
	end

	if rejects > 0 then
		cleanBatches = 0
		local rejectRatio = rejects / attempts
		stepDistance = math.max(MIN_STEP, stepDistance * (1 - math.min(0.25, 0.12 + rejectRatio * 0.2)))
		return
	end

	cleanBatches += 1
	if cleanBatches >= 6 then
		cleanBatches = 0
		stepDistance = math.min(MAX_STEP, stepDistance + 4)
	end
end

function Transport.reset()
	stepDistance = DEFAULT_STEP
	cleanBatches = 0
end

function Transport.getStepDistance()
	return stepDistance
end

return Transport
