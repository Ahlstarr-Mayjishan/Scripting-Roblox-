-- [[
--  NULLSCAPE - Accessibility Controller
--  Vai trò: Quản lý trạng thái và phối hợp các tính năng trợ năng (Accessibility) của hack.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Executor = getgenv().loadModule("NULLSCAPE/Accessibility/executor.luau")
local GC = getgenv().loadModule("NULLSCAPE/Accessibility/GC.luau")

local Controller = {
    SpringerAutoJumpEnabled = false,
    Destroyed = false,
    
    EnemiesFolder = nil,
    PermanentConnections = {}
}

local _LocalPlayer = Players.LocalPlayer
local inLobby = true
local folderConnections = {}

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

inLobby = not isInMatch()

-- Ngắt các kết nối quan sát thư mục
local function disconnectFolderObservations()
    for _, conn in ipairs(folderConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    table.clear(folderConnections)
end

-- Hàm dọn dẹp tài nguyên
function Controller:CleanUp()
    disconnectFolderObservations()
    GC.cleanAll()
    self.EnemiesFolder = nil
    
    if self.Destroyed and self.PermanentConnections then
        for _, conn in ipairs(self.PermanentConnections) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        table.clear(self.PermanentConnections)
    end
end

-- Thiết lập cấu hình tự động nhảy
function Controller:SetSpringerAutoJump(value)
    self.SpringerAutoJumpEnabled = value
    self:updateSpringerAutoJumpState()
    
    if getgenv().Rayfield then
        getgenv().Rayfield:Notify({
            Title = "Accessibility Config",
            Content = (value and "Activated" or "Disabled") .. " Springer Auto Jump",
            Duration = 2
        })
    end
end

local function handleSpringerShockwave(enemy, child)
    if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
        Executor.setupAutoJump(enemy, child, Controller, GC)
    end
end

-- Xử lý từng thực thể Springer khi xuất hiện
local function processEntity(enemy)
    if not enemy then return end
    
    if string.find(enemy.Name, "Springer") then
        -- 1. Lắng nghe các shockwave được thêm vào động sau này (khi Springer nhảy)
        local childAddedConn = enemy.ChildAdded:Connect(function(child)
            handleSpringerShockwave(enemy, child)
        end)
        GC.registerEntityConnection(enemy, childAddedConn)
        
        -- 2. Xử lý các shockwave đã có sẵn trong model
        for _, child in ipairs(enemy:GetChildren()) do
            handleSpringerShockwave(enemy, child)
        end
    end
end

-- Gỡ bỏ lắng nghe của thực thể khi bị xóa
local function removeEntity(enemy)
    GC.removeEntityConnections(enemy)
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

-- Cập nhật động trạng thái Auto Jump của Springer dựa trên cài đặt và immunity mode
function Controller:updateSpringerAutoJumpState()
    local entitiesController = getgenv().loadModule("NULLSCAPE/Entities/controller.luau")
    local isBlatant = entitiesController and entitiesController.SpringerImmunityMode == "Blatant"
    
    if self.SpringerAutoJumpEnabled and not isBlatant then
        -- Kích hoạt quan sát thư mục nếu chưa kích hoạt
        if not next(folderConnections) then
            startObservingFolders()
        end
    else
        -- Blatant mode hoặc Auto Jump tắt -> Giải phóng hoàn toàn để CPU nghỉ ngơi
        disconnectFolderObservations()
        GC.cleanAll()
        self.EnemiesFolder = nil
    end
end

-- Hàm cập nhật trạng thái sảnh chờ
local function setInLobby(val)
    if inLobby == val then return end
    inLobby = val
    if val then
        disconnectFolderObservations()
        Controller:CleanUp()
    else
        Controller:updateSpringerAutoJumpState()
    end
end

-- Khởi tạo ban đầu khi nạp script
if not inLobby then
    Controller:updateSpringerAutoJumpState()
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực
task.spawn(function()
    local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
    if inRoundVal and inRoundVal:IsA("BoolValue") then
        setInLobby(not inRoundVal.Value)
        
        local conn = inRoundVal.Changed:Connect(function(val)
            if Controller.Destroyed then return end
            setInLobby(not val)
        end)
        table.insert(Controller.PermanentConnections, conn)
    end
end)

return Controller
