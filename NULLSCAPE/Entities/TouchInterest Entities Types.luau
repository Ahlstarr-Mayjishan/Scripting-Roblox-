-- [[
--  NULLSCAPE - TouchInterest Entities Types & Ranges Logic
--  Vai trò: Quản lý tập trung tất cả thực thể miễn nhiễm bằng nguyên lý Xóa TouchInterest (TouchTransmitter).
-- ]]

local Logic = {}

-- ============================================================
--  BẢNG CẤU HÌNH TÊN THỰC THỂ CÓ CÙNG NGUYÊN LÝ TOUCHINTEREST
-- ============================================================
Logic.TargetNames = {
    ["Baby"] = "Baby",
    ["Bell"] = "Bell",
    ["Mart"] = "Mart",
}

-- ============================================================
--  LOGIC XỬ LÝ CHUNG (KHÔNG CẦN THAY ĐỔI KHI THÊM THỰC THỂ)
-- ============================================================

-- Bảng lưu trữ thực thể đã xử lý trong round hiện tại để tránh lặp vô hạn
local processedEntities = setmetatable({}, { __mode = "k" })
local descendantConnections = setmetatable({}, { __mode = "k" })

-- Các hàm helper tương thích ngược cho các executor cũ/mobile
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

local function findInTable(t, val)
    if not t then return nil end
    if table.find then
        return table.find(t, val)
    end
    for i, v in ipairs(t) do
        if v == val then
            return i
        end
    end
    return nil
end

local function debugPrint(...)
    warn("[DEBUG NULLSCAPE TouchInterest]", ...)
end

-- Hàm kiểm tra xem tên thực thể có nằm trong danh sách cần xóa TouchInterest không (Không phân biệt hoa thường)
function Logic.isTargetEntity(name)
    if not name then return false end
    local lowerName = string.lower(name)
    for configName, _ in pairs(Logic.TargetNames) do
        if string.find(lowerName, string.lower(configName)) then
            return true
        end
    end
    return false
end

-- Lấy hàm kiểm tra trạng thái bật/tắt menu tương ứng từ Controller
function Logic.getImmunityCheck(name, controller)
    if not name then return nil end
    if not controller then return nil end
    local lowerName = string.lower(name)
    for configName, _ in pairs(Logic.TargetNames) do
        if string.find(lowerName, string.lower(configName)) then
            -- Áp dụng động thuộc tính "[Tên]Immune" từ controller
            local immuneKey = configName .. "Immune"
            return function()
                return controller[immuneKey] == true
            end
        end
    end
    return nil
end

-- Hàm đặt trạng thái InLobby để dọn dẹp danh sách đã xử lý
function Logic.setInLobbyState(val)
    debugPrint("setInLobbyState called with:", val)
    if val == false then
        clearTable(processedEntities)
        clearTable(descendantConnections)
        debugPrint("processedEntities and descendantConnections cleared for new round")
        
        -- Quét thử toàn bộ workspace sau 5 giây để tìm mọi TouchInterest
        task.delay(5, function()
            warn("--- NULLSCAPE: QUÉT TOÀN BỘ TOUCHINTEREST ---")
            local count = 0
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("TouchTransmitter") or obj.Name == "TouchInterest" then
                    count = count + 1
                    warn("   [" .. tostring(count) .. "] " .. obj:GetFullName())
                end
            end
            warn("--- NULLSCAPE: KẾT THÚC QUÉT (Tổng cộng: " .. tostring(count) .. ") ---")
        end)
    end
end

-- Thực hiện xóa TouchInterest / TouchTransmitter của thực thể và lưu cache khôi phục
local function removeTouchFromPart(gc, enemy, part)
    if not part or not part.Parent then return end
    
    local parentPart = part.Parent
    debugPrint("removeTouchFromPart called for:", part:GetFullName(), "| Parent:", parentPart and parentPart.Name)
    
    if parentPart and typeof(parentPart) == "Instance" then
        if not gc.SavedPartsData[parentPart] then
            gc.SavedPartsData[parentPart] = {
                touches = {},
                enemyName = enemy.Name
            }
        end
        -- Tránh lưu lặp lại cùng một TouchInterest
        if not findInTable(gc.SavedPartsData[parentPart].touches, part) then
            table.insert(gc.SavedPartsData[parentPart].touches, part)
        end
    end
    
    local success, err = pcall(function()
        part.Parent = nil
    end)
    debugPrint("unparent result success:", success, "| err:", err, "| parent after:", part.Parent)
end

-- Kích hoạt miễn nhiễm cho thực thể
function Logic.enableImmunity(gc, enemy)
    debugPrint("enableImmunity called for:", enemy and enemy:GetFullName())
    if not enemy or not (enemy:IsA("Model") or enemy:IsA("BasePart")) then return end
    
    -- Lấy controller bằng cơ chế gc hoặc fallback getgenv() toàn cục chống bất đồng bộ bản sao
    local controller = gc.Controller or (getgenv().Client and getgenv().Client.Modules and getgenv().Client.Modules.EntitiesController)
    debugPrint("Controller resolved:", controller ~= nil)
    
    local checkFunc = Logic.getImmunityCheck(enemy.Name, controller)
    debugPrint("checkFunc found:", checkFunc ~= nil)
    if checkFunc then
        debugPrint("checkFunc value:", checkFunc())
    end
    
    -- 1. Nếu toggle đang bật và thực thể chưa được xử lý xóa TouchInterest trong round này
    if checkFunc and checkFunc() then
        if not processedEntities[enemy] then
            processedEntities[enemy] = true
            
            -- Sử dụng task.defer để trì hoãn nhẹ một vi khung hình, đợi Roblox hoàn tất đồng bộ cây phân cấp con
            task.defer(function()
                if not enemy or not enemy.Parent then return end
                local descendants = enemy:GetDescendants()
                debugPrint("Deferred scan for:", enemy.Name, "| Descendants count:", #descendants)
                for _, part in ipairs(descendants) do
                    pcall(function()
                        debugPrint("   - Descendant name:", part.Name, "| Class:", part.ClassName)
                    end)
                    if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                        debugPrint("Found TouchInterest in deferred scan:", part:GetFullName())
                        removeTouchFromPart(gc, enemy, part)
                    end
                end
            end)
        end
    end
    
    -- 2. Đăng ký sự kiện lắng nghe DescendantAdded nếu chưa có kết nối nào cho thực thể này
    if not descendantConnections[enemy] then
        local descConn = enemy.DescendantAdded:Connect(function(part)
            debugPrint("DescendantAdded in:", enemy.Name, "| Part:", part.Name, "| ClassName:", part.ClassName)
            if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                if checkFunc and checkFunc() then
                    debugPrint("Removing TouchInterest from DescendantAdded:", part:GetFullName())
                    removeTouchFromPart(gc, enemy, part)
                else
                    debugPrint("Toggle is OFF or checkFunc nil, skipping DescendantAdded TouchInterest removal")
                end
            end
        end)
        descendantConnections[enemy] = descConn
        gc.registerEntityConnection(enemy, descConn)
    end
end

-- Tắt miễn nhiễm (Khôi phục lại TouchInterest cho một loại thực thể)
function Logic.disableImmunityForType(gc, entityName)
    debugPrint("disableImmunityForType called for:", entityName)
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.enemyName and string.find(string.lower(data.enemyName), string.lower(entityName)) then
            if part and part.Parent and data.touches then
                debugPrint("Restoring touches for:", part:GetFullName())
                for _, touch in ipairs(data.touches) do
                    pcall(function()
                        touch.Parent = part
                    end)
                    debugPrint("Restored touch:", touch:GetFullName(), "to:", part.Name)
                end
                
                -- Khôi phục xong thì giải phóng khỏi processedEntities để cho phép xử lý lại khi bật toggle
                local enemy = part
                if part.Parent and part.Parent.Name ~= "Enemies" and part.Parent.Name ~= "Skinwalkers" then
                    enemy = part.Parent
                end
                if enemy then
                    processedEntities[enemy] = nil
                    debugPrint("Cleared processedEntities for restored enemy:", enemy.Name)
                end
            end
            gc.SavedPartsData[part] = nil
        end
    end
end

-- Khôi phục tất cả TouchInterest và làm sạch toàn bộ cache
function Logic.restoreAll(gc)
    debugPrint("restoreAll called")
    if not gc.SavedPartsData then return end
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.touches then
            if part and part.Parent then
                debugPrint("Restoring touches for:", part:GetFullName())
                for _, touch in ipairs(data.touches) do
                    pcall(function()
                        touch.Parent = part
                    end)
                end
            end
        end
    end
    clearTable(gc.SavedPartsData)
    clearTable(processedEntities)
    clearTable(descendantConnections)
    debugPrint("All caches cleared in restoreAll")
end

-- Chặn các cuộc gọi RemoteEvent gây debuff từ thực thể TouchInterest (như Bell)
function Logic.shouldBlockRemoteCall(remote, args, controller)
    if not controller then
        return false
    end

    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false
    end

    local remoteName = remote.Name
    if remoteName ~= "ClientEvent" then
        return false
    end

    -- 1. Kiểm tra thực thể Bell
    if controller.BellImmune then
        local hasDebuff = false
        for _, arg in ipairs(args) do
            if typeof(arg) == "string" and string.lower(arg) == "debuff" then
                hasDebuff = true
                break
            end
        end

        if hasDebuff then
            -- Duyệt ngược lên để tìm xem remote có thuộc Model Bell không
            local current = remote.Parent
            local depth = 0
            while current and current ~= workspace and current ~= game and depth < 50 do
                depth = depth + 1
                local nameSuccess, name = pcall(function() return current.Name end)
                if nameSuccess and name and string.find(string.lower(name), "bell") then
                    debugPrint("[HOOK] Blocked Bell ClientEvent(Debuff)")
                    return true
                end
                local parentSuccess, parent = pcall(function() return current.Parent end)
                if parentSuccess then
                    current = parent
                else
                    break
                end
            end
        end
    end

    return false
end

return Logic
