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

local inLobby = false       -- Đang ở sảnh chờ/lựa chọn
local isHibernating = false -- Đã dọn sạch thực thể trong trận và đang ngủ đông

-- Xác minh 2 bước kiểm tra trạng thái game (trong trận hay ở sảnh chờ)
local function isInMatch()
    local lobby = workspace:FindFirstChild("Lobby")
    local selectFolder = workspace:FindFirstChild("Select")
    
    local lobbyCount = lobby and #lobby:GetChildren() or 0
    local selectCount = selectFolder and #selectFolder:GetChildren() or 0
    
    -- Nếu cả hai thư mục đều trống (0 children) hoặc không tồn tại, tức là đang trong trận
    return lobbyCount == 0 and selectCount == 0
end

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
    
    Controller.EntityConnections[enemy] = Controller.EntityConnections[enemy] or {}
    local connections = Controller.EntityConnections[enemy]

    local function applyImmunity(part)
        local checkFunc = targetNames[enemy.Name]
        if checkFunc and checkFunc() then
            if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                pcall(function() part:Destroy() end)
            elseif part:IsA("BasePart") then
                pcall(function() part.CanTouch = false end)
            end
        end
    end

    -- Xử lý các bộ phận hiện có của thực thể
    for _, part in ipairs(enemy:GetDescendants()) do
        applyImmunity(part)
    end

    -- Lắng nghe các bộ phận mới được thêm vào thực thể sau này (tránh sót hitbox khi đang replicate)
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
    if not Controller.EnemiesFolder then return false, false, false end
    
    local foundAny = false
    local touchInterestsExist = false
    local allLoaded = true
    
    for _, enemy in ipairs(Controller.EnemiesFolder:GetChildren()) do
        local checkFunc = targetNames[enemy.Name]
        if checkFunc and checkFunc() then
            foundAny = true
            
            -- Đảm bảo thực thể đã tải xong nhân vật trước khi kiểm tra trạng thái TouchInterest
            local loaded = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildOfClass("Humanoid") or enemy:FindFirstChildWhichIsA("BasePart")
            if not loaded then
                allLoaded = false
            end
            
            for _, part in ipairs(enemy:GetDescendants()) do
                if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                    touchInterestsExist = true
                    break
                end
            end
        end
        if touchInterestsExist then break end
    end
    
    return foundAny, touchInterestsExist, allLoaded
end

-- Vòng lặp quan sát TouchInterest của các mục tiêu đặc biệt với cơ chế ngủ đông
task.spawn(function()
    while true do
        task.wait(1) -- Kiểm tra 1 giây 1 lần
        
        -- Xác minh 2 bước kiểm tra trạng thái phòng chờ / trong trận
        local currentInMatch = isInMatch()
        
        if not currentInMatch then
            -- Nếu đang ở Lobby/Select (có phần tử con) -> Ngừng quét
            if not inLobby then
                inLobby = true
                isHibernating = false -- Reset trạng thái quét của trận cũ
                warn("[NULLSCAPE] Đang ở Lobby/Select. Tạm dừng quét.")
            end
            continue
        else
            -- Nếu đã vào trận (Lobby & Select trống) -> Đánh thức hệ thống
            if inLobby then
                inLobby = false
                isHibernating = false -- Bắt đầu trận mới, kích hoạt quét
                warn("[NULLSCAPE] Đã vào trận. Bắt đầu quét...")
            end
        end
        
        -- Nếu đang ở trạng thái ngủ đông (đã dọn sạch trận này), không làm gì cả
        if isHibernating then
            continue
        end
        
        -- Nếu EnemiesFolder bị nil -> Chúng ta tiếp tục đợi cho đến khi nó xuất hiện
        if not Controller.EnemiesFolder then
            continue
        end
        
        -- Thực hiện kiểm tra TouchInterest
        local foundAny, touchInterestsExist, allLoaded = checkTargetsForTouchInterest()
        
        if foundAny then
            if not touchInterestsExist and allLoaded then
                -- Tất cả TouchInterest của các thực thể mục tiêu hiện tại đã được xóa hoàn toàn và đã load xong
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
