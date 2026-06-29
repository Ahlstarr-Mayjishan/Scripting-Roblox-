--!nocheck
-- [[
--  NULLSCAPE - Grappler Anchor Memory
--  Short-lived success/failure memory for grapple targets. This keeps assist
--  from repeatedly choosing a recently blocked or unsafe anchor.
-- ]]

local AnchorMemory = {}

local DEFAULT_SUCCESS_TTL = 0.55
local DEFAULT_FAILURE_TTL = 1.4
local DEFAULT_FAILURE_PENALTY = 85
local DEFAULT_SUCCESS_BONUS = -18

function AnchorMemory.new()
	return {
		Success = {},
		Failure = {},
		LastFailureReason = nil,
		LastSuccessReason = nil,
	}
end

local function keyOf(instance)
	return instance
end

local function pruneBucket(bucket, now)
	for key, record in pairs(bucket) do
		if not key or not key.Parent or now > (record.Until or 0) then
			bucket[key] = nil
		end
	end
end

function AnchorMemory.prune(state)
	if not state then
		return
	end
	local now = time()
	pruneBucket(state.Success, now)
	pruneBucket(state.Failure, now)
end

function AnchorMemory.clear(state)
	if not state then
		return
	end
	table.clear(state.Success)
	table.clear(state.Failure)
	state.LastFailureReason = nil
	state.LastSuccessReason = nil
end

function AnchorMemory.recordSuccess(state, instance, reason, score)
	if not (state and instance and instance.Parent) then
		return
	end
	local now = time()
	state.Success[keyOf(instance)] = {
		Until = now + DEFAULT_SUCCESS_TTL,
		Reason = reason,
		Score = score,
		Count = 1,
	}
	state.Failure[keyOf(instance)] = nil
	state.LastSuccessReason = reason
end

function AnchorMemory.recordFailure(state, instance, reason, penalty)
	if not (state and instance and instance.Parent) then
		return
	end
	local now = time()
	local key = keyOf(instance)
	local existing = state.Failure[key]
	local count = existing and ((existing.Count or 0) + 1) or 1
	state.Failure[key] = {
		Until = now + DEFAULT_FAILURE_TTL,
		Reason = reason,
		Penalty = penalty or DEFAULT_FAILURE_PENALTY,
		Count = count,
	}
	state.LastFailureReason = reason
end

function AnchorMemory.score(state, instance)
	if not (state and instance and instance.Parent) then
		return 0, nil
	end

	local now = time()
	local failure = state.Failure[keyOf(instance)]
	if failure then
		if now > (failure.Until or 0) then
			state.Failure[keyOf(instance)] = nil
		else
			return (failure.Penalty or DEFAULT_FAILURE_PENALTY) * math.min(failure.Count or 1, 3), failure.Reason
		end
	end

	local success = state.Success[keyOf(instance)]
	if success then
		if now > (success.Until or 0) then
			state.Success[keyOf(instance)] = nil
		else
			return DEFAULT_SUCCESS_BONUS, success.Reason
		end
	end

	return 0, nil
end

return AnchorMemory
