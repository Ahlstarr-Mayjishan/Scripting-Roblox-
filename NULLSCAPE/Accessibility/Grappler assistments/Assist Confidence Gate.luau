--!nocheck
-- [[
--  NULLSCAPE - Grappler Assist Confidence Gate
--  Refuses assisted snaps when the best target is too weak or too close to the runner-up.
-- ]]

local Gate = {}

local DEFAULT_MIN_SCORE = -35
local DEFAULT_MIN_MARGIN = 5

local function getNumber(value, fallback, minimum, maximum)
	return math.clamp(tonumber(value) or fallback, minimum, maximum)
end

function Gate.accept(bestHit, bestScore, secondScore, controller, intent)
	if controller and controller.GrappleAssistConfidenceGateEnabled == false then
		return true
	end
	if not bestHit then
		return false
	end

	local minScore = getNumber(controller and controller.GrappleAssistMinConfidenceScore, DEFAULT_MIN_SCORE, -100, 80)
	local pilotMode = intent and intent.PilotMode
	if pilotMode == "Emergency" then
		minScore -= 30
	elseif pilotMode == "Pilot" or pilotMode == "Technique" then
		minScore -= 14
	end

	if (tonumber(bestScore) or -math.huge) < minScore then
		return false
	end

	if secondScore and secondScore > -math.huge then
		local margin = (tonumber(bestScore) or 0) - secondScore
		local requiredMargin =
			getNumber(controller and controller.GrappleAssistConfidenceMargin, DEFAULT_MIN_MARGIN, 0, 50)
		local confidence = tonumber(intent and intent.Confidence) or 0
		if confidence >= 0.78 then
			requiredMargin *= 0.55
		end
		if pilotMode == "Emergency" then
			requiredMargin *= 0.35
		elseif pilotMode == "Pilot" or pilotMode == "Technique" then
			requiredMargin *= 0.65
		end
		if margin < requiredMargin then
			return false
		end
	end

	return true
end

return Gate
