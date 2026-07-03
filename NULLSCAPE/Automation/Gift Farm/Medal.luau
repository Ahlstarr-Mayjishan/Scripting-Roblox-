--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local Medal = {}

local ACTION_COOLDOWN = 0.8
local TOUCH_SETTLE = 0.08
local lastActionAt = 0

local function getCharacter()
	return game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.Character
end

local function getMedalPart()
	local medal = workspace:FindFirstChild("Medal")
	if not medal then
		return nil
	end
	if medal:IsA("BasePart") then
		return medal
	end
	if medal:IsA("Model") then
		return medal:FindFirstChild("Handle") or medal:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function touch(part, hrp)
	if typeof(firetouchinterest) ~= "function" then
		return
	end
	pcall(function()
		firetouchinterest(part, hrp, 0)
		task.wait()
		firetouchinterest(part, hrp, 1)
	end)
end

local function carriesMedal()
	local character = getCharacter()
	return character and character:FindFirstChild("Medal") ~= nil
end

function Medal.tryStep(controller, hrp)
	if not (controller and controller.CollectMedalEnabled == true and hrp and hrp.Parent) then
		return false
	end
	if os.clock() - lastActionAt < ACTION_COOLDOWN then
		return false
	end

	if carriesMedal() then
		local beacon = Context.getBeaconPart()
		if not beacon then
			return false
		end

		lastActionAt = os.clock()
		if Context and typeof(Context.restoreBeaconInteraction) == "function" then
			Context.restoreBeaconInteraction()
		end
		Context.moveCharacterTo(CFrame.new(beacon.Position + Vector3.new(0, 4, 0)))
		task.wait(TOUCH_SETTLE)
		touch(beacon, hrp)
		return true, "SubmittingMedal"
	end

	local medalPart = getMedalPart()
	if not medalPart then
		return false
	end

	lastActionAt = os.clock()
	Context.moveCharacterTo(medalPart.CFrame + Vector3.new(0, 2, 0))
	task.wait(TOUCH_SETTLE)
	touch(medalPart, hrp)
	return true, "CollectingMedal"
end

function Medal.reset()
	lastActionAt = 0
end

return Medal
