--!nocheck
--[[
	NULLSCAPE - Entities Kolona Auto QTE
	Pulses UsingAbility only during Kolona's fatal QTE window, then releases it.
]]

local Players = game:GetService("Players")

local AutoQTE = {}
local GameState = getgenv().loadModule("NULLSCAPE/Core/Game State Context.luau")

local LocalPlayer = Players.LocalPlayer
local LOOP_INTERVAL = 0.025
local IDLE_INTERVAL = 0.15
local PULSE_HOLD = 0.03
local PULSE_COOLDOWN = 0.45
local INVERTED_MAX = 0.08

local enabled = false
local running = false
local targetNumber = nil
local currentTick = nil
local pulsed = false
local pulseHumanoid = nil
local pulseStartedAt = -1000
local wasKolonaActive = false
local tickStates = setmetatable({}, { __mode = "k" })

local function getHumanoid()
	if GameState and typeof(GameState.getHumanoid) == "function" then
		return GameState.getHumanoid()
	end

	local character = LocalPlayer and LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getMain()
	local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local kolonaGui = playerGui and playerGui:FindFirstChild("Kolona")
	return kolonaGui and kolonaGui:FindFirstChild("Main")
end

local function isKolonaActive(main)
	if (GameState and GameState.isKolonaActive and GameState.isKolonaActive()) == true then
		return true
	end
	if shared.KolonaActive == true then
		return true
	end

	local gui = main and main.Parent
	if not (gui and gui:IsA("LayerCollector") and gui.Enabled == true) then
		return false
	end

	local background = main:FindFirstChild("Background")
	return background and background:IsA("ImageLabel") and background.ImageTransparency < 0.99
end

local function isInverted(main)
	local background = main and main:FindFirstChild("Background")
	if not (background and background:IsA("GuiObject")) then
		return false
	end

	local color = background.ImageColor3
	return color.R <= INVERTED_MAX and color.G <= INVERTED_MAX and color.B <= INVERTED_MAX
end

local function getNumberLabel(main)
	local number = main and main:FindFirstChild("Number")
	if not number and main and main.Parent then
		local centered = main.Parent:FindFirstChild("CenteredMain")
		number = centered and centered:FindFirstChild("Number")
	end
	return number and number:IsA("TextLabel") and number or nil
end

local function resetCycle()
	targetNumber = nil
	currentTick = nil
	pulsed = false
	table.clear(tickStates)
end

local function captureTarget(main)
	if targetNumber then
		return
	end

	local number = tonumber((getNumberLabel(main) or {}).Text)
	if number and number >= 5 and number <= 60 then
		targetNumber = number
	end
end

local function updateTick(main)
	local folder = main and main:FindFirstChild("tick")
	if not folder then
		return
	end

	for _, sound in ipairs(folder:GetChildren()) do
		if sound:IsA("Sound") then
			local nowPlaying = sound.IsPlaying == true
			if nowPlaying and tickStates[sound] ~= true then
				currentTick = tonumber(sound.Name) or currentTick
			end
			tickStates[sound] = nowPlaying
		end
	end
end

local function isFatalWindow(main)
	if targetNumber and currentTick == targetNumber then
		return true
	end

	local eyes = main and main:FindFirstChild("Eyes")
	if eyes and eyes:IsA("ImageLabel") and eyes.ImageTransparency < 0.5 then
		return true
	end

	local deathSpin = main and main:FindFirstChild("deathSpin")
	return deathSpin and deathSpin:IsA("Sound") and deathSpin.IsPlaying == true
end

local function setUsingAbility(humanoid, value)
	if GameState and typeof(GameState.setUsingAbility) == "function" then
		GameState.setUsingAbility(value)
	else
		pcall(function()
			humanoid:SetAttribute("UsingAbility", value)
		end)
	end
end

local function isUsingAbility(humanoid)
	if GameState and typeof(GameState.getUsingAbility) == "function" and GameState.getUsingAbility() == true then
		return true
	end
	return humanoid and humanoid:GetAttribute("UsingAbility") == true
end

local function cancelPulse()
	local humanoid = pulseHumanoid
	if humanoid and humanoid.Parent then
		setUsingAbility(humanoid, false)
	end
	pulseHumanoid = nil
end

local function pulse(humanoid)
	if pulseHumanoid or time() - pulseStartedAt < PULSE_COOLDOWN then
		return
	end

	pulseHumanoid = humanoid
	pulseStartedAt = time()
	setUsingAbility(humanoid, true)

	task.delay(PULSE_HOLD, function()
		if pulseHumanoid == humanoid then
			cancelPulse()
		end
	end)
end

local function tryComplete(humanoid, main)
	if pulsed then
		return
	end

	pulsed = true
	if isUsingAbility(humanoid) or isInverted(main) then
		return
	end

	pulse(humanoid)
end

local function run(controller)
	if running then
		return
	end

	running = true
	task.spawn(function()
		while enabled and controller and not controller.Destroyed do
			local main = getMain()
			local humanoid = getHumanoid()
			local active = isKolonaActive(main)

			if active and not wasKolonaActive then
				resetCycle()
			end
			wasKolonaActive = active

			if not (active and main and humanoid) then
				cancelPulse()
				resetCycle()
				task.wait(IDLE_INTERVAL)
				continue
			end

			captureTarget(main)
			updateTick(main)
			if isFatalWindow(main) then
				tryComplete(humanoid, main)
			end

			task.wait(LOOP_INTERVAL)
		end

		cancelPulse()
		running = false
	end)
end

function AutoQTE.update(controller)
	enabled = controller and controller.KolonaAutoQTEEnabled == true
	if enabled then
		run(controller)
	else
		cancelPulse()
	end
	return true
end

function AutoQTE.disable()
	enabled = false
	cancelPulse()
	return true
end

return AutoQTE
