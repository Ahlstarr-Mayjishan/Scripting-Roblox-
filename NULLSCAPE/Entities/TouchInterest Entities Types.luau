-- [[
--  NULLSCAPE - TouchInterest Entities Types & Ranges Logic
--  Vai trò: Chứa toàn bộ logic định danh loại thực thể (Baby, Bell, Mart),
--  danh sách/phạm vi thực thể thuộc diện bảo vệ (TouchInterest) và các thuật toán kiểm tra
--  trạng thái TouchInterest của thực thể. Cung cấp API logic để Executor và Controller sử dụng.
-- ]]

local Logic = {}

-- Danh sách/phạm vi các thực thể cần bảo vệ
Logic.TargetNames = {
    ["Baby"] = "Baby",
    ["Bell"] = "Bell",
    ["Mart"] = "Mart",
    ["Springer"] = "Springer"
}

-- Trả về chức năng kiểm tra trạng thái miễn nhiễm tương ứng
function Logic.getImmunityCheck(name, controller)
    if not name then return nil end
    for entityName, _ in pairs(Logic.TargetNames) do
        if string.find(name, entityName) then
            if entityName == "Baby" then
                return function() return controller.BabyImmune end
            elseif entityName == "Bell" then
                return function() return controller.BellImmune end
            elseif entityName == "Mart" then
                return function() return controller.MartImmune end
            elseif entityName == "Springer" then
                return function() return controller.SpringerImmune end
            end
        end
    end
    return nil
end

-- Kiểm tra xem một thực thể cụ thể có thuộc diện cần xử lý bảo vệ không
function Logic.isTargetEntity(name)
    if not name then return false end
    for entityName, _ in pairs(Logic.TargetNames) do
        if string.find(name, entityName) then
            return true
        end
    end
    return false
end


-- Bật miễn nhiễm (ẩn TouchInterest và tắt CanTouch) cho một thực thể cụ thể
function Logic.enableImmunity(gc, enemy)
    if not enemy then return end
    
    local isSpringer = string.find(enemy.Name, "Springer")
    
    for _, descendant in ipairs(enemy:GetDescendants()) do
        if descendant:IsA("TouchTransmitter") or descendant.Name == "TouchInterest" then
            local part = descendant.Parent
            if part and part:IsA("BasePart") then
                if not gc.SavedPartsData[part] then
                    gc.SavedPartsData[part] = {
                        touch = descendant,
                        originalCanTouch = part.CanTouch,
                        enemyName = enemy.Name
                    }
                end
                pcall(function() descendant.Parent = nil end)
                pcall(function() part.CanTouch = false end)
            end
        elseif isSpringer and descendant:IsA("BasePart") then
            -- Tắt CanTouch cho tất cả BasePart của Springer nếu chưa lưu, ngoại trừ các shockwave
            local name = descendant.Name
            if name ~= "SpringerShockwave" and name ~= "DemonShockwave" then
                if not gc.SavedPartsData[descendant] then
                    gc.SavedPartsData[descendant] = {
                        touch = nil,
                        originalCanTouch = descendant.CanTouch,
                        enemyName = enemy.Name
                    }
                end
                pcall(function() descendant.CanTouch = false end)
            end
        end
    end
end

function Logic.disableImmunityForType(gc, entityName)
    for part, data in pairs(gc.SavedPartsData) do
        if data and string.find(data.enemyName, entityName) then
            if part and part.Parent then
                if data.touch then
                    pcall(function() data.touch.Parent = part end)
                end
                pcall(function() part.CanTouch = data.originalCanTouch end)
            end
            gc.SavedPartsData[part] = nil
        end
    end
end

-- Khôi phục toàn bộ dữ liệu TouchInterest và dọn sạch cache
function Logic.restoreAll(gc)
    if gc.SavedPartsData then
        for part, data in pairs(gc.SavedPartsData) do
            if part and part.Parent and data then
                if data.touch then
                    pcall(function() data.touch.Parent = part end)
                end
                pcall(function() part.CanTouch = data.originalCanTouch end)
            end
        end
        table.clear(gc.SavedPartsData)
    end
end

return Logic
