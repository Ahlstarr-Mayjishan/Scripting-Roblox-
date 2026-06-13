-- [[
--  NULLSCAPE - Entities Controller (Optimized Performance & GC Edition)
--  Chỉ tập trung vào quản lý, quan sát, tối ưu hiệu năng và tự động thu gom rác (GC).
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Nạp module dọn dẹp riêng biệt (Cleaner)
local Cleaner = loadstring(readfile("NULLSCAPE/Entities/cleaner.luau"))()


-- Dòng code liệt kê các thực thể đặc biệt cần quét
local targetNames = { ["Baby"] = true, ["Mart"] = true, ["Bell"] = true }

local Controller = {
    Enabled = false,
    Method = "DisableTouch", -- "Noclip", "DisableTouch"
    
    -- Bộ nhớ đệm quản lý tài nguyên (GC)
    ActiveConnections = {}, -- Lưu các sự kiện để disconnect khi thư mục Enemies bị hủy
    EntityConnections = {}, -- Kết nối riêng lẻ của từng thực thể
    EnemiesFolder = nil,
    FolderObserver = nil    -- Theo dõi sự thay đổi của thư mục Enemies trong Workspace
}

local isHibernating = false -- Trạng thái ngủ đông của checker TouchInterest

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
    
    -- Thu gom rác của Rayfield Highlights nếu có
    if getgenv().espHighlights then
        for player, hl in pairs(getgenv().espHighlights) do
            pcall(function() hl:Destroy() end)
        end
        getgenv().espHighlights = {}
    end
    
    warn("[NULLSCAPE] Đã kích hoạt cơ chế GC: Dọn dẹp toàn bộ bộ nhớ đệm và kết nối thực thể cũ.")
end

-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function processEntity(enemy)
    if not Controller.Enabled or not enemy then return end
    
    -- Nếu là các thực thể đặc biệt (Baby, Mart, Bell), chuyển giao hoàn toàn cho module Cleaner
    if targetNames[enemy.Name] then
        Cleaner.removeTouchInterests(enemy)
        return
    end

    Controller.EntityConnections[enemy] = Controller.EntityConnections[enemy] or {}
    local connections = Controller.EntityConnections[enemy]

    local function applyImmunity(part)
        if not part:IsA("BasePart") then return end
        
        -- 1. Phương thức Vô hiệu hóa va chạm (Noclip)
        if Controller.Method == "Noclip" then
            part.CanCollide = false
            
        -- 2. Phương thức Xóa sát thương chạm (Disable Touch)
        elseif Controller.Method == "DisableTouch" then
            part.CanTouch = false
            -- Tìm và xóa TouchTransmitter (nếu có)
            local transmitter = part:FindFirstChildOfClass("TouchTransmitter") or part:FindFirstChild("TouchInterest")
            if transmitter then
                pcall(function() transmitter:Destroy() end)
            end
        end
    end

    -- Xử lý các bộ phận hiện có của thực thể
    for _, part in ipairs(enemy:GetDescendants()) do
        applyImmunity(part)
    end

    -- Lắng nghe các bộ phận mới được thêm vào thực thể sau này (tránh sót hitbox)
    local descConn = enemy.DescendantAdded:Connect(function(part)
        applyImmunity(part)
    end)
    table.insert(connections, descConn)
end

-- Gỡ bỏ lắng nghe của thực thể khi nó bị xóa
local function removeEntity(enemy)
    if Controller.EntityConnections[enemy] then
        for _, conn in ipairs(Controller.EntityConnections[enemy]) do
            if conn then conn:Disconnect() end
        end
        Controller.EntityConnections[enemy] = nil
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

    -- 2. Lắng nghe khi thực thể bị xóa khỏi game
    local childRemovedConn = folder.ChildRemoved:Connect(function(child)
        removeEntity(child)
    end)
    table.insert(self.ActiveConnections, childRemovedConn)

    -- 3. Xử lý các thực thể đã có sẵn trong thư mục
    for _, child in ipairs(folder:GetChildren()) do
        processEntity(child)
    end

    -- 4. Cơ chế tự động GC khi thư mục bị xóa/hủy khỏi Workspace
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
        if targetNames[enemy.Name] then
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
        
        -- Thực hiện kiểm tra khi hệ thống miễn nhiễm được bật
        if Controller.Enabled then
            local foundAny, touchInterestsExist = checkTargetsForTouchInterest()
            
            if foundAny then
                if not touchInterestsExist then
                    -- Tất cả TouchInterest của các thực thể mục tiêu hiện tại đã được xóa hoàn toàn
                    isHibernating = true
                    warn("[NULLSCAPE] Đã xác nhận: Toàn bộ TouchInterest của Baby, Mart, Bell đã biến mất. Hệ thống vào trạng thái ngủ đông.")
                    
                    if getgenv().Rayfield then
                        getgenv().Rayfield:Notify({
                            Title = "Hệ thống bảo vệ",
                            Content = "TouchInterest của các thực thể đặc biệt đã được dọn sạch. Trạng thái: Ngủ đông.",
                            Duration = 3
                        })
                    end
                else
                    -- Nếu vẫn còn, kích hoạt Cleaner để dọn dẹp
                    for _, enemy in ipairs(Controller.EnemiesFolder:GetChildren()) do
                        if targetNames[enemy.Name] then
                            Cleaner.removeTouchInterests(enemy)
                        end
                    end
                end
            end
        end
    end
end)

-- Kích hoạt / Tắt miễn nhiễm
function Controller:Toggle(state)
    self.Enabled = state
    if state and self.EnemiesFolder then
        -- Kích hoạt lại trạng thái cho các thực thể hiện có
        for _, child in ipairs(self.EnemiesFolder:GetChildren()) do
            processEntity(child)
        end
    elseif not state then
        -- Giải phóng toàn bộ kết nối thực thể khi tắt
        for enemy, connections in pairs(self.EntityConnections) do
            for _, conn in ipairs(connections) do
                if conn then conn:Disconnect() end
            end
        end
        self.EntityConnections = {}
    end

    if getgenv().Rayfield then
        getgenv().Rayfield:Notify({
            Title = "Miễn nhiễm thực thể",
            Content = state and "Đã bật hệ thống miễn nhiễm!" or "Đã tắt hệ thống miễn nhiễm!",
            Duration = 2
        })
    end
end

-- Đặt phương thức miễn nhiễm
function Controller:SetMethod(methodName)
    local oldMethod = self.Method
    self.Method = methodName
    
    if self.Enabled and self.EnemiesFolder and oldMethod ~= methodName then
        -- Reset và chạy lại để áp dụng phương thức mới
        for _, child in ipairs(self.EnemiesFolder:GetChildren()) do
            processEntity(child)
        end
    end

    if getgenv().Rayfield then
        getgenv().Rayfield:Notify({
            Title = "Miễn nhiễm thực thể",
            Content = "Phương thức hiện tại: " .. methodName,
            Duration = 2
        })
    end
end

return Controller
