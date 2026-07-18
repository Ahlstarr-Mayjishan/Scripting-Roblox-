--!nocheck
-- [[
--  NULLSCAPE - Gift Farm Run Policy
--  Owns run targets, AFK rests, repeat completion, and immunity handoff.
-- ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local ImmunityHandoff = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Immunity Handoff.luau")
local NoTracking = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/No Tracking.luau")
local RuleOverlay = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Rule Overlay.luau")
local RunLevelTracker = getgenv().loadModule("NULLSCAPE/Automation/RunLevelTracker.luau")

local RunPolicy = {}
local localPlayer = Players.LocalPlayer
local random = Random.new()

local state = {
	Enabled = false,
	ConfigSignature = nil,
	ActiveTarget = nil,
	CompletedRuns = 0,
	CompletedTarget = nil,
	AwaitingDeath = false,
	DeathConfirmed = false,
	AwaitingRunReset = false,
	CompletedRoundsSinceRest = 0,
	WaitUntil = nil,
	WaitRemaining = nil,
	WaitLevel = nil,
	Leaving = false,
	LeaveThread = nil,
	RulesSuspended = false,
}

local function getLevel()
	local levelValue = ReplicatedStorage:FindFirstChild("Level")
	return math.max(0, math.floor(tonumber(levelValue and levelValue.Value) or 0))
end

local function getNativeGoldenProgress()
	local counters = ReplicatedStorage:FindFirstChild("GiftCounters")
	local golden = counters and counters:FindFirstChild("GoldenGift")
	local handler = Context.getGiftClientHandler()
	local giftCount = handler and handler.GiftCount and handler.GiftCount.GoldenGift
	if not golden and not giftCount then
		return nil
	end

	local maximum = math.max(
		0,
		tonumber(golden and golden:GetAttribute("MaxGifts")) or 0,
		tonumber(giftCount and giftCount.Current) or 0,
		tonumber(giftCount and giftCount.Collected) or 0
	)
	local collected = math.max(
		0,
		tonumber(golden and golden:GetAttribute("Collected")) or 0,
		tonumber(giftCount and giftCount.Collected) or 0
	)
	return {
		GoldenMax = maximum,
		GoldenCollected = collected,
		GoldenProgressRatio = maximum > 0 and math.clamp(collected / maximum, 0, 1) or 0,
	}
end

local function getHumanoid()
	local character = localPlayer and localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function isDead()
	local deadValue = localPlayer and localPlayer:FindFirstChild("Dead")
	if deadValue and deadValue.Value == true then
		return true
	end
	local humanoid = getHumanoid()
	return humanoid ~= nil and humanoid.Health <= 0
end

local function isRespawnReady()
	local character = localPlayer and localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

local function formatDuration(seconds)
	local total = math.max(0, math.ceil(tonumber(seconds) or 0))
	local minutes = math.floor(total / 60)
	return string.format("%02d:%02d", minutes, total % 60)
end

local function getConfigSignature(controller)
	return table.concat({
		tostring(controller.GiftFarmGoalMode),
		tostring(controller.GiftFarmTargetLevel),
		tostring(controller.GiftFarmMinLevel),
		tostring(controller.GiftFarmMaxLevel),
	}, "|")
end

local function chooseTarget(controller)
	if controller.GiftFarmGoalMode == "Min-Max" then
		local maximum = math.max(0, math.floor(tonumber(controller.GiftFarmMaxLevel) or 50))
		if maximum == 0 then
			state.ActiveTarget = 0
			controller.GiftFarmActiveTargetLevel = 0
			return
		end

		local minimum = math.max(1, math.floor(tonumber(controller.GiftFarmMinLevel) or 10))
		if maximum < minimum then
			minimum, maximum = maximum, minimum
		end
		state.ActiveTarget = random:NextInteger(minimum, maximum)
	else
		state.ActiveTarget = math.max(0, math.floor(tonumber(controller.GiftFarmTargetLevel) or 100))
	end
	controller.GiftFarmActiveTargetLevel = state.ActiveTarget
end

local function resetRunState(controller, resetCompletedRuns)
	state.CompletedTarget = nil
	state.AwaitingDeath = false
	state.DeathConfirmed = false
	state.AwaitingRunReset = false
	state.WaitUntil = nil
	state.WaitRemaining = nil
	state.WaitLevel = nil
	NoTracking.reset()
	RunLevelTracker.reset()
	state.CompletedRoundsSinceRest = 0
	if resetCompletedRuns then
		state.CompletedRuns = 0
	end
	controller.GiftFarmCompletedRuns = state.CompletedRuns
	controller.GiftFarmPolicyHolding = false
	controller.GiftFarmRestPending = false
	chooseTarget(controller)
	RuleOverlay.hide()
end

local function syncConfiguration(controller)
	local signature = getConfigSignature(controller)
	if signature == state.ConfigSignature then
		return
	end
	state.ConfigSignature = signature
	ImmunityHandoff.restore()
	resetRunState(controller, true)
end

local function getWaitMinutes(controller, level)
	if level >= 50 then
		return math.clamp(tonumber(controller.GiftFarmWaitMinutes50Plus) or 20, 0, 30)
	elseif level >= 25 then
		return math.clamp(tonumber(controller.GiftFarmWaitMinutes25To49) or 10, 0, 30)
	elseif level >= 10 then
		return math.clamp(tonumber(controller.GiftFarmWaitMinutes10To24) or 5, 0, 30)
	end
	return 0
end

local function hold(controller, status, detail, overlayText)
	controller.GiftFarmPolicyHolding = true
	if overlayText then
		RuleOverlay.show(overlayText)
	end
	return {
		Hold = true,
		Status = status,
		Detail = detail,
	}
end

local function release(controller)
	controller.GiftFarmPolicyHolding = false
	RuleOverlay.hide()
	return { Hold = false }
end

local function performRuntimeGC()
	Context.releaseCharacterControl({
		SkipVelocityClear = true,
		SkipStateChange = true,
		ForceAbilityClear = true,
	})
	if typeof(collectgarbage) == "function" then
		pcall(collectgarbage, "collect")
	end
end

local function leaveGame(controller)
	if state.Leaving then
		return
	end
	state.Leaving = true
	controller.GiftFarmEnabled = false
	RuleOverlay.show(string.format("Gift Farm complete\n%d run(s) finished - leaving server", state.CompletedRuns))
	state.LeaveThread = task.delay(1, function()
		state.LeaveThread = nil
		if localPlayer then
			pcall(function()
				localPlayer:Kick("Gift Farm repeats complete")
			end)
		end
	end)
end

local function stepTargetLifecycle(controller)
	local level = getLevel()
	local repeatCount = math.max(0, math.floor(tonumber(controller.GiftFarmRepeatCount) or 0))
	if state.CompletedRuns > 0 and repeatCount > 0 and state.CompletedRuns >= repeatCount then
		leaveGame(controller)
		return hold(
			controller,
			"Completed",
			string.format("Completed %d/%d runs; leaving", state.CompletedRuns, repeatCount),
			string.format("Gift Farm complete\n%d/%d runs - leaving server", state.CompletedRuns, repeatCount)
		)
	end

	if state.AwaitingRunReset then
		if level < (state.CompletedTarget or math.huge) then
			state.CompletedTarget = nil
			state.AwaitingRunReset = false
			state.CompletedRoundsSinceRest = 0
			chooseTarget(controller)
			return release(controller)
		end
		return hold(
			controller,
			"WaitingForRunReset",
			string.format("Run %d complete; waiting for level reset", state.CompletedRuns),
			string.format("Run %d complete\nWaiting for the next run", state.CompletedRuns)
		)
	end

	if state.AwaitingDeath then
		if isDead() then
			state.DeathConfirmed = true
			return hold(
				controller,
				"WaitingForRespawn",
				"Death confirmed; waiting for respawn",
				"Death confirmed\nWaiting for respawn"
			)
		end

		if state.DeathConfirmed and isRespawnReady() then
			performRuntimeGC()
			ImmunityHandoff.restore()
			state.AwaitingDeath = false
			state.DeathConfirmed = false
			state.AwaitingRunReset = true
			return hold(
				controller,
				"RecoveringRun",
				"Respawned; immunity restored and runtime GC complete",
				"Respawn complete\nWaiting for level reset"
			)
		end

		return hold(
			controller,
			"TargetReached",
			string.format("Target level %d reached; immunity disabled", state.ActiveTarget or 0),
			string.format("Target level %d reached\nWaiting for death", state.ActiveTarget or 0)
		)
	end

	if not state.ActiveTarget then
		chooseTarget(controller)
	end
	if state.ActiveTarget == 0 then
		return nil
	end
	if level < (state.ActiveTarget or math.huge) then
		return nil
	end

	state.CompletedRuns += 1
	state.CompletedTarget = state.ActiveTarget
	state.WaitUntil = nil
	state.WaitRemaining = nil
	state.WaitLevel = nil
	controller.GiftFarmRestPending = false
	controller.GiftFarmCompletedRuns = state.CompletedRuns
	ImmunityHandoff.disable()
	performRuntimeGC()

	if repeatCount > 0 and state.CompletedRuns >= repeatCount then
		leaveGame(controller)
		return hold(
			controller,
			"Completed",
			string.format("Completed %d/%d runs; leaving", state.CompletedRuns, repeatCount),
			string.format("Gift Farm complete\n%d/%d runs - leaving server", state.CompletedRuns, repeatCount)
		)
	end

	state.AwaitingDeath = true
	return hold(
		controller,
		"TargetReached",
		string.format("Target level %d reached; immunity disabled", state.ActiveTarget),
		string.format("Target level %d reached\nWaiting for death", state.ActiveTarget)
	)
end

local function stepWait(controller)
	if not state.WaitLevel then
		return nil
	end

	local now = os.clock()
	if Context.isInRound() then
		if state.WaitUntil then
			state.WaitRemaining = math.max(0, state.WaitUntil - now)
			state.WaitUntil = nil
		end
		controller.GiftFarmRestPending = true
		return nil
	end

	if not state.WaitUntil then
		local remaining = math.max(0, tonumber(state.WaitRemaining) or 0)
		if remaining <= 0 then
			state.WaitRemaining = nil
			state.WaitLevel = nil
			controller.GiftFarmRestPending = false
			return release(controller)
		end
		state.WaitUntil = now + remaining
		performRuntimeGC()
	end

	local remaining = state.WaitUntil - now
	if remaining <= 0 then
		state.WaitUntil = nil
		state.WaitRemaining = nil
		state.WaitLevel = nil
		controller.GiftFarmRestPending = false
		return release(controller)
	end

	return hold(
		controller,
		"AFKWaiting",
		string.format("Level %d rest | %s remaining", state.WaitLevel or getLevel(), formatDuration(remaining)),
		string.format(
			"Gift Farm resting at level %d\nNext action in %s",
			state.WaitLevel or getLevel(),
			formatDuration(remaining)
		)
	)
end

local function stepCompletedRoundRest(controller, completion)
	if typeof(completion) ~= "table" then
		return nil
	end

	local level = math.max(0, math.floor(tonumber(completion.Level) or 0))
	local waitMinutes = getWaitMinutes(controller, level)
	if waitMinutes <= 0 then
		return nil
	end

	local threshold = math.clamp(tonumber(controller.GiftFarmGoldenEfficiency) or 100, 0, 100)
	if threshold <= 0 then
		return nil
	end

	local maximum = tonumber(completion.GoldenMax) or 0
	local collected = tonumber(completion.GoldenCollected) or 0
	local ratio = tonumber(completion.GoldenProgressRatio) or (maximum > 0 and collected / maximum or 0)
	if maximum <= 0 or ratio + 1e-6 < threshold / 100 then
		return nil
	end

	local everyRound = controller.GiftFarmRestMode == "Every Completed Round"
		or controller.GiftFarmRestMode == "Every Completed Level"
	if everyRound then
		state.CompletedRoundsSinceRest = 0
	else
		state.CompletedRoundsSinceRest += 1
		local interval = math.clamp(
			math.floor(tonumber(controller.GiftFarmRestIntervalRounds) or 5),
			1,
			30
		)
		if state.CompletedRoundsSinceRest < interval then
			return nil
		end
		state.CompletedRoundsSinceRest = 0
	end

	state.WaitLevel = level
	state.WaitRemaining = waitMinutes * 60
	state.WaitUntil = nil
	controller.GiftFarmRestPending = true
	return stepWait(controller)
end

local function suspendRules(controller)
	if state.LeaveThread then
		pcall(task.cancel, state.LeaveThread)
		state.LeaveThread = nil
	end
	if not state.RulesSuspended then
		ImmunityHandoff.restore()
		RuleOverlay.destroy()
		state.ConfigSignature = nil
		state.ActiveTarget = nil
		state.CompletedRuns = 0
		state.CompletedTarget = nil
		state.AwaitingDeath = false
		state.DeathConfirmed = false
		state.AwaitingRunReset = false
		state.WaitUntil = nil
		state.WaitRemaining = nil
		state.WaitLevel = nil
		state.Leaving = false
		NoTracking.reset()
		RunLevelTracker.reset()
		state.CompletedRoundsSinceRest = 0
		state.RulesSuspended = true
	end
	controller.GiftFarmCompletedRuns = 0
	controller.GiftFarmActiveTargetLevel = nil
	controller.GiftFarmRestPending = false
	return release(controller)
end

function RunPolicy.enable(controller)
	if not controller then
		return false
	end
	state.Enabled = true
	state.Leaving = false
	state.RulesSuspended = false
	if controller.GiftFarmRulesEnabled == true then
		syncConfiguration(controller)
	else
		suspendRules(controller)
	end
	return true
end

function RunPolicy.step(controller, scanInfo)
	if not (state.Enabled and controller and controller.GiftFarmEnabled and not controller.Destroyed) then
		return { Hold = false }
	end
	if controller.GiftFarmRulesEnabled ~= true then
		return suspendRules(controller)
	end

	state.RulesSuspended = false
	syncConfiguration(controller)
	local levelSnapshot = RunLevelTracker.update(
		getLevel(),
		Context.isInRound(),
		scanInfo,
		getNativeGoldenProgress()
	)
	controller.GiftFarmCurrentLevel = levelSnapshot.Level
	local noTracking = NoTracking.step(controller)
	if noTracking and noTracking.ResetComplete then
		state.CompletedRoundsSinceRest = 0
		RunLevelTracker.reset()
		chooseTarget(controller)
		return release(controller)
	end
	if noTracking and noTracking.Hold then
		state.WaitUntil = nil
		state.WaitRemaining = nil
		state.WaitLevel = nil
		controller.GiftFarmRestPending = false
		return hold(controller, noTracking.Status, noTracking.Detail, noTracking.OverlayText)
	end
	local lifecycle = stepTargetLifecycle(controller)
	if lifecycle and lifecycle.Hold then
		return lifecycle
	end
	local waiting = stepWait(controller)
	if waiting and waiting.Hold then
		return waiting
	end
	local completedRoundRest = stepCompletedRoundRest(controller, levelSnapshot.Completion)
	if completedRoundRest and completedRoundRest.Hold then
		return completedRoundRest
	end
	return release(controller)
end

function RunPolicy.disable(controller)
	state.Enabled = false
	if state.LeaveThread and not state.Leaving then
		pcall(task.cancel, state.LeaveThread)
		state.LeaveThread = nil
	end
	ImmunityHandoff.restore()
	RuleOverlay.destroy()
	state.ConfigSignature = nil
	state.ActiveTarget = nil
	state.CompletedRuns = 0
	state.CompletedTarget = nil
	state.AwaitingDeath = false
	state.DeathConfirmed = false
	state.AwaitingRunReset = false
	state.WaitUntil = nil
	state.WaitRemaining = nil
	state.WaitLevel = nil
	state.Leaving = false
	state.RulesSuspended = false
	NoTracking.reset()
	RunLevelTracker.reset()
	state.CompletedRoundsSinceRest = 0
	if controller then
		controller.GiftFarmCompletedRuns = 0
		controller.GiftFarmActiveTargetLevel = nil
		controller.GiftFarmCurrentLevel = 0
		controller.GiftFarmPolicyHolding = false
		controller.GiftFarmRestPending = false
	end
	return true
end

function RunPolicy.getState()
	return state
end

return RunPolicy
