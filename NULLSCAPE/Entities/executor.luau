-- [[
--  NULLSCAPE - Entities Executor & Cleaner
--  Vai trò: Thực thi sửa đổi trạng thái thực thể bằng cách gọi các tính năng từ TouchInterest logic
-- ]]

local TouchInterest = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest.luau")
local Executor = {}

-- Thực thi bật miễn nhiễm cho một thực thể
function Executor.enableImmunity(gc, enemy)
    TouchInterest.enableImmunity(gc, enemy)
end

-- Thực thi tắt miễn nhiễm cho một loại thực thể
function Executor.disableImmunityForType(gc, entityName)
    TouchInterest.disableImmunityForType(gc, entityName)
end

-- Thực thi khôi phục toàn bộ TouchInterest và giải phóng bộ nhớ
function Executor.restoreAll(gc)
    TouchInterest.restoreAll(gc)
end

return Executor
