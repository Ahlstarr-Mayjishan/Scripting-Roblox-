--!nocheck
-- [[
--  Authoritative native Pylon progress shared by Automation workflows.
-- ]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PylonState = {}

PylonState.TargetLevel = 35

function PylonState.getLevel()
	local level = ReplicatedStorage:FindFirstChild("Level")
	if level and (level:IsA("IntValue") or level:IsA("NumberValue")) then
		return tonumber(level.Value) or 0
	end
	return 0
end

function PylonState.getProgress()
	local completed = tonumber(ReplicatedStorage:GetAttribute("PylonsDone")) or 0
	local maximum = tonumber(ReplicatedStorage:GetAttribute("MaxPylons")) or 0
	return completed, maximum
end

local function countActiveTaggedPylons()
	local active = 0
	local pending = 0
	for _, pylon in ipairs(CollectionService:GetTagged("Pylon")) do
		if pylon and pylon:IsDescendantOf(workspace) then
			active += 1
			if pylon:GetAttribute("Completed") ~= true then
				pending += 1
			end
		end
	end
	return active, pending
end

function PylonState.getSnapshot(controller)
	local level = PylonState.getLevel()
	local completed, maximum = PylonState.getProgress()
	local active, taggedPending = countActiveTaggedPylons()
	local enabled = controller and controller.PylonActivatorEnabled == true
	local complete = maximum > 0 and completed >= maximum
		or controller and controller.PylonActivatorComplete == true
	local pending = enabled
		and level >= PylonState.TargetLevel
		and not complete
		and (maximum > completed or taggedPending > 0 or controller.PylonActivatorPending == true)

	return {
		Enabled = enabled,
		Level = level,
		Completed = completed,
		Maximum = maximum,
		Active = active,
		TaggedPending = taggedPending,
		Complete = complete == true,
		Pending = pending == true,
	}
end

function PylonState.shouldWait(controller)
	local snapshot = PylonState.getSnapshot(controller)
	return snapshot.Pending, snapshot
end

return PylonState
