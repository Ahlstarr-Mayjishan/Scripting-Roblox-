--!nocheck

local InfiniteAirJump = getgenv().loadModule("NULLSCAPE/Accessibility/Infinite Air Jump.luau")
local ClientUpgradeInjector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local AirJumps = {
	Hooked = false,
}

local OPTIONS = { "DoubleJump", "PocketBell" }
local selectedMap = {}

local function accessibilityOwnsAirJump()
	local globals = getgenv()._NULLSCAPE_Globals
	local controller = globals and globals.activeAccessibilityController
	return controller and controller.InfiniteAirJumpEnabled == true
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
	if ClientUpgradeInjector then
		ClientUpgradeInjector.sync({
			DoubleJump = map.DoubleJump == true,
			PocketBell = map.PocketBell == true,
		})
	end
	return normalized
end

function AirJumps.start(controller, _gc)
	if controller then
		AirJumps.setSelections(controller.AirJumpSelections or {})
	end
	if InfiniteAirJump and typeof(InfiniteAirJump.initialize) == "function" then
		local initialized = InfiniteAirJump.initialize()
		AirJumps.Hooked = initialized == true
		return initialized
	end
	AirJumps.Hooked = false
	return false
end

function AirJumps.stop()
	selectedMap = {}
	AirJumps.Hooked = false
	if ClientUpgradeInjector then
		ClientUpgradeInjector.clear({ "DoubleJump", "PocketBell" })
	end
	if not accessibilityOwnsAirJump() and InfiniteAirJump and typeof(InfiniteAirJump.disable) == "function" then
		InfiniteAirJump.disable()
	end
end

function AirJumps.hasSelection(upgradeName)
	return selectedMap[upgradeName] == true
end

return AirJumps
