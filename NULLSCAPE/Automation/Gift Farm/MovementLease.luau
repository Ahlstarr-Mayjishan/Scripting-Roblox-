--!nocheck
-- [[
--  NULLSCAPE - Movement Lease Manager
--  Provides exclusive access to character movement (teleport, foothold, release)
-- ]]

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Workspace = game:GetService("Workspace")

local MovementLease = {}
local activeLeaseToken = 0
local activeFootholdToken = 0
local activeFootholdPart = nil

local FOOTHOLD_SIZE = Vector3.new(18, 1, 18)
local FOOTHOLD_OFFSET = Vector3.new(0, -3.6, 0)
local SAFETY_FOOTHOLD_DURATION = 2.5
local FLOOR_RAY_DISTANCE = 20

local function setActiveLeaseState(leaseToken, ownerName)
	local globals = getgenv()._NULLSCAPE_Globals
	if typeof(globals) ~= "table" then
		return
	end

	globals.GiftFarmMovementLeaseActive = leaseToken ~= nil
	globals.GiftFarmMovementLeaseToken = leaseToken
	globals.GiftFarmMovementLeaseOwner = ownerName
end

local function clearActiveLeaseState(leaseToken)
	local globals = getgenv()._NULLSCAPE_Globals
	if typeof(globals) ~= "table" then
		return
	end

	if leaseToken == nil or globals.GiftFarmMovementLeaseToken == leaseToken then
		globals.GiftFarmMovementLeaseActive = false
		globals.GiftFarmMovementLeaseToken = nil
		globals.GiftFarmMovementLeaseOwner = nil
	end
end

local function getRuntimeContainer()
	local container = Workspace:FindFirstChild("NULLSCAPE_Runtime")
	if not container then
		container = Instance.new("Folder")
		container.Name = "NULLSCAPE_Runtime"
		container.Parent = Workspace
	end
	return container
end

-- Creates or retrieves the single foothold part
local function getFootholdPart()
	if activeFootholdPart and activeFootholdPart.Parent then
		return activeFootholdPart
	end

	activeFootholdPart = Instance.new("Part")
	activeFootholdPart.Name = "NULLSCAPE_MovementLeaseFoothold"
	activeFootholdPart.Anchored = true
	activeFootholdPart.CanCollide = true
	activeFootholdPart.CanTouch = false
	activeFootholdPart.CanQuery = true
	activeFootholdPart.CastShadow = false
	activeFootholdPart.Material = Enum.Material.SmoothPlastic
	activeFootholdPart.Transparency = 1
	activeFootholdPart.Size = FOOTHOLD_SIZE
	activeFootholdPart.Parent = getRuntimeContainer()
	return activeFootholdPart
end

local function cleanUpFootholdPart()
	if activeFootholdPart then
		pcall(function()
			activeFootholdPart:Destroy()
		end)
		activeFootholdPart = nil
	end
end

local function hasGroundBelow(hrp)
	if not (hrp and hrp.Parent) then
		return false
	end

	local params = RaycastParams.new()
	local currentRooms = Workspace:FindFirstChild("CurrentRooms")
	if currentRooms then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { currentRooms }
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { hrp.Parent, getRuntimeContainer() }
	end
	params.RespectCanCollide = true

	local result = Workspace:Raycast(hrp.Position, Vector3.new(0, -FLOOR_RAY_DISTANCE, 0), params)
	return result ~= nil
end

function MovementLease.acquire(ownerName)
	activeLeaseToken += 1
	local leaseToken = activeLeaseToken
	setActiveLeaseState(leaseToken, ownerName)

	-- Create lease object
	local lease = {}
	lease.Token = leaseToken
	lease.Owner = ownerName

	function lease:isValid()
		return activeLeaseToken == leaseToken
	end

	function lease:moveTo(cframe)
		if not self:isValid() then
			return false
		end
		local cf = typeof(cframe) == "Vector3" and CFrame.new(cframe) or cframe
		return Context.moveCharacterTo(cf)
	end

	function lease:placeFoothold(position)
		if not self:isValid() then
			return nil
		end
		activeFootholdToken += 1
		local part = getFootholdPart()
		part.Parent = getRuntimeContainer()
		part.CFrame = CFrame.new(position + FOOTHOLD_OFFSET)
		return part
	end

	function lease:release(options)
		if not self:isValid() then
			return
		end
		clearActiveLeaseState(leaseToken)
		options = options or {}
		local hrp = Context.getRootPart()
		local hasGround = false
		if hrp then
			hasGround = hasGroundBelow(hrp)
		end

		local keepDuration = tonumber(options.KeepFootholdDuration)
		local airborneWithoutGround = not hasGround
		if airborneWithoutGround and (not keepDuration or keepDuration < SAFETY_FOOTHOLD_DURATION) then
			keepDuration = SAFETY_FOOTHOLD_DURATION
		end

		local shouldKeepFoothold = keepDuration and hrp
		if shouldKeepFoothold and not (activeFootholdPart and activeFootholdPart.Parent) then
			self:placeFoothold(hrp.Position)
		end

		-- Schedule removal using foothold token to avoid destroying a newer foothold
		if keepDuration and keepDuration > 0 then
			local myFootholdToken = activeFootholdToken
			task.delay(keepDuration, function()
				if activeFootholdToken == myFootholdToken then
					cleanUpFootholdPart()
				end
			end)
		else
			cleanUpFootholdPart()
		end

		if hrp then
			Context.releaseCharacterControl({
				SkipVelocityClear = options.SkipVelocityClear == true,
				SkipTouchRestore = options.SkipTouchRestore == true,
				SkipStateChange = options.SkipStateChange == true,
				State = options.State or Enum.HumanoidStateType.Running,
			})
		end
	end

	return lease
end

function MovementLease.invalidateActive()
	activeLeaseToken += 1
	clearActiveLeaseState()
	cleanUpFootholdPart()
end

return MovementLease
