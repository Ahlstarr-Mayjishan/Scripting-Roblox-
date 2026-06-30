-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Executor
--  Vai trò: Chỉ đảm nhiệm việc thực thi và gọi các tính năng/API từ file logic chính (như Simulated Upgrades/Radar logic.luau).
--  Thực thi dọn dẹp vẽ cũ và định vị vẽ ESP/Highlight mới.
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local Magnet = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Magnet logic.luau")
local Barrier = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Defuse Kits.luau")
local Executor = {}
local missingWarnings = {}

local function getCallable(module, methodName, label)
    if module and typeof(module[methodName]) == "function" then
        return module[methodName]
    end

    local key = tostring(label) .. "." .. tostring(methodName)
    if not missingWarnings[key] then
        missingWarnings[key] = true
        warn("[NULLSCAPE Executor] Missing callable: " .. key)
    end

    return nil
end

-- Run visual cleanup
function Executor.clearVisuals(gc, keepArrows)
    local clearVisuals = getCallable(Logic, "clearVisuals", "RadarLogic")
    if clearVisuals then
        clearVisuals(gc, keepArrows)
    end
end

-- Run ESP/style updates
function Executor.updateESPStyles(controller, gc, hrp)
    local updateESPStyles = getCallable(Logic, "updateESPStyles", "RadarLogic")
    if updateESPStyles then
        updateESPStyles(controller, gc, hrp)
    end
end

-- Run gift magnet automation
function Executor.updateMagnet(controller, hrp)
    local update = getCallable(Magnet, "update", "Magnet")
    if update then
        update(controller, hrp)
    end
end

-- Run tripmine barrier assists
function Executor.updateBarriers(controller, gc)
    local updateBarrier = getCallable(Barrier, "update", "DefuseKits")
    if updateBarrier then
        updateBarrier(controller, gc)
    end
end

return Executor
