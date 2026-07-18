--!nocheck
-- [[
--  NULLSCAPE - Native Choice Registry
--  Tracks ChoiceOrb instances and metadata changes without repeated tag scans.
-- ]]

local CollectionService = game:GetService("CollectionService")

local Registry = {}

local entries = {}
local connections = {}
local revision = 0
local started = false
local cachedOrbs = nil

local function bump()
	revision += 1
	cachedOrbs = nil
end

local function disconnect(connection)
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

local function untrack(orb)
	local entry = entries[orb]
	if not entry then
		return
	end
	for _, connection in ipairs(entry.Connections) do
		disconnect(connection)
	end
	entries[orb] = nil
	bump()
end

local function track(orb)
	if not (orb and typeof(orb) == "Instance") or entries[orb] then
		return
	end
	local entry = { Connections = {} }
	entries[orb] = entry
	local function bindPrompt(instance)
		if instance:IsA("ProximityPrompt") then
			entry.Connections[#entry.Connections + 1] = instance:GetPropertyChangedSignal("Enabled"):Connect(bump)
		end
	end

	for _, attribute in ipairs({ "ChoiceType", "ChoiceName", "ItemIndex", "Active" }) do
		entry.Connections[#entry.Connections + 1] = orb:GetAttributeChangedSignal(attribute):Connect(bump)
	end
	entry.Connections[#entry.Connections + 1] = orb.DescendantAdded:Connect(function(instance)
		bindPrompt(instance)
		bump()
	end)
	entry.Connections[#entry.Connections + 1] = orb.DescendantRemoving:Connect(bump)
	entry.Connections[#entry.Connections + 1] = orb.AncestryChanged:Connect(function()
		if not orb:IsDescendantOf(workspace) then
			untrack(orb)
		end
	end)
	for _, descendant in ipairs(orb:GetDescendants()) do
		bindPrompt(descendant)
	end
	bump()
end

function Registry.start()
	if started then
		return true
	end
	started = true

	for _, orb in ipairs(CollectionService:GetTagged("ChoiceOrb")) do
		track(orb)
	end
	connections[#connections + 1] = CollectionService:GetInstanceAddedSignal("ChoiceOrb"):Connect(track)
	connections[#connections + 1] = CollectionService:GetInstanceRemovedSignal("ChoiceOrb"):Connect(untrack)
	bump()
	return true
end

function Registry.stop()
	if not started then
		return
	end
	started = false
	for _, connection in ipairs(connections) do
		disconnect(connection)
	end
	table.clear(connections)
	local orbs = {}
	for orb in pairs(entries) do
		orbs[#orbs + 1] = orb
	end
	for _, orb in ipairs(orbs) do
		untrack(orb)
	end
	bump()
end

function Registry.getOrbs()
	Registry.start()
	if cachedOrbs then
		return cachedOrbs
	end
	local orbs = {}
	for orb in pairs(entries) do
		if orb:IsDescendantOf(workspace) then
			orbs[#orbs + 1] = orb
		end
	end
	cachedOrbs = orbs
	return cachedOrbs
end

function Registry.getRevision()
	return revision
end

return Registry
