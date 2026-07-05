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

local PipelinedCollector = {}
local FOOTHOLD_SIZE = Vector3.new(18, 1, 18)
local FOOTHOLD_OFFSET = Vector3.new(0, -3.6, 0)
local DISABLE_FOOTHOLD_DURATION = 2

local foothold = nil
local footholdRemovalToken = 0

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
	foothold.Parent = workspace
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
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end)
end

local function getOneWayLatency()
	local ping = 0.06
	pcall(function()
		local rawPing = Stats.Network:GetPing()
		if rawPing > 0 then
			ping = (rawPing > 1 and rawPing / 1000 or rawPing)
		end
	end)
	return math.clamp(ping * 0.5, 0.025, 0.075)
end

local function waitForReplicationSync()
	RunService.Heartbeat:Wait()
	RunService.RenderStepped:Wait()
	local waitTime = getOneWayLatency()
	if waitTime > 0 then
		task.wait(waitTime)
	end
end

local function waitForArrival(hrp, targetPosition)
	if not (hrp and hrp.Parent and typeof(targetPosition) == "Vector3") then
		return false
	end

	local start = os.clock()
	local tolerance = 2.0
	while os.clock() - start <= 0.15 do
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

function PipelinedCollector.releaseCharacter(options)
	options = options or {}
	local hrp = Context.getRootPart()
	local shouldKeepFoothold = options.KeepFootholdDuration and hrp and hrp.Parent
	if shouldKeepFoothold and (not foothold or not foothold.Parent) then
		placeFoothold(hrp.Position)
	end

	removeFoothold(shouldKeepFoothold and options.KeepFootholdDuration or nil)
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
	local collectedEvent = Context.getCollectedGiftEvent()

	local ok, err = pcall(function()
		for index, step in ipairs(route) do
			if isAborted(options) then
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

			waitForArrival(hrp, standingPosition)
			if isAborted(options) then
				return
			end

			local currentPos = hrp.Position
			task.spawn(function()
				for _, item in ipairs(cluster) do
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

			if index < #route then
				waitForReplicationSync()
			end
		end
	end)

	PipelinedCollector.releaseCharacter({
		KeepFootholdDuration = DISABLE_FOOTHOLD_DURATION,
	})

	if not ok then
		error(err, 0)
	end

	return true
end

return PipelinedCollector
