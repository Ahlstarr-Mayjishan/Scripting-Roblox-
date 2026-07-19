--!nocheck

local GameState = getgenv().loadModule("NULLSCAPE/Core/Game State Context.luau")

local Lap2Policy = {}

local GOLDEN_GIFT_FLOOR_PERCENT = 40

function Lap2Policy.sync(controller)
	local active = GameState
		and typeof(GameState.isCurseEnabled) == "function"
		and GameState.isCurseEnabled("Lap2") == true

	if controller then
		controller.GiftFarmLap2Active = active
		controller.GiftFarmGoldenEfficiencyFloor = active and GOLDEN_GIFT_FLOOR_PERCENT or 0
	end

	return active
end

function Lap2Policy.reset(controller)
	if controller then
		controller.GiftFarmLap2Active = false
		controller.GiftFarmGoldenEfficiencyFloor = 0
	end
end

function Lap2Policy.getGoldenFloorPercent()
	return GOLDEN_GIFT_FLOOR_PERCENT
end

return Lap2Policy
