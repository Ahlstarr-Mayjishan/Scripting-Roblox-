--!nocheck
-- [[
--  NULLSCAPE - Status Effect and Knockback Immunity Controller
--  Manages status effect immunities and physical shockwave knockbacks.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local getgenv = getgenv

local StatusImmunity = {
	ActiveImmunities = {},
	ActiveCallbacks = setmetatable({}, { __mode = "k" }),
	Hooked = false,
}

getgenv()._NULLSCAPE_Globals = getgenv()._NULLSCAPE_Globals or {}
local runtimeGlobals = getgenv()._NULLSCAPE_Globals
if runtimeGlobals then
	runtimeGlobals.NullscapeStatusImmunity = StatusImmunity
end

local function getController()
	local sharedState = getgenv()._NULLSCAPE_Globals
	return sharedState and sharedState.activeEntitiesController
end

local function rememberCallback(callback)
	if typeof(callback) == "function" then
		StatusImmunity.ActiveCallbacks[callback] = true
	end
end

function StatusImmunity.isImmune(statusName)
	if StatusImmunity.ActiveImmunities[statusName] == true then
		return true
	end

	local controller = getController()
	if controller and statusName == "Concussion" and controller.FleshConcussionImmune == true then
		return true
	end

	return false
end

function StatusImmunity.GetActiveImmunities()
	local list = {}
	for name, active in pairs(StatusImmunity.ActiveImmunities) do
		if active and name ~= "Springer Knockback" and name ~= "Flesh" and name ~= "Concussion" then
			table.insert(list, name)
		end
	end
	table.sort(list)
	return list
end

function StatusImmunity.RefreshActiveEffects()
	for _, debuffName in ipairs({ "Flesh", "Panic", "Concussion", "Fire", "Insanity", "Overtuned" }) do
		if StatusImmunity.isImmune(debuffName) then
			for callback in pairs(StatusImmunity.ActiveCallbacks) do
				pcall(callback, debuffName, false)
			end
		end
	end

	local controller = getController()
	if controller and typeof(controller.ReconcileImmunityState) == "function" then
		controller:ReconcileImmunityState()
	end
end

function StatusImmunity.SetActiveImmunities(options)
	local previous = table.clone(StatusImmunity.ActiveImmunities)

	table.clear(StatusImmunity.ActiveImmunities)
	for _, opt in ipairs(options) do
		if opt ~= "Springer Knockback" and opt ~= "Flesh" and opt ~= "Concussion" then
			StatusImmunity.ActiveImmunities[opt] = true
		end
	end

	local controller = getController()
	if not controller then
		return
	end

	-- Immediately remove active debuffs if newly immune
	for _, debuffName in ipairs({ "Flesh", "Panic", "Concussion", "Fire", "Insanity", "Overtuned" }) do
		if StatusImmunity.ActiveImmunities[debuffName] and not previous[debuffName] then
			for callback in pairs(StatusImmunity.ActiveCallbacks) do
				pcall(callback, debuffName, false)
			end
		end
	end

	-- Update Bell Touch
	if StatusImmunity.ActiveImmunities["Bell Knockback"] ~= previous["Bell Knockback"] then
		if typeof(controller.SetBellKnockbackImmune) == "function" then
			controller:SetBellKnockbackImmune(StatusImmunity.ActiveImmunities["Bell Knockback"] == true)
		end
	end

	if typeof(controller.ReconcileImmunityState) == "function" then
		controller:ReconcileImmunityState()
	end
end

function StatusImmunity.initialize()
	local sharedState = getgenv()._NULLSCAPE_Globals or {}
	getgenv()._NULLSCAPE_Globals = sharedState
	sharedState.NullscapeStatusImmunity = StatusImmunity

	if sharedState.StatusEffectHooked or StatusImmunity.Hooked then
		return
	end

	local StatusEffectChanged = ReplicatedStorage:FindFirstChild("Events")
		and ReplicatedStorage.Events:FindFirstChild("StatusEffectChanged")
	if StatusEffectChanged and StatusEffectChanged:IsA("RemoteEvent") then
		pcall(function()
			if typeof(hookfunction) == "function" then
				local oldConnect
				oldConnect = hookfunction(StatusEffectChanged.OnClientEvent.Connect, function(self, callback)
					local isTarget = false
					pcall(function()
						isTarget = (self == StatusEffectChanged.OnClientEvent)
					end)

					if isTarget then
						rememberCallback(callback)
						local newCallback = function(statusName, isActive, ...)
							if StatusImmunity.isImmune(statusName) then
								return
							end
							return callback(statusName, isActive, ...)
						end
						return oldConnect(self, newCallback)
					end
					return oldConnect(self, callback)
				end)
				sharedState.OriginalOnClientEventConnect = oldConnect
			end
		end)

		-- Hook existing connections
		pcall(function()
			if typeof(getconnections) == "function" and typeof(hookfunction) == "function" then
				for _, connection in ipairs(getconnections(StatusEffectChanged.OnClientEvent)) do
					local originalFunction = connection.Function
					if typeof(originalFunction) == "function" then
						rememberCallback(originalFunction)
						local oldFunc
						oldFunc = hookfunction(originalFunction, function(statusName, isActive, ...)
							if StatusImmunity.isImmune(statusName) then
								return
							end
							return oldFunc(statusName, isActive, ...)
						end)
					end
				end
			end
		end)
	end

	pcall(function()
		local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		local handlerModule = clientModules and clientModules:FindFirstChild("StatusEffectHandler")
		if handlerModule and handlerModule:IsA("ModuleScript") then
			local StatusEffectHandler = require(handlerModule)
			if typeof(StatusEffectHandler) == "table" and typeof(StatusEffectHandler.HasStatus) == "function" then
				if typeof(hookfunction) == "function" then
					local oldHasStatus
					oldHasStatus = hookfunction(StatusEffectHandler.HasStatus, function(statusName, ...)
						if StatusImmunity.isImmune(statusName) then
							return false
						end
						return oldHasStatus(statusName, ...)
					end)
					sharedState.OriginalHasStatus = oldHasStatus
				else
					local oldHasStatus = StatusEffectHandler.HasStatus
					sharedState.OriginalHasStatus = oldHasStatus
					StatusEffectHandler.HasStatus = function(statusName, ...)
						if StatusImmunity.isImmune(statusName) then
							return false
						end
						return oldHasStatus(statusName, ...)
					end
				end
			end
		end
	end)

	sharedState.StatusEffectHooked = true
	StatusImmunity.Hooked = true
end

function StatusImmunity.removeAllStatuses()
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local handlerModule = clientModules and clientModules:FindFirstChild("StatusEffectHandler")
	if handlerModule and handlerModule:IsA("ModuleScript") then
		local StatusEffectHandler = require(handlerModule)
		if typeof(StatusEffectHandler) == "table" and typeof(StatusEffectHandler.RemoveAllStatuses) == "function" then
			pcall(StatusEffectHandler.RemoveAllStatuses)
		end
	end
	for _, debuffName in ipairs({ "Flesh", "Panic", "Concussion", "Fire", "Insanity", "Overtuned" }) do
		for callback in pairs(StatusImmunity.ActiveCallbacks) do
			pcall(callback, debuffName, false)
		end
	end
end

return StatusImmunity
