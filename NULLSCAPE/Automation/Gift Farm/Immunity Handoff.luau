--!nocheck
-- [[
--  NULLSCAPE - Gift Farm Immunity Handoff
--  Temporarily disables entity immunities and restores their exact prior state.
-- ]]

local ImmunityHandoff = {}

local state = {
	Snapshot = nil,
	Controller = nil,
	StatusSnapshot = nil,
	StatusModule = nil,
}

local function getController()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.activeEntitiesController or nil
end

local function reconcile(controller)
	if not controller then
		return
	end
	if typeof(controller.ReconcileImmunityState) == "function" then
		pcall(function()
			controller:ReconcileImmunityState()
		end)
	end
	if typeof(controller.UpdateTouchImmunityState) == "function" then
		pcall(function()
			controller:UpdateTouchImmunityState()
		end)
	end
end

function ImmunityHandoff.disable()
	if state.Snapshot then
		return false
	end

	local controller = getController()
	if typeof(controller) ~= "table" or controller.Destroyed == true then
		return false
	end

	local snapshot = {}
	for key, value in pairs(controller) do
		if typeof(key) == "string" and typeof(value) == "boolean" and string.match(key, "Immune$") then
			snapshot[key] = value
			controller[key] = false
		end
	end
	state.Snapshot = snapshot
	state.Controller = controller

	local statusImmunity = controller.StatusImmunity
	if typeof(statusImmunity) == "table" and typeof(statusImmunity.ActiveImmunities) == "table" then
		local statusSnapshot = {}
		for name, active in pairs(statusImmunity.ActiveImmunities) do
			if active == true then
				table.insert(statusSnapshot, name)
			end
		end
		state.StatusSnapshot = statusSnapshot
		state.StatusModule = statusImmunity
		if typeof(statusImmunity.SetActiveImmunities) == "function" then
			pcall(statusImmunity.SetActiveImmunities, {})
		end
	end
	reconcile(controller)
	return true
end

function ImmunityHandoff.restore()
	local snapshot = state.Snapshot
	local controller = state.Controller
	local statusSnapshot = state.StatusSnapshot
	local statusImmunity = state.StatusModule
	state.Snapshot = nil
	state.Controller = nil
	state.StatusSnapshot = nil
	state.StatusModule = nil
	if not (snapshot and controller and controller.Destroyed ~= true) then
		return false
	end

	for key, value in pairs(snapshot) do
		controller[key] = value
	end
	if statusSnapshot and statusImmunity and typeof(statusImmunity.SetActiveImmunities) == "function" then
		pcall(statusImmunity.SetActiveImmunities, statusSnapshot)
	end
	reconcile(controller)
	return true
end

function ImmunityHandoff.getState()
	return state
end

return ImmunityHandoff
