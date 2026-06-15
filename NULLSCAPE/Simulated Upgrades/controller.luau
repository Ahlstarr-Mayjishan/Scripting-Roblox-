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
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

local Executor = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/executor.luau")
local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local GC = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/GC.luau")
local MatrixTetrahedron = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Matrix Tetrahedron.luau")

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
    
    MatrixTetrahedronEnabled = false, -- Mô phỏng Matrix Tetrahedron di chuyển instant acceleration
    MomentumReduction = 1.0,          -- Lực Momentum Reduction tùy biến (mặc định 100%)
    
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
-- Forward reference cho unregisterInstrument (dùng trong registerInstrument callback)
local unregisterInstrument

-- Kiểm tra xem có mục tiêu hợp lệ nào được bật hay không
local function checkActiveState()
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
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return end
    local nameLower = obj.Name:lower()
    
    local isGift = string.find(nameLower, "gift") or string.find(nameLower, "present") or obj:HasTag("Gift")
    local isTripmine = string.find(nameLower, "tripmine")
    
    if isGift or isTripmine then
        local targetPart = obj:IsA("Model") and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart") or obj) or obj
        if not targetPart then return end
        
        for _, g in ipairs(Controller.ActiveGifts) do
            if g.part == targetPart or g.model == obj then return end
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
        
        table.insert(Controller.ActiveGifts, {part = targetPart, model = obj, color = color, type = giftType})
        updateRunningState()
    end
end

local function unregisterGift(obj)
    local removed = false
    for i, g in ipairs(Controller.ActiveGifts) do
        if g.part == obj or g.model == obj then
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
    if not (Logic.isInstrument(obj.Name) or obj:HasTag("CadenceOrb")) then return end
    
    -- Theo ref.lua: CadenceOrb chỉ hợp lệ khi CanTouch = true (chưa bị nhặt)
    if obj:IsA("BasePart") and obj:HasTag("CadenceOrb") then
        if not obj.CanTouch then return end
    end
    
    local targetPart = obj:IsA("Model") and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj
    if targetPart and targetPart:IsA("BasePart") then
        for _, inst in ipairs(Controller.ActiveInstruments) do
            if inst.model == obj or inst.part == targetPart then return end
        end
        table.insert(Controller.ActiveInstruments, {part = targetPart, model = obj, color = Logic.ESPColors.Cadence, type = "Cadence"})
        updateRunningState()
        
        -- Theo ref.lua: lắng nghe CanTouch thay đổi → tự động unregister
        if obj:IsA("BasePart") and obj:HasTag("CadenceOrb") then
            local canTouchConn
            canTouchConn = obj:GetPropertyChangedSignal("CanTouch"):Connect(function()
                if not obj.CanTouch then
                    unregisterInstrument(obj)
                    if canTouchConn then
                        canTouchConn:Disconnect()
                        canTouchConn = nil
                    end
                end
            end)
            table.insert(folderConnections, canTouchConn)
        end
    end
end

unregisterInstrument = function(obj)
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
    -- Theo ref.lua: object được tag "Altar" có thể là Model trực tiếp với HitBox bên trong,
    -- hoặc HitBox nằm ở altarObj.Parent (parent của tagged object)
    -- Kiểm tra: AltarUsed attribute để bỏ qua altar đã dùng
    local parentObj = altarObj.Parent
    if parentObj and parentObj:GetAttribute("AltarUsed") then return end
    
    -- Tìm HitBox: ưu tiên trong chính altarObj, sau đó thử ở parent
    local hitBox = altarObj:FindFirstChild("HitBox") or altarObj:FindFirstChild("Hitbox")
    if not hitBox and parentObj then
        hitBox = parentObj:FindFirstChild("HitBox") or parentObj:FindFirstChild("Hitbox")
    end
    
    -- Fallback: dùng bất kỳ BasePart nào trong altarObj hoặc chính altarObj
    local targetPart = hitBox
    if not targetPart then
        if altarObj:IsA("BasePart") then
            targetPart = altarObj
        elseif altarObj:IsA("Model") then
            targetPart = altarObj:FindFirstChildWhichIsA("BasePart")
        end
    end
    
    if not targetPart or not targetPart:IsA("BasePart") then return end
    
    for _, a in ipairs(Controller.ActiveAltars) do
        if a.model == altarObj or a.part == targetPart then return end
    end
    
    local altarName, altarColor = Logic.getAltarTypeAndColor(altarObj)
    table.insert(Controller.ActiveAltars, {part = targetPart, model = altarObj, color = altarColor, type = "Altar", altarName = altarName})
    updateRunningState()
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
    
    -- 1. Đăng ký các thực thể hiện có bằng CollectionService (Chuẩn xác theo ref.lua)
    for _, obj in ipairs(CollectionService:GetTagged("Gift")) do
        registerGift(obj)
    end
    for _, obj in ipairs(CollectionService:GetTagged("CadenceOrb")) do
        registerInstrument(obj)
    end
    for _, obj in ipairs(CollectionService:GetTagged("Altar")) do
        registerAltar(obj)
    end
    
    -- Lắng nghe các tín hiệu thêm/bớt tag của CollectionService
    table.insert(folderConnections, CollectionService:GetInstanceAddedSignal("Gift"):Connect(registerGift))
    table.insert(folderConnections, CollectionService:GetInstanceRemovedSignal("Gift"):Connect(unregisterGift))
    
    table.insert(folderConnections, CollectionService:GetInstanceAddedSignal("CadenceOrb"):Connect(registerInstrument))
    table.insert(folderConnections, CollectionService:GetInstanceRemovedSignal("CadenceOrb"):Connect(unregisterInstrument))
    
    table.insert(folderConnections, CollectionService:GetInstanceAddedSignal("Altar"):Connect(registerAltar))
    table.insert(folderConnections, CollectionService:GetInstanceRemovedSignal("Altar"):Connect(unregisterAltar))
    
    -- 2. Fallback: Lắng nghe cấu trúc thư mục Workspace phòng trường hợp game đổi cơ chế
    local function checkAndObserve(child)
        if child.Name == "Item_Pools" then
            observeItemPools(child)
        elseif child.Name == "Enemies" then
            observeEnemies(child)
        elseif child.Name == "CurrentRooms" then
            observeCurrentRooms(child)
        else
            -- Đề phòng Gift hoặc nhạc cụ spawn trực tiếp ngoài workspace
            registerGift(child)
            registerInstrument(child)
        end
    end
    
    local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
    table.insert(folderConnections, wsConn)
    
    local wsRemovedConn = workspace.ChildRemoved:Connect(function(child)
        unregisterGift(child)
        unregisterInstrument(child)
    end)
    table.insert(folderConnections, wsRemovedConn)
    
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
        if not checkActiveState() then
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
        while not Controller.Destroyed and checkActiveState() do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    Executor.updateESPStyles(Controller, GC, hrp)
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

local utilityLoopActive = false
local function startUtilityLoop()
    if utilityLoopActive then return end
    utilityLoopActive = true
    task.spawn(function()
        while not Controller.Destroyed do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    Executor.updateMagnet(Controller, hrp)
                end)
                pcall(function()
                    Executor.updateBarriers(Controller, GC)
                end)
                
                -- Tự động kích hoạt lại Matrix Tetrahedron nếu được bật nhưng chưa hook (phòng hờ load trễ/lobby)
                if Controller.MatrixTetrahedronEnabled and MatrixTetrahedron and not MatrixTetrahedron.Hooked then
                    pcall(function()
                        local reduction = Controller.MomentumReduction or 1.0
                        MatrixTetrahedron.setReduction(reduction)
                        if reduction > 0 then
                            MatrixTetrahedron.start(Controller, GC)
                        end
                    end)
                end
            end
            task.wait(0.1)
        end
        utilityLoopActive = false
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
        stopRenderStepped()
    else
        startObservingFolders()
        updateRunningState()
        startUtilityLoop()
    end
end

-- Hàm trigger cập nhật ESP tức thì khi thay đổi cấu hình
local function triggerInstantUpdate()
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

-- Bật/tắt mô phỏng nâng cấp Matrix Tetrahedron
function Controller:SetMatrixTetrahedron(value)
    self.MatrixTetrahedronEnabled = value
    if MatrixTetrahedron then
        if value then
            local reduction = self.MomentumReduction or 1.0
            MatrixTetrahedron.setReduction(reduction)
            if reduction > 0 then
                MatrixTetrahedron.start(self, GC)
            end
        else
            MatrixTetrahedron.stop()
        end
    end
    
    if getgenv().Rayfield then
        getgenv().Rayfield:Notify({
            Title = "Simulated Upgrades",
            Content = (value and "Activated" or "Disabled") .. " Matrix Tetrahedron Simulation",
            Duration = 2
        })
    end
end

-- Tùy biến lực Momentum Reduction của Matrix Tetrahedron
function Controller:SetMomentumReduction(value)
    local val = tonumber(value) or 1.0
    if val > 1 then
        val = val / 100
    end
    val = math.clamp(val, 0, 1)
    
    self.MomentumReduction = val
    if MatrixTetrahedron then
        MatrixTetrahedron.setReduction(val)
        if self.MatrixTetrahedronEnabled and val > 0 then
            MatrixTetrahedron.start(self, GC)
        elseif val == 0 then
            MatrixTetrahedron.stop()
        end
    end
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



-- Hàm dọn dẹp tài nguyên (GC) khi tắt hoặc hủy UI
function Controller:CleanUp()
    self.Destroyed = true
    disconnectFolderObservations()
    stopRenderStepped()
    
    if MatrixTetrahedron then
        pcall(function() MatrixTetrahedron.stop() end)
    end
    
    if self.PermanentConnections then
        for _, conn in ipairs(self.PermanentConnections) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        table.clear(self.PermanentConnections)
    end
    
    GC.cleanAll()
end

-- Khởi tạo ban đầu khi nạp script
startObservingFolders()
updateRunningState()
startUtilityLoop()

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
                            local args = {...}
                            local isDefuse = false
                            local isTetrahedron = false
                            local isRadarPlayer = false
                            local isRadarAltars = false
                            local isRadarInstruments = false
                            for _, v in ipairs(args) do
                                if v == "DefuseKit" or v == "Defuse Kit" then
                                    isDefuse = true
                                elseif v == "MatrixTetrahedron" or v == "Matrix Tetrahedron" then
                                    isTetrahedron = true
                                elseif v == "RadarPlayer" then
                                    isRadarPlayer = true
                                elseif v == "RadarAltars" then
                                    isRadarAltars = true
                                elseif v == "RadarInstruments" then
                                    isRadarInstruments = true
                                end
                            end
                            if isDefuse and Controller.SimulateDefuseKit then
                                return true
                            end
                            if isTetrahedron and Controller.MatrixTetrahedronEnabled then
                                return true
                            end
                            if isRadarPlayer and Controller.RadarEnabled then
                                return true
                            end
                            if isRadarAltars and Controller.RadarEnabled and Controller.AltarESPEnabled then
                                return true
                            end
                            if isRadarInstruments and Controller.RadarEnabled and Controller.CadenceESPEnabled then
                                return true
                            end
                            return oldIsUpgradeEnabled(...)
                        end)
                    else
                        local oldIsUpgradeEnabled = UpgradeHandler.IsUpgradeEnabled
                        UpgradeHandler.IsUpgradeEnabled = function(...)
                            local args = {...}
                            local isDefuse = false
                            local isTetrahedron = false
                            local isRadarPlayer = false
                            local isRadarAltars = false
                            local isRadarInstruments = false
                            for _, v in ipairs(args) do
                                if v == "DefuseKit" or v == "Defuse Kit" then
                                    isDefuse = true
                                elseif v == "MatrixTetrahedron" or v == "Matrix Tetrahedron" then
                                    isTetrahedron = true
                                elseif v == "RadarPlayer" then
                                    isRadarPlayer = true
                                elseif v == "RadarAltars" then
                                    isRadarAltars = true
                                elseif v == "RadarInstruments" then
                                    isRadarInstruments = true
                                end
                            end
                            if isDefuse and Controller.SimulateDefuseKit then
                                return true
                            end
                            if isTetrahedron and Controller.MatrixTetrahedronEnabled then
                                return true
                            end
                            if isRadarPlayer and Controller.RadarEnabled then
                                return true
                            end
                            if isRadarAltars and Controller.RadarEnabled and Controller.AltarESPEnabled then
                                return true
                            end
                            if isRadarInstruments and Controller.RadarEnabled and Controller.CadenceESPEnabled then
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
                            local args = {...}
                            local isDefuse = false
                            local isTetrahedron = false
                            local isRadar = false
                            for _, v in ipairs(args) do
                                if v == "DefuseKit" or v == "Defuse Kit" then
                                    isDefuse = true
                                elseif v == "MatrixTetrahedron" or v == "Matrix Tetrahedron" then
                                    isTetrahedron = true
                                elseif v == "RadarPlayer" or v == "RadarAltars" or v == "RadarInstruments" then
                                    isRadar = true
                                end
                            end
                            if isDefuse and Controller.SimulateDefuseKit then
                                return Controller.DefuseKitStack or 3
                            end
                            if isTetrahedron and Controller.MatrixTetrahedronEnabled then
                                return 1
                            end
                            if isRadar and Controller.RadarEnabled then
                                return 1
                            end
                            return oldGetUpgradeStack(...)
                        end)
                    else
                        local oldGetUpgradeStack = UpgradeHandler.GetUpgradeStack
                        UpgradeHandler.GetUpgradeStack = function(...)
                            local args = {...}
                            local isDefuse = false
                            local isTetrahedron = false
                            local isRadar = false
                            for _, v in ipairs(args) do
                                if v == "DefuseKit" or v == "Defuse Kit" then
                                    isDefuse = true
                                elseif v == "MatrixTetrahedron" or v == "Matrix Tetrahedron" then
                                    isTetrahedron = true
                                elseif v == "RadarPlayer" or v == "RadarAltars" or v == "RadarInstruments" then
                                    isRadar = true
                                end
                            end
                            if isDefuse and Controller.SimulateDefuseKit then
                                return Controller.DefuseKitStack or 3
                            end
                            if isTetrahedron and Controller.MatrixTetrahedronEnabled then
                                return 1
                            end
                            if isRadar and Controller.RadarEnabled then
                                return 1
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
