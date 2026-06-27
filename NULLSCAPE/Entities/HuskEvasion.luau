-- [[
--  NULLSCAPE - Husk / Skinwalker Evasion
--  Vai trò: Quản lý đổi tên model, bộ phận và tắt CanTouch của Husk/Skinwalker
-- ]]

local Logic = {}

-- ============================================================
--  CẤU HÌNH THỰC THỂ HUSK / SKINWALKER
-- ============================================================
Logic.Config = {
    ["Skinwalker"] = "SkinwalkerImmune",
    ["Husk"] = "SkinwalkerImmune",
    -- Thêm thực thể Husk mới tại đây
}

function Logic.isHuskEntity(name)
    if not name then return false end
    local lowerName = string.lower(name)
    for configName, _ in pairs(Logic.Config) do
        if string.find(lowerName, string.lower(configName)) then
            return true
        end
    end
    return false
end

function Logic.enableHuskImmunity(gc, enemy)
    if not enemy or not enemy:IsA("Model") then return end
    if not Logic.isHuskEntity(enemy.Name) and not (enemy:GetAttribute("OriginalName") and Logic.isHuskEntity(enemy:GetAttribute("OriginalName"))) then return end

    if not enemy:GetAttribute("OriginalName") then
        enemy:SetAttribute("OriginalName", enemy.Name)
    end

    pcall(function()
        if not string.find(enemy.Name, "SafeWalker") then
            enemy.Name = "SafeWalker_" .. enemy.Name
        end
    end)

    local originalName = enemy:GetAttribute("OriginalName") or enemy.Name

    for _, part in ipairs(enemy:GetDescendants()) do
        if part:IsA("BasePart") then
            if not gc.SavedPartsData[part] then
                gc.SavedPartsData[part] = {
                    originalCanTouch = part.CanTouch,
                    originalName     = part.Name,
                    enemyName        = originalName
                }
            end
            pcall(function() part.CanTouch = false end)

            if part.Name == "head" then
                pcall(function() part.Name = "SafeHead" end)
            end
        elseif part:IsA("Decal") or part:IsA("Texture") then
            if part.Name == "sprite" then
                if not gc.SavedPartsData[part] then
                    gc.SavedPartsData[part] = {
                        originalName = part.Name,
                        enemyName    = originalName
                    }
                end
                pcall(function() part.Name = "SafeSprite" end)
            end
        end
    end
end

function Logic.onHuskDescendantAdded(gc, enemy, part)
    if not Logic.isHuskEntity(enemy.Name) and not (enemy:GetAttribute("OriginalName") and Logic.isHuskEntity(enemy:GetAttribute("OriginalName"))) then return end

    local originalName = enemy:GetAttribute("OriginalName") or enemy.Name

    if part:IsA("BasePart") then
        if not gc.SavedPartsData[part] then
            gc.SavedPartsData[part] = {
                originalCanTouch = part.CanTouch,
                originalName     = part.Name,
                enemyName        = originalName
            }
        end
        pcall(function() part.CanTouch = false end)
        if part.Name == "head" then
            pcall(function() part.Name = "SafeHead" end)
        end
    elseif part:IsA("Decal") or part:IsA("Texture") then
        if part.Name == "sprite" then
            if not gc.SavedPartsData[part] then
                gc.SavedPartsData[part] = {
                    originalName = part.Name,
                    enemyName    = originalName
                }
            end
            pcall(function() part.Name = "SafeSprite" end)
        end
    end
end

function Logic.disableHuskImmunity(gc)
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.enemyName and Logic.isHuskEntity(data.enemyName) then
            if part and part.Parent then
                if data.originalCanTouch ~= nil then
                    pcall(function() part.CanTouch = data.originalCanTouch end)
                end
                if data.originalName then
                    pcall(function() part.Name = data.originalName end)
                end
            end
            gc.SavedPartsData[part] = nil
        end
    end

    local function restoreFolder(folder)
        if not folder then return end
        for _, child in ipairs(folder:GetChildren()) do
            local originalName = child:GetAttribute("OriginalName")
            if originalName and Logic.isHuskEntity(originalName) then
                pcall(function() child.Name = originalName end)
                child:SetAttribute("OriginalName", nil)
            end
        end
    end

    restoreFolder(workspace:FindFirstChild("Enemies"))
    restoreFolder(workspace:FindFirstChild("Skinwalkers"))
    restoreFolder(workspace)
end

return Logic
