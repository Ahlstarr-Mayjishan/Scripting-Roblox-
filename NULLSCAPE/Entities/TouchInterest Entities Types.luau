-- [[
--  NULLSCAPE - TouchInterest Entities Types & Ranges Logic
--  Vai trò: Chứa toàn bộ logic định danh loại thực thể (Baby, Bell, Mart),
--  danh sách/phạm vi thực thể thuộc diện bảo vệ (TouchInterest) và các thuật toán kiểm tra
--  trạng thái TouchInterest của thực thể. Cung cấp API logic để Executor và Controller sử dụng.
--
--  LƯU Ý: Husk / Skinwalker được quản lý riêng tại "Magnitude Types.luau".
-- ]]

local Logic = {}

-- Danh sách thực thể cần bảo vệ bằng cách xóa TouchInterest
Logic.TargetNames = {
    ["Baby"] = "Baby",
    ["Bell"] = "Bell",
    ["Mart"] = "Mart",
}

-- Trả về hàm kiểm tra trạng thái miễn nhiễm tương ứng
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
            end
        end
    end
    return nil
end

-- Kiểm tra xem một thực thể có thuộc diện Baby/Bell/Mart không
function Logic.isTargetEntity(name)
    if not name then return false end
    for entityName, _ in pairs(Logic.TargetNames) do
        if string.find(name, entityName) then
            return true
        end
    end
    return false
end

-- Bật miễn nhiễm: xóa toàn bộ TouchInterest / TouchTransmitter của thực thể
function Logic.enableImmunity(gc, enemy)
    if not enemy or not enemy:IsA("Model") then return end

    for _, part in ipairs(enemy:GetDescendants()) do
        if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
            local parentPart = part.Parent
            if parentPart and parentPart:IsA("BasePart") then
                if gc.SavedPartsData[parentPart] then
                    gc.SavedPartsData[parentPart].touch = part
                else
                    gc.SavedPartsData[parentPart] = {
                        touch     = part,
                        enemyName = enemy.Name
                    }
                end
            end
            pcall(function() part.Parent = nil end)
        end
    end
end

-- Tắt miễn nhiễm: khôi phục TouchInterest cho một loại thực thể cụ thể
function Logic.disableImmunityForType(gc, entityName)
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.enemyName and string.find(data.enemyName, entityName) then
            if part and part.Parent and data.touch then
                pcall(function() data.touch.Parent = part end)
            end
            gc.SavedPartsData[part] = nil
        end
    end
end

-- Khôi phục toàn bộ TouchInterest và dọn sạch cache (Baby/Bell/Mart)
function Logic.restoreAll(gc)
    if not gc.SavedPartsData then return end
    for part, data in pairs(gc.SavedPartsData) do
        if data then
            if part and part.Parent and data.touch then
                pcall(function() data.touch.Parent = part end)
            end
        end
    end
    table.clear(gc.SavedPartsData)
end

return Logic
