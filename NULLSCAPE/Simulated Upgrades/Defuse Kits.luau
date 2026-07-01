--!nocheck
-- [[
--  NULLSCAPE - Tripmine Defuse / Barrier Logic
--  Keeps defensive tripmine modes separate from Charger-specific assists.
-- ]]

local Barrier = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")

local LocalPlayer = Players.LocalPlayer

local BLOCKER_MODE = "Blocker"
local BARRIER_MODE = "Barrier"
local BLOCKER_FOLDER_NAME = "NULLSCAPE_TripmineBlockers"
local BLOCKER_SCAN_RADIUS = 64
local BLOCKER_BASE_RADIUS = 2.25
local BLOCKER_REPEL_PADDING = 0.75
local BLOCKER_REPEL_SPEED = 34
local BLOCKER_REPEL_VERTICAL_LIFT = 2.5
local BLOCKER_RADIUS_TOUCH_PADDING = 0.65
local BLOCKER_COLLISION_HEIGHT = 4.25
local BLOCKER_VERTICAL_OFFSET = 1.8
local BLOCKER_CREATE_PADDING = 3
local BLOCKER_APPROACH_PADDING = 2.5
local BLOCKER_MAX_ACTIVE = 4
local ACTIVE_WATCH_INTERVAL = 0.12
local IDLE_WATCH_INTERVAL = 0.35

local activeController = nil
local watcherRunning = false
local watcherToken = {}
local iframeObject = nil
local cachedGCH = nil
local blockerFolder = nil
local blockerParts = {}

local globals = getgenv()._NULLSCAPE_Globals or {}
getgenv()._NULLSCAPE_Globals = globals
globals.TripmineBarrierWatcherToken = watcherToken
globals.TripmineIframeOwners = globals.TripmineIframeOwners or {}

local IFRAME_OWNER = "DefuseKits"

local function getIframeOwners()
	globals.TripmineIframeOwners = globals.TripmineIframeOwners or {}
	return globals.TripmineIframeOwners
end

local function hasIframeOwner()
	for _, owns in pairs(getIframeOwners()) do
		if owns then
			return true
		end
	end

	return false
end

local function hasIframes()
	return iframeObject ~= nil and iframeObject.Parent ~= nil
end

local function addIframes()
	getIframeOwners()[IFRAME_OWNER] = true

	if hasIframes() then
		return
	end

	local existing = LocalPlayer:FindFirstChild("TRIP_IFRAMES")
	if existing then
		iframeObject = existing
		return
	end

	local obj = Instance.new("BoolValue")
	obj.Name = "TRIP_IFRAMES"
	obj.Parent = LocalPlayer
	iframeObject = obj
end

local function removeIframes()
	getIframeOwners()[IFRAME_OWNER] = nil
	if hasIframeOwner() then
		return
	end

	if iframeObject then
		pcall(function()
			iframeObject:Destroy()
		end)
		iframeObject = nil
	end

	local existing = LocalPlayer:FindFirstChild("TRIP_IFRAMES")
	if existing then
		pcall(function()
			existing:Destroy()
		end)
	end
end

local function getGiftClientHandler()
	if cachedGCH then
		return cachedGCH
	end

	local ok, result = pcall(function()
		return require(game:GetService("ReplicatedFirst").ClientModules.GiftClient.GiftClientHandler)
	end)
	if ok and result then
		cachedGCH = result
		return result
	end

	return nil
end

local function getBlockerFolder()
	if blockerFolder and blockerFolder.Parent then
		return blockerFolder
	end

	local existing = Workspace:FindFirstChild(BLOCKER_FOLDER_NAME)
	if existing then
		blockerFolder = existing
		return blockerFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = BLOCKER_FOLDER_NAME
	folder.Parent = Workspace
	blockerFolder = folder
	return folder
end

local function destroyBlocker(giftId)
	local part = blockerParts[giftId]
	if part then
		pcall(function()
			part:Destroy()
		end)
		blockerParts[giftId] = nil
	end
end

local function clearBlockers()
	for giftId in pairs(blockerParts) do
		destroyBlocker(giftId)
	end
end

local function getBlockerRadius(gift)
	local size = tonumber(gift and gift.Size) or 1
	return math.clamp(BLOCKER_BASE_RADIUS * size + BLOCKER_RADIUS_TOUCH_PADDING, 2.75, 8)
end

local function getBlockerTransparency(dist, radius)
	if type(dist) ~= "number" then
		return 0.96
	end

	if dist <= radius + 1.5 then
		return 0.94
	end

	if dist <= radius + 4 then
		return 0.98
	end

	return 1
end

local function getGiftPosition(gift)
	local giftPos = gift and gift.Position
	if typeof(giftPos) == "Vector3" then
		return giftPos
	end

	local model = gift and gift.Model
	if typeof(model) == "Instance" and model.Parent then
		if model:IsA("BasePart") then
			return model.Position
		end

		local part = model:FindFirstChildWhichIsA("BasePart", true)
		if part and part.Parent then
			return part.Position
		end
	end

	return nil
end

local function isTripmineGiftActive(gift)
	if not gift or not gift.Tripmine or gift.Collected or gift.Destroyed or gift.ClientCollected then
		return false
	end

	local model = gift.Model
	if typeof(model) == "Instance" and not model.Parent then
		return false
	end

	return getGiftPosition(gift) ~= nil
end

local function getHorizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getTripmineThreatScore(hrp, giftPos, dist, radius)
	local velocity = getHorizontal(hrp.AssemblyLinearVelocity or hrp.Velocity)
	local speed = velocity.Magnitude
	local score = dist

	if speed > 8 then
		local travel = velocity.Unit * math.clamp(speed * 0.28, 4, 18)
		local projectedPos = hrp.Position + travel
		local projectedDist = (getHorizontal(projectedPos - giftPos)).Magnitude
		local toMine = getHorizontal(giftPos - hrp.Position)
		local ahead = toMine.Magnitude > 0.05 and velocity.Unit:Dot(toMine.Unit) or 0

		if ahead > 0.25 and projectedDist <= radius + BLOCKER_APPROACH_PADDING then
			score = math.min(score, projectedDist - speed * 0.02)
		end
	end

	return score
end

local function shouldCreateBlocker(hrp, giftPos, dist, radius)
	if dist <= radius + BLOCKER_CREATE_PADDING then
		return true
	end

	local velocity = getHorizontal(hrp.AssemblyLinearVelocity or hrp.Velocity)
	if velocity.Magnitude <= 12 then
		return false
	end

	local toMine = getHorizontal(giftPos - hrp.Position)
	if toMine.Magnitude <= 0.05 or velocity.Unit:Dot(toMine.Unit) <= 0.25 then
		return false
	end

	local projectedPos = hrp.Position + velocity.Unit * math.clamp(velocity.Magnitude * 0.28, 4, 18)
	local projectedDist = (getHorizontal(projectedPos - giftPos)).Magnitude
	return projectedDist <= radius + BLOCKER_APPROACH_PADDING
end

local function ensureBlocker(giftId, gift, giftPos, dist)
	if typeof(giftPos) ~= "Vector3" then
		destroyBlocker(giftId)
		return nil
	end

	local radius = getBlockerRadius(gift)
	local part = blockerParts[giftId]
	if not (part and part.Parent) then
		part = Instance.new("Part")
		part.Name = "TripmineBlocker_" .. tostring(giftId)
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.ForceField
		part.Color = Color3.fromRGB(255, 0, 170)
		part.Transparency = 1
		part.Parent = getBlockerFolder()
		blockerParts[giftId] = part
	end

	local diameter = radius * 2
	part.Size = Vector3.new(diameter, BLOCKER_COLLISION_HEIGHT, diameter)
	part.CFrame = CFrame.new(giftPos + Vector3.new(0, BLOCKER_VERTICAL_OFFSET, 0))
	part.Transparency = getBlockerTransparency(dist, radius)
	return part
end

local function applyTripmineRepel(hrp, gift, dist)
	local giftPos = getGiftPosition(gift)
	if not (hrp and typeof(giftPos) == "Vector3") then
		return
	end

	local radius = getBlockerRadius(gift)
	if dist > radius + BLOCKER_REPEL_PADDING then
		return
	end

	local away = hrp.Position - giftPos
	if away.Magnitude <= 0.05 then
		away = Vector3.new(0, 0, 1)
	end

	local flatAway = Vector3.new(away.X, 0, away.Z)
	if flatAway.Magnitude <= 0.05 then
		flatAway = away
	end
	flatAway = flatAway.Unit

	local velocity = hrp.Velocity
	local inwardSpeed = -Vector3.new(velocity.X, 0, velocity.Z):Dot(flatAway)
	local pushSpeed = math.max(BLOCKER_REPEL_SPEED, inwardSpeed + 18)
	local nextHorizontal = flatAway * pushSpeed
	local nextY = math.max(velocity.Y, BLOCKER_REPEL_VERTICAL_LIFT)
	local nextVelocity = Vector3.new(nextHorizontal.X, nextY, nextHorizontal.Z)
	hrp.Velocity = nextVelocity
	MomentumMemory.noteImpulse(hrp, "DefuseKitBlockerRepel", velocity, nextVelocity, nextVelocity - velocity, {
		GiftName = tostring(gift and gift.Name or "Tripmine"),
	})
end

local function updateBlockers()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		clearBlockers()
		return
	end

	local GCH = getGiftClientHandler()
	if not GCH or not GCH.Gifts then
		clearBlockers()
		return
	end

	local hrpPos = hrp.Position
	local candidates = {}
	local seen = {}

	for giftId, gift in pairs(GCH.Gifts) do
		if isTripmineGiftActive(gift) then
			local giftPos = getGiftPosition(gift)
			local dist = (hrpPos - giftPos).Magnitude
			local radius = getBlockerRadius(gift)

			if dist <= BLOCKER_SCAN_RADIUS and shouldCreateBlocker(hrp, giftPos, dist, radius) then
				table.insert(candidates, {
					GiftId = giftId,
					Gift = gift,
					Position = giftPos,
					Distance = dist,
					Score = getTripmineThreatScore(hrp, giftPos, dist, radius),
				})
			else
				destroyBlocker(giftId)
			end
		else
			destroyBlocker(giftId)
		end
	end

	table.sort(candidates, function(a, b)
		return a.Score < b.Score
	end)

	for i, candidate in ipairs(candidates) do
		if i > BLOCKER_MAX_ACTIVE then
			destroyBlocker(candidate.GiftId)
			continue
		end

		seen[candidate.GiftId] = true
		ensureBlocker(candidate.GiftId, candidate.Gift, candidate.Position, candidate.Distance)
		applyTripmineRepel(hrp, candidate.Gift, candidate.Distance)
	end

	for giftId in pairs(blockerParts) do
		if not seen[giftId] then
			destroyBlocker(giftId)
		end
	end
end

local function startWatcher()
	if watcherRunning then
		return
	end
	watcherRunning = true

	task.spawn(function()
		local cleanedIdle = false
		while not globals or globals.TripmineBarrierWatcherToken == watcherToken do
			task.wait(
				activeController and activeController.TripmineBarrierEnabled and ACTIVE_WATCH_INTERVAL
					or IDLE_WATCH_INTERVAL
			)

			if not activeController or not activeController.TripmineBarrierEnabled then
				if not cleanedIdle then
					removeIframes()
					clearBlockers()
					cleanedIdle = true
				end
				continue
			end
			cleanedIdle = false

			local mode = activeController.TripmineMode or BARRIER_MODE
			if mode == BARRIER_MODE or mode == BLOCKER_MODE then
				addIframes()
			else
				removeIframes()
				clearBlockers()
				continue
			end

			if mode == BLOCKER_MODE then
				updateBlockers()
			else
				clearBlockers()
			end
		end
		removeIframes()
		clearBlockers()
		watcherRunning = false
	end)
end

function Barrier.update(controller)
	activeController = controller

	if not controller.TripmineBarrierEnabled then
		removeIframes()
		clearBlockers()
	end
end

function Barrier.Init()
	startWatcher()
	print("[NULLSCAPE Defuse] Module ready. Modes: Barrier | Blocker")
end

Barrier.Init()

return Barrier
