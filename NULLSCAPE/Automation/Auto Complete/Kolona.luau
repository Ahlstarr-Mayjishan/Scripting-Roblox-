--!nocheck
--[[
	NULLSCAPE - Automation Auto Complete Kolona
	Completes Kolona's local ability-state QTE while it is active.
]]

local Players = game:GetService("Players")

local Kolona = {}

local LocalPlayer = Players.LocalPlayer
local LOOP_INTERVAL = 0.025
local INVERTED_COLOR_MAX = 0.08
local PULSE_HOLD_TIME = 0.09
local PULSE_COOLDOWN = 0.45

local enabled = false
local running = false
local targetNumber = nil
local currentTick = nil
local pulsedThisCycle = false
local pulseActive = false
local lastPulseAt = -1000
local tickSoundStates = setmetatable({}, { __mode = "k" })

local function getCharacter()
	return LocalPlayer and LocalPlayer.Character
end

local function getHumanoid()
	local character = getCharacter()
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getKolonaMain()
	local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local kolonaGui = playerGui and playerGui:FindFirstChild("Kolona")
	return kolonaGui and kolonaGui:FindFirstChild("Main")
end

local function isKolonaVisible(main)
	if not (main and main.Parent) then
		return false
	end

	local gui = main.Parent
	if gui:IsA("LayerCollector") and gui.Enabled ~= true then
		return false
	end

	local background = main:FindFirstChild("Background")
	return shared.KolonaActive == true
		or (background and background:IsA("ImageLabel") and background.ImageTransparency < 0.99)
end

local function isInverted(main)
	local background = main and main:FindFirstChild("Background")
	if not (background and background:IsA("GuiObject")) then
		return false
	end

	local color = background.ImageColor3
	return color.R <= INVERTED_COLOR_MAX and color.G <= INVERTED_COLOR_MAX and color.B <= INVERTED_COLOR_MAX
end

local function getNumberText(main)
	local number = main and main:FindFirstChild("Number")
	if not (number and number:IsA("TextLabel")) then
		return nil
	end

	return tostring(number.Text or "")
end

local function getVisibleNumber(main)
	local text = getNumberText(main)
	local value = tonumber(text)
	return value
end

local function isDeathSpinWindow(main)
	if not main then
		return false
	end

	local eyes = main:FindFirstChild("Eyes")
	if eyes and eyes:IsA("ImageLabel") and eyes.ImageTransparency < 0.5 then
		return true
	end

	local deathSpin = main:FindFirstChild("deathSpin")
	return deathSpin and deathSpin:IsA("Sound") and deathSpin.IsPlaying == true
end

local function resetCycle()
	targetNumber = nil
	currentTick = nil
	pulsedThisCycle = false
	pulseActive = false
	table.clear(tickSoundStates)
end

local function updateTargetNumber(main)
	if targetNumber then
		return
	end

	local visibleNumber = getVisibleNumber(main)
	if visibleNumber and visibleNumber >= 5 then
		targetNumber = visibleNumber
	end
end

local function updateCurrentTick(main)
	local tickFolder = main and main:FindFirstChild("tick")
	if not tickFolder then
		return
	end

	for _, child in ipairs(tickFolder:GetChildren()) do
		if child:IsA("Sound") then
			local wasPlaying = tickSoundStates[child] == true
			local isPlaying = child.IsPlaying == true
			if isPlaying and not wasPlaying then
				local tickNumber = tonumber(child.Name)
				if tickNumber then
					currentTick = tickNumber
				end
			end
			tickSoundStates[child] = isPlaying
		end
	end
end

local function isQteWindow(main)
	if targetNumber and currentTick == targetNumber then
		return true
	end

	if targetNumber and not currentTick then
		local visibleNumber = getVisibleNumber(main)
		if visibleNumber and visibleNumber == targetNumber then
			return true
		end
	end

	return isDeathSpinWindow(main)
end

local function setStatus(controller, status, detail)
	if controller then
		controller.AutoCompleteKolonaStatus = status or "Idle"
		controller.AutoCompleteKolonaDetail = detail or ""
	end
end

local function pulseAbility(humanoid)
	if pulseActive or time() - lastPulseAt < PULSE_COOLDOWN then
		return false
	end

	pulseActive = true
	lastPulseAt = time()
	pcall(function()
		humanoid:SetAttribute("UsingAbility", true)
	end)

	task.delay(PULSE_HOLD_TIME, function()
		if humanoid and humanoid.Parent then
			pcall(function()
				humanoid:SetAttribute("UsingAbility", false)
			end)
		end
		pulseActive = false
	end)

	return true
end

local function stopPulse()
	if pulseActive then
		local humanoid = getHumanoid()
		if humanoid and humanoid.Parent then
			pcall(function()
				humanoid:SetAttribute("UsingAbility", false)
			end)
		end
	end
	pulseActive = false
end

local function completeWindow(controller, humanoid, main)
	if pulsedThisCycle then
		return
	end

	local usingAbility = humanoid:GetAttribute("UsingAbility") == true
	local inverted = isInverted(main)

	if usingAbility then
		setStatus(
			controller,
			"UserHandled",
			inverted and "ability already active; inverted Kolona not touched" or "ability already active"
		)
		pulsedThisCycle = true
		return
	end

	if inverted then
		setStatus(controller, "UserHandled", "inverted window already released")
		pulsedThisCycle = true
		return
	end

	if pulseAbility(humanoid) then
		pulsedThisCycle = true
		setStatus(controller, "Tapped", "fallback ability pulse")
	end
end

local function restoreUsingAbility()
	if pulseActive then
		local humanoid = getHumanoid()
		if humanoid and humanoid.Parent then
			pcall(function()
				humanoid:SetAttribute("UsingAbility", false)
			end)
		end
	else
		pcall(function()
			stopPulse()
		end)
	end
end

local function run(controller)
	if running then
		return
	end

	running = true
	task.spawn(function()
		while enabled and controller and not controller.Destroyed do
			local main = getKolonaMain()
			local humanoid = getHumanoid()
			if not (humanoid and isKolonaVisible(main)) then
				restoreUsingAbility()
				resetCycle()
				setStatus(controller, "Waiting")
				task.wait(0.15)
				continue
			end

			updateCurrentTick(main)
			updateTargetNumber(main)
			if isQteWindow(main) then
				completeWindow(controller, humanoid, main)
			else
				setStatus(
					controller,
					"Watching",
					targetNumber
							and (currentTick and ("target " .. tostring(targetNumber) .. " | tick " .. tostring(
								currentTick
							)) or ("target " .. tostring(targetNumber)))
						or "waiting for target"
				)
			end
			task.wait(LOOP_INTERVAL)
		end

		restoreUsingAbility()
		setStatus(controller, "Idle")
		running = false
	end)
end

function Kolona.update(controller)
	enabled = controller and controller.AutoCompleteKolonaEnabled == true
	if enabled then
		run(controller)
	else
		restoreUsingAbility()
		setStatus(controller, "Idle")
	end
	return true
end

function Kolona.disable(controller)
	enabled = false
	restoreUsingAbility()
	setStatus(controller, "Idle")
	return true
end

function Kolona.getStatus(controller)
	return {
		Status = controller and controller.AutoCompleteKolonaStatus or "Idle",
		Detail = controller and controller.AutoCompleteKolonaDetail or "",
	}
end

return Kolona
