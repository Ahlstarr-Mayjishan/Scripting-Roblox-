-- [[
--  NULLSCAPE - Entities Executor & Cleaner
--  Vai trò: Chỉ đảm nhiệm việc thực thi sửa đổi trạng thái thực thể bằng cách gọi các tính năng/API từ file logic
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest Entities Types.luau")
local Executor = {}

-- Thực thi bật miễn nhiễm cho một thực thể
function Executor.enableImmunity(controller, enemy)
    Logic.enableImmunity(controller, enemy)
end

-- Thực thi tắt miễn nhiễm cho một loại thực thể
function Executor.disableImmunityForType(controller, entityName)
    Logic.disableImmunityForType(controller, entityName)
end

-- Thực thi khôi phục toàn bộ TouchInterest và giải phóng bộ nhớ
function Executor.restoreAll(controller)
    Logic.restoreAll(controller)
end

return Executor
