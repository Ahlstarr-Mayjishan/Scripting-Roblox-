-- [[
--  NULLSCAPE - Entities Protection Logic
--  Vai trò: Quản lý tập trung toàn bộ logic bảo vệ và miễn nhiễm thực thể:
--    1. Miễn nhiễm TouchInterest (Baby, Bell, Mart) bằng cách vô hiệu hóa CanTouch.
--    2. Chặn RemoteEvent gây sát thương/báo tử (ICBM, Springer, Bell).
--    3. Miễn nhiễm Husk/Skinwalker bằng cách đổi tên model/bộ phận và tắt CanTouch.
-- ]]

local Logic = {}

local Players = game:GetService("Players")

-- ============================================================
--  CẤU HÌNH THỰC THỂ & REMOTES
-- ============================================================
Logic.TouchInterestTargets = {
    ["Baby"] = "Baby",
    ["Bell"] = "Bell",
    ["Mart"] = "Mart",
}

Logic.TargetRemotes = {
    ["ClientEvent"] = true,
    ["ShockwaveEvent"] = true,
}

-- Bảng lưu trữ thực thể đã xử lý trong round hiện tại để tránh lặp vô hạn
local processedEntities = setmetatable({}, { __mode = "k" })
local descendantConnections = setmetatable({}, { __mode = "k" })

local function clearTable(t)
    if not t then return end
    if table.clear then
        table.clear(t)
    else
        for k in pairs(t) do
            t[k] = nil
        end
    end
end

-- ============================================================
--  LOGIC TOUCHINTEREST (Baby, Bell, Mart)
-- ============================================================

function Logic.isTargetEntity(name)
    if not name then return false end
    local lowerName = string.lower(name)
    for configName, _ in pairs(Logic.TouchInterestTargets) do
        if string.find(lowerName, string.lower(configName)) then
            return true
        end
    end
    return false
end

function Logic.getImmunityCheck(name, controller)
    if not name or not controller then return nil end
    local lowerName = string.lower(name)
    for configName, _ in pairs(Logic.TouchInterestTargets) do
        if string.find(lowerName, string.lower(configName)) then
            local immuneKey = configName .. "Immune"
            return function()
                return controller[immuneKey] == true
            end
        end
    end
    return nil
end

local function removeTouchFromPart(gc, enemy, part)
    if not part or not part.Parent then return end
    local parentPart = part.Parent
    
    if parentPart and parentPart:IsA("BasePart") then
        if not gc.SavedPartsData[parentPart] then
            gc.SavedPartsData[parentPart] = {
                originalCanTouch = parentPart.CanTouch,
                enemyName = enemy.Name,
                connections = {}
            }
            
            parentPart.CanTouch = false
            
            -- Lắng nghe phòng trường hợp game tự bật lại CanTouch
            local conn = parentPart:GetPropertyChangedSignal("CanTouch"):Connect(function()
                if parentPart.CanTouch then
                    parentPart.CanTouch = false
                end
            end)
            table.insert(gc.SavedPartsData[parentPart].connections, conn)
            gc.registerEntityConnection(enemy, conn)
        end
    end
end

function Logic.enableImmunity(gc, enemy)
    if not enemy or not (enemy:IsA("Model") or enemy:IsA("BasePart")) then return end
    
    local controller = gc.Controller or (getgenv().Client and getgenv().Client.Modules and getgenv().Client.Modules.EntitiesController)
    local checkFunc = Logic.getImmunityCheck(enemy.Name, controller)
    
    if checkFunc and checkFunc() then
        if not processedEntities[enemy] then
            processedEntities[enemy] = true
            
            task.defer(function()
                if not enemy or not enemy.Parent then return end
                for _, part in ipairs(enemy:GetDescendants()) do
                    if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                        removeTouchFromPart(gc, enemy, part)
                    end
                end
            end)
        end
    end
    
    if not descendantConnections[enemy] then
        local descConn = enemy.DescendantAdded:Connect(function(part)
            if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                if checkFunc and checkFunc() then
                    removeTouchFromPart(gc, enemy, part)
                end
            end
        end)
        descendantConnections[enemy] = descConn
        gc.registerEntityConnection(enemy, descConn)
    end
end

function Logic.disableImmunityForType(gc, entityName)
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.enemyName and string.find(string.lower(data.enemyName), string.lower(entityName)) then
            if part and part.Parent then
                if data.connections then
                    for _, conn in ipairs(data.connections) do
                        if conn then conn:Disconnect() end
                    end
                end
                
                pcall(function()
                    part.CanTouch = data.originalCanTouch
                end)
                
                local enemy = part
                if part.Parent and part.Parent.Name ~= "Enemies" and part.Parent.Name ~= "Skinwalkers" then
                    enemy = part.Parent
                end
                if enemy then
                    processedEntities[enemy] = nil
                end
            end
            gc.SavedPartsData[part] = nil
        end
    end
end

function Logic.restoreAll(gc)
    if not gc.SavedPartsData then return end
    for part, data in pairs(gc.SavedPartsData) do
        if data then
            if part and part.Parent then
                if data.connections then
                    for _, conn in ipairs(data.connections) do
                        if conn then conn:Disconnect() end
                    end
                end
                pcall(function()
                    part.CanTouch = data.originalCanTouch
                end)
            end
        end
    end
    clearTable(gc.SavedPartsData)
    clearTable(processedEntities)
    clearTable(descendantConnections)
end

-- ============================================================
--  LOGIC HUSK / SKINWALKER
-- ============================================================

function Logic.isHuskEntity(name)
    if not name then return false end
    return string.find(name, "Skinwalker") ~= nil or string.find(name, "Husk") ~= nil
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
end

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

-- ============================================================
--  LOGIC CHẶN REMOTE EVENT (ICBM, Springer, Bell)
-- ============================================================

function Logic.shouldBlockRemoteCall(remote, args, controller)
    if not controller then
        return false
    end

    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false
    end

    local remoteName = remote.Name
    if not Logic.TargetRemotes[remoteName] then
        return false
    end

    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character

    -- Helper check xem remote có thuộc Model của thực thể mục tiêu không
    local function findEntityParent(obj, targetSubName)
        local current = obj.Parent
        local depth = 0
        while current and current ~= workspace and current ~= game and depth < 50 do
            depth = depth + 1
            local nameSuccess, name = pcall(function() return current.Name end)
            if nameSuccess and name and string.find(string.lower(name), string.lower(targetSubName)) then
                return current
            end
            local parentSuccess, parent = pcall(function() return current.Parent end)
            if parentSuccess then
                current = parent
            else
                break
            end
        end
        return nil
    end

    -- Helper check xem remote hoặc args có nhắm tới người khác không
    local function isTargetsSomeoneElse()
        for i = 2, #args do
            local arg = args[i]
            if typeof(arg) == "Instance" then
                if arg:IsA("Player") and arg ~= LocalPlayer then
                    return true
                elseif arg:IsA("Model") and arg:FindFirstChildOfClass("Humanoid") and arg ~= char then
                    return true
                end
            elseif typeof(arg) == "table" then
                for _, val in pairs(arg) do
                    if typeof(val) == "Instance" then
                        if val:IsA("Player") and val ~= LocalPlayer then
                            return true
                        elseif val:IsA("Model") and val:FindFirstChildOfClass("Humanoid") and val ~= char then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- 1. XỬ LÝ BELL REMOTE BLOCKING (ClientEvent - debuff)
    if controller.BellImmune and remoteName == "ClientEvent" then
        local hasDebuff = false
        for _, arg in ipairs(args) do
            if typeof(arg) == "string" and string.lower(arg) == "debuff" then
                hasDebuff = true
                break
            end
        end
        if hasDebuff and findEntityParent(remote, "bell") then
            return true
        end
    end

    -- 2. XỬ LÝ ICBM REMOTE BLOCKING (ClientEvent - kill/combust/damage)
    if controller.ICBMImmune and remoteName == "ClientEvent" then
        local hasKill = false
        local hasCombust = false
        local hasDamage = false

        for _, arg in ipairs(args) do
            if typeof(arg) == "string" then
                local lowerArg = string.lower(arg)
                if lowerArg == "kill" then
                    hasKill = true
                elseif lowerArg == "combust" then
                    hasCombust = true
                elseif string.find(lowerArg, "damage") or string.find(lowerArg, "debuff") or string.find(lowerArg, "burn") or string.find(lowerArg, "fire") or string.find(lowerArg, "hit") then
                    hasDamage = true
                end
            end
        end

        local isICBM = false
        if findEntityParent(remote, "ICBM") then
            isICBM = true
        else
            for _, arg in ipairs(args) do
                if typeof(arg) == "Instance" and string.find(arg.Name, "ICBM") then
                    isICBM = true
                    break
                elseif typeof(arg) == "string" and string.find(arg, "ICBM") then
                    isICBM = true
                    break
                end
            end
        end

        if not isICBM then
            local enemies = workspace:FindFirstChild("Enemies")
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do
                    if string.find(enemy.Name, "ICBM") then
                        isICBM = true
                        break
                    end
                end
            end
        end

        if isICBM or true then
            local isBlatant = (controller.SpringerImmunityMode == "Blatant")
            if isBlatant then
                if (hasKill or hasCombust or hasDamage) and not isTargetsSomeoneElse() then
                    return true
                end
            else
                if (hasKill or hasCombust) and not isTargetsSomeoneElse() then
                    return true
                end
            end
        end
    end

    -- 3. XỬ LÝ SPRINGER REMOTE BLOCKING (ClientEvent/ShockwaveEvent)
    if controller.SpringerImmune then
        local hasKill = false
        local hasDemonKill = false
        local hasDebuff = false

        for _, arg in ipairs(args) do
            if typeof(arg) == "string" then
                if arg == "Kill" then
                    hasKill = true
                elseif arg == "DemonKill" then
                    hasDemonKill = true
                elseif arg == "Debuff" then
                    hasDebuff = true
                end
            end
        end

        local isSpringer = false
        if findEntityParent(remote, "Springer") then
            isSpringer = true
        else
            for _, arg in ipairs(args) do
                if typeof(arg) == "Instance" and string.find(arg.Name, "Springer") then
                    isSpringer = true
                    break
                elseif typeof(arg) == "string" and string.find(arg, "Springer") then
                    isSpringer = true
                    break
                end
            end
        end

        if not isSpringer then
            local enemies = workspace:FindFirstChild("Enemies")
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do
                    if string.find(enemy.Name, "Springer") then
                        isSpringer = true
                        break
                    end
                end
            end
        end

        if isSpringer or true then
            if remoteName == "ClientEvent" then
                if (hasKill or hasDemonKill) and not isTargetsSomeoneElse() then
                    return true
                end
            elseif remoteName == "ShockwaveEvent" then
                if hasDebuff and controller.SpringerImmunityMode == "Blatant" and not isTargetsSomeoneElse() then
                    return true
                end
            end
        end
    end

    return false
end

-- ============================================================
--  QUẢN LÝ TRẠNG THÁI SẢNH CHỜ
-- ============================================================

function Logic.setInLobbyState(val)
    if val == false then
        clearTable(processedEntities)
        clearTable(descendantConnections)
    end
end

return Logic
