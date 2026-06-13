-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Executor
--  Vai trò: Chỉ đảm nhiệm việc thực thi và gọi các tính năng/API từ file logic chính (như Simulated Upgrades/Radar logic.luau).
--  Thực thi dọn dẹp vẽ cũ và định vị vẽ ESP/Highlight mới.
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local Executor = {}

-- Thực thi dọn dẹp vẽ cũ
function Executor.clearVisuals(gc, keepArrows)
    Logic.clearVisuals(gc, keepArrows)
end

-- Thực thi vẽ ESP mới
function Executor.updateESP(controller, gc, hrp)
    Logic.updateESP(controller, gc, hrp)
end

return Executor
