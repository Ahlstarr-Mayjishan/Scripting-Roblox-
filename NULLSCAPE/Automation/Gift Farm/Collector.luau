--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local RunService = game:GetService("RunService")

local Collector = {}
local CLUSTER_SETTLE = 0.04
local comboCount = 0
local lastCollectTick = 0
local activeRestore = nil

local function collectGift(gift, collectedEvent)
	local now = tick()
	if math.min(1.2, math.pow(1.1, comboCount) * 0.8) <= now - lastCollectTick then
		comboCount = 0
	end
	comboCount += 1
	lastCollectTick = now

	pcall(function()
		gift:Collect(false, true, comboCount)
	end)

	if collectedEvent then
		pcall(function()
			collectedEvent:Fire()
		end)
	end
end

local function clearVelocity(hrp)
	if not (hrp and hrp.Parent) then
		return
	end

	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
end

function Collector.releaseCharacter()
	local hrp = Context.getRootPart()
	if hrp and hrp.Parent then
		hrp.Anchored = false
		clearVelocity(hrp)
	end
end

function Collector.restoreMovement()
	local restore = activeRestore
	activeRestore = nil

	if restore and restore.Hrp and restore.Hrp.Parent then
		local hrp = restore.Hrp
		if restore.ReturnAfter ~= false and restore.CFrame then
			Context.moveCharacterTo(restore.CFrame)
		end
		hrp.Anchored = false
		clearVelocity(hrp)
		return true
	end

	Collector.releaseCharacter()
	return false
end

function Collector.collectCluster(controller, hrp, cluster, range, options)
	if not (hrp and hrp.Parent and cluster and cluster[1]) then
		return false
	end

	options = options or {}
	local oldCFrame = hrp.CFrame
	local targetCFrame = CFrame.new(cluster[1].pos + Vector3.new(0, 3, 0))
	local collectedEvent = Context.getCollectedGiftEvent()
	local returnAfter = controller.GiftFarmReturnAfterCluster ~= false and options.KeepPosition ~= true

	activeRestore = {
		Hrp = hrp,
		CFrame = oldCFrame,
		ReturnAfter = returnAfter,
	}

	local ok, err = pcall(function()
		hrp.Anchored = false
		Context.moveCharacterTo(targetCFrame)
		clearVelocity(hrp)
		RunService.Heartbeat:Wait()
		task.wait(CLUSTER_SETTLE)

		local currentPos = hrp.Position
		local perFrame = math.clamp(tonumber(controller.GiftFarmCollectsPerFrame) or 8, 1, 60)
		local collectedThisFrame = 0

		for _, item in ipairs(cluster) do
			if item.rawObj
				and not item.rawObj.Destroyed
				and not item.rawObj.Collected
				and (item.pos - currentPos).Magnitude <= range + 1
			then
				collectGift(item.rawObj, collectedEvent)
				collectedThisFrame += 1
				if collectedThisFrame >= perFrame then
					collectedThisFrame = 0
					RunService.Heartbeat:Wait()
					if not (hrp and hrp.Parent) then
						break
					end
					currentPos = hrp.Position
				end
			end
		end

		task.wait(CLUSTER_SETTLE)
	end)

	Collector.restoreMovement()
	if not ok then
		error(err, 0)
	end

	return true
end

return Collector
