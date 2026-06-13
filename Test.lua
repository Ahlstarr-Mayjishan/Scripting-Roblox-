--[[
    Test.lua - Headless UltraHell experiment
    The standalone debug UI was removed because the feature now lives in
    STAR GLITCHER ~ REVITALIZED -> Blatant & Bypass -> UltraHell Gamemode.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Shared = getgenv().__STAR_GLITCHER_ULTRAHELL or {
    Hooked = false,
    CapturedRemote = nil,
    CapturedArgs = nil,
    CapturedName = nil,
}
getgenv().__STAR_GLITCHER_ULTRAHELL = Shared

local Settings = getgenv().__STAR_GLITCHER_ULTRAHELL_TEST or {
    Enabled = false,
    HitsPerSecond = 10,
}
getgenv().__STAR_GLITCHER_ULTRAHELL_TEST = Settings

local EXCLUDE_KEYWORDS = { "chat", "move", "walk", "jump", "anim", "inventory", "sprint" }
local COMBAT_KEYWORDS = {
    "hit", "damage", "attack", "punch", "slash", "shoot", "fire",
    "impact", "ability", "skill", "weapon", "tool",
}

local function isCombatRemote(remote, args)
    local name = tostring(remote):lower()
    for _, word in ipairs(EXCLUDE_KEYWORDS) do
        if string.find(name, word, 1, true) then
            return false
        end
    end

    for _, word in ipairs(COMBAT_KEYWORDS) do
        if string.find(name, word, 1, true) then
            return true
        end
    end

    for index = 1, args.n do
        local arg = args[index]
        if typeof(arg) == "Instance" and arg:IsA("Model") and arg ~= LocalPlayer.Character then
            return true
        end
    end

    return false
end

if not Shared.Hooked then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(target, ...)
        local method = getnamecallmethod()
        local args = table.pack(...)

        if not checkcaller() and (method == "FireServer" or method == "InvokeServer") and isCombatRemote(target, args) then
            Shared.CapturedRemote = target
            Shared.CapturedArgs = args
            Shared.CapturedName = target.Name
            print("[UltraHell/Test] Captured combat packet from " .. tostring(target.Name))
        end

        return oldNamecall(target, ...)
    end))

    Shared.Hooked = true
end

task.spawn(function()
    local tokenBucket = 0
    while true do
        local dt = RunService.Heartbeat:Wait()
        if not Settings.Enabled or not Shared.CapturedRemote or not Shared.CapturedArgs then
            tokenBucket = 0
        else
            local rate = math.clamp(tonumber(Settings.HitsPerSecond) or 10, 1, 100)
            tokenBucket = math.min(tokenBucket + (rate * dt), rate)
            while tokenBucket >= 1 do
                tokenBucket = tokenBucket - 1
                if Shared.CapturedRemote.ClassName == "RemoteEvent" then
                    Shared.CapturedRemote:FireServer(table.unpack(Shared.CapturedArgs, 1, Shared.CapturedArgs.n))
                elseif Shared.CapturedRemote.ClassName == "RemoteFunction" then
                    task.spawn(function()
                        Shared.CapturedRemote:InvokeServer(table.unpack(Shared.CapturedArgs, 1, Shared.CapturedArgs.n))
                    end)
                end
            end
        end
    end
end)

print("[Star Glitcher] UltraHell test is now headless.")
print("[Star Glitcher] Use the main UI in Blatant & Bypass -> UltraHell Gamemode.")
