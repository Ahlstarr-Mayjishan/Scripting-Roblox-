--!nocheck
-- [[
--  NULLSCAPE - Pipelined Collector Submodule
--  Performs fast pipelined gift collection by scheduling remote fires
--  asynchronously and overlapping movement with one-way replication delays.
-- ]]

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Distance = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Distance.luau")

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local PipelinedCollector = {}
local FOOTHOLD_SIZE = Vector3.new(18, 1, 18)
local FOOTHOLD_OFFSET = Vector3.new(0, -3.6, 0)
local DISABLE_FOOTHOLD_DURATION = 2
local COLLECT_SETTLE_FRAMES = 1
local PRE_COLLECT_SYNC_MULTIPLIER = 0.75
local PRE_COLLECT_SYNC_MIN = 0.035
local PRE_COLLECT_SYNC_MAX = 0.11
local COLLECT_ACCEPTANCE_STEP = 0.01
local ADAPTIVE_MIN_MULTIPLIER = 0.85
local ADAPTIVE_MAX_MULTIPLIER = 1.9
local ADAPTIVE_FAILURE_STEP = 0.12
local ADAPTIVE_SUCCESS_STEP = 0.025
local TAIL_CLUSTER_SIZE = 2
local TAIL_HOLD_MULTIPLIER = 1.35
local MAX_RETRY_ITEMS = 24

local foothold = nil
local footholdRemovalToken = 0
local pipelineToken = 0
local acceptanceMultiplier = 1

local function getFoothold()
	if foothold and foothold.Parent then
		return foothold
	end

	foothold = Instance.new("Part")
	foothold.Name = "NULLSCAPE_PipelinedFoothold"
	foothold.Anchored = true
	foothold.CanCollide = true
	foothold.CanTouch = false
	foothold.CanQuery = false
	foothold.CastShadow = false
	foothold.Material = Enum.Material.SmoothPlastic
	foothold.Transparency = 1
	foothold.Size = FOOTHOLD_SIZE
	foothold.Parent = Workspace
	return foothold
end

local function placeFoothold(position)
	footholdRemovalToken += 1
	local part = getFoothold()
	part.CFrame = CFrame.new(position + FOOTHOLD_OFFSET)
	return part
end

local function removeFoothold(delaySeconds)
	local delayTime = tonumber(delaySeconds) or 0
	if delayTime > 0 and foothold and foothold.Parent then
		local token = footholdRemovalToken + 1
		footholdRemovalToken = token
		local part = foothold
		task.delay(delayTime, function()
			if footholdRemovalToken ~= token or foothold ~= part then
				return
			end
			if part and part.Parent then
				pcall(function()
					part:Destroy()
				end)
			end
			if foothold == part then
				foothold = nil
			end
		end)
		return
	end

	if foothold then
		footholdRemovalToken += 1
		pcall(function()
			foothold:Destroy()
		end)
		foothold = nil
	end
end

local function clearVelocity(hrp)
	if not (hrp and hrp.Parent) then
		return
	end
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
end

local function getHumanoid(hrp)
	local character = hrp and hrp.Parent
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function releaseHumanoidState(hrp)
	local humanoid = getHumanoid(hrp)
	if not humanoid then
		return
	end
	pcall(function()
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end)
end

local function hasGroundBelow(hrp)
	if not (hrp and hrp.Parent) then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { hrp.Parent, foothold }

	local result = Workspace:Raycast(hrp.Position, Vector3.new(0, -8, 0), params)
	return result ~= nil
end

local function normalizePingSeconds(value)
	local ping = tonumber(value)
	if not ping or ping <= 0 then
		return nil
	end
	if ping > 1 then
		ping /= 1000
	end
	return ping
end

local function getPingSeconds()
	local ok, result = pcall(function()
		if Stats.Network and typeof(Stats.Network.GetPing) == "function" then
			return Stats.Network:GetPing()
		end
		return nil
	end)
	local ping = ok and normalizePingSeconds(result) or nil
	if ping then
		return ping
	end

	ok, result = pcall(function()
		local serverStats = Stats.Network and Stats.Network:FindFirstChild("ServerStatsItem")
		local dataPing = serverStats and serverStats:FindFirstChild("Data Ping")
		if dataPing and typeof(dataPing.GetValue) == "function" then
			return dataPing:GetValue()
		end
		return nil
	end)
	return ok and normalizePingSeconds(result) or nil
end

local function getOneWayLatency()
	local ping = getPingSeconds() or 0.08
	return math.clamp(ping * 0.5, 0.03, 0.12)
end

local function waitForArrival(hrp, targetPosition, shouldAbort)
	if not (hrp and hrp.Parent and typeof(targetPosition) == "Vector3") then
		return false
	end

	local start = os.clock()
	local tolerance = 2.0
	while os.clock() - start <= 0.15 do
		if typeof(shouldAbort) == "function" and shouldAbort() then
			return false
		end
		if not (hrp and hrp.Parent) then
			return false
		end

		clearVelocity(hrp)
		local distance = (hrp.Position - targetPosition).Magnitude
		if distance <= tolerance then
			return true
		end

		Context.moveCharacterTo(CFrame.new(targetPosition))
		RunService.Heartbeat:Wait()
	end

	if typeof(shouldAbort) == "function" and shouldAbort() then
		return false
	end
	return (hrp.Position - targetPosition).Magnitude <= tolerance
end

local function settleBeforeCollect(hrp, shouldAbort)
	for _ = 1, COLLECT_SETTLE_FRAMES do
		if typeof(shouldAbort) == "function" and shouldAbort() then
			return false
		end
		clearVelocity(hrp)
		RunService.Heartbeat:Wait()
	end
	if typeof(shouldAbort) == "function" and shouldAbort() then
		return false
	end
	local syncWait = math.clamp(getOneWayLatency() * PRE_COLLECT_SYNC_MULTIPLIER, PRE_COLLECT_SYNC_MIN, PRE_COLLECT_SYNC_MAX)
	local startedAt = os.clock()
	while os.clock() - startedAt < syncWait do
		if typeof(shouldAbort) == "function" and shouldAbort() then
			return false
		end
		clearVelocity(hrp)
		task.wait(math.min(COLLECT_ACCEPTANCE_STEP, math.max(0, syncWait - (os.clock() - startedAt))))
	end
	clearVelocity(hrp)
	return true
end

local function collectCluster(routeToken, cluster, currentPos, collectRange, collectedEvent, stats)
	if routeToken ~= pipelineToken then
		return {}
	end

	local attempted = {}
	for _, item in ipairs(cluster) do
		if routeToken ~= pipelineToken then
			return attempted
		end
		if item.rawObj
			and not item.rawObj.Destroyed
			and not item.rawObj.Collected
			and not item.rawObj.ClientCollected
			and Distance.isWithinRange(item.pos, currentPos, collectRange)
		then
			table.insert(attempted, item)
			stats.Attempted += 1
			pcall(function()
				item.rawObj:Collect(false, true)
			end)
			if collectedEvent then
				pcall(function()
					collectedEvent:Fire()
				end)
			end
		end
	end

	return attempted
end

local function waitForCollectAcceptance(hrp, shouldAbort, attempted, clusterSize)
	if #attempted <= 0 then
		return true
	end

	local tailMultiplier = clusterSize <= TAIL_CLUSTER_SIZE and TAIL_HOLD_MULTIPLIER or 1
	local waitTime = getOneWayLatency() * acceptanceMultiplier * tailMultiplier
	local start = os.clock()
	while os.clock() - start < waitTime do
		if typeof(shouldAbort) == "function" and shouldAbort() then
			return false
		end
		clearVelocity(hrp)
		task.wait(math.min(COLLECT_ACCEPTANCE_STEP, math.max(0, waitTime - (os.clock() - start))))
	end

	if typeof(shouldAbort) == "function" and shouldAbort() then
		return false
	end
	clearVelocity(hrp)
	return true
end

local function updateAdaptiveAcceptance(stats)
	if stats.Attempted <= 0 then
		return
	end

	local failed = stats.Failed or 0
	if failed > 0 then
		acceptanceMultiplier = math.min(
			ADAPTIVE_MAX_MULTIPLIER,
			acceptanceMultiplier + ADAPTIVE_FAILURE_STEP * math.min(failed, 3)
		)
	else
		acceptanceMultiplier = math.max(ADAPTIVE_MIN_MULTIPLIER, acceptanceMultiplier - ADAPTIVE_SUCCESS_STEP)
	end
	stats.AcceptanceMultiplier = acceptanceMultiplier
end

local function noteAttemptResults(attempted, stats)
	for _, item in ipairs(attempted) do
		local rawObj = item.rawObj
		local accepted = rawObj
			and (rawObj.Destroyed or rawObj.Collected or rawObj.ClientCollected)
		if accepted then
			stats.Accepted += 1
		else
			stats.Failed += 1
			if #stats.Retry < MAX_RETRY_ITEMS then
				table.insert(stats.Retry, item)
			end
		end
	end
	updateAdaptiveAcceptance(stats)
end

local function isAborted(options)
	return options and typeof(options.AbortCheck) == "function" and options.AbortCheck() == true
end

function PipelinedCollector.cancelPending()
	pipelineToken += 1
end

function PipelinedCollector.resetAdaptive()
	acceptanceMultiplier = 1
end

function PipelinedCollector.releaseCharacter(options)
	options = options or {}
	if options.ForceRelease == true then
		PipelinedCollector.cancelPending()
	end

	local hrp = Context.getRootPart()
	local shouldKeepFoothold = options.KeepFootholdDuration
		and hrp
		and hrp.Parent
		and options.ForceRelease ~= true
		and (not options.OnlyKeepFootholdIfAirborne or not hasGroundBelow(hrp))
	if shouldKeepFoothold and (not foothold or not foothold.Parent) then
		placeFoothold(hrp.Position)
	end

	local keepDuration = nil
	if shouldKeepFoothold then
		keepDuration = options.KeepFootholdDuration
	end
	removeFoothold(keepDuration)
	if hrp and hrp.Parent then
		Context.releaseCharacterControl({
			SkipVelocityClear = options.SkipVelocityClear == true,
			SkipStateChange = options.SkipStateChange == true,
			State = Enum.HumanoidStateType.Running,
		})
	end
end

function PipelinedCollector.collectRoute(_controller, hrp, route, range, options)
	if not (hrp and hrp.Parent and route and route[1]) then
		return false
	end

	options = options or {}
	pipelineToken += 1
	local routeToken = pipelineToken
	local collectedEvent = Context.getCollectedGiftEvent()
	local stats = {
		Attempted = 0,
		Accepted = 0,
		Failed = 0,
		Retry = {},
		AcceptanceMultiplier = acceptanceMultiplier,
	}
	local function shouldAbort()
		return routeToken ~= pipelineToken
			or Context.getRootPart() ~= hrp
			or isAborted(options)
	end

	local ok, err = pcall(function()
		for index, step in ipairs(route) do
			if shouldAbort() then
				return
			end

			local cluster = step.Cluster or {}
			if #cluster == 0 then
				continue
			end

			local planInfo = step.Info
			local targetPosition = planInfo and planInfo.TargetPosition or (cluster[1] and cluster[1].pos)
			if not targetPosition then
				continue
			end

			local collectRange = planInfo and planInfo.SafeRange or range
			local standingPosition = Distance.getRootPosition(targetPosition)

			hrp.Anchored = false
			placeFoothold(standingPosition)
			Context.moveCharacterTo(CFrame.new(standingPosition))
			clearVelocity(hrp)

			local arrived = waitForArrival(hrp, standingPosition, shouldAbort)
			if shouldAbort() then
				return
			end

			local attempted = {}
			if arrived and settleBeforeCollect(hrp, shouldAbort) then
				attempted = collectCluster(routeToken, cluster, hrp.Position, collectRange, collectedEvent, stats)
			end
			if #attempted > 0 and not waitForCollectAcceptance(hrp, shouldAbort, attempted, #cluster) then
				return
			end
			noteAttemptResults(attempted, stats)
			if shouldAbort() then
				return
			end
		end
	end)

	if shouldAbort() then
		PipelinedCollector.releaseCharacter({
			ForceRelease = true,
		})
	else
		PipelinedCollector.releaseCharacter({
			KeepFootholdDuration = DISABLE_FOOTHOLD_DURATION,
			OnlyKeepFootholdIfAirborne = true,
		})
	end

	if not ok then
		error(err, 0)
	end

	return true, stats
end

return PipelinedCollector
