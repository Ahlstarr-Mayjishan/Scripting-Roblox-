--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local RunService = game:GetService("RunService")

local Collector = {}
local CLUSTER_SETTLE = 0.08
local comboCount = 0
local lastCollectTick = 0

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

function Collector.collectCluster(controller, hrp, cluster, range)
	local oldCFrame = hrp.CFrame
	local oldAnchored = hrp.Anchored
	local targetCFrame = CFrame.new(cluster[1].pos + Vector3.new(0, 3, 0))
	local collectedEvent = Context.getCollectedGiftEvent()

	hrp.Anchored = true
	hrp.CFrame = targetCFrame
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
	if controller.GiftFarmReturnAfterCluster ~= false and hrp.Parent then
		hrp.CFrame = oldCFrame
	end
	if hrp.Parent then
		hrp.Anchored = oldAnchored
	end
end

return Collector
