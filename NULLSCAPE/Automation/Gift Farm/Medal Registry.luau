--!nocheck
-- [[
--  NULLSCAPE - Medal Registry
--  Performs one discovery scan, then tracks Medal instances reactively.
-- ]]

local CollectionService = game:GetService("CollectionService")

local Registry = {}

local medals = setmetatable({}, { __mode = "k" })
local connections = {}
local started = false
local revision = 0
local cachedInstances = nil

local function bump()
	revision += 1
	cachedInstances = nil
end

local function isMedal(instance)
	return instance
		and typeof(instance) == "Instance"
		and (instance.Name == "Medal" or CollectionService:HasTag(instance, "Medal"))
end

local function add(instance)
	if isMedal(instance) and not medals[instance] then
		medals[instance] = true
		bump()
	end
end

local function remove(instance)
	if medals[instance] then
		medals[instance] = nil
		bump()
	end
end

function Registry.start()
	if started then
		return true
	end
	started = true
	connections[#connections + 1] = workspace.DescendantAdded:Connect(add)
	connections[#connections + 1] = workspace.DescendantRemoving:Connect(remove)
	connections[#connections + 1] = CollectionService:GetInstanceAddedSignal("Medal"):Connect(add)
	connections[#connections + 1] = CollectionService:GetInstanceRemovedSignal("Medal"):Connect(remove)

	local scanStartedAt = os.clock()
	local scanned = 0
	for _, descendant in ipairs(workspace:GetDescendants()) do
		add(descendant)
		scanned += 1
		if scanned % 200 == 0 and os.clock() - scanStartedAt >= 0.003 then
			task.wait()
			scanStartedAt = os.clock()
		end
	end
	for _, tagged in ipairs(CollectionService:GetTagged("Medal")) do
		add(tagged)
	end

	bump()
	return true
end

function Registry.stop()
	if not started then
		return
	end
	started = false
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(connections)
	table.clear(medals)
	bump()
end

function Registry.getInstances()
	Registry.start()
	if cachedInstances then
		return cachedInstances
	end
	local result = {}
	for instance in pairs(medals) do
		if instance:IsDescendantOf(workspace) then
			result[#result + 1] = instance
		end
	end
	cachedInstances = result
	return cachedInstances
end

function Registry.getRevision()
	return revision
end

return Registry
