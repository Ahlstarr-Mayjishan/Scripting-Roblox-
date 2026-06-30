--!nocheck
--[[
 NULLSCAPE - Grappler Assist Candidate Registry
 Tracks named grapple targets in Workspace for fast assist scans.
]]

local Workspace = game:GetService("Workspace")

local CandidateRegistry = {}

function CandidateRegistry.new(validTargets, isTargetUsable)
	return {
		Candidates = {},
		Connections = {},
		ValidTargets = validTargets or {},
		IsTargetUsable = isTargetUsable,
	}
end

function CandidateRegistry.getTargetPart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

function CandidateRegistry.getCandidateName(state, instance, part)
	local validTargets = state and state.ValidTargets or {}
	if instance and validTargets[instance.Name] then
		return instance.Name
	end
	if part and validTargets[part.Name] then
		return part.Name
	end
	return nil
end

function CandidateRegistry.register(state, instance)
	if not (state and instance) then
		return
	end

	local part = CandidateRegistry.getTargetPart(instance)
	local targetName = CandidateRegistry.getCandidateName(state, instance, part)
	if not part or not targetName then
		return
	end
	if state.IsTargetUsable and state.IsTargetUsable(targetName, part) == false then
		return
	end

	state.Candidates[instance] = {
		Instance = instance,
		Part = part,
		Name = targetName,
	}
end

function CandidateRegistry.registerBranch(state, instance, root)
	local current = instance
	while current and current ~= root do
		CandidateRegistry.register(state, current)
		current = current.Parent
	end
end

function CandidateRegistry.unregister(state, instance)
	if not (state and instance) then
		return
	end

	state.Candidates[instance] = nil
end

function CandidateRegistry.unregisterTree(state, instance)
	CandidateRegistry.unregister(state, instance)
	if not instance then
		return
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		CandidateRegistry.unregister(state, descendant)
	end
end

function CandidateRegistry.clearConnections(state)
	if not state then
		return
	end

	for _, connection in ipairs(state.Connections) do
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
	table.clear(state.Connections)
end

function CandidateRegistry.clear(state)
	if not state then
		return
	end

	CandidateRegistry.clearConnections(state)
	table.clear(state.Candidates)
end

function CandidateRegistry.rebuild(state)
	if not state then
		return
	end

	table.clear(state.Candidates)
	local validTargets = state.ValidTargets or {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if validTargets[descendant.Name] then
			CandidateRegistry.registerBranch(state, descendant, Workspace)
		end
	end
end

function CandidateRegistry.watchWorkspace(state)
	if not state then
		return
	end

	CandidateRegistry.clearConnections(state)
	CandidateRegistry.rebuild(state)

	table.insert(
		state.Connections,
		Workspace.DescendantAdded:Connect(function(descendant)
			if state.ValidTargets[descendant.Name] then
				CandidateRegistry.registerBranch(state, descendant, Workspace)
			end
		end)
	)
	table.insert(
		state.Connections,
		Workspace.DescendantRemoving:Connect(function(descendant)
			if state.ValidTargets[descendant.Name] then
				CandidateRegistry.unregisterTree(state, descendant)
			end
		end)
	)
end

function CandidateRegistry.toList(state)
	local list = {}
	if not state then
		return list
	end

	for _, candidate in pairs(state.Candidates) do
		table.insert(list, candidate)
	end
	return list
end

return CandidateRegistry
