-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Controller
--  Vai trò: Đảm nhiệm việc quan sát hiệu năng, phân tích tài nguyên và đưa ra các quyết định điều phối:
--  - Giám sát trạng thái hoạt động của script, điều phối chế độ ngủ đông (hibernating) tối ưu CPU.
--  - Phát hiện trạng thái sảnh chờ/trận đấu (khi inLobby = false sẽ kích hoạt gọi quét scan).
--  - Phát lệnh gọi quét định vị (scan) định kỳ thông qua Executor.
--  - Gửi kết nối đăng ký qua GC và phát lệnh dọn dẹp giải phóng tài nguyên.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Executor = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/executor.luau")
local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local GC = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/GC.luau")

local Controller = {
    RadarEnabled = false,
    GiftESPEnabled = false,
    CadenceESPEnabled = false,
    AltarESPEnabled = false,
    AltarFilter = {"All"},
    ESPStyle = "Highlight", -- Mặc định: "Highlight" hoặc "Dot"
    Destroyed = false,
    
    AutoCollectEnabled = false,
    AutoCollectRange = 20,
    AutoCollectMode = "Legit",
    
    TripmineBarrierEnabled = false,
    SimulateDefuseKit = false,
    DefuseKitStack = 3,
    
    NearestGiftPosition = nil,
    NearestCadencePosition = nil,
    NearestAltarPosition = nil,
    ActiveGifts = {},
    ActiveInstruments = {},
    ActiveAltars = {},
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
local matchLoopsActive = false
local folderConnections = {}

-- Forward references cho việc quản lý các loop
local startMatchLoops, startRenderStepped, stopRenderStepped

-- Kiểm tra xem có mục tiêu hợp lệ nào được bật hay không
local function checkActiveState()
    if inLobby then return false end
    if not Controller.RadarEnabled then return false end
    
    if Controller.GiftESPEnabled and #Controller.ActiveGifts > 0 then
        return true
    end
    if Controller.CadenceESPEnabled and #Controller.ActiveInstruments > 0 then
        return true
    end
    if Controller.AltarESPEnabled and #Controller.ActiveAltars > 0 then
        return true
    end
    
    return false
end

-- Điều phối trạng thái chạy/dừng của các loop và render
local function updateRunningState()
    if checkActiveState() then
        startMatchLoops()
        startRenderStepped()
    else
        stopRenderStepped()
    end
end

-- Ngắt các kết nối sự kiện thư mục
local function disconnectFolderObservations()
    for _, conn in ipairs(folderConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    table.clear(folderConnections)
end

-- Đăng ký các hàm helper để quan sát vật thể thời gian thực
local function registerGift(obj)
    if not obj:IsA("BasePart") then return end
    local nameLower = obj.Name:lower()
    
    local isGift = string.find(nameLower, "gift") or string.find(nameLower, "present")
    local isTripmine = string.find(nameLower, "tripmine")
    
    if isGift or isTripmine then
        for _, g in ipairs(Controller.ActiveGifts) do
            if g.part == obj then return end
        end
        
        -- Xác định màu sắc và phân loại từ bảng màu dùng chung
        local color = Logic.ESPColors.Gift
        local giftType = "Gift"
        
        if isTripmine then
            color = Logic.ESPColors.Tripmine
            giftType = "Tripmine"
        elseif string.find(nameLower, "golden") then
            color = Logic.ESPColors.GoldenGift
            giftType = "GoldenGift"
        elseif string.find(nameLower, "passage") then
            color = Logic.ESPColors.PassageGift
            giftType = "PassageGift"
        end
        
        table.insert(Controller.ActiveGifts, {part = obj, color = color, type = giftType})
        updateRunningState()
    end
end

local function unregisterGift(obj)
    local removed = false
    for i, g in ipairs(Controller.ActiveGifts) do
        if g.part == obj then
            table.remove(Controller.ActiveGifts, i)
            removed = true
            break
        end
    end
    if removed then
        updateRunningState()
    end
end

local function registerInstrument(obj)
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return end
    if not Logic.isInstrument(obj.Name) then return end
    
    local targetPart = obj:IsA("Model") and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj
    if targetPart and targetPart:IsA("BasePart") then
        for _, inst in ipairs(Controller.ActiveInstruments) do
            if inst.model == obj or inst.part == targetPart then return end
        end
        table.insert(Controller.ActiveInstruments, {part = targetPart, model = obj, color = Logic.ESPColors.Cadence, type = "Cadence"})
        updateRunningState()
    end
end

local function unregisterInstrument(obj)
    local removed = false
    for i, inst in ipairs(Controller.ActiveInstruments) do
        if inst.model == obj or inst.part == obj then
            table.remove(Controller.ActiveInstruments, i)
            removed = true
            break
        end
    end
    if removed then
        updateRunningState()
    end
end

local function registerAltar(altarObj)
    local targetPart = altarObj:IsA("Model") and (altarObj:FindFirstChild("HumanoidRootPart") or altarObj:FindFirstChildWhichIsA("BasePart")) or altarObj
    if targetPart and targetPart:IsA("BasePart") then
        for _, a in ipairs(Controller.ActiveAltars) do
            if a.model == altarObj or a.part == targetPart then return end
        end
        local altarName, altarColor = Logic.getAltarTypeAndColor(altarObj)
        table.insert(Controller.ActiveAltars, {part = targetPart, model = altarObj, color = altarColor, type = "Altar", altarName = altarName})
        updateRunningState()
    end
end

local function unregisterAltar(altarObj)
    local removed = false
    for i, a in ipairs(Controller.ActiveAltars) do
        if a.model == altarObj or a.part == altarObj then
            table.remove(Controller.ActiveAltars, i)
            removed = true
            break
        end
    end
    if removed then
        updateRunningState()
    end
end

local function observeItemPools(folder)
    for _, obj in ipairs(folder:GetDescendants()) do
        registerGift(obj)
        registerInstrument(obj)
    end
    
    local addedConn = folder.DescendantAdded:Connect(function(obj)
        registerGift(obj)
        registerInstrument(obj)
    end)
    table.insert(folderConnections, addedConn)
    
    local removedConn = folder.DescendantRemoving:Connect(function(obj)
        unregisterGift(obj)
        unregisterInstrument(obj)
    end)
    table.insert(folderConnections, removedConn)
end

local function observeEnemies(folder)
    for _, obj in ipairs(folder:GetDescendants()) do
        registerInstrument(obj)
    end
    
    local addedConn = folder.DescendantAdded:Connect(function(obj)
        registerInstrument(obj)
    end)
    table.insert(folderConnections, addedConn)
    
    local removedConn = folder.DescendantRemoving:Connect(function(obj)
        unregisterInstrument(obj)
    end)
    table.insert(folderConnections, removedConn)
end

local function checkRoomForAltar(room)
    local altarObj = room:FindFirstChild("AltarLocation") or room:FindFirstChild("AltarModel") or room:FindFirstChild("Altar")
    if altarObj then
        registerAltar(altarObj)
    end
    
    local childAddedConn = room.ChildAdded:Connect(function(child)
        if child.Name == "AltarLocation" or child.Name == "AltarModel" or child.Name == "Altar" then
            registerAltar(child)
        end
    end)
    table.insert(folderConnections, childAddedConn)
end

local function observeCurrentRooms(folder)
    for _, room in ipairs(folder:GetChildren()) do
        checkRoomForAltar(room)
    end
    
    local roomAddedConn = folder.ChildAdded:Connect(function(room)
        checkRoomForAltar(room)
    end)
    table.insert(folderConnections, roomAddedConn)
    
    local roomRemovedConn = folder.ChildRemoved:Connect(function(room)
        local altarObj = room:FindFirstChild("AltarLocation") or room:FindFirstChild("AltarModel") or room:FindFirstChild("Altar")
        if altarObj then
            unregisterAltar(altarObj)
        end
    end)
    table.insert(folderConnections, roomRemovedConn)
end

local function startObservingFolders()
    disconnectFolderObservations()
    
    table.clear(Controller.ActiveGifts)
    table.clear(Controller.ActiveInstruments)
    table.clear(Controller.ActiveAltars)
    
    local function checkAndObserve(child)
        if child.Name == "Item_Pools" then
            observeItemPools(child)
        elseif child.Name == "Enemies" then
            observeEnemies(child)
        elseif child.Name == "CurrentRooms" then
            observeCurrentRooms(child)
        end
    end
    
    local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
    table.insert(folderConnections, wsConn)
    
    local itemPools = workspace:FindFirstChild("Item_Pools")
    if itemPools then observeItemPools(itemPools) end
    
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then observeEnemies(enemies) end
    
    local currentRooms = workspace:FindFirstChild("CurrentRooms")
    if currentRooms then observeCurrentRooms(currentRooms) end
end

-- RenderStepped connection management
local renderConn = nil

stopRenderStepped = function()
    if renderConn then
        renderConn:Disconnect()
        renderConn = nil
    end
end

startRenderStepped = function()
    if renderConn then return end
    renderConn = RunService.RenderStepped:Connect(function()
        if Controller.Destroyed then
            stopRenderStepped()
            return
        end
        if inLobby or not checkActiveState() then
            stopRenderStepped()
            return
        end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        pcall(function()
            Executor.updateRender(Controller, GC, hrp)
        end)
    end)
end

-- Vòng lặp cập nhật styles hiển thị (Dot <-> Highlight) cực nhanh mỗi 0.15 giây
startMatchLoops = function()
    if matchLoopsActive then return end
    matchLoopsActive = true
    
    task.spawn(function()
        while not Controller.Destroyed and not inLobby and checkActiveState() do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    Executor.updateESPStyles(Controller, GC, hrp)
                end)
                pcall(function()
                    Executor.updateMagnet(Controller, hrp)
                end)
                pcall(function()
                    Executor.updateBarriers(Controller, GC)
                end)
            end
            task.wait(0.1)
        end
        matchLoopsActive = false
        -- Xóa visuals cũ khi dừng loop (hủy cả các mũi tên chỉ hướng)
        pcall(function()
            Executor.clearVisuals(GC, false)
        end)
    end)
end

-- Hàm cập nhật trạng thái sảnh chờ và tự động dọn dẹp visual khi vào sảnh
local function setInLobby(val)
    if inLobby == val then return end
    inLobby = val
    if val then
        pcall(function()
            Executor.clearVisuals(GC, false)
        end)
        disconnectFolderObservations()
        stopRenderStepped()
        table.clear(Controller.ActiveGifts)
        table.clear(Controller.ActiveInstruments)
        table.clear(Controller.ActiveAltars)
    else
        startObservingFolders()
        updateRunningState()
    end
end

-- Hàm trigger cập nhật ESP tức thì khi thay đổi cấu hình
local function triggerInstantUpdate()
    if inLobby then return end
    updateRunningState()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and checkActiveState() then
        pcall(function()
            Executor.updateESPStyles(Controller, GC, hrp)
        end)
    end
end

-- Bật/tắt radar tổng
function Controller:SetRadarEnabled(value)
    self.RadarEnabled = value
    if not value then
        pcall(function()
            Executor.clearVisuals(GC, false)
        end)
    end
    triggerInstantUpdate()
end

-- Bật/tắt định vị hộp quà
function Controller:SetGiftESP(value)
    self.GiftESPEnabled = value
    triggerInstantUpdate()
end

-- Bật/tắt định vị nhạc cụ Cadence
function Controller:SetCadenceESP(value)
    self.CadenceESPEnabled = value
    triggerInstantUpdate()
end

-- Bật/tắt định vị Đàn tế (Altar)
function Controller:SetAltarESP(value)
    self.AltarESPEnabled = value
    triggerInstantUpdate()
end

-- Bộ lọc loại Altar (Hỗ trợ multi-select table)
function Controller:SetAltarFilter(option)
    if typeof(option) == "string" then
        self.AltarFilter = {option}
    else
        self.AltarFilter = option or {"All"}
    end
    triggerInstantUpdate()
end

-- Thay đổi chế độ hiển thị ESP
function Controller:SetESPStyle(style)
    self.ESPStyle = style or "Highlight"
    pcall(function()
        Executor.clearVisuals(GC, true)
    end)
    triggerInstantUpdate()
end

-- Bật/tắt Auto Collect
function Controller:SetAutoCollectEnabled(value)
    self.AutoCollectEnabled = value
end

-- Điều chỉnh khoảng cách Auto Collect
function Controller:SetAutoCollectRange(value)
    self.AutoCollectRange = value
end

-- Thiết lập chế độ Auto Collect (Legit / Blatant)
function Controller:SetAutoCollectMode(value)
    self.AutoCollectMode = value or "Legit"
end

-- Bật/tắt rào cản vật lý mìn (Tripmine Barrier)
function Controller:SetTripmineBarrier(value)
    self.TripmineBarrierEnabled = value
end

-- Bật/tắt mô phỏng Defuse Kit
function Controller:SetSimulateDefuseKit(value)
    self.SimulateDefuseKit = value
end

-- Điều chỉnh số stack Defuse Kit mô phỏng
function Controller:SetDefuseKitStack(value)
    self.DefuseKitStack = value
end

-- Hàm phát hiện nâng cấp Radar chính thức của game đã mở khóa (Tối ưu hóa tránh đệ quy sâu)
local function checkRadarUnlocked()
    local unlocked = false
    local checkValue = function(val)
        if not val then return false end
        if val:IsA("BoolValue") and val.Value == true then
            return true
        elseif (val:IsA("NumberValue") or val:IsA("IntValue")) and val.Value >= 1 then
            return true
        end
        return false
    end

    -- 1. Check trực tiếp trong LocalPlayer
    for _, name in ipairs({"Radar", "RadarUpgrade", "RadarUnlocked"}) do
        local child = LocalPlayer:FindFirstChild(name)
        if checkValue(child) then return true end
    end

    -- 2. Check trong các thư mục Upgrades/Stats/Passives/Perks của LocalPlayer
    for _, folderName in ipairs({"Upgrades", "Passives", "Perks", "Stats", "UpgradesFolder"}) do
        local folder = LocalPlayer:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if string.find(child.Name:lower(), "radar") and checkValue(child) then
                    return true
                end
            end
        end
    end

    -- 3. Check trong ReplicatedStorage (chứa Upgrades toàn cục hoặc theo tên người chơi)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    for _, folderName in ipairs({
        "Upgrades", 
        "PlayerUpgrades", 
        "Upgrades_" .. LocalPlayer.Name, 
        LocalPlayer.Name .. "_Upgrades"
    }) do
        local folder = ReplicatedStorage:FindFirstChild(folderName)
        if folder then
            local playerFolder = folder:FindFirstChild(LocalPlayer.Name) or folder
            for _, child in ipairs(playerFolder:GetChildren()) do
                if string.find(child.Name:lower(), "radar") and checkValue(child) then
                    return true
                end
            end
        end
    end

    -- 4. Fallback: Quét đệ quy nhanh trên LocalPlayer như cũ
    local function check(parent)
        if not parent or unlocked then return end
        local pName = parent.Name
        if pName == "PlayerGui" or pName == "PlayerScripts" or pName == "Backpack" or pName == "StarterGear" then
            return
        end
        
        for _, child in ipairs(parent:GetChildren()) do
            local name = child.Name:lower()
            if string.find(name, "radar") and checkValue(child) then
                unlocked = true
                break
            end
            if not unlocked then
                check(child)
            end
        end
    end
    pcall(function() check(LocalPlayer) end)
    return unlocked
end

-- Hàm dọn dẹp tài nguyên (GC) khi tắt hoặc hủy UI
function Controller:CleanUp()
    self.Destroyed = true
    disconnectFolderObservations()
    stopRenderStepped()
    
    if self.PermanentConnections then
        for _, conn in ipairs(self.PermanentConnections) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        table.clear(self.PermanentConnections)
    end
    
    GC.cleanAll()
end

-- Khởi tạo ban đầu khi nạp script
if not inLobby then
    startObservingFolders()
    updateRunningState()
end

-- Vòng lặp phát hiện Radar chính thức của game
task.spawn(function()
    while not Controller.Destroyed do
        task.wait(5.0) -- Kiểm tra 5.0 giây một lần cực kỳ tối ưu
        if Controller.Destroyed then break end
        
        if checkRadarUnlocked() then
            if getgenv().Rayfield then
                getgenv().Rayfield:Notify({
                    Title = "Radar Auto Disabled",
                    Content = "Official game radar detected. Custom radar disabled to optimize performance!",
                    Duration = 5
                })
            end
            Controller:CleanUp()
            break
        end
    end
end)

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

local function hookUpgradeHandler()
    task.spawn(function()
        local ReplicatedFirst = game:GetService("ReplicatedFirst")
        local ClientModules = ReplicatedFirst:WaitForChild("ClientModules", 15)
        local UpgradeHandlerModule = ClientModules and ClientModules:WaitForChild("UpgradeHandler", 15)
        if UpgradeHandlerModule then
            local success, UpgradeHandler = pcall(require, UpgradeHandlerModule)
            if success and typeof(UpgradeHandler) == "table" then
                if UpgradeHandler.IsUpgradeEnabled then
                    if typeof(hookfunction) == "function" then
                        local oldIsUpgradeEnabled
                        oldIsUpgradeEnabled = hookfunction(UpgradeHandler.IsUpgradeEnabled, function(...)
                            local isDefuse = false
                            for i = 1, select("#", ...) do
                                if select(i, ...) == "DefuseKit" then
                                    isDefuse = true
                                    break
                                end
                            end
                            if isDefuse and Controller.SimulateDefuseKit then
                                return true
                            end
                            return oldIsUpgradeEnabled(...)
                        end)
                    else
                        local oldIsUpgradeEnabled = UpgradeHandler.IsUpgradeEnabled
                        UpgradeHandler.IsUpgradeEnabled = function(...)
                            local isDefuse = false
                            for i = 1, select("#", ...) do
                                if select(i, ...) == "DefuseKit" then
                                    isDefuse = true
                                    break
                                end
                            end
                            if isDefuse and Controller.SimulateDefuseKit then
                                return true
                            end
                            return oldIsUpgradeEnabled(...)
                        end
                    end
                end
                
                if UpgradeHandler.GetUpgradeStack then
                    if typeof(hookfunction) == "function" then
                        local oldGetUpgradeStack
                        oldGetUpgradeStack = hookfunction(UpgradeHandler.GetUpgradeStack, function(...)
                            local isDefuse = false
                            for i = 1, select("#", ...) do
                                if select(i, ...) == "DefuseKit" then
                                    isDefuse = true
                                    break
                                end
                            end
                            if isDefuse and Controller.SimulateDefuseKit then
                                return Controller.DefuseKitStack or 3
                            end
                            return oldGetUpgradeStack(...)
                        end)
                    else
                        local oldGetUpgradeStack = UpgradeHandler.GetUpgradeStack
                        UpgradeHandler.GetUpgradeStack = function(...)
                            local isDefuse = false
                            for i = 1, select("#", ...) do
                                if select(i, ...) == "DefuseKit" then
                                    isDefuse = true
                                    break
                                end
                            end
                            if isDefuse and Controller.SimulateDefuseKit then
                                return Controller.DefuseKitStack or 3
                            end
                            return oldGetUpgradeStack(...)
                        end
                    end
                end
            end
        end
    end)
end

pcall(hookUpgradeHandler)

return Controller
