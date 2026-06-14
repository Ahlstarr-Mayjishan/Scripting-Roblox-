-- [[
--  NULLSCAPE - Entities Executor & Cleaner
--  Vai trò: Chỉ đảm nhiệm việc thực thi sửa đổi trạng thái thực thể bằng cách gọi các tính năng/API từ file logic
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest Entities Types.luau")
local Executor = {}

-- Thực thi bật miễn nhiễm cho một thực thể
function Executor.enableImmunity(gc, enemy)
    Logic.enableImmunity(gc, enemy)
end

-- Thực thi tắt miễn nhiễm cho một loại thực thể
function Executor.disableImmunityForType(gc, entityName)
    Logic.disableImmunityForType(gc, entityName)
end

-- Thực thi khôi phục toàn bộ TouchInterest và giải phóng bộ nhớ
function Executor.restoreAll(gc)
    Logic.restoreAll(gc)
end

return Executor
