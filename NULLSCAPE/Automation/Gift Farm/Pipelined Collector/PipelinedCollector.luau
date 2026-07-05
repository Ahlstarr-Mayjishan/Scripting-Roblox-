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

local foothold = nil
local footholdRemovalToken = 0
local pipelineToken = 0

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
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
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

local function waitForReplicationSync()
	RunService.Heartbeat:Wait()
	local waitTime = getOneWayLatency()
	if waitTime > 0 then
		task.wait(waitTime)
	end
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

	return (hrp.Position - targetPosition).Magnitude <= tolerance
end

local function isAborted(options)
	return options and typeof(options.AbortCheck) == "function" and options.AbortCheck() == true
end

function PipelinedCollector.cancelPending()
	pipelineToken += 1
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
		hrp.Anchored = false
		releaseHumanoidState(hrp)
		clearVelocity(hrp)
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
	local function shouldAbort()
		return routeToken ~= pipelineToken or isAborted(options)
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

			if arrived then
				local currentPos = hrp.Position
				task.spawn(function()
					if routeToken ~= pipelineToken then
						return
					end
					for _, item in ipairs(cluster) do
						if routeToken ~= pipelineToken then
							return
						end
						if item.rawObj
							and not item.rawObj.Destroyed
							and not item.rawObj.Collected
							and not item.rawObj.ClientCollected
							and Distance.isWithinRange(item.pos, currentPos, collectRange)
						then
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
				end)
			end

			if index < #route then
				if shouldAbort() then
					return
				end
				waitForReplicationSync()
			end
		end
	end)

	PipelinedCollector.releaseCharacter({
		KeepFootholdDuration = DISABLE_FOOTHOLD_DURATION,
		OnlyKeepFootholdIfAirborne = true,
	})

	if not ok then
		error(err, 0)
	end

	return true
end

return PipelinedCollector
