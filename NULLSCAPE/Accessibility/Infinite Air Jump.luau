-- [[
--  NULLSCAPE - Infinite Air Jump
--  Replenishes one native DoubleJump charge before each air-jump attempt.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {}

local function getGlobals()
    local env = getgenv()
    env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
    return env._NULLSCAPE_Globals
end

local function shouldRefill()
    local controller = getGlobals().activeAccessibilityController
    return controller and controller.InfiniteAirJumpEnabled == true
end

local function refillNativeCharge(doubleJump)
    if not shouldRefill() or typeof(doubleJump) ~= "table" then
        return
    end

    local availableJumps = doubleJump.AvailableJumps
    if typeof(availableJumps) ~= "table" then
        return
    end

    availableJumps.DoubleJump = math.max(tonumber(availableJumps.DoubleJump) or 0, 1)
end

function Logic.initialize()
    local globals = getGlobals()
    if globals.InfiniteAirJumpHooked then
        return true
    end

    local movement = ReplicatedStorage:FindFirstChild("Movement")
    local moduleScript = movement and movement:FindFirstChild("DoubleJump")
    if not moduleScript or not moduleScript:IsA("ModuleScript") then
        return false
    end

    local success, doubleJumpModule = pcall(require, moduleScript)
    if not success or typeof(doubleJumpModule) ~= "table" or typeof(doubleJumpModule.TryDoubleJump) ~= "function" then
        return false
    end

    local hookSuccess = pcall(function()
        if typeof(hookfunction) == "function" then
            local oldTryDoubleJump
            oldTryDoubleJump = hookfunction(doubleJumpModule.TryDoubleJump, function(self, ...)
                refillNativeCharge(self)
                return oldTryDoubleJump(self, ...)
            end)
            globals.OriginalTryDoubleJump = oldTryDoubleJump
        else
            local oldTryDoubleJump = doubleJumpModule.TryDoubleJump
            globals.OriginalTryDoubleJump = oldTryDoubleJump
            doubleJumpModule.TryDoubleJump = function(self, ...)
                refillNativeCharge(self)
                return oldTryDoubleJump(self, ...)
            end
        end
    end)

    if not hookSuccess then
        return false
    end

    globals.InfiniteAirJumpHooked = true
    return true
end

return Logic
