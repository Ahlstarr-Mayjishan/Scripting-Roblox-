-- [[
--  NULLSCAPE - TouchInterest Entities Types & Ranges Logic
--  Vai trò: Quản lý tập trung tất cả thực thể miễn nhiễm bằng nguyên lý Xóa TouchInterest (TouchTransmitter).
--  
--  HƯỚNG DẪN CẤU HÌNH:
--  Nếu game cập nhật thêm thực thể mới có cùng nguyên lý (chỉ cần xóa TouchInterest là miễn nhiễm),
--  bạn chỉ cần thêm tên của thực thể đó vào bảng `Logic.TargetNames` bên dưới.
-- ]]

local Logic = {}

-- ============================================================
--  BẢNG CẤU HÌNH TÊN THỰC THỂ CÓ CÙNG NGUYÊN LÝ TOUCHINTEREST
-- ============================================================
Logic.TargetNames = {
    ["Baby"] = "Baby",
    ["Bell"] = "Bell",
    ["Mart"] = "Mart",
    -- Thêm tên thực thể mới vào đây. Ví dụ: ["NewEntity"] = "NewEntity"
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

-- Hàm kiểm tra xem tên thực thể có nằm trong danh sách cần xóa TouchInterest không
function Logic.isTargetEntity(name)
    if not name then return false end
    for configName, _ in pairs(Logic.TargetNames) do
        if string.find(name, configName) then
            return true
        end
    end
    return false
end

-- Lấy hàm kiểm tra trạng thái bật/tắt menu tương ứng từ Controller
function Logic.getImmunityCheck(name, controller)
    if not name then return nil end
    if not controller then return nil end
    for configName, _ in pairs(Logic.TargetNames) do
        if string.find(name, configName) then
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
    if val == false then
        clearTable(processedEntities)
    end
end

-- Thực hiện xóa TouchInterest / TouchTransmitter của thực thể và lưu cache khôi phục
local function removeTouchFromPart(gc, enemy, part)
    if not part or not part.Parent then return end
    
    local parentPart = part.Parent
    -- parentPart có thể là Model (ví dụ: Bell, Baby) hoặc BasePart
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
    
    pcall(function()
        part.Parent = nil
    end)
end

-- Kích hoạt miễn nhiễm cho thực thể
function Logic.enableImmunity(gc, enemy)
    if not enemy or not enemy:IsA("Model") then return end
    
    -- Đảm bảo chỉ chạy 1 lần/1 round trên mỗi thực thể để tránh lặp vô hạn gây đứng máy
    if processedEntities[enemy] then return end
    processedEntities[enemy] = true
    
    -- Lấy controller bằng cơ chế gc hoặc fallback getgenv() toàn cục chống bất đồng bộ bản sao
    local controller = gc.Controller or (getgenv().Client and getgenv().Client.Modules and getgenv().Client.Modules.EntitiesController)
    local checkFunc = Logic.getImmunityCheck(enemy.Name, controller)
    
    -- 1. Đăng ký sự kiện lắng nghe để xóa ngay lập tức nếu TouchInterest được tải xuống trễ hẳn
    local descConn = enemy.DescendantAdded:Connect(function(part)
        if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
            if checkFunc and checkFunc() then
                removeTouchFromPart(gc, enemy, part)
            end
        end
    end)
    gc.registerEntityConnection(enemy, descConn)
    
    -- 2. Sử dụng task.defer để trì hoãn nhẹ một vi khung hình, đợi Roblox hoàn tất đồng bộ cây phân cấp con
    task.defer(function()
        if not enemy or not enemy.Parent then return end
        for _, part in ipairs(enemy:GetDescendants()) do
            if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                if checkFunc and checkFunc() then
                    removeTouchFromPart(gc, enemy, part)
                end
            end
        end
    end)
end

-- Tắt miễn nhiễm (Khôi phục lại TouchInterest cho một loại thực thể)
function Logic.disableImmunityForType(gc, entityName)
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.enemyName and string.find(data.enemyName, entityName) then
            if part and part.Parent and data.touches then
                for _, touch in ipairs(data.touches) do
                    pcall(function()
                        touch.Parent = part
                    end)
                end
                
                -- Khôi phục xong thì giải phóng khỏi processedEntities để cho phép xử lý lại khi bật toggle
                local enemy = part:IsA("Model") and part or part.Parent
                if enemy and enemy:IsA("Model") then
                    processedEntities[enemy] = nil
                end
            end
            gc.SavedPartsData[part] = nil
        end
    end
end

-- Khôi phục tất cả TouchInterest và làm sạch toàn bộ cache
function Logic.restoreAll(gc)
    if not gc.SavedPartsData then return end
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.touches then
            if part and part.Parent then
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
end

return Logic
