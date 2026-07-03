--!nocheck

local RunService = game:GetService("RunService")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Scanner = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Scanner.luau")
local Collector = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Collector.luau")
local ClusterPlanner = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Cluster Planner.luau")
local Progress = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Progress.luau")

local Runtime = {}
local DEFAULT_RANGE = 60
local MIN_SCAN_INTERVAL = 0.12
local EMPTY_COMPLETE_DELAY = 2.5

local enabled = false
local busy = false
local connection = nil
local inRoundConnection = nil
local lastScan = 0
local lastGiftSeenAt = 0
local beaconReturnDone = false
local hasSeenGoldenThisRound = false

local function setStatus(controller, status, detail)
	if controller then
		controller.GiftFarmStatus = status or "Idle"
		controller.GiftFarmDetail = detail or ""
	end
end

local function resetRoundState(controller, inRound)
	busy = false
	lastScan = 0
	lastGiftSeenAt = 0
	beaconReturnDone = false
	hasSeenGoldenThisRound = false
	if Scanner and typeof(Scanner.reset) == "function" then
		Scanner.reset()
	end
	if inRound then
		setStatus(controller, "WaitingForGifts", "Round started")
	else
		setStatus(controller, "WaitingForRound", "Round ended")
	end
end

local function observeInRound(controller, gc)
	local inRound = Context.getInRoundValue()
	if not inRound then
		setStatus(controller, "WaitingForGifts")
		return
	end

	resetRoundState(controller, inRound.Value == true)
	inRoundConnection = inRound.Changed:Connect(function(value)
		if not enabled or not controller or controller.Destroyed then
			return
		end
		resetRoundState(controller, value == true)
	end)

	if gc and typeof(gc.registerConnection) == "function" then
		gc.registerConnection(inRoundConnection)
	end
end

local function returnToBeacon(controller, hrp, reason)
	if beaconReturnDone or controller.GiftFarmReturnToBeaconAfterGolden == false then
		return false
	end
	if not Context.isBeaconActive() then
		return false
	end

	local beacon = Context.getBeaconPart()
	if not (beacon and hrp and hrp.Parent) then
		return false
	end

	beaconReturnDone = true
	hrp.CFrame = CFrame.new(beacon.Position + Vector3.new(0, 4, 0))
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
	setStatus(controller, "ReturningToBeacon", reason or "Golden gifts complete")
	return true
end

local function processOnce(controller)
	if not enabled or busy or not controller or controller.Destroyed then
		return
	end

	local now = os.clock()
	if now - lastScan < MIN_SCAN_INTERVAL then
		return
	end
	lastScan = now
	busy = true

	task.spawn(function()
		local ok, err = pcall(function()
			if not Context.isInRound() then
				setStatus(controller, "WaitingForRound")
				return
			end

			local hrp = Context.getRootPart()
			if not hrp then
				setStatus(controller, "WaitingForCharacter")
				return
			end

			if controller.PylonActivatorHolding == true then
				setStatus(controller, "PausedForPylon", "Pylon activation has movement priority")
				return
			end

			local gch = Context.getGiftClientHandler()
			if not (gch and gch.Gifts) then
				setStatus(controller, "WaitingForGiftClient")
				return
			end

			local candidates, scanInfo = Scanner.scan(controller, gch)
			if scanInfo and scanInfo.RawGolden and scanInfo.RawGolden > 0 then
				hasSeenGoldenThisRound = true
			end
			if lastGiftSeenAt > 0 and hasSeenGoldenThisRound and scanInfo and scanInfo.RawGolden == 0 then
				if returnToBeacon(controller, hrp, "Golden gifts complete") then
					return
				end
			end

			if #candidates == 0 then
				if lastGiftSeenAt > 0 and os.clock() - lastGiftSeenAt >= EMPTY_COMPLETE_DELAY then
					if returnToBeacon(controller, hrp, "Round targets complete") then
						return
					end
					setStatus(controller, "RoundCompleteWatching")
				else
					setStatus(controller, "WaitingForGifts")
				end
				return
			end

			lastGiftSeenAt = os.clock()
			local range = DEFAULT_RANGE
			if typeof(controller.GetGiftFarmRange) == "function" then
				range = controller:GetGiftFarmRange()
			else
				range = math.clamp(tonumber(controller.GiftFarmRange) or DEFAULT_RANGE, 5, DEFAULT_RANGE)
			end
			local cluster, planInfo = ClusterPlanner.pickBestCluster(candidates, range, hrp.Position)
			local burstLimit = math.clamp(tonumber(controller.GiftFarmBurstSize) or 16, 1, 60)
			while #cluster > burstLimit do
				table.remove(cluster)
			end

			local focus = scanInfo and scanInfo.GoldenLocked and "golden" or "gifts"
			local score = planInfo and planInfo.Score
			local planned = score and (" | plan " .. tostring(score.Golden) .. "/" .. tostring(score.Total)) or ""
			setStatus(controller, "Collecting", tostring(#cluster) .. " " .. focus .. planned)
			Collector.collectCluster(controller, hrp, cluster, range)

			local normalCollected, normalTotal, normalRatio = Progress.getNormalGiftProgress(gch)
			local goldenText = scanInfo and (" | Golden " .. tostring(scanInfo.Golden or 0)) or ""
			setStatus(
				controller,
				"Rescanning",
				string.format("Normal %d/%d (%.0f%%)", normalCollected, normalTotal, normalRatio * 100) .. goldenText
			)
		end)

		if not ok then
			setStatus(controller, "Error", tostring(err))
		end
		busy = false
	end)
end

function Runtime.enable(controller, gc)
	if enabled then
		return true
	end

	enabled = true
	observeInRound(controller, gc)
	connection = RunService.Heartbeat:Connect(function()
		if controller and controller.GiftFarmEnabled then
			processOnce(controller)
		end
	end)
	if gc and typeof(gc.registerConnection) == "function" then
		gc.registerConnection(connection)
	end
	return true
end

function Runtime.disable(controller)
	enabled = false
	busy = false
	if Collector and typeof(Collector.restoreMovement) == "function" then
		Collector.restoreMovement()
	end
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
		connection = nil
	end
	if inRoundConnection then
		pcall(function()
			inRoundConnection:Disconnect()
		end)
		inRoundConnection = nil
	end
	resetRoundState(controller, false)
	setStatus(controller, "Idle")
	return true
end

function Runtime.update(controller, gc)
	if controller and controller.GiftFarmEnabled then
		return Runtime.enable(controller, gc)
	end
	return Runtime.disable(controller)
end

function Runtime.getStatus(controller)
	return {
		Status = controller and controller.GiftFarmStatus or "Idle",
		Detail = controller and controller.GiftFarmDetail or "",
	}
end

return Runtime
