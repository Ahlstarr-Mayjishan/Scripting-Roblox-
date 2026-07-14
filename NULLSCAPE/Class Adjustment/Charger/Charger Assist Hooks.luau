--!nocheck
-- Executor-facing native interop: hookfunction has executor-specific signatures.

local Hooks = { Movement = nil, Entries = {}, Handlers = nil }

local function packResults(...)
	local values = { ... }
	values.n = select("#", ...)
	return values
end

local function handleInput(isAlt, original, movement, inputState, ...)
	local handlers = Hooks.Handlers
	if movement ~= Hooks.Movement or not handlers or handlers.isActive() ~= true then
		return original(movement, inputState, ...)
	end
	if handlers.before(isAlt, inputState) == true then
		return nil
	end
	local results = packResults(pcall(original, movement, inputState, ...))
	handlers.after(isAlt, inputState)
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

local function installAction(key, movement, methodName, isAlt)
	local target = movement and movement[methodName]
	if typeof(target) ~= "function" or typeof(hookfunction) ~= "function" then
		return false
	end
	local original
	local success = pcall(function()
		original = hookfunction(target, function(self, inputState, ...)
			return handleInput(isAlt, original, self, inputState, ...)
		end)
	end)
	if not success or typeof(original) ~= "function" then
		return false
	end
	Hooks.Entries[key] = { Target = target, Original = original }
	return true
end

function Hooks.call(isAlt, inputState)
	local hook = Hooks.Entries[isAlt and "Alt" or "Primary"]
	if hook and hook.Original and Hooks.Movement then
		return pcall(hook.Original, Hooks.Movement, inputState)
	end
	return false
end

function Hooks.restore()
	if typeof(hookfunction) == "function" then
		for _, hook in pairs(Hooks.Entries) do
			if hook.Target and hook.Original then
				pcall(hookfunction, hook.Target, hook.Original)
			end
		end
	end
	Hooks.Movement = nil
	Hooks.Entries = {}
	Hooks.Handlers = nil
end

function Hooks.install(movement, handlers)
	if Hooks.Movement == movement and next(Hooks.Entries) ~= nil then
		Hooks.Handlers = handlers
		return true
	end
	Hooks.restore()
	Hooks.Movement = movement
	Hooks.Handlers = handlers
	local primary = installAction("Primary", movement, "SpecialAction", false)
	local alt = installAction("Alt", movement, "AltSpecialAction", true)
	if not primary and not alt then
		Hooks.restore()
		return false
	end
	return true
end

return Hooks
