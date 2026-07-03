--!nocheck

local Progress = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

function Progress.getNormalGiftProgress(gch)
	local giftCount = gch and gch.GiftCount and gch.GiftCount.Gift
	if giftCount then
		local collected = tonumber(giftCount.Collected) or 0
		local current = tonumber(giftCount.Current) or 0
		local total = collected + current
		if total > 0 then
			return collected, total, collected / total
		end
	end

	local counters = ReplicatedStorage:FindFirstChild("GiftCounters")
	local giftCounter = counters and counters:FindFirstChild("Gift")
	if giftCounter then
		local maxGifts = tonumber(giftCounter:GetAttribute("MaxGifts")) or 0
		local remaining = tonumber(giftCounter.Value) or 0
		if maxGifts > 0 then
			local collected = math.max(0, maxGifts - remaining)
			return collected, maxGifts, collected / maxGifts
		end
	end

	return 0, 0, 0
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
