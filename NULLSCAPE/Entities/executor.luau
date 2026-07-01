-- [[
--  NULLSCAPE - Entities Executor & Cleaner
--  Dispatches entity immunity logic without replacing the existing cores.
-- ]]

local TouchInterest = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest.luau")
local SpecialImmunity = getgenv().loadModule("NULLSCAPE/Entities/SpecialImmunity.luau")
local Executor = {}

function Executor.enableImmunity(gc, enemy)
	TouchInterest.enableImmunity(gc, enemy)
end

function Executor.disableImmunityForType(gc, entityName)
	TouchInterest.disableImmunityForType(gc, entityName)
	SpecialImmunity.disableForType(entityName)
end

function Executor.restoreAll(gc)
	TouchInterest.restoreAll(gc)
	SpecialImmunity.disable()
end

function Executor.reconcile(gc)
	if TouchInterest and typeof(TouchInterest.reconcile) == "function" then
		TouchInterest.reconcile(gc)
	end
end

function Executor.enableSpecialImmunity()
	return SpecialImmunity.enable()
end

function Executor.disableSpecialImmunityForType(entityName)
	SpecialImmunity.disableForType(entityName)
end

function Executor.disableSpecialImmunity()
	SpecialImmunity.disable()
end

return Executor
