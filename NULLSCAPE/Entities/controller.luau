-- [[
--  NULLSCAPE - Entities Controller (Optimized Performance & GC Edition)
--  Chỉ tập trung vào quản lý, quan sát, tối ưu hiệu năng và tự động thu gom rác (GC).
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Controller = {
    -- Trạng thái bật/tắt miễn nhiễm cho từng thực thể
    BabyImmune = false,
    BellImmune = false,
    MartImmune = false,
    Destroyed = false,
    
    -- Bộ nhớ đệm quản lý tài nguyên (GC)
    ActiveConnections = {}, -- Lưu các sự kiện để disconnect khi thư mục Enemies bị hủy
    EntityConnections = {}, -- Kết nối riêng lẻ của từng thực thể
    EnemiesFolder = nil,
    FolderObserver = nil,   -- Theo dõi sự thay đổi của thư mục Enemies trong Workspace
    SavedPartsData = setmetatable({}, { __mode = "k" }) -- Cache lưu TouchInterest & CanTouch
}

local targetNames = {
    ["Baby"] = function() return Controller.BabyImmune end,
    ["Bell"] = function() return Controller.BellImmune end,
    ["Mart"] = function() return Controller.MartImmune end
}

local inLobby = false       -- Đang ở sảnh chờ/lựa chọn
local isHibernating = false -- Đã dọn sạch thực thể trong trận và đang ngủ đông

-- Xác minh kiểm tra trạng thái game bằng ReplicatedStorage.InRound
local function isInMatch()
    local inRoundVal = ReplicatedStorage:FindFirstChild("InRound")
    if inRoundVal and inRoundVal:IsA("BoolValue") then
        return inRoundVal.Value
    end
    
    -- Fallback 1: Nếu thư mục Enemies tồn tại và có thực thể bên trong, chắc chắn đang trong trận
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies and #enemies:GetChildren() > 0 then
        return true
    end
    
    -- Fallback 2: Đếm phần tử con trong sảnh chờ
    local lobby = workspace:FindFirstChild("Lobby")
    local selectFolder = workspace:FindFirstChild("Select")
    
    local lobbyCount = lobby and #lobby:GetChildren() or 0
    local selectCount = selectFolder and #selectFolder:GetChildren() or 0
    
    return lobbyCount == 0 and selectCount == 0
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực (Real-time change listener)
task.spawn(function()
    local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
    if inRoundVal and inRoundVal:IsA("BoolValue") then
        local conn = inRoundVal.Changed:Connect(function(val)
            if Controller.Destroyed then return end
            if val then
                -- Bắt đầu trận mới, kích hoạt quét ngay lập tức
                inLobby = false
                isHibernating = false
            else
                -- Về phòng chờ, tạm ngưng hoạt động quét
                inLobby = true
                isHibernating = false
            end
        end)
        table.insert(Controller.ActiveConnections, conn)
    end
end)

-- Bật miễn nhiễm (ẩn TouchInterest và tắt CanTouch) cho một thực thể cụ thể
function Controller:EnableImmunity(enemy)
    if not enemy then return end
    for _, descendant in ipairs(enemy:GetDescendants()) do
        if descendant:IsA("TouchTransmitter") or descendant.Name == "TouchInterest" then
            local part = descendant.Parent
            if part and part:IsA("BasePart") then
                if not self.SavedPartsData[part] then
                    self.SavedPartsData[part] = {
                        touch = descendant,
                        originalCanTouch = part.CanTouch
                    }
                end
                pcall(function() descendant.Parent = nil end)
                pcall(function() part.CanTouch = false end)
            end
        end
    end
end

-- Tắt miễn nhiễm (khôi phục lại TouchInterest và CanTouch) cho một thực thể cụ thể
function Controller:DisableImmunity(enemy)
    if not enemy then return end
    for part, data in pairs(self.SavedPartsData) do
        if part and part.Parent and part:IsDescendantOf(enemy) then
            if data.touch then
                pcall(function() data.touch.Parent = part end)
            end
            pcall(function() part.CanTouch = data.originalCanTouch end)
            self.SavedPartsData[part] = nil
        end
    end
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
    
    isHibernating = false -- Đánh thức checker
    
    -- Áp dụng thay đổi tức thời cho thực thể đã tồn tại trong workspace
    if self.EnemiesFolder then
        for _, child in ipairs(self.EnemiesFolder:GetChildren()) do
            if child.Name == entityName then
                if value then
                    self:EnableImmunity(child)
                else
                    self:DisableImmunity(child)
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
    -- Khôi phục lại toàn bộ TouchInterest trước khi dọn dẹp (nếu có)
    if self.SavedPartsData then
        for part, data in pairs(self.SavedPartsData) do
            if part and part.Parent and data then
                if data.touch then
                    pcall(function() data.touch.Parent = part end)
                end
                pcall(function() part.CanTouch = data.originalCanTouch end)
            end
        end
        table.clear(self.SavedPartsData)
    end

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
end

-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function processEntity(enemy)
    if not enemy then return end
    
    Controller.EntityConnections[enemy] = Controller.EntityConnections[enemy] or {}
    local connections = Controller.EntityConnections[enemy]

    -- Nếu đang bật miễn nhiễm cho thực thể này thì ẩn ngay lập tức
    local checkFunc = targetNames[enemy.Name]
    if checkFunc and checkFunc() then
        Controller:EnableImmunity(enemy)
    end

    -- Lắng nghe các bộ phận mới được thêm vào thực thể sau này (tránh sót hitbox khi đang replicate)
    local descConn = enemy.DescendantAdded:Connect(function(part)
        local checkFunc = targetNames[enemy.Name]
        if checkFunc and checkFunc() then
            if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                local parentPart = part.Parent
                if parentPart and parentPart:IsA("BasePart") then
                    if not Controller.SavedPartsData[parentPart] then
                        Controller.SavedPartsData[parentPart] = {
                            touch = part,
                            originalCanTouch = parentPart.CanTouch
                        }
                    end
                    pcall(function() part.Parent = nil end)
                    pcall(function() parentPart.CanTouch = false end)
                end
            end
        end
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
end

-- Quét tìm thư mục Enemies trong Workspace
local function startObserving()
    -- Theo dõi khi thư mục Enemies xuất hiện trong Workspace
    local function checkAndObserve(child)
        if Controller.Destroyed then return end
        if child.Name == "Enemies" and child:IsA("Folder") then
            Controller:ObserveFolder(child)
        end
    end

    local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
    table.insert(Controller.ActiveConnections, wsConn)
    
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
    while not Controller.Destroyed do
        task.wait(1) -- Kiểm tra 1 giây 1 lần
        if Controller.Destroyed then break end
        
        -- Xác minh trạng thái phòng chờ / trong trận
        local currentInMatch = isInMatch()
        
        if not currentInMatch then
            -- Nếu đang ở Lobby/Select -> Ngừng quét
            if not inLobby then
                inLobby = true
                isHibernating = false -- Reset trạng thái quét của trận cũ
            end
            continue
        else
            -- Nếu đã vào trận -> Đánh thức hệ thống
            if inLobby then
                inLobby = false
                isHibernating = false -- Bắt đầu trận mới, kích hoạt quét
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
                
                if getgenv().Rayfield then
                    getgenv().Rayfield:Notify({
                        Title = "Hệ thống bảo vệ",
                        Content = "TouchInterest của thực thể kích hoạt đã được dọn sạch. Trạng thái: Ngủ đông.",
                        Duration = 3
                    })
                end
            else
                -- Nếu vẫn còn, kích hoạt ẩn đi và lưu trữ
                for _, enemy in ipairs(Controller.EnemiesFolder:GetChildren()) do
                    local checkFunc = targetNames[enemy.Name]
                    if checkFunc and checkFunc() then
                        Controller:EnableImmunity(enemy)
                    end
                end
            end
        end
    end
end)

return Controller
