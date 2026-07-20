--!nocheck
-- [[
--  NULLSCAPE - Movement Lease Manager
--  Provides exclusive access to character movement (teleport, foothold, release)
-- ]]

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Transport = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Transport.luau")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MovementLease = {}
local activeLeaseToken = 0
local activeClaimToken = nil
local activeOwnerName = nil
local activeFootholdToken = 0
local activeFootholdPart = nil
local heldRootPart = nil
local heldCharacter = nil
local heldWasAnchored = false

local FOOTHOLD_SIZE = Vector3.new(18, 1, 18)
local FOOTHOLD_OFFSET = Vector3.new(0, -3.6, 0)
local SAFETY_FOOTHOLD_DURATION = 2.5
local FLOOR_RAY_DISTANCE = 20

local function releasePositionHold()
	local rootPart = heldRootPart
	local character = heldCharacter
	local wasAnchored = heldWasAnchored
	heldRootPart = nil
	heldCharacter = nil
	heldWasAnchored = false

	if not (rootPart and rootPart.Parent and character and character.Parent) then
		return
	end
	if Players.LocalPlayer.Character ~= character then
		return
	end

	pcall(function()
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.Anchored = wasAnchored
	end)
end

local function holdCharacterAt(rootPart, targetCFrame)
	local character = rootPart and rootPart.Parent
	if not (character and Players.LocalPlayer.Character == character) then
		return false
	end

	releasePositionHold()
	heldRootPart = rootPart
	heldCharacter = character
	heldWasAnchored = rootPart.Anchored

	local success = pcall(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:Move(Vector3.zero, false)
			humanoid:SetAttribute("PlayerMoveDirection", Vector3.zero)
			humanoid:SetAttribute("TrueMoveDirection", Vector3.zero)
		end
		rootPart.CFrame = targetCFrame
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.Anchored = true
	end)

	if not success then
		heldRootPart = nil
		heldCharacter = nil
		heldWasAnchored = false
	end
	return success
end

local function getOwnerPriority(ownerName)
	local name = tostring(ownerName or "")
	if string.sub(name, 1, 5) == "Pylon" then
		return 30
	elseif name == "AutoChoose" then
		return 20
	end
	return 10
end

local function createDeniedLease(ownerName, blockedBy)
	local lease = {
		Owner = ownerName,
		BlockedBy = blockedBy,
	}

	function lease:isValid()
		return false
	end

	function lease:moveTo()
		return false
	end

	function lease:moveCollectTo()
		return false
	end

	function lease:reportCollectResult() end

	function lease:placeFoothold()
		return nil
	end

	function lease:release() end

	return lease
end

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

local function createLease(ownerName, allowPreempt)
	if activeClaimToken == activeLeaseToken then
		if not allowPreempt then
			return nil
		end
		if getOwnerPriority(ownerName) < getOwnerPriority(activeOwnerName) then
			return createDeniedLease(ownerName, activeOwnerName)
		end
	end

	activeLeaseToken += 1
	local leaseToken = activeLeaseToken
	activeClaimToken = leaseToken
	activeOwnerName = ownerName
	setActiveLeaseState(leaseToken, ownerName)

	-- Create lease object
	local lease = {}
	lease.Token = leaseToken
	lease.Owner = ownerName
	local lastTargetCFrame = nil

	function lease:isValid()
		return activeLeaseToken == leaseToken
	end

	function lease:moveTo(cframe)
		if not self:isValid() then
			return false
		end
		local cf = typeof(cframe) == "Vector3" and CFrame.new(cframe) or cframe
		if typeof(cf) ~= "CFrame" then
			return false
		end
		releasePositionHold()
		lastTargetCFrame = cf
		return Context.moveCharacterTo(cf)
	end

	function lease:moveCollectTo(cframe)
		if not self:isValid() then
			return false
		end
		local cf = typeof(cframe) == "Vector3" and CFrame.new(cframe) or cframe
		if typeof(cf) ~= "CFrame" then
			return false
		end
		releasePositionHold()
		lastTargetCFrame = cf
		return Transport.moveTo(cf, function()
			return not self:isValid()
		end)
	end

	function lease:reportCollectResult(attempted, rejected)
		if not self:isValid() then
			return
		end
		Transport.reportCollectResult(attempted, rejected)
	end

	function lease:placeFoothold(position)
		if not self:isValid() then
			return nil
		end
		releasePositionHold()
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

		local shouldHoldPosition = options.HoldPosition == true or not hasGround
		local holdCFrame = hrp and hrp.CFrame or nil
		if hrp and lastTargetCFrame then
			holdCFrame = lastTargetCFrame
		end

		if shouldHoldPosition and hrp and holdCFrame then
			self:placeFoothold(holdCFrame.Position)
			shouldHoldPosition = holdCharacterAt(hrp, holdCFrame)
		end

		local keepDuration = tonumber(options.KeepFootholdDuration)
		local airborneWithoutGround = not hasGround
		if shouldHoldPosition or (options.OnlyKeepFootholdIfAirborne == true and hasGround) then
			keepDuration = nil
		elseif airborneWithoutGround and (not keepDuration or keepDuration < SAFETY_FOOTHOLD_DURATION) then
			keepDuration = SAFETY_FOOTHOLD_DURATION
		end

		local shouldKeepFoothold = keepDuration and hrp
		if shouldKeepFoothold and not (activeFootholdPart and activeFootholdPart.Parent) then
			self:placeFoothold(hrp.Position)
		end

		-- Schedule removal using foothold token to avoid destroying a newer foothold
		if not shouldHoldPosition then
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
		end

		if hrp and not shouldHoldPosition then
			Context.releaseCharacterControl({
				SkipVelocityClear = options.SkipVelocityClear == true,
				SkipStateChange = options.SkipStateChange == true,
				ForceAbilityClear = options.ForceAbilityClear == true,
				State = options.State or Enum.HumanoidStateType.Running,
			})
		end

		if activeLeaseToken == leaseToken then
			activeClaimToken = nil
			activeOwnerName = nil
			activeLeaseToken += 1
		end
	end

	return lease
end

function MovementLease.acquire(ownerName)
	return createLease(ownerName, true)
end

function MovementLease.tryAcquire(ownerName)
	return createLease(ownerName, false)
end

function MovementLease.getActiveOwner()
	if activeClaimToken == activeLeaseToken then
		return activeOwnerName
	end
	return nil
end

function MovementLease.invalidateActive(maxOwnerPriority)
	if activeClaimToken == activeLeaseToken
		and maxOwnerPriority ~= nil
		and getOwnerPriority(activeOwnerName) > maxOwnerPriority
	then
		return false
	end
	activeLeaseToken += 1
	activeClaimToken = nil
	activeOwnerName = nil
	clearActiveLeaseState()
	releasePositionHold()
	cleanUpFootholdPart()
	return true
end

function MovementLease.resetTransport()
	Transport.reset()
end

return MovementLease
