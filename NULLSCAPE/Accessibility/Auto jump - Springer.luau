--!nocheck
-- [[
--  NULLSCAPE - Springer Auto Jump
--  Schedules one native jump for each expanding Springer shockwave.
-- ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {}

local NORMAL_WAVE_SIZE = 128
local SPRINGLOADED_WAVE_SIZE = 256
local NORMAL_WAVE_DURATION = 1.5
local SPRINGLOADED_WAVE_DURATION = 2.5
local JUMP_LEAD_TIME = 0.12
local MAX_VERTICAL_DISTANCE = 10
local MIN_WAVE_DIAMETER = 0.5

local cachedCurseHandler
local attemptedCurseHandler = false

local function isSpringloaded()
	if not attemptedCurseHandler then
		attemptedCurseHandler = true
		local replicatedFirst = game:GetService("ReplicatedFirst")
		local clientModules = replicatedFirst:FindFirstChild("ClientModules")
		local curseHandlerModule = clientModules and clientModules:FindFirstChild("CurseHandler")
		if curseHandlerModule and curseHandlerModule:IsA("ModuleScript") then
			local success, handler = pcall(require, curseHandlerModule)
			if success and typeof(handler) == "table" then
				cachedCurseHandler = handler
			end
		end
	end

	if cachedCurseHandler and typeof(cachedCurseHandler.IsCurseEnabled) == "function" then
		local success, enabled = pcall(cachedCurseHandler.IsCurseEnabled, "Springloaded")
		if success then
			return enabled == true
		end
	end

	local curses = ReplicatedStorage:FindFirstChild("Curses") or ReplicatedStorage:FindFirstChild("ActiveCurses")
	local value = curses and curses:FindFirstChild("Springloaded")
	return value and value:IsA("BoolValue") and value.Value == true or false
end

local function getWaveProfile(enemy)
	local springloaded = isSpringloaded()
	local fallbackSize = springloaded and SPRINGLOADED_WAVE_SIZE or NORMAL_WAVE_SIZE
	local attributeName = springloaded and "SpringloadedShockwaveSize" or "ShockwaveSize"
	local configuredSize = enemy:GetAttribute(attributeName)
	local diameter = typeof(configuredSize) == "Vector3" and configuredSize.X or fallbackSize

	return math.max(tonumber(diameter) or fallbackSize, MIN_WAVE_DIAMETER), springloaded and SPRINGLOADED_WAVE_DURATION or NORMAL_WAVE_DURATION
end

local function getLocalCharacterState()
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return player, character, root, humanoid
end

local function horizontalDistance(first, second)
	local delta = first - second
	return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function requestJump(humanoid)
	if humanoid.FloorMaterial == Enum.Material.Air then
		return
	end

	humanoid.Jump = true
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end)
end

function Logic.setupAutoJump(enemy, shockwave, controller, gc)
	if not enemy or not shockwave or not controller or not gc then
		return false
	end

	local cycle = 0
	local scheduledCycle = 0

	local function scheduleJump()
		if not controller.SpringerAutoJumpEnabled or not shockwave.CanTouch then
			return
		end

		cycle = cycle + 1
		local currentCycle = cycle

		-- The AI sets CanTouch before Position and Size in the same task. Deferring once
		-- observes that completed state without adding a per-frame watcher.
		task.defer(function()
			if currentCycle ~= cycle or scheduledCycle == currentCycle then
				return
			end
			if not controller.SpringerAutoJumpEnabled or not shockwave.CanTouch then
				return
			end

			local player, character, root, humanoid = getLocalCharacterState()
			if not player or math.abs(root.Position.Y - shockwave.Position.Y) > MAX_VERTICAL_DISTANCE then
				return
			end

			local diameter, duration = getWaveProfile(enemy)
			local radius = diameter * 0.5
			local distance = horizontalDistance(root.Position, shockwave.Position)
			if distance >= radius then
				return
			end

			local elapsedRatio = math.clamp(shockwave.Size.X / diameter, 0, 1)
			local elapsed = duration * (2 / math.pi) * math.asin(elapsedRatio)
			local arrival = duration * (2 / math.pi) * math.asin(math.clamp(distance / radius, 0, 1))
			local delay = arrival - elapsed - JUMP_LEAD_TIME
			scheduledCycle = currentCycle

			local function jumpWhenDue()
				if currentCycle ~= cycle or not controller.SpringerAutoJumpEnabled or not shockwave.CanTouch then
					return
				end
				if player.Character ~= character or humanoid.Parent ~= character then
					return
				end

				requestJump(humanoid)
			end

			if delay <= 0 then
				jumpWhenDue()
			else
				task.delay(delay, jumpWhenDue)
			end
		end)
	end

	local canTouchConnection = shockwave:GetPropertyChangedSignal("CanTouch"):Connect(function()
		if shockwave.CanTouch then
			scheduleJump()
		else
			cycle = cycle + 1
		end
	end)
	gc.registerEntityConnection(enemy, canTouchConnection)

	if shockwave.CanTouch then
		scheduleJump()
	end

	return true
end

return Logic
