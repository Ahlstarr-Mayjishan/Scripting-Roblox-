-- [[
--  NULLSCAPE - Entities Controller (Optimized Performance & GC Edition)
--  Chỉ tập trung vào quản lý, quan sát, tối ưu hiệu năng và tự động thu gom rác (GC).
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Nạp module dọn dẹp riêng biệt (Cleaner)
local Cleaner = getgenv().loadModule("NULLSCAPE/Entities/cleaner.luau")

local Controller = {
    -- Trạng thái bật/tắt miễn nhiễm cho từng thực thể
    BabyImmune = false,
    BellImmune = false,
    MartImmune = false,
    
    -- Bộ nhớ đệm quản lý tài nguyên (GC)
    ActiveConnections = {}, -- Lưu các sự kiện để disconnect khi thư mục Enemies bị hủy
    EntityConnections = {}, -- Kết nối riêng lẻ của từng thực thể
    EnemiesFolder = nil,
    FolderObserver = nil    -- Theo dõi sự thay đổi của thư mục Enemies trong Workspace
}

local targetNames = {
    ["Baby"] = function() return Controller.BabyImmune end,
    ["Bell"] = function() return Controller.BellImmune end,
    ["Mart"] = function() return Controller.MartImmune end
}

local isHibernating = false -- Trạng thái ngủ đông của checker TouchInterest

-- Thiết lập cấu hình miễn nhiễm và kích hoạt dọn dẹp tức thời
function Controller:SetImmunity(entityName, value)
    if entityName == "Baby" then
        self.BabyImmune = value
    elseif entityName == "Bell" then
        self.BellImmune = value
    elseif entityName == "Mart" then
        self.MartImmune = value
    end
    
    if value then
        isHibernating = false -- Đánh thức checker
        
        -- Dọn dẹp tức thời nếu thực thể đã tồn tại trong workspace
        if self.EnemiesFolder then
            for _, child in ipairs(self.EnemiesFolder:GetChildren()) do
                if child.Name == entityName then
                    Cleaner.removeTouchInterests(child)
                end
            end
        end
    end
    
    if getgenv().Rayfield then
        getgenv().Rayfield:Notify({
            Title = "Cấu hình bảo vệ",
            Content = (value and "Kích hoạt" or "Vô hiệu hóa") .. " miễn nhiễm với " .. entityName,
            Duration = 2
        })
    end
end

-- Hàm dọn dẹp tài nguyên (Garbage Collection - GC) giải phóng bộ nhớ
function Controller:CleanUp()
    -- Disconnect các kết nối của từng thực thể
    for enemy, connections in pairs(self.EntityConnections) do
        for _, conn in ipairs(connections) do
            if conn then conn:Disconnect() end
        end
    end
    self.EntityConnections = {}

    -- Disconnect các kết nối chung của thư mục
    for _, conn in ipairs(self.ActiveConnections) do
        if conn then conn:Disconnect() end
    end
    self.ActiveConnections = {}

    self.EnemiesFolder = nil
    
    warn("[NULLSCAPE] Đã kích hoạt cơ chế GC: Dọn dẹp toàn bộ bộ nhớ đệm và kết nối thực thể cũ.")
end

-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function processEntity(enemy)
    if not enemy then return end
    
    -- Kiểm tra xem thực thể có trong danh sách mục tiêu và đang được bật Toggle không
    local checkFunc = targetNames[enemy.Name]
    if checkFunc and checkFunc() then
        Cleaner.removeTouchInterests(enemy)
    end
end

-- Thiết lập quan sát thư mục Enemies trong Workspace
function Controller:ObserveFolder(folder)
    self:CleanUp() -- Dọn dẹp tàn dư cũ trước khi gán mới
    self.EnemiesFolder = folder

    -- 1. Lắng nghe khi thực thể mới xuất hiện
    local childAddedConn = folder.ChildAdded:Connect(function(child)
        processEntity(child)
    end)
    table.insert(self.ActiveConnections, childAddedConn)

    -- 2. Xử lý các thực thể đã có sẵn trong thư mục
    for _, child in ipairs(folder:GetChildren()) do
        processEntity(child)
    end

    -- 3. Cơ chế tự động GC khi thư mục bị xóa/hủy khỏi Workspace
    local destroyingConn = folder.AncestryChanged:Connect(function(_, parent)
        if not parent then
            -- Thư mục Enemies đã bị xóa hoàn toàn khỏi trò chơi (chuyển màn, game reset,...)
            self:CleanUp()
        end
    end)
    table.insert(self.ActiveConnections, destroyingConn)
    
    warn("[NULLSCAPE] Đang quan sát thư mục Enemies mới.")
end

-- Quét tìm thư mục Enemies trong Workspace
local function startObserving()
    -- Theo dõi khi thư mục Enemies xuất hiện trong Workspace
    local function checkAndObserve(child)
        if child.Name == "Enemies" and child:IsA("Folder") then
            Controller:ObserveFolder(child)
        end
    end

    local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
    
    -- Quét thư mục hiện có
    local initialFolder = workspace:FindFirstChild("Enemies")
    if initialFolder and initialFolder:IsA("Folder") then
        Controller:ObserveFolder(initialFolder)
    end
end
task.spawn(startObserving)

-- Kiểm tra xem trong các thực thể mục tiêu còn TouchInterest nào không
local function checkTargetsForTouchInterest()
    if not Controller.EnemiesFolder then return false, false end
    
    local foundAny = false
    local touchInterestsExist = false
    
    for _, enemy in ipairs(Controller.EnemiesFolder:GetChildren()) do
        local checkFunc = targetNames[enemy.Name]
        if checkFunc and checkFunc() then
            foundAny = true
            for _, part in ipairs(enemy:GetDescendants()) do
                if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                    touchInterestsExist = true
                    break
                end
            end
        end
        if touchInterestsExist then break end
    end
    
    return foundAny, touchInterestsExist
end

-- Vòng lặp quan sát TouchInterest của các mục tiêu đặc biệt với cơ chế ngủ đông
task.spawn(function()
    while true do
        task.wait(1) -- Kiểm tra 1 giây 1 lần
        
        -- Nếu EnemiesFolder bị nil -> Đánh thức cơ chế kiểm tra (tái kích hoạt)
        if not Controller.EnemiesFolder then
            if isHibernating then
                isHibernating = false
                warn("[NULLSCAPE] Thư mục Enemies đã bằng nil. Tái kích hoạt cơ chế quan sát TouchInterest (Check 1s/lần).")
            end
            continue
        end
        
        -- Nếu đang ở trạng thái ngủ đông, không làm gì cả
        if isHibernating then
            continue
        end
        
        -- Thực hiện kiểm tra
        local foundAny, touchInterestsExist = checkTargetsForTouchInterest()
        
        if foundAny then
            if not touchInterestsExist then
                -- Tất cả TouchInterest của các thực thể mục tiêu hiện tại đã được xóa hoàn toàn
                isHibernating = true
                warn("[NULLSCAPE] Đã xác nhận: Toàn bộ TouchInterest của các mục tiêu bật bảo vệ đã biến mất. Hệ thống vào trạng thái ngủ đông.")
                
                if getgenv().Rayfield then
                    getgenv().Rayfield:Notify({
                        Title = "Hệ thống bảo vệ",
                        Content = "TouchInterest của thực thể kích hoạt đã được dọn sạch. Trạng thái: Ngủ đông.",
                        Duration = 3
                    })
                end
            else
                -- Nếu vẫn còn, kích hoạt Cleaner để dọn dẹp
                for _, enemy in ipairs(Controller.EnemiesFolder:GetChildren()) do
                    local checkFunc = targetNames[enemy.Name]
                    if checkFunc and checkFunc() then
                        Cleaner.removeTouchInterests(enemy)
                    end
                end
            end
        end
    end
end)

return Controller
