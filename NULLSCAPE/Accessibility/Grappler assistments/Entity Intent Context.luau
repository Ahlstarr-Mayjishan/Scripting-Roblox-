--!nocheck
--[[
	NULLSCAPE - Grappler Entity Intent Context
	Detects entity-specific states that should temporarily steer grapple targeting.
]]

local Players = game:GetService("Players")

local Context = {}
local GameState = getgenv().loadModule("NULLSCAPE/Core/Game State Context.luau")

local LocalPlayer = Players.LocalPlayer

local DISABLED_ATTRIBUTES = {
	"Disabled",
	"Disable",
	"Inactive",
	"Finished",
	"Ended",
	"Dead",
}

local ACTIVE_ATTRIBUTES = {
	"Active",
	"Enabled",
	"Started",
	"Triggered",
}

local function hasTruthyAttribute(instance, names)
	for _, name in ipairs(names) do
		local value = instance:GetAttribute(name)
		if value == true then
			return true
		end
	end

	return false
end

local function hasFalsyActiveAttribute(instance)
	for _, name in ipairs(ACTIVE_ATTRIBUTES) do
		local value = instance:GetAttribute(name)
		if value == false then
			return true
		end
	end

	return false
end

local function hasAnyActiveAttribute(instance)
	for _, name in ipairs(ACTIVE_ATTRIBUTES) do
		if instance:GetAttribute(name) ~= nil then
			return true
		end
	end

	return false
end

local function hasClientBindable(instance)
	local bindable = instance:FindFirstChild("ClientBindable")
	return bindable and bindable:IsA("BindableEvent")
end

function Context.getRazorbloom(character)
	character = character or LocalPlayer and LocalPlayer.Character
	local razorbloom = character and character:FindFirstChild("Razorbloom")
	if not (razorbloom and razorbloom.Parent) then
		return nil
	end

	if hasTruthyAttribute(razorbloom, DISABLED_ATTRIBUTES) or hasFalsyActiveAttribute(razorbloom) then
		return nil
	end

	if hasAnyActiveAttribute(razorbloom) then
		return razorbloom
	end

	return hasClientBindable(razorbloom) and razorbloom or nil
end

function Context.isRazorbloomActive(character)
	if Context.getRazorbloom(character) ~= nil then
		return true
	end

	return GameState and typeof(GameState.isRazorbloomActive) == "function" and GameState.isRazorbloomActive(character)
end

function Context.isKolonaActive()
	return GameState and typeof(GameState.isKolonaActive) == "function" and GameState.isKolonaActive()
end

return Context
