-- [[
--  NULLSCAPE - Magnitude Entities Types & Anti Logic
--  Vai trò:
--    1. Kiểm tra và chặn các cuộc gọi RemoteEvent gây sát thương từ ICBM.
--    2. Quản lý miễn nhiễm Husk / Skinwalker (đổi tên model, đổi tên bộ phận,
--       tắt CanTouch) theo cơ chế một lần duy nhất.
-- ]]

local Logic = {}

local Players = game:GetService("Players")

-- ============================================================
--  ICBM – Chặn RemoteEvent
-- ============================================================

function Logic.isTargetRemote(remote)
    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false
    end
    return remote.Name == "ClientEvent"
end

function Logic.shouldBlockRemoteCall(remote, args, controller)
    if not controller or not controller.ICBMImmune then
        return false
    end

    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false
    end

    if remote.Name ~= "ClientEvent" then
        return false
    end

    local firstArg = args[1]
    if typeof(firstArg) ~= "string" then
        return false
    end

    -- ICBM sử dụng tham số "Kill" hoặc "Combust" để báo tử client-side
    if firstArg ~= "Kill" and firstArg ~= "Combust" then
        return false
    end

    -- Xác định xem cuộc gọi này có thực sự liên quan đến ICBM hay không
    local isICBMRelated = false

    -- 1. Kiểm tra xem remote có nằm trong model ICBM không
    local current = remote.Parent
    local depth = 0
    while current and current ~= workspace and current ~= game and depth < 50 do
        depth = depth + 1
        local nameSuccess, name = pcall(function() return current.Name end)
        if nameSuccess and name and string.find(name, "ICBM") then
            isICBMRelated = true
            break
        end
        local parentSuccess, parent = pcall(function() return current.Parent end)
        if parentSuccess then
            current = parent
        else
            break
        end
    end

    -- 2. Kiểm tra các đối số truyền vào xem có chứa Instance hoặc chuỗi "ICBM" không
    if not isICBMRelated then
        for _, arg in ipairs(args) do
            if typeof(arg) == "Instance" then
                local nameSuccess, name = pcall(function() return arg.Name end)
                if nameSuccess and name and string.find(name, "ICBM") then
                    isICBMRelated = true
                    break
                end
            elseif typeof(arg) == "string" then
                if string.find(arg, "ICBM") then
                    isICBMRelated = true
                    break
                end
            end
        end
    end

    -- 3. Nếu không xác định được nhưng remote là ClientEvent và có ICBM trong game, mặc định coi là liên quan
    if not isICBMRelated then
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                if string.find(enemy.Name, "ICBM") then
                    isICBMRelated = true
                    break
                end
            end
        end
    end

    -- 4. Dự phòng cuối cùng cho ClientEvent khi ICBMImmune = true
    if not isICBMRelated then
        isICBMRelated = true
    end

    if not isICBMRelated then
        return false
    end

    -- Kiểm tra xem mục tiêu có phải là một người chơi khác hay không
    local targetsSomeoneElse = false
    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character

    for i = 2, #args do
        local arg = args[i]
        if typeof(arg) == "Instance" then
            if arg:IsA("Player") then
                if arg ~= LocalPlayer then
                    targetsSomeoneElse = true
                    break
                end
            elseif arg:IsA("Model") and arg:FindFirstChildOfClass("Humanoid") then
                if arg ~= char then
                    targetsSomeoneElse = true
                    break
                end
            end
        elseif typeof(arg) == "table" then
            for _, val in pairs(arg) do
                if typeof(val) == "Instance" then
                    if val:IsA("Player") then
                        if val ~= LocalPlayer then
                            targetsSomeoneElse = true
                            break
                        end
                    elseif val:IsA("Model") and val:FindFirstChildOfClass("Humanoid") then
                        if val ~= char then
                            targetsSomeoneElse = true
                            break
                        end
                    end
                end
            end
        end
        if targetsSomeoneElse then break end
    end

    -- Nếu không nhắm vào người khác, mặc định là tự tác động lên bản thân (Local Player) -> chặn
    return not targetsSomeoneElse
end

-- ============================================================
--  Husk / Skinwalker – Miễn nhiễm một lần (rename + CanTouch)
-- ============================================================

-- Kiểm tra xem model có phải Husk/Skinwalker không
function Logic.isHuskEntity(name)
    if not name then return false end
    return string.find(name, "Skinwalker") ~= nil or string.find(name, "Husk") ~= nil
end

-- Áp dụng miễn nhiễm cho một model Husk/Skinwalker:
--   • Đổi tên Model thành "SafeWalker_<tên gốc>"
--   • Đổi tên part "head" -> "SafeHead"
--   • Đổi tên decal/texture "sprite" -> "SafeSprite"
--   • Tắt CanTouch = false một lần cho tất cả BasePart
function Logic.enableHuskImmunity(gc, enemy)
    if not enemy or not enemy:IsA("Model") then return end
    if not Logic.isHuskEntity(enemy.Name) and not (enemy:GetAttribute("OriginalName") and Logic.isHuskEntity(enemy:GetAttribute("OriginalName"))) then return end

    -- Lưu tên gốc nếu chưa có
    if not enemy:GetAttribute("OriginalName") then
        enemy:SetAttribute("OriginalName", enemy.Name)
    end

    -- Đổi tên model để bypass check tên phía LocalScript
    pcall(function()
        if not string.find(enemy.Name, "SafeWalker") then
            enemy.Name = "SafeWalker_" .. enemy.Name
        end
    end)

    local originalName = enemy:GetAttribute("OriginalName") or enemy.Name

    for _, part in ipairs(enemy:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Tắt CanTouch một lần
            pcall(function() part.CanTouch = false end)

            -- Lưu vào GC để có thể khôi phục
            if not gc.SavedPartsData[part] then
                gc.SavedPartsData[part] = {
                    originalCanTouch = part.CanTouch,
                    originalName     = part.Name,
                    enemyName        = originalName
                }
            end

            -- Đổi tên head
            if part.Name == "head" then
                pcall(function() part.Name = "SafeHead" end)
            end

        elseif part:IsA("Decal") or part:IsA("Texture") then
            -- Đổi tên sprite
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

-- Xử lý descendant mới được thêm vào (khi entity đang replicate)
function Logic.onHuskDescendantAdded(gc, enemy, part)
    if not Logic.isHuskEntity(enemy.Name) and not (enemy:GetAttribute("OriginalName") and Logic.isHuskEntity(enemy:GetAttribute("OriginalName"))) then return end

    local originalName = enemy:GetAttribute("OriginalName") or enemy.Name

    if part:IsA("BasePart") then
        pcall(function() part.CanTouch = false end)
        if not gc.SavedPartsData[part] then
            gc.SavedPartsData[part] = {
                originalCanTouch = part.CanTouch,
                originalName     = part.Name,
                enemyName        = originalName
            }
        end
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

-- Tắt miễn nhiễm Husk – khôi phục CanTouch, tên bộ phận và tên model
function Logic.disableHuskImmunity(gc)
    -- Khôi phục từng part đã lưu
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

    -- Khôi phục tên model trong workspace
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
