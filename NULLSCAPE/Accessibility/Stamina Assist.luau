--!nocheck
-- [[
--  NULLSCAPE - Stamina Assist
--  Shared accessibility helper for keeping native class stamina/timer resources full.
--  Any class special that exposes Time/TimeClamp style fields can use this module.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {
	Connection = nil,
	HookedMovementCore = nil,
	OriginalMovementStep = nil,
	WrappedMovementStep = nil,
	LastRefillAt = 0,
	LastSpecial = nil,
	LastMovement = nil,
}

local REFILL_INTERVAL = 0.02

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function getController()
	return getGlobals().activeAccessibilityController
end

local function getMode()
	local controller = getController()
	local mode = controller and (controller.StaminaMode or controller.GrapplerStaminaMode)
	if mode == true then
		return "Infinite Stamina"
	end

	mode = tostring(mode or "Off")
	if mode == "Infinite" then
		return "Infinite Stamina"
	end

	return mode
end

local function getMovementCore()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local movementCoreScript = movement and movement:FindFirstChild("MovementCore")
	if not movementCoreScript then
		return nil
	end

	local success, movementCore = pcall(require, movementCoreScript)
	if success and typeof(movementCore) == "table" then
		return movementCore
	end

	return nil
end

local function getMaxTime(special)
	return tonumber(special and special.usedGrappleTime)
		or tonumber(special and special.usedStaminaTime)
		or tonumber(special and special.StaminaClamp)
		or tonumber(special and special.TimeClamp)
		or tonumber(special and special.MaxStamina)
		or tonumber(special and special.MaxTime)
		or tonumber(special and special.Time)
		or tonumber(special and special.Stamina)
end

local function getCurrentTime(special)
	return tonumber(special and special.Stamina)
		or tonumber(special and special.Time)
		or tonumber(special and special.CurrentTime)
		or 0
end

function Logic.isEnabled()
	return getMode() == "Infinite Stamina"
end

function Logic.supports(special)
	return typeof(special) == "table" and getMaxTime(special) ~= nil
end

function Logic.getRatio(special)
	if Logic.isEnabled() then
		return 1
	end

	local maxTime = getMaxTime(special) or 0
	if maxTime <= 0 then
		return 1
	end

	return math.clamp(getCurrentTime(special) / maxTime, 0, 1)
end

function Logic.refill(special)
	if not Logic.isEnabled() or not Logic.supports(special) then
		return false
	end

	local maxTime = getMaxTime(special)
	if not maxTime or maxTime <= 0 then
		return false
	end

	local needsRefill = getCurrentTime(special) < maxTime
		or special.TimeClamp ~= nil and tonumber(special.TimeClamp) ~= maxTime
		or special.StaminaClamp ~= nil and tonumber(special.StaminaClamp) ~= maxTime
		or special.TimeDrained == true
		or special.StaminaDrained == true

	if not needsRefill then
		return true
	end

	if special.Time ~= nil then
		special.Time = maxTime
	end
	if special.Stamina ~= nil then
		special.Stamina = maxTime
	end
	if special.CurrentTime ~= nil then
		special.CurrentTime = maxTime
	end
	if special.TimeClamp ~= nil then
		special.TimeClamp = maxTime
	end
	if special.StaminaClamp ~= nil then
		special.StaminaClamp = maxTime
	end
	if special.TimeDrained ~= nil then
		special.TimeDrained = false
	end
	if special.StaminaDrained ~= nil then
		special.StaminaDrained = false
	end

	local ui = special.UI
	local frame = ui and ui:FindFirstChild("Frame")
	local bar = frame and frame:FindFirstChild("Bar")
	if bar then
		pcall(function()
			bar.Size = UDim2.fromScale(1, 1)
		end)
	end

	return true
end

local function rememberMovement(movement)
	if typeof(movement) ~= "table" then
		return
	end

	local globals = getGlobals()
	Logic.LastMovement = movement
	globals.NullscapeStaminaMovement = movement

	if movement.ActiveSpecial then
		Logic.LastSpecial = movement.ActiveSpecial
		globals.NullscapeLastActiveSpecial = movement.ActiveSpecial
	end
end

local function refillMovement(movement)
	if not Logic.isEnabled() then
		return false
	end

	rememberMovement(movement)
	local special = movement and movement.ActiveSpecial or Logic.LastSpecial
	return Logic.refill(special)
end

local function installMovementHook()
	local movementCore = getMovementCore()
	if not movementCore or typeof(movementCore.Step) ~= "function" then
		return false
	end

	if Logic.HookedMovementCore == movementCore and Logic.WrappedMovementStep == movementCore.Step then
		return true
	end

	if movementCore.__NULLSCAPE_stamina_assist_hooked and movementCore.__NULLSCAPE_stamina_assist_wrapper then
		Logic.HookedMovementCore = movementCore
		Logic.WrappedMovementStep = movementCore.__NULLSCAPE_stamina_assist_wrapper
		Logic.OriginalMovementStep = movementCore.__NULLSCAPE_stamina_assist_original
		return true
	end

	local originalStep = movementCore.Step
	local wrappedStep
	wrappedStep = function(self, dt, ...)
		if self and self.IsLocalPlayer then
			refillMovement(self)
		end

		local results = table.pack(originalStep(self, dt, ...))

		if self and self.IsLocalPlayer then
			refillMovement(self)
		end

		return table.unpack(results, 1, results.n)
	end

	movementCore.Step = wrappedStep
	movementCore.__NULLSCAPE_stamina_assist_hooked = true
	movementCore.__NULLSCAPE_stamina_assist_original = originalStep
	movementCore.__NULLSCAPE_stamina_assist_wrapper = wrappedStep

	Logic.HookedMovementCore = movementCore
	Logic.OriginalMovementStep = originalStep
	Logic.WrappedMovementStep = wrappedStep
	return true
end

local function uninstallMovementHook()
	local movementCore = Logic.HookedMovementCore or getMovementCore()
	if
		movementCore
		and Logic.WrappedMovementStep
		and movementCore.Step == Logic.WrappedMovementStep
		and Logic.OriginalMovementStep
	then
		movementCore.Step = Logic.OriginalMovementStep
	end

	if movementCore and movementCore.__NULLSCAPE_stamina_assist_wrapper == Logic.WrappedMovementStep then
		movementCore.__NULLSCAPE_stamina_assist_hooked = false
		movementCore.__NULLSCAPE_stamina_assist_original = nil
		movementCore.__NULLSCAPE_stamina_assist_wrapper = nil
	end

	Logic.HookedMovementCore = nil
	Logic.OriginalMovementStep = nil
	Logic.WrappedMovementStep = nil
end

function Logic.step()
	if not Logic.isEnabled() then
		return
	end

	local now = time()
	if now - (Logic.LastRefillAt or 0) < REFILL_INTERVAL then
		return
	end
	Logic.LastRefillAt = now

	local globals = getGlobals()
	local movement = Logic.LastMovement or globals.NullscapeStaminaMovement or globals.NullscapeRailLocalMovement
	if movement then
		refillMovement(movement)
	elseif Logic.LastSpecial or globals.NullscapeLastActiveSpecial then
		Logic.refill(Logic.LastSpecial or globals.NullscapeLastActiveSpecial)
	end
end

function Logic.initialize()
	if not installMovementHook() then
		return false
	end

	return true
end

function Logic.disable()
	if Logic.Connection then
		pcall(function()
			Logic.Connection:Disconnect()
		end)
		Logic.Connection = nil
	end
	uninstallMovementHook()
	Logic.LastSpecial = nil
	Logic.LastMovement = nil
end

return Logic
