-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Executor
--  Vai trò: Chỉ đảm nhiệm việc thực thi và gọi các tính năng/API từ file logic chính (như Simulated Upgrades/Radar logic.luau).
--  Thực thi dọn dẹp vẽ cũ và định vị vẽ ESP/Highlight mới.
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local Magnet = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Magnet logic.luau")
local Barrier = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Defuse Kits.luau")
local Executor = {}

-- Thực thi dọn dẹp vẽ cũ
function Executor.clearVisuals(gc, keepArrows)
    Logic.clearVisuals(gc, keepArrows)
end

-- Thực thi cập nhật khoảng cách và style visual
function Executor.updateESPStyles(controller, gc, hrp)
    Logic.updateESPStyles(controller, gc, hrp)
end

-- Thực thi tự động hút quà (Magnet Bypass)
function Executor.updateMagnet(controller, hrp)
    Magnet.update(controller, hrp)
end

-- Thực thi cập nhật rào cản vật lý mìn (Tripmine Barrier)
function Executor.updateBarriers(controller, gc)
    Barrier.update(controller, gc)
end

return Executor
