--!nocheck

local Progress = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NORMAL_PACING_START = 0.7
local NORMAL_PACING_FULL = 0.9
local NORMAL_PACING_MAX_BATCH = 8
local NORMAL_PACING_MIN_BATCH = 2

local function getGiftProgress(gch, giftType)
	local giftCount = gch and gch.GiftCount and gch.GiftCount[giftType]
	local collected = tonumber(giftCount and giftCount.Collected) or 0
	local current = tonumber(giftCount and giftCount.Current) or 0
	local counters = ReplicatedStorage:FindFirstChild("GiftCounters")
	local giftCounter = counters and counters:FindFirstChild(giftType)
	local maxGifts = tonumber(giftCounter and giftCounter:GetAttribute("MaxGifts")) or 0

	if maxGifts > 0 then
		return collected, maxGifts, math.clamp(collected / maxGifts, 0, 1)
	end

	if giftCount then
		local total = math.max(collected, current)
		if total > 0 then
			return collected, total, collected / total
		end
	end

	return 0, 0, 0
end

function Progress.getNormalGiftProgress(gch)
	return getGiftProgress(gch, "Gift")
end

function Progress.getGoldenGiftProgress(gch)
	return getGiftProgress(gch, "GoldenGift")
end

function Progress.getNormalPacingBatchSize(normalRatio)
	local ratio = tonumber(normalRatio) or 0
	if ratio < NORMAL_PACING_START then
		return nil
	end

	local strength = math.clamp(
		(ratio - NORMAL_PACING_START) / (NORMAL_PACING_FULL - NORMAL_PACING_START),
		0,
		1
	)
	return math.max(
		NORMAL_PACING_MIN_BATCH,
		math.floor(NORMAL_PACING_MAX_BATCH - strength * (NORMAL_PACING_MAX_BATCH - NORMAL_PACING_MIN_BATCH) + 0.5)
	)
end

function Progress.shouldCollectNormalGift()
	return true
end

function Progress.getGiftPriority(gift, _normalRatio, _controller)
	if gift.Golden then
		return 0
	end
	if not Progress.shouldCollectNormalGift() then
		return nil
	end
	return 1
end

return Progress
