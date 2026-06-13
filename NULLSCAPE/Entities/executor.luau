-- [[
--  NULLSCAPE - Entities Executor & Cleaner
--  Vai trò: Chỉ đảm nhiệm việc thực thi sửa đổi trạng thái thực thể (ẩn/khôi phục TouchInterest,
--  vô hiệu hóa CanTouch) bằng cách gọi các tính năng/API từ file logic (TouchInterest Entities Types.luau).
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest Entities Types.luau")
local Executor = {}

-- Bật miễn nhiễm (ẩn TouchInterest và tắt CanTouch) cho một thực thể cụ thể
function Executor.enableImmunity(controller, enemy)
    if not enemy then return end
    for _, descendant in ipairs(enemy:GetDescendants()) do
        if descendant:IsA("TouchTransmitter") or descendant.Name == "TouchInterest" then
            local part = descendant.Parent
            if part and part:IsA("BasePart") then
                if not controller.SavedPartsData[part] then
                    controller.SavedPartsData[part] = {
                        touch = descendant,
                        originalCanTouch = part.CanTouch,
                        enemyName = enemy.Name
                    }
                end
                pcall(function() descendant.Parent = nil end)
                pcall(function() part.CanTouch = false end)
            end
        end
    end
end

-- Tắt miễn nhiễm (khôi phục lại TouchInterest và CanTouch) cho một loại thực thể cụ thể
function Executor.disableImmunityForType(controller, entityName)
    for part, data in pairs(controller.SavedPartsData) do
        if data and data.enemyName == entityName then
            if part and part.Parent then
                if data.touch then
                    pcall(function() data.touch.Parent = part end)
                end
                pcall(function() part.CanTouch = data.originalCanTouch end)
            end
            controller.SavedPartsData[part] = nil
        end
    end
end

-- Khôi phục toàn bộ dữ liệu TouchInterest và dọn sạch cache
function Executor.restoreAll(controller)
    if controller.SavedPartsData then
        for part, data in pairs(controller.SavedPartsData) do
            if part and part.Parent and data then
                if data.touch then
                    pcall(function() data.touch.Parent = part end)
                end
                pcall(function() part.CanTouch = data.originalCanTouch end)
            end
        end
        table.clear(controller.SavedPartsData)
    end
end

return Executor
