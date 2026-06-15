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

-- Thực hiện xóa TouchInterest / TouchTransmitter của thực thể và lưu cache khôi phục
local function removeTouchFromPart(gc, enemy, part)
    if not part or not part.Parent then return end
    
    local parentPart = part.Parent
    if parentPart and parentPart:IsA("BasePart") then
        if gc.SavedPartsData[parentPart] then
            gc.SavedPartsData[parentPart].touch = part
        else
            gc.SavedPartsData[parentPart] = {
                touch = part,
                enemyName = enemy.Name
            }
        end
    end
    
    pcall(function()
        part.Parent = nil
    end)
end

-- Kích hoạt miễn nhiễm cho thực thể
function Logic.enableImmunity(gc, enemy)
    if not enemy or not enemy:IsA("Model") then return end
    
    -- 1. Quét toàn bộ những phần tử hiện có
    for _, part in ipairs(enemy:GetDescendants()) do
        if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
            removeTouchFromPart(gc, enemy, part)
        end
    end
    
    -- 2. Đăng ký sự kiện lắng nghe để xóa ngay lập tức nếu TouchInterest được tải xuống trễ
    local descConn = enemy.DescendantAdded:Connect(function(part)
        if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
            removeTouchFromPart(gc, enemy, part)
        end
    end)
    
    gc.registerEntityConnection(enemy, descConn)
end

-- Tắt miễn nhiễm (Khôi phục lại TouchInterest cho một loại thực thể)
function Logic.disableImmunityForType(gc, entityName)
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.enemyName and string.find(data.enemyName, entityName) then
            if part and part.Parent and data.touch then
                pcall(function()
                    data.touch.Parent = part
                end)
            end
            gc.SavedPartsData[part] = nil
        end
    end
end

-- Khôi phục tất cả TouchInterest và làm sạch toàn bộ cache
function Logic.restoreAll(gc)
    if not gc.SavedPartsData then return end
    for part, data in pairs(gc.SavedPartsData) do
        if data and data.touch then
            if part and part.Parent then
                pcall(function()
                    data.touch.Parent = part
                end)
            end
        end
    end
    table.clear(gc.SavedPartsData)
end

return Logic
