--!nocheck
--[[
	NULLSCAPE - Entities Kolona Auto QTE
	Casts the local class ability through its native movement API during Kolona's fatal window.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AutoQTE = {}
local GameState = getgenv().loadModule("NULLSCAPE/Core/Game State Context.luau")

local LocalPlayer = Players.LocalPlayer
local ACTIVE_INTERVAL = 0.025
local IDLE_INTERVAL = 0.15
local ABILITY_HOLD = 0.06
local MOVEMENT_RETRY_INTERVAL = 0.05
local INVERTED_MAX = 0.08
local GRAPPLE_RANGE = 90

local enabled = false
local running = false
local targetNumber = nil
local currentTick = nil
local cycleComplete = false
local castInProgress = false
local cachedMovement = nil
local lastMovementSearchAt = -1000
local ownedMovement = nil
local ownedSpecial = nil
local wasKolonaActive = false
local castGeneration = 0
local tickStates = setmetatable({}, { __mode = "k" })

local function getCharacter()
	if GameState and typeof(GameState.getCharacter) == "function" then
		return GameState.getCharacter()
	end
	return LocalPlayer and LocalPlayer.Character
end

local function getHumanoid(character)
	if GameState and typeof(GameState.getHumanoid) == "function" then
		return GameState.getHumanoid(character)
	end
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
	cycleComplete = false
	table.clear(tickStates)
end

local function captureTarget(main)
	if targetNumber then
		return
	end

	local label = getNumberLabel(main)
	local number = label and tonumber(label.Text)
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

local function isUsingAbility(humanoid)
	if GameState and typeof(GameState.getUsingAbility) == "function" then
		return GameState.getUsingAbility() == true
	end
	return humanoid and humanoid:GetAttribute("UsingAbility") == true
end

local function isLocalMovement(candidate, character, humanoid)
	if typeof(candidate) ~= "table" then
		return false
	end
	local metatable = getmetatable(candidate)
	local specialAction = rawget(candidate, "SpecialAction")
		or (typeof(metatable) == "table" and rawget(metatable, "SpecialAction"))

	return rawget(candidate, "IsLocalPlayer") == true
		and rawget(candidate, "Player") == LocalPlayer
		and rawget(candidate, "Character") == character
		and rawget(candidate, "Humanoid") == humanoid
		and typeof(specialAction) == "function"
end

local function findMovement(character, humanoid)
	if isLocalMovement(cachedMovement, character, humanoid) then
		return cachedMovement
	end
	cachedMovement = nil

	local globals = getgenv()._NULLSCAPE_Globals
	if globals then
		local candidates = table.pack(globals.NullscapeStaminaMovement, globals.NullscapeRailLocalMovement)
		for index = 1, candidates.n do
			local candidate = candidates[index]
			if isLocalMovement(candidate, character, humanoid) then
				cachedMovement = candidate
				return candidate
			end
		end
	end

	if time() - lastMovementSearchAt < MOVEMENT_RETRY_INTERVAL or typeof(getgc) ~= "function" then
		return nil
	end
	lastMovementSearchAt = time()

	local ok, objects = pcall(getgc, true)
	if not (ok and typeof(objects) == "table") then
		return nil
	end

	for _, candidate in next, objects do
		if isLocalMovement(candidate, character, humanoid) then
			cachedMovement = candidate
			return candidate
		end
	end

	return nil
end

local function getClassId(movement)
	local classId = movement and movement.ClassID
	if typeof(classId) ~= "string" and GameState and typeof(GameState.getClassId) == "function" then
		classId = GameState.getClassId()
	end
	return typeof(classId) == "string" and string.lower(classId) or ""
end

local function findGrappleHit(grapple, character)
	local ok, hit = pcall(function()
		return grapple:Cast(true)
	end)
	if ok and hit and hit.Instance then
		return hit
	end

	local root = grapple and grapple.RootPart
	if not (root and root.Parent) then
		return nil
	end

	local params = grapple.grappleParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = false
	elseif grapple.Movement and grapple.Movement.moveCastParams then
		params.FilterDescendantsInstances = grapple.Movement.moveCastParams.FilterDescendantsInstances
	end

	local camera = Workspace.CurrentCamera
	local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local forward = root.CFrame.LookVector
	local directions = {
		look,
		forward,
		-Vector3.yAxis,
		Vector3.yAxis,
		right,
		-right,
		-forward,
		(forward + right).Unit,
		(forward - right).Unit,
	}

	for _, direction in ipairs(directions) do
		local result = Workspace:Raycast(root.Position, direction * GRAPPLE_RANGE, params)
		if result and result.Instance and not result.Instance:IsDescendantOf(character) then
			return result
		end
	end

	return nil
end

local function releaseOwnedCast()
	local movement = ownedMovement
	local special = ownedSpecial
	ownedMovement = nil
	ownedSpecial = nil

	if not (movement and special and movement.ActiveSpecial == special) then
		return
	end

	pcall(function()
		if movement.grappling == true and typeof(special.End) == "function" then
			special:End(false)
		elseif typeof(movement.SpecialAction) == "function" then
			movement:SpecialAction(Enum.UserInputState.End)
		end
	end)
end

local function castGrapple(movement, grapple, character, humanoid)
	if movement.grappling or tonumber(grapple.Charges) == 0 or typeof(grapple.Start) ~= "function" then
		return "unavailable"
	end

	local hit = findGrappleHit(grapple, character)
	if not hit then
		return "retry"
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Running and hit.Instance.Name ~= "JumpPad" then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	ownedMovement = movement
	ownedSpecial = grapple
	local ok = pcall(function()
		grapple:Start(hit)
	end)
	if not ok or not (movement.grappling == true and isUsingAbility(humanoid)) then
		ownedMovement = nil
		ownedSpecial = nil
		return "unavailable"
	end

	task.wait(ABILITY_HOLD)
	releaseOwnedCast()
	return "success"
end

local function castStandardAbility(movement, special, humanoid)
	ownedMovement = movement
	ownedSpecial = special
	local ok = pcall(function()
		movement:SpecialAction(Enum.UserInputState.Begin)
	end)
	if not ok then
		ownedMovement = nil
		ownedSpecial = nil
		return "unavailable"
	end

	local startedAt = time()
	repeat
		if isUsingAbility(humanoid) then
			break
		end
		task.wait()
	until time() - startedAt >= ABILITY_HOLD

	local activated = isUsingAbility(humanoid)
	local remaining = ABILITY_HOLD - (time() - startedAt)
	if activated and remaining > 0 then
		task.wait(remaining)
	end
	releaseOwnedCast()
	return activated and "success" or "unavailable"
end

local function castNativeAbility(character, humanoid)
	if isUsingAbility(humanoid) then
		return "success"
	end

	local movement = findMovement(character, humanoid)
	local special = movement and movement.ActiveSpecial
	if not (movement and special) then
		return "retry"
	end

	if getClassId(movement):find("grappler", 1, true) then
		return castGrapple(movement, special, character, humanoid)
	end
	return castStandardAbility(movement, special, humanoid)
end

local function tryComplete(character, humanoid, main)
	if cycleComplete or castInProgress then
		return
	end

	-- Kolona's Idiotware inversion expects the ability to remain unused.
	if isInverted(main) then
		cycleComplete = true
		return
	end

	-- A player-owned cast already satisfies Kolona; never cancel or replace it.
	if isUsingAbility(humanoid) then
		cycleComplete = true
		return
	end

	castInProgress = true
	castGeneration += 1
	local generation = castGeneration
	task.spawn(function()
		local outcome = castNativeAbility(character, humanoid)
		if generation == castGeneration then
			castInProgress = false
			if outcome ~= "retry" then
				cycleComplete = true
			end
		end
	end)
end

local function run(controller)
	if running then
		return
	end

	running = true
	task.spawn(function()
		while enabled and controller and not controller.Destroyed do
			local character = getCharacter()
			local main = getMain()
			local humanoid = getHumanoid(character)
			local active = isKolonaActive(main)

			if active and not wasKolonaActive then
				resetCycle()
			end
			wasKolonaActive = active

			if not (active and character and main and humanoid) then
				releaseOwnedCast()
				resetCycle()
				task.wait(IDLE_INTERVAL)
				continue
			end

			captureTarget(main)
			updateTick(main)
			if isFatalWindow(main) then
				tryComplete(character, humanoid, main)
			end

			task.wait(ACTIVE_INTERVAL)
		end

		running = false
	end)
end

function AutoQTE.update(controller)
	enabled = controller and controller.KolonaAutoQTEEnabled == true
	if enabled then
		run(controller)
	else
		AutoQTE.disable()
	end
	return true
end

function AutoQTE.disable()
	enabled = false
	castGeneration += 1
	castInProgress = false
	releaseOwnedCast()
	resetCycle()
	cachedMovement = nil
	wasKolonaActive = false
	return true
end

return AutoQTE
