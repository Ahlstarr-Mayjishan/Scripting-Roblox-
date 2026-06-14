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
local ClientSideHitLogic = getgenv().loadModule("NULLSCAPE/Entities/ClientSideHit Entities Types.luau")
local GC = getgenv().loadModule("NULLSCAPE/Entities/GC.luau")

local Controller = {
    -- Trạng thái bật/tắt miễn nhiễm cho từng thực thể
    BabyImmune = false,
    BellImmune = false,
    MartImmune = false,
    ICBMImmune = false,
    SpringerImmune = false,
    SpringerImmunityMode = "Legit",
    Destroyed = false,
    
    EnemiesFolder = nil,
    PermanentConnections = {}
}

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

local inLobby = not isInMatch()       -- Đang ở sảnh chờ/lựa chọn (Khởi tạo ban đầu)
local hasInRoundValue = false
local folderConnections = {}

-- Ngắt các kết nối quan sát thư mục
local function disconnectFolderObservations()
    for _, conn in ipairs(folderConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    table.clear(folderConnections)
end


-- Hàm dọn dẹp tài nguyên (Garbage Collection - GC) giải phóng bộ nhớ
function Controller:CleanUp()
    disconnectFolderObservations()
    GC.cleanAll()
    self.EnemiesFolder = nil
    
    -- Nếu bị hủy hoàn toàn (Destroyed = true), giải phóng các kết nối vĩnh viễn
    if self.Destroyed and self.PermanentConnections then
        for _, conn in ipairs(self.PermanentConnections) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        table.clear(self.PermanentConnections)
    end
end

local disabledShockwaves = {}

local function restoreShockwave(part)
    local data = disabledShockwaves[part]
    if data then
        if data.conn1 then pcall(function() data.conn1:Disconnect() end) end
        if data.conn2 then pcall(function() data.conn2:Disconnect() end) end
        pcall(function() part.CanTouch = data.originalCanTouch end)
        pcall(function() part.CanCollide = data.originalCanCollide end)
        disabledShockwaves[part] = nil
    end
end

local function disableShockwave(enemy, part)
    if not part then return end
    if disabledShockwaves[part] then return end
    
    local originalCanTouch = part.CanTouch
    local originalCanCollide = part.CanCollide
    
    part.CanTouch = false
    part.CanCollide = false
    
    local conn1 = part:GetPropertyChangedSignal("CanTouch"):Connect(function()
        if part.CanTouch then
            part.CanTouch = false
        end
    end)
    
    local conn2 = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
        if part.CanCollide then
            part.CanCollide = false
        end
    end)
    
    disabledShockwaves[part] = {
        conn1 = conn1,
        conn2 = conn2,
        originalCanTouch = originalCanTouch,
        originalCanCollide = originalCanCollide,
        enemy = enemy
    }
end


-- Thiết lập cấu hình miễn nhiễm và kích hoạt dọn dẹp tức thời
function Controller:SetImmunity(entityName, value)
    if entityName == "Baby" then
        self.BabyImmune = value
    elseif entityName == "Bell" then
        self.BellImmune = value
    elseif entityName == "Mart" then
        self.MartImmune = value
    elseif entityName == "ICBM" then
        self.ICBMImmune = value
    elseif entityName == "Springer" then
        self.SpringerImmune = value
    end

    -- Áp dụng thay đổi tức thời cho thực thể đã tồn tại trong workspace
    if value then
        if self.EnemiesFolder then
            for _, child in ipairs(self.EnemiesFolder:GetChildren()) do
                if child.Name == entityName or string.find(child.Name, entityName) then
                    Executor.enableImmunity(GC, child)
                end
                if entityName == "Springer" and string.find(child.Name, "Springer") and self.SpringerImmunityMode == "Blatant" then
                    for _, subChild in ipairs(child:GetChildren()) do
                        if subChild.Name == "SpringerShockwave" or subChild.Name == "DemonShockwave" then
                            disableShockwave(child, subChild)
                        end
                    end
                end
            end
        end
    else
        Executor.disableImmunityForType(GC, entityName)
        if entityName == "Springer" then
            for part, data in pairs(disabledShockwaves) do
                restoreShockwave(part)
            end
        end
    end
    
    if getgenv().Rayfield then
        getgenv().Rayfield:Notify({
            Title = "Protection Config",
            Content = (value and "Activated" or "Disabled") .. " immunity for " .. entityName,
            Duration = 2
        })
    end
end

-- Cấu hình chế độ bảo vệ Springer (Blatant: tắt hẳn sóng, Legit: giữ lại lực đẩy sóng)
function Controller:SetSpringerImmunityMode(mode)
    self.SpringerImmunityMode = mode
    
    if self.SpringerImmune then
        if mode == "Blatant" then
            -- Tắt toàn bộ sóng đang tồn tại
            if self.EnemiesFolder then
                for _, enemy in ipairs(self.EnemiesFolder:GetChildren()) do
                    if string.find(enemy.Name, "Springer") then
                        for _, child in ipairs(enemy:GetChildren()) do
                            if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
                                disableShockwave(enemy, child)
                            end
                        end
                    end
                end
            end
        else
            -- Legit: Khôi phục lại toàn bộ sóng để có lực đẩy
            for part, data in pairs(disabledShockwaves) do
                restoreShockwave(part)
            end
        end
    end
end

-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function processEntity(enemy)
    if not enemy then return end
    
    -- Nếu đang bật miễn nhiễm cho thực thể này thì ẩn ngay lập tức
    local checkFunc = Logic.getImmunityCheck(enemy.Name, Controller)
    if checkFunc and checkFunc() then
        Executor.enableImmunity(GC, enemy)
    end

    -- Xử lý vô hiệu hóa shockwave cho Springer
    if string.find(enemy.Name, "Springer") then
        local childAddedConn = enemy.ChildAdded:Connect(function(child)
            if (child.Name == "SpringerShockwave" or child.Name == "DemonShockwave") and Controller.SpringerImmune and Controller.SpringerImmunityMode == "Blatant" then
                disableShockwave(enemy, child)
            end
        end)
        GC.registerEntityConnection(enemy, childAddedConn)
        
        for _, child in ipairs(enemy:GetChildren()) do
            if (child.Name == "SpringerShockwave" or child.Name == "DemonShockwave") and Controller.SpringerImmune and Controller.SpringerImmunityMode == "Blatant" then
                disableShockwave(enemy, child)
            end
        end
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
    for part, data in pairs(disabledShockwaves) do
        if data.enemy == enemy then
            restoreShockwave(part)
        end
    end
end

-- Thiết lập quan sát thư mục Enemies trong Workspace
function Controller:ObserveFolder(folder)
    self.EnemiesFolder = folder

    -- 1. Lắng nghe khi thực thể mới xuất hiện
    local childAddedConn = folder.ChildAdded:Connect(function(child)
        processEntity(child)
    end)
    table.insert(folderConnections, childAddedConn)

    -- 2. Lắng nghe khi thực thể bị xóa khỏi game
    local childRemovedConn = folder.ChildRemoved:Connect(function(child)
        removeEntity(child)
    end)
    table.insert(folderConnections, childRemovedConn)

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
    table.insert(folderConnections, destroyingConn)
end

-- Quét tìm thư mục Enemies trong Workspace và lắng nghe sự thay đổi
local function startObservingFolders()
    disconnectFolderObservations()
    
    local function checkAndObserve(child)
        if Controller.Destroyed then return end
        if child.Name == "Enemies" and child:IsA("Folder") then
            Controller:ObserveFolder(child)
        end
    end

    local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
    table.insert(folderConnections, wsConn)
    
    local initialFolder = workspace:FindFirstChild("Enemies")
    if initialFolder and initialFolder:IsA("Folder") then
        Controller:ObserveFolder(initialFolder)
    end
end

-- Hàm cập nhật trạng thái sảnh chờ và tự động dọn dẹp visual/connections
local function setInLobby(val)
    if inLobby == val then return end
    inLobby = val
    if val then
        disconnectFolderObservations()
        Controller:CleanUp()
    else
        startObservingFolders()
    end
end

-- Khởi tạo ban đầu khi nạp script
if not inLobby then
    startObservingFolders()
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực
task.spawn(function()
    local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
    if inRoundVal and inRoundVal:IsA("BoolValue") then
        hasInRoundValue = true
        setInLobby(not inRoundVal.Value)
        
        local conn = inRoundVal.Changed:Connect(function(val)
            if Controller.Destroyed then return end
            setInLobby(not val)
        end)
        table.insert(Controller.PermanentConnections, conn)
    end
end)

-- Vòng lặp quan sát dự phòng (chỉ chạy khi không có InRound)
task.spawn(function()
    while not Controller.Destroyed and not hasInRoundValue do
        task.wait(3.0)
        if Controller.Destroyed or hasInRoundValue then break end
        setInLobby(not isInMatch())
    end
end)

-- Hook để chặn RemoteEvent báo tử của thực thể Client-side (như ICBM) một cách an toàn
local hookInitialized = false
local function initializeICBMHook()
    if hookInitialized then return end
    hookInitialized = true
    
    -- Xây dựng bảng tra cứu nhanh O(1) tên RemoteEvent cần chặn để tối ưu hóa hiệu năng tối đa cho Mobile/Low-end
    local TargetRemoteNames = {}
    for remoteName, _ in pairs(ClientSideHitLogic.TargetEntities) do
        TargetRemoteNames[remoteName] = true
    end

    local function handleRemoteCall(self, ...)
        if TargetRemoteNames[self.Name] then
            if ClientSideHitLogic.isTargetRemote(self) then
                local args = {...}
                local shouldBlock, entityName = ClientSideHitLogic.shouldBlockRemoteCall(self, args)
                if shouldBlock then
                    local immuneProperty = entityName .. "Immune"
                    if Controller[immuneProperty] == true then
                        return true -- Trả về true chỉ ra cần chặn cuộc gọi này
                    end
                end
            end
        end
        return false
    end

    -- 1. Hook __namecall (Phương pháp chuẩn và mạnh nhất cho các cuộc gọi dạng Remote:FireServer(...))
    local namecallSuccess = false
    if typeof(hookmetamethod) == "function" then
        local success, err = pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" and self.ClassName == "RemoteEvent" then
                    local success, shouldBlock = pcall(handleRemoteCall, self, ...)
                    if success and shouldBlock then
                        return -- Chặn đứng cuộc gọi
                    end
                end
                return oldNamecall(self, ...)
            end)
            namecallSuccess = true
        end)
    end

    -- 2. Hook FireServer prototype (Dự phòng cho cuộc gọi dạng Remote.FireServer(Remote, ...))
    local prototypeSuccess = false
    if typeof(hookfunction) == "function" then
        local success, err = pcall(function()
            local remoteProto = Instance.new("RemoteEvent")
            local oldFireServer
            oldFireServer = hookfunction(remoteProto.FireServer, function(self, ...)
                local success, shouldBlock = pcall(handleRemoteCall, self, ...)
                if success and shouldBlock then
                    return -- Chặn đứng cuộc gọi
                end
                return oldFireServer(self, ...)
            end)
            prototypeSuccess = true
        end)
    end
    
    if not namecallSuccess and not prototypeSuccess then
        warn("Failed to initialize any ClientSideHit hook. Exploits might not be supported.")
    end
end

task.spawn(initializeICBMHook)

return Controller
