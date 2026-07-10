--!nocheck
-- [[
--  NULLSCAPE - Advanced Gravity Coil Simulation
--  Ref logic:
--    - Base JumpPower = 35
--    - AdvancedGravityCoil reduces it to 35 * 0.8 = 28
--    - MovementCore adds an upward assist task on Jumping while the upgrade is enabled
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local BASE_JUMP_POWER = 35
local MIN_JUMP_POWER = 28
local MAX_JUMP_POWER = 100

local Logic = {
	JumpPower = MIN_JUMP_POWER,
	Connection = nil,
	CharacterConnection = nil,
	OriginalJumpPowerByHumanoid = setmetatable({}, { __mode = "k" }),
	Hooked = false,
}

local function getHumanoid()
	local character = LocalPlayer and LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function applyJumpPower(controller)
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end
	if Logic.OriginalJumpPowerByHumanoid[humanoid] == nil then
		Logic.OriginalJumpPowerByHumanoid[humanoid] = humanoid.JumpPower
	end

	local jumpPower =
		math.clamp(tonumber(controller.AdvancedGravityCoilJumpPower) or Logic.JumpPower, MIN_JUMP_POWER, MAX_JUMP_POWER)
	humanoid.JumpPower = jumpPower
end

local function restoreJumpPower()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.JumpPower = Logic.OriginalJumpPowerByHumanoid[humanoid] or BASE_JUMP_POWER
		Logic.OriginalJumpPowerByHumanoid[humanoid] = nil
	end
end

function Logic.start(controller, gc)
	Logic.JumpPower =
		math.clamp(tonumber(controller.AdvancedGravityCoilJumpPower) or Logic.JumpPower, MIN_JUMP_POWER, MAX_JUMP_POWER)
	applyJumpPower(controller)

	if not Logic.CharacterConnection and LocalPlayer then
		Logic.CharacterConnection = LocalPlayer.CharacterAdded:Connect(function()
			task.defer(function()
				if controller.AdvancedGravityCoilEnabled then
					applyJumpPower(controller)
				end
			end)
		end)
	end

	if Logic.Connection then
		Logic.Hooked = true
		return
	end

	Logic.Connection = RunService.Heartbeat:Connect(function()
		if not controller.AdvancedGravityCoilEnabled then
			return
		end

		applyJumpPower(controller)
	end)
	Logic.Hooked = true
end

function Logic.stop()
	if Logic.Connection then
		Logic.Connection:Disconnect()
		Logic.Connection = nil
	end

	if Logic.CharacterConnection then
		Logic.CharacterConnection:Disconnect()
		Logic.CharacterConnection = nil
	end

	restoreJumpPower()
	Logic.OriginalJumpPowerByHumanoid = setmetatable({}, { __mode = "k" })
	Logic.Hooked = false
end

function Logic.setJumpPower(value)
	Logic.JumpPower = math.clamp(tonumber(value) or MIN_JUMP_POWER, MIN_JUMP_POWER, MAX_JUMP_POWER)
end

function Logic.getMinJumpPower()
	return MIN_JUMP_POWER
end

function Logic.getMaxJumpPower()
	return MAX_JUMP_POWER
end

return Logic
