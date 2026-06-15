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

-- Helper in log có kiểm tra toggle Debug Logs trong master settings
local function debugPrint(...)
    local Client = getgenv().Client
    if Client and Client.DebugLogs then
        print("[DEBUG NULLSCAPE]", ...)
    end
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
        debugPrint("processedEntities cleared for new round")
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
    if not enemy or not enemy:IsA("Model") then return end
    
    -- Đảm bảo chỉ chạy 1 lần/1 round trên mỗi thực thể để tránh lặp vô hạn gây đứng máy
    if processedEntities[enemy] then 
        debugPrint("Entity already processed this round, skipping:", enemy.Name)
        return 
    end
    processedEntities[enemy] = true
    
    -- Lấy controller bằng cơ chế gc hoặc fallback getgenv() toàn cục chống bất đồng bộ bản sao
    local controller = gc.Controller or (getgenv().Client and getgenv().Client.Modules and getgenv().Client.Modules.EntitiesController)
    debugPrint("Controller resolved:", controller ~= nil)
    
    local checkFunc = Logic.getImmunityCheck(enemy.Name, controller)
    debugPrint("checkFunc found:", checkFunc ~= nil)
    if checkFunc then
        debugPrint("checkFunc value:", checkFunc())
    end
    
    -- 1. Đăng ký sự kiện lắng nghe để xóa ngay lập tức nếu TouchInterest được tải xuống trễ hẳn
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
    gc.registerEntityConnection(enemy, descConn)
    
    -- 2. Sử dụng task.defer để trì hoãn nhẹ một vi khung hình, đợi Roblox hoàn tất đồng bộ cây phân cấp con
    task.defer(function()
        if not enemy or not enemy.Parent then return end
        debugPrint("Deferred scan for:", enemy.Name, "| Descendants count:", #enemy:GetDescendants())
        for _, part in ipairs(enemy:GetDescendants()) do
            if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                debugPrint("Found TouchInterest in deferred scan:", part:GetFullName())
                if checkFunc and checkFunc() then
                    debugPrint("Removing TouchInterest from deferred scan:", part:GetFullName())
                    removeTouchFromPart(gc, enemy, part)
                else
                    debugPrint("Toggle is OFF or checkFunc nil, skipping deferred scan TouchInterest removal")
                end
            end
        end
    end)
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
                local enemy = part:IsA("Model") and part or part.Parent
                if enemy and enemy:IsA("Model") then
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
    debugPrint("All caches cleared in restoreAll")
end

return Logic
