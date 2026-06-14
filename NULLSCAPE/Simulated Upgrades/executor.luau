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

-- Thực thi cập nhật khoảng cách và style visual
function Executor.updateESPStyles(controller, gc, hrp)
    Logic.updateESPStyles(controller, gc, hrp)
end

-- Thực thi cập nhật render thời gian thực của mũi tên/ping
function Executor.updateRender(controller, gc, hrp)
    Logic.updateRender(controller, gc, hrp)
end

return Executor
