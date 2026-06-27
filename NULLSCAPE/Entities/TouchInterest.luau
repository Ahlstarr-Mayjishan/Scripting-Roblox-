-- [[
--  NULLSCAPE - TouchInterest Entities Immunity
--  Vai trò: Quản lý miễn nhiễm thực thể bằng nguyên lý Xóa TouchInterest (CanTouch = false)
-- ]]

local Logic = {}

-- ============================================================
--  CẤU HÌNH THỰC THỂ TOUCHINTEREST
-- ============================================================
Logic.Config = {
    ["Baby"] = "BabyImmune",
    ["Bell"] = "BellImmune",
    ["Flesh"] = "FleshImmune",
    ["Mart"] = "MartImmune",
    ["Telefragger"] = "TelefraggerImmune",
    ["Guardian"] = "GuardianImmune",
    ["ShadowGuardian"] = "GuardianImmune",
    ["Sigil"] = "SigilImmune",
    ["Cadence"] = "CadenceImmune",
    ["Catalyst"] = "CatalystImmune",
    -- Thêm thực thể TouchInterest mới tại đây, ví dụ:
    -- ["Demon"] = "DemonImmune",
}

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

function Logic.isTargetEntity(name)
    if not name then return false end
    local lowerName = string.lower(name)
    for configName, _ in pairs(Logic.Config) do
        if string.find(lowerName, string.lower(configName)) then
            return true
        end
    end
    return false
end

function Logic.getImmunityCheck(name, controller)
    if not name or not controller then return nil end
    local lowerName = string.lower(name)
    for configName, immuneKey in pairs(Logic.Config) do
        if string.find(lowerName, string.lower(configName)) then
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
    if controller and controller.inLobby then
        return
    end
    
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
        if data and data.originalCanTouch ~= nil and data.connections then
            if part and part.Parent then
                for _, conn in ipairs(data.connections) do
                    if conn then conn:Disconnect() end
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

function Logic.setInLobbyState(val)
    if val == false then
        clearTable(processedEntities)
        clearTable(descendantConnections)
    end
end

return Logic
