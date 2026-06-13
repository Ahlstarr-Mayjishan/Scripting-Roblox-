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
    ["Mart"] = "Mart"
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

-- Kiểm tra xem trong các thực thể mục tiêu còn TouchInterest nào không
function Logic.checkTargetsForTouchInterest(enemiesFolder, controller)
    if not enemiesFolder then return false, false, false end
    
    local foundAny = false
    local touchInterestsExist = false
    local allLoaded = true
    
    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        local checkFunc = Logic.getImmunityCheck(enemy.Name, controller)
        if checkFunc and checkFunc() then
            foundAny = true
            
            -- Đảm bảo thực thể đã tải xong nhân vật trước khi kiểm tra trạng thái TouchInterest
            local loaded = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildOfClass("Humanoid") or enemy:FindFirstChildWhichIsA("BasePart")
            if not loaded then
                allLoaded = false
            end
            
            for _, part in ipairs(enemy:GetDescendants()) do
                if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                    touchInterestsExist = true
                    break
                end
            end
        end
        if touchInterestsExist then break end
    end
    
    return foundAny, touchInterestsExist, allLoaded
end

-- Bật miễn nhiễm (ẩn TouchInterest và tắt CanTouch) cho một thực thể cụ thể
function Logic.enableImmunity(gc, enemy)
    if not enemy then return end
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
        end
    end
end

-- Tắt miễn nhiễm (khôi phục lại TouchInterest và CanTouch) cho một loại thực thể cụ thể
function Logic.disableImmunityForType(gc, entityName)
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.enemyName == entityName then
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
