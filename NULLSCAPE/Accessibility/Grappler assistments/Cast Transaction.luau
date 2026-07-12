--!nocheck
--[[
	NULLSCAPE - Grappler Cast Transaction
	Tracks cast confirmation so failed starts do not look like successful anchors.
]]

local AnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Anchor Memory.luau")
local FailFeedback = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Fail Feedback Loop.luau")
local Gateway = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Decision Gateway.luau")
local StateAdapter = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Grapple State Adapter.luau")

local Transaction = {
	Pending = setmetatable({}, { __mode = "k" }),
	Last = setmetatable({}, { __mode = "k" }),
}

local CONFIRM_WINDOW = 0.32

local function noteAnchor(hit, success)
	if hit and hit.Instance and AnchorMemory and typeof(AnchorMemory.noteCastResult) == "function" then
		AnchorMemory.noteCastResult(hit.Instance, success)
	end
end

local function record(grapple, source, hit, state, reason)
	Transaction.Last[grapple] = {
		Source = source,
		Part = hit and hit.Instance,
		State = state,
		Reason = reason,
		At = time(),
	}
end

function Transaction.expect(grapple, hit, controller, source)
	if not (grapple and hit) then
		return false
	end

	Transaction.Pending[grapple] = {
		Hit = hit,
		Controller = controller,
		Source = source or "native",
		ExpiresAt = time() + CONFIRM_WINDOW,
	}
	record(grapple, source, hit, "pending")
	return true
end

function Transaction.start(grapple, hit, controller, source, context)
	if not (grapple and typeof(grapple.Start) == "function") then
		return false
	end
	if StateAdapter and typeof(StateAdapter.canStart) == "function" then
		local allowed, reason = StateAdapter.canStart(grapple, hit)
		if not allowed then
			noteAnchor(hit, false)
			record(grapple, source, hit, "blocked", reason)
			return false
		end
	end

	local decision = nil
	if Gateway and typeof(Gateway.evaluate) == "function" then
		local success, result = pcall(Gateway.evaluate, grapple, hit, controller, context)
		if success then
			decision = result
		end
	end
	if decision and decision.Accept == false then
		noteAnchor(hit, false)
		record(grapple, source, hit, "rejected", decision.Reason)
		return false
	end

	local invoked, result = pcall(function()
		return grapple:Start(hit)
	end)
	local accepted = invoked and result ~= false
	if not accepted then
		noteAnchor(hit, false)
		record(grapple, source, hit, "failed", invoked and "native-rejected" or "start-error")
		return false
	end

	Transaction.expect(grapple, hit, controller, source)
	return true
end

function Transaction.step(grapple)
	local pending = Transaction.Pending[grapple]
	if not pending then
		return false
	end

	local movement = grapple and grapple.Movement
	if movement and movement.grappling == true then
		noteAnchor(pending.Hit, true)
		if FailFeedback and typeof(FailFeedback.noteAssistCast) == "function" then
			FailFeedback.noteAssistCast(grapple, pending.Hit, pending.Controller)
		end
		record(grapple, pending.Source, pending.Hit, "confirmed")
		Transaction.Pending[grapple] = nil
		return true
	end

	if time() >= pending.ExpiresAt then
		noteAnchor(pending.Hit, false)
		record(grapple, pending.Source, pending.Hit, "unconfirmed", "attach-timeout")
		Transaction.Pending[grapple] = nil
		return true
	end

	return false
end

function Transaction.getLast(grapple)
	return Transaction.Last[grapple]
end

function Transaction.reset(grapple)
	if grapple then
		Transaction.Pending[grapple] = nil
		Transaction.Last[grapple] = nil
	else
		table.clear(Transaction.Pending)
		table.clear(Transaction.Last)
	end
end

return Transaction
