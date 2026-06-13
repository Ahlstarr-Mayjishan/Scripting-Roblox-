-- [[
--  NULLSCAPE - Entities Controller
--  Vai trò: Đảm nhiệm việc quan sát hiệu năng, phân tích tài nguyên và đưa ra các quyết định điều phối:
--  - Phát hiện trạng thái sảnh chờ/trận đấu (khi inLobby = false sẽ kích hoạt gọi quét scan).
--  - Giám sát trạng thái hoạt động của script, điều phối chế độ ngủ đông (hibernating) tối ưu CPU.
--  - Gửi kết nối đăng ký qua GC và phát lệnh dọn dẹp giải phóng tài nguyên.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Executor = getgenv().loadModule("NULLSCAPE/Entities/executor.luau")
local Logic = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest Entities Types.luau")
local GC = getgenv().loadModule("NULLSCAPE/Entities/GC.luau")

local Controller = {
    -- Trạng thái bật/tắt miễn nhiễm cho từng thực thể
    BabyImmune = false,
    BellImmune = false,
    MartImmune = false,
    Destroyed = false,
    
    EnemiesFolder = nil
}

local inLobby = false       -- Đang ở sảnh chờ/lựa chọn
local isHibernating = false -- Đã dọn sạch thực thể trong trận và đang ngủ đông

-- Xác minh kiểm tra trạng thái game bằng ReplicatedStorage.InRound
local function isInMatch()
    local inRoundVal = ReplicatedStorage:FindFirstChild("InRound")
    if inRoundVal and inRoundVal:IsA("BoolValue") then
        return inRoundVal.Value
    end
    
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies and #enemies:GetChildren() > 0 then
        return true
    end
    
    return false
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực
task.spawn(function()
    local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
    if inRoundVal and inRoundVal:IsA("BoolValue") then
        local conn = inRoundVal.Changed:Connect(function(val)
            if Controller.Destroyed then return end
            if val then
                inLobby = false
                isHibernating = false
            else
                inLobby = true
                isHibernating = false
            end
        end)
        GC.registerConnection(conn)
    end
end)

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
    if value then
        if self.EnemiesFolder then
            for _, child in ipairs(self.EnemiesFolder:GetChildren()) do
                if child.Name == entityName then
                    Executor.enableImmunity(GC, child)
                end
            end
        end
    else
        Executor.disableImmunityForType(GC, entityName)
    end
    
    if getgenv().Rayfield then
        getgenv().Rayfield:Notify({
            Title = "Protection Config",
            Content = (value and "Activated" or "Disabled") .. " immunity for " .. entityName,
            Duration = 2
        })
    end
end

-- Hàm dọn dẹp tài nguyên (Garbage Collection - GC) giải phóng bộ nhớ
function Controller:CleanUp()
    GC.cleanAll()
    self.EnemiesFolder = nil
end

-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function processEntity(enemy)
    if not enemy then return end
    
    -- Nếu đang bật miễn nhiễm cho thực thể này thì ẩn ngay lập tức
    local checkFunc = Logic.getImmunityCheck(enemy.Name, Controller)
    if checkFunc and checkFunc() then
        Executor.enableImmunity(GC, enemy)
    end

    -- Lắng nghe các bộ phận mới được thêm vào thực thể sau này (tránh sót hitbox khi đang replicate)
    local descConn = enemy.DescendantAdded:Connect(function(part)
        local checkFunc = Logic.getImmunityCheck(enemy.Name, Controller)
        if checkFunc and checkFunc() then
            if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
                local parentPart = part.Parent
                if parentPart and parentPart:IsA("BasePart") then
                    if not GC.SavedPartsData[parentPart] then
                        GC.SavedPartsData[parentPart] = {
                            touch = part,
                            originalCanTouch = parentPart.CanTouch,
                            enemyName = enemy.Name
                        }
                    end
                    pcall(function() part.Parent = nil end)
                    pcall(function() parentPart.CanTouch = false end)
                end
            end
        end
    end)
    GC.registerEntityConnection(enemy, descConn)
end

-- Gỡ bỏ lắng nghe của thực thể khi nó bị xóa
local function removeEntity(enemy)
    GC.removeEntityConnections(enemy)
end

-- Thiết lập quan sát thư mục Enemies trong Workspace
function Controller:ObserveFolder(folder)
    self:CleanUp() -- Dọn dẹp tàn dư cũ trước khi gán mới
    self.EnemiesFolder = folder

    -- 1. Lắng nghe khi thực thể mới xuất hiện
    local childAddedConn = folder.ChildAdded:Connect(function(child)
        processEntity(child)
    end)
    GC.registerConnection(childAddedConn)

    -- 2. Lắng nghe khi thực thể bị xóa khỏi game
    local childRemovedConn = folder.ChildRemoved:Connect(function(child)
        removeEntity(child)
    end)
    GC.registerConnection(childRemovedConn)

    -- 3. Xử lý các thực thể đã có sẵn trong thư mục
    for _, child in ipairs(folder:GetChildren()) do
        processEntity(child)
    end

    -- 4. Cơ chế tự động GC khi thư mục bị xóa/hủy khỏi Workspace
    local destroyingConn = folder.AncestryChanged:Connect(function(_, parent)
        if not parent then
            -- Thư mục Enemies đã bị xóa hoàn toàn khỏi trò chơi
            self:CleanUp()
        end
    end)
    GC.registerConnection(destroyingConn)
end

-- Quét tìm thư mục Enemies trong Workspace
local function startObserving()
    local function checkAndObserve(child)
        if Controller.Destroyed then return end
        if child.Name == "Enemies" and child:IsA("Folder") then
            Controller:ObserveFolder(child)
        end
    end

    local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
    GC.registerConnection(wsConn)
    
    local initialFolder = workspace:FindFirstChild("Enemies")
    if initialFolder and initialFolder:IsA("Folder") then
        Controller:ObserveFolder(initialFolder)
    end
end
task.spawn(startObserving)

-- Vòng lặp quan sát TouchInterest của các mục tiêu đặc biệt với cơ chế ngủ đông
task.spawn(function()
    while not Controller.Destroyed do
        task.wait(1) -- Kiểm tra 1 giây 1 lần
        if Controller.Destroyed then break end
        
        local currentInMatch = isInMatch()
        
        if not currentInMatch then
            if not inLobby then
                inLobby = true
                isHibernating = false
            end
            continue
        else
            if inLobby then
                inLobby = false
                isHibernating = false
            end
        end
        
        if isHibernating then
            continue
        end
        
        if not Controller.EnemiesFolder then
            continue
        end
        
        -- Gọi logic kiểm tra trạng thái TouchInterest từ logic file
        local foundAny, touchInterestsExist, allLoaded = Logic.checkTargetsForTouchInterest(Controller.EnemiesFolder, Controller)
        
        if foundAny then
            if not touchInterestsExist and allLoaded then
                isHibernating = true
                
                if getgenv().Rayfield then
                    getgenv().Rayfield:Notify({
                        Title = "Protection System",
                        Content = "TouchInterest of active entities has been cleaned. Status: Hibernating.",
                        Duration = 3
                    })
                end
            else
                for _, enemy in ipairs(Controller.EnemiesFolder:GetChildren()) do
                    local checkFunc = Logic.getImmunityCheck(enemy.Name, Controller)
                    if checkFunc and checkFunc() then
                        Executor.enableImmunity(GC, enemy)
                    end
                end
            end
        end
    end
end)

return Controller
