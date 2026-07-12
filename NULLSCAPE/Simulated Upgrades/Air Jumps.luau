--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientUpgradeInjector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local AirJumps = {
	Hooked = false,
	RefreshVersion = 0,
	AppliedRefresh = setmetatable({}, { __mode = "k" }),
	MovementCore = nil,
	OriginalStep = nil,
	WrappedStep = nil,
}

local OPTIONS = { "DoubleJump", "PocketBell" }
local selectedMap = {}

local function getActiveController()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.activeUpgradeController
end

local function getMovementCore()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local module = movement and movement:FindFirstChild("MovementCore")
	if not module then
		return nil
	end

	local success, core = pcall(require, module)
	if success and typeof(core) == "table" then
		return core
	end

	return nil
end

local function refreshNativeJumpBars(movement)
	if not (movement and movement.IsLocalPlayer and movement.DoubleJump) then
		return false
	end
	if AirJumps.AppliedRefresh[movement] == AirJumps.RefreshVersion then
		return false
	end

	local success = pcall(function()
		movement.DoubleJump:Refresh()
	end)
	if success then
		AirJumps.AppliedRefresh[movement] = AirJumps.RefreshVersion
	end
	return success
end

local function maintainInfiniteJumpBars(movement, controller)
	if not (controller and controller.InfiniteJumpEnabled == true and movement and movement.DoubleJump) then
		return false
	end

	local available = movement.DoubleJump.AvailableJumps
	if typeof(available) ~= "table" then
		return false
	end

	local overrides = {}
	local needsRefresh = false
	if selectedMap.DoubleJump == true and (tonumber(available.DoubleJump) or 0) < 1 then
		overrides.DoubleJump = 1
		needsRefresh = true
	end
	if selectedMap.PocketBell == true and (tonumber(available.PocketBell) or 0) < 1 then
		overrides.PocketBell = 1
		needsRefresh = true
	end

	if not needsRefresh then
		return false
	end

	return pcall(function()
		movement.DoubleJump:Refresh(overrides)
	end)
end

local function installStepHook()
	local movementCore = getMovementCore()
	if not (movementCore and typeof(movementCore.Step) == "function") then
		return false
	end

	if AirJumps.MovementCore == movementCore and movementCore.Step == AirJumps.WrappedStep then
		return true
	end

	if movementCore.__NULLSCAPE_air_jumps_wrapper then
		AirJumps.MovementCore = movementCore
		AirJumps.OriginalStep = movementCore.__NULLSCAPE_air_jumps_original
		AirJumps.WrappedStep = movementCore.__NULLSCAPE_air_jumps_wrapper
		return true
	end

	local originalStep = movementCore.Step
	local wrappedStep
	wrappedStep = function(self, dt, ...)
		local results = table.pack(originalStep(self, dt, ...))
		local controller = getActiveController()
		if controller and controller.AirJumpSimulationEnabled == true then
			refreshNativeJumpBars(self)
			maintainInfiniteJumpBars(self, controller)
		end
		return table.unpack(results, 1, results.n)
	end

	movementCore.Step = wrappedStep
	movementCore.__NULLSCAPE_air_jumps_original = originalStep
	movementCore.__NULLSCAPE_air_jumps_wrapper = wrappedStep
	AirJumps.MovementCore = movementCore
	AirJumps.OriginalStep = originalStep
	AirJumps.WrappedStep = wrappedStep
	return true
end

local function uninstallStepHook()
	local movementCore = AirJumps.MovementCore or getMovementCore()
	local restored = false
	if movementCore and movementCore.Step == AirJumps.WrappedStep and AirJumps.OriginalStep then
		movementCore.Step = AirJumps.OriginalStep
		restored = true
	end
	if restored and movementCore and movementCore.__NULLSCAPE_air_jumps_wrapper == AirJumps.WrappedStep then
		movementCore.__NULLSCAPE_air_jumps_original = nil
		movementCore.__NULLSCAPE_air_jumps_wrapper = nil
	end

	if restored then
		AirJumps.MovementCore = nil
		AirJumps.OriginalStep = nil
		AirJumps.WrappedStep = nil
	end
end

local function normalizeSelections(options)
	local normalized = {}
	local map = {}
	if typeof(options) ~= "table" then
		return normalized, map
	end

	for _, option in ipairs(options) do
		if table.find(OPTIONS, option) and not map[option] then
			table.insert(normalized, option)
			map[option] = true
		end
	end

	return normalized, map
end

function AirJumps.getOptions()
	return { "DoubleJump", "PocketBell" }
end

function AirJumps.setSelections(options)
	local normalized, map = normalizeSelections(options)
	selectedMap = map
	AirJumps.RefreshVersion += 1
	if ClientUpgradeInjector then
		ClientUpgradeInjector.sync({
			DoubleJump = map.DoubleJump == true,
			PocketBell = map.PocketBell == true,
		})
	end
	return normalized
end

function AirJumps.setInfiniteEnabled(_value)
	AirJumps.RefreshVersion += 1
end

function AirJumps.start(controller, _gc)
	if controller then
		AirJumps.setSelections(controller.AirJumpSelections or {})
	end
	AirJumps.Hooked = installStepHook()
	return AirJumps.Hooked
end

function AirJumps.stop()
	selectedMap = {}
	AirJumps.Hooked = false
	if ClientUpgradeInjector then
		ClientUpgradeInjector.clear({ "DoubleJump", "PocketBell" })
	end
	AirJumps.RefreshVersion += 1
	table.clear(AirJumps.AppliedRefresh)
	uninstallStepHook()
end

function AirJumps.hasSelection(upgradeName)
	return selectedMap[upgradeName] == true
end

return AirJumps
