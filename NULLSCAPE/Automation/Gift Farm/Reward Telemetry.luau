--!nocheck
-- [[
--  Compact local reward telemetry for deriving server-side XP/Tripcoin rewards.
--  One bounded file is overwritten for each Gift Farm runtime.
-- ]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Progress.luau")
local RuntimeBudget = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Runtime Budget.luau")

local Telemetry = {}
local OUTPUT_FOLDER = "NULLSCAPE/telemetry"
local OUTPUT_FILE = OUTPUT_FOLDER .. "/gift_farm_reward_runtime.json"
local MAX_RECORDS = 128
local REPLICA_WAIT_TIMEOUT = 4
local REPLICA_POLL_INTERVAL = 0.25
local REPLICA_STABLE_TIME = 0.75
local REPLICA_MIN_WAIT = 2
local OBSERVE_INTERVAL = RuntimeBudget.Telemetry.ObserveInterval

local runtimeName = nil
local document = nil
local activeRound = nil
local pendingGeneration = 0
local moduleCache = {}
local lastObserveAt = -math.huge

local function utcTimestamp()
	local ok, value = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ")
	return ok and value or tostring(os.time())
end

local function createRuntimeName()
	local ok, stamp = pcall(os.date, "!%Y%m%dT%H%M%SZ")
	stamp = ok and stamp or tostring(os.time())
	return string.format("GiftFarm-%s-%04d", stamp, math.random(0, 9999))
end

local function safeRequire(pathSegments)
	local key = table.concat(pathSegments, "/")
	if moduleCache[key] then
		return moduleCache[key]
	end

	local cursor = ReplicatedFirst
	for _, segment in ipairs(pathSegments) do
		cursor = cursor and cursor:FindFirstChild(segment)
		if not cursor then
			return nil
		end
	end
	if not cursor:IsA("ModuleScript") then
		return nil
	end

	local ok, result = pcall(require, cursor)
	if ok and typeof(result) == "table" then
		moduleCache[key] = result
		return result
	end
	return nil
end

local function readNumberValue(name)
	local value = ReplicatedStorage:FindFirstChild(name)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
		return tonumber(value.Value) or 0
	end
	return 0
end

local function getClassId()
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local classId = character and character:GetAttribute("Class")
	return typeof(classId) == "string" and classId or "Unknown"
end

local function captureRewards()
	local statisticsHandler = safeRequire({ "ClientModules", "Core", "PlayerData", "StatisticsHandler" })
	local inventoryHandler = safeRequire({ "ClientModules", "Core", "PlayerData", "InventoryHandler" })
	local statistics = nil
	if statisticsHandler and typeof(statisticsHandler.GetStatistics) == "function" then
		pcall(function()
			statistics = statisticsHandler.GetStatistics()
		end)
	end

	local classId = getClassId()
	local tripcoins = 0
	local tripcoinsReady = false
	if inventoryHandler and typeof(inventoryHandler.GetTripcoins) == "function" then
		pcall(function()
			local value = tonumber(inventoryHandler.GetTripcoins())
			if value ~= nil then
				tripcoins = value
				tripcoinsReady = true
			end
		end)
	end
	local statisticsReady = typeof(statistics) == "table" and tonumber(statistics.XP) ~= nil
	local classXPReady = statisticsReady and classId ~= "Unknown" and typeof(statistics.ClassXP) == "table"

	return {
		Ready = statisticsReady and tripcoinsReady,
		XP = tonumber(statistics and statistics.XP) or 0,
		ClassId = classId,
		ClassXPReady = classXPReady,
		ClassXP = tonumber(statistics and statistics.ClassXP and statistics.ClassXP[classId]) or 0,
		Tripcoins = tripcoins,
	}
end

local function captureGifts(giftClientHandler)
	local normalCollected, normalMax = Progress.getNormalGiftProgress(giftClientHandler)
	local goldenCollected, goldenMax = Progress.getGoldenGiftProgress(giftClientHandler)
	return {
		Normal = math.max(0, tonumber(normalCollected) or 0),
		NormalMax = math.max(0, tonumber(normalMax) or 0),
		Golden = math.max(0, tonumber(goldenCollected) or 0),
		GoldenMax = math.max(0, tonumber(goldenMax) or 0),
	}
end

local function rewardsEqual(left, right)
	return left.Ready == right.Ready
		and left.XP == right.XP
		and left.ClassXP == right.ClassXP
		and left.Tripcoins == right.Tripcoins
end

local function writeDocument()
	if not (document and writefile) then
		return false
	end
	document.UpdatedAt = utcTimestamp()
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, document)
	if not ok then
		return false
	end
	if makefolder then
		pcall(makefolder, "NULLSCAPE")
		pcall(makefolder, OUTPUT_FOLDER)
	end
	return pcall(writefile, OUTPUT_FILE, encoded)
end

local function ensureRuntime(controller)
	if document then
		return
	end
	runtimeName = createRuntimeName()
	document = {
		Schema = 2,
		RuntimeName = runtimeName,
		StartedAt = utcTimestamp(),
		Records = {},
	}
	if controller then
		controller.GiftFarmTelemetryRuntimeName = runtimeName
		controller.GiftFarmTelemetryPath = OUTPUT_FILE
	end
	writeDocument()
	print("[GiftFarmTelemetry] runtime=" .. runtimeName .. " file=" .. OUTPUT_FILE)
end

function Telemetry.start(controller)
	ensureRuntime(controller)
	return runtimeName
end

function Telemetry.beginRound(controller, giftClientHandler)
	ensureRuntime(controller)
	lastObserveAt = -math.huge
	activeRound = {
		RuntimeName = runtimeName,
		Level = readNumberValue("Level"),
		Difficulty = readNumberValue("Difficulty"),
		Mode = controller and controller.GiftFarmMode or "Unknown",
		StartedAt = utcTimestamp(),
		Before = captureRewards(),
		GiftsAtStart = captureGifts(giftClientHandler),
	}
	activeRound.GiftsPeak = table.clone(activeRound.GiftsAtStart)
	return true
end

function Telemetry.observeRound(giftClientHandler)
	if not activeRound then
		return false
	end
	local now = os.clock()
	if now - lastObserveAt < OBSERVE_INTERVAL then
		return true
	end
	lastObserveAt = now
	local gifts = captureGifts(giftClientHandler)
	local peak = activeRound.GiftsPeak
	peak.Normal = math.max(peak.Normal, gifts.Normal)
	peak.NormalMax = math.max(peak.NormalMax, gifts.NormalMax)
	peak.Golden = math.max(peak.Golden, gifts.Golden)
	peak.GoldenMax = math.max(peak.GoldenMax, gifts.GoldenMax)
	return true
end

function Telemetry.observePerformance(metrics)
	if not activeRound or typeof(metrics) ~= "table" then
		return false
	end
	activeRound.Performance = metrics
	return true
end

function Telemetry.endRound(controller, giftClientHandler)
	if not activeRound then
		return false
	end

	local round = activeRound
	activeRound = nil
	local generation = pendingGeneration
	local giftsAtEnd = captureGifts(giftClientHandler)
	local giftPeak = round.GiftsPeak
	giftPeak.Normal = math.max(giftPeak.Normal, giftsAtEnd.Normal)
	giftPeak.NormalMax = math.max(giftPeak.NormalMax, giftsAtEnd.NormalMax)
	giftPeak.Golden = math.max(giftPeak.Golden, giftsAtEnd.Golden)
	giftPeak.GoldenMax = math.max(giftPeak.GoldenMax, giftsAtEnd.GoldenMax)
	local immediateRewards = captureRewards()

	task.spawn(function()
		local waitStartedAt = os.clock()
		local deadline = os.clock() + REPLICA_WAIT_TIMEOUT
		local stableSince = os.clock()
		local latest = immediateRewards
		repeat
			task.wait(REPLICA_POLL_INTERVAL)
			if generation ~= pendingGeneration then
				return
			end
			local nextRewards = captureRewards()
			if rewardsEqual(latest, nextRewards) then
				if
					os.clock() - waitStartedAt >= REPLICA_MIN_WAIT
					and os.clock() - stableSince >= REPLICA_STABLE_TIME
				then
					latest = nextRewards
					break
				end
			else
				latest = nextRewards
				stableSince = os.clock()
			end
		until os.clock() >= deadline

		round.EndedAt = utcTimestamp()
		round.Gifts = {
			Normal = math.max(0, giftPeak.Normal - round.GiftsAtStart.Normal),
			NormalMax = giftPeak.NormalMax,
			Golden = math.max(0, giftPeak.Golden - round.GiftsAtStart.Golden),
			GoldenMax = giftPeak.GoldenMax,
		}
		round.GiftsAtStart = nil
		round.GiftsPeak = nil
		round.After = latest
		local rewardsValid = round.Before.Ready == true and latest.Ready == true
		local classXPValid = rewardsValid
			and round.Before.ClassXPReady == true
			and latest.ClassXPReady == true
			and round.Before.ClassId == latest.ClassId
		round.Delta = {
			Valid = rewardsValid,
			XP = latest.XP - round.Before.XP,
			ClassXPValid = classXPValid,
			ClassXP = latest.ClassXP - round.Before.ClassXP,
			Tripcoins = latest.Tripcoins - round.Before.Tripcoins,
		}

		local records = document and document.Records
		if not records then
			return
		end
		table.insert(records, round)
		while #records > MAX_RECORDS do
			table.remove(records, 1)
		end
		writeDocument()
		if controller then
			controller.GiftFarmTelemetryRuntimeName = runtimeName
			controller.GiftFarmTelemetryPath = OUTPUT_FILE
		end
	end)
	return true
end

function Telemetry.stop()
	pendingGeneration += 1
	activeRound = nil
	lastObserveAt = -math.huge
	writeDocument()
	return true
end

function Telemetry.getRuntimeName()
	return runtimeName
end

return Telemetry
