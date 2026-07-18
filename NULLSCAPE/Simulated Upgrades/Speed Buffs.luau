--!nocheck
--[[
	NULLSCAPE - Native Speed Buff Simulation
	Feeds simulated upgrade stacks into the native UpgradeHandler. MovementCore.UpdateSpeed
	then applies the game's own SwiftnessRing, SportShoes, and Adrenaline formulas.
]]

local Players = game:GetService("Players")

local Injector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local Logic = {
	SelectedBuffs = {},
	RefreshVersion = 0,
	AppliedRefresh = setmetatable({}, { __mode = "k" }),
	LastMovement = nil,
	MovementCore = nil,
	OriginalStep = nil,
	WrappedStep = nil,
	Hooked = false,
}

local OPTIONS = {
	"Swiftness Ring I (+10%)",
	"Swiftness Ring II (+10%)",
	"Swiftness Ring III (+10%)",
	"Adrenaline (+20%)",
	"Sport Shoes (+40%)",
}

local function isAdrenalineAvailable()
	local solo = game:GetService("ReplicatedStorage"):FindFirstChild("Solo")
	return solo and solo.Value == true or #Players:GetPlayers() <= 2
end

local function getNativeStacks(controller)
	local selectedBuffs = controller and controller.SpeedBuffSelections or Logic.SelectedBuffs
	local stacks = {
		SwiftnessRing = 0,
		Adrenaline = 0,
		SportShoes = 0,
	}

	for _, option in ipairs(selectedBuffs or {}) do
		if string.find(option, "Swiftness Ring", 1, true) then
			stacks.SwiftnessRing = math.min(stacks.SwiftnessRing + 1, 3)
		elseif option == "Adrenaline (+20%)" and isAdrenalineAvailable() then
			stacks.Adrenaline = 1
		elseif option == "Sport Shoes (+40%)" then
			stacks.SportShoes = 1
		end
	end

	return stacks
end

local function syncNativeStacks(controller)
	if not Injector then
		return false
	end

	local stacks = getNativeStacks(controller)
	return Injector.syncStacks(stacks)
end

local function getActiveController()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.activeUpgradeController
end

local function getMovementCore()
	local movement = game:GetService("ReplicatedStorage"):FindFirstChild("Movement")
	local module = movement and movement:FindFirstChild("MovementCore")
	if not module then
		return nil
	end

	local success, core = pcall(require, module)
	return success and typeof(core) == "table" and core or nil
end

local function refreshNativeSpeed(movement)
	if not (movement and movement.IsLocalPlayer and typeof(movement.UpdateSpeed) == "function") then
		return false
	end
	if Logic.AppliedRefresh[movement] == Logic.RefreshVersion then
		return false
	end

	local success = pcall(function()
		movement:UpdateSpeed()
	end)
	if success then
		Logic.AppliedRefresh[movement] = Logic.RefreshVersion
	end
	return success
end

local function installStepHook()
	local movementCore = getMovementCore()
	if not (movementCore and typeof(movementCore.Step) == "function") then
		return false
	end

	if Logic.MovementCore == movementCore and movementCore.Step == Logic.WrappedStep then
		return true
	end

	if movementCore.__NULLSCAPE_speed_buffs_wrapper then
		Logic.MovementCore = movementCore
		Logic.OriginalStep = movementCore.__NULLSCAPE_speed_buffs_original
		Logic.WrappedStep = movementCore.__NULLSCAPE_speed_buffs_wrapper
		return true
	end

	local originalStep = movementCore.Step
	local wrappedStep
	wrappedStep = function(self, dt, ...)
		local results = table.pack(originalStep(self, dt, ...))
		local controller = getActiveController()
		if controller and controller.SpeedBuffsEnabled == true then
			Logic.LastMovement = self
			refreshNativeSpeed(self)
		end
		return table.unpack(results, 1, results.n)
	end

	movementCore.Step = wrappedStep
	movementCore.__NULLSCAPE_speed_buffs_original = originalStep
	movementCore.__NULLSCAPE_speed_buffs_wrapper = wrappedStep
	Logic.MovementCore = movementCore
	Logic.OriginalStep = originalStep
	Logic.WrappedStep = wrappedStep
	return true
end

local function uninstallStepHook()
	local movementCore = Logic.MovementCore or getMovementCore()
	local restored = false
	if movementCore and movementCore.Step == Logic.WrappedStep and Logic.OriginalStep then
		movementCore.Step = Logic.OriginalStep
		restored = true
	end
	if restored and movementCore and movementCore.__NULLSCAPE_speed_buffs_wrapper == Logic.WrappedStep then
		movementCore.__NULLSCAPE_speed_buffs_original = nil
		movementCore.__NULLSCAPE_speed_buffs_wrapper = nil
	end
	if restored then
		Logic.MovementCore = nil
		Logic.OriginalStep = nil
		Logic.WrappedStep = nil
	end
end

function Logic.start(controller, _gc)
	Logic.RefreshVersion += 1
	Logic.Hooked = syncNativeStacks(controller) and installStepHook()
	return Logic.Hooked
end

function Logic.stop()
	if Injector then
		Injector.clear({ "SwiftnessRing", "Adrenaline", "SportShoes" })
	end
	Logic.RefreshVersion += 1
	refreshNativeSpeed(Logic.LastMovement)
	table.clear(Logic.AppliedRefresh)
	uninstallStepHook()
	Logic.LastMovement = nil
	Logic.Hooked = false
end

function Logic.setSelectedBuffs(selectedBuffs)
	local normalized = {}
	for _, option in ipairs(selectedBuffs or {}) do
		if table.find(OPTIONS, option) and not table.find(normalized, option) then
			table.insert(normalized, option)
		end
	end
	Logic.SelectedBuffs = normalized
	Logic.RefreshVersion += 1
end

function Logic.getOptions()
	return table.clone(OPTIONS)
end

return Logic
