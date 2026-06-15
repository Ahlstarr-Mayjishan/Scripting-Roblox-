-- [[
--  NULLSCAPE - Entities Controller
--  Vai trò: Đảm nhiệm việc quan sát hiệu năng, phân tích tài nguyên và đưa ra các quyết định điều phối:
--  - Phát hiện trạng thái sảnh chờ/trận đấu (khi inLobby = false sẽ kích hoạt gọi quét scan).
--  - Giám sát trạng thái hoạt động của script, điều phối chế độ ngủ đông (hibernating) tối ưu CPU.
--  - Gửi kết nối đăng ký qua GC và phát lệnh dọn dẹp giải phóng tài nguyên.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Executor = getgenv().loadModule("NULLSCAPE/Entities/executor.luau")
local TouchInterest = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest.luau")
local HuskEvasion = getgenv().loadModule("NULLSCAPE/Entities/HuskEvasion.luau")
local RemoteBlocking = getgenv().loadModule("NULLSCAPE/Entities/RemoteBlocking.luau")
local GC = getgenv().loadModule("NULLSCAPE/Entities/GC.luau")

local Controller = {
    -- Trạng thái bật/tắt miễn nhiễm cho từng thực thể
    BabyImmune = false,
    BellImmune = false,
    MartImmune = false,
    ICBMImmune = false,
    SpringerImmune = false,
    SkinwalkerImmune = false,
    SpringerImmunityMode = "Legit",
    Destroyed = false,
    
    EnemiesFolder = nil,
    PermanentConnections = {},
    StartSkinwalkerEvasion = nil
}
GC.Controller = Controller

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

local function debugPrint(...)
    warn("[DEBUG NULLSCAPE Controller]", ...)
end

local inLobby = not isInMatch()       -- Đang ở sảnh chờ/lựa chọn (Khởi tạo ban đầu)
local hasInRoundValue = false
local folderConnections = {}          -- key: folder -> value: list of connections
local workspaceConnections = {}       -- list of workspace-level connections

-- Ngắt các kết nối quan sát thư mục và workspace
local function disconnectFolderObservations()
    for _, conn in ipairs(workspaceConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    table.clear(workspaceConnections)

    for folder, conns in pairs(folderConnections) do
        for _, conn in ipairs(conns) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
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
    debugPrint("SetImmunity called for:", entityName, "| value:", value)
    if entityName == "Baby" then
        self.BabyImmune = value
    elseif entityName == "Bell" then
        self.BellImmune = value
    elseif entityName == "Mart" then
        self.MartImmune = value
    elseif entityName == "ICBM" then
        self.ICBMImmune = value
    elseif entityName == "Skinwalker" then
        self.SkinwalkerImmune = value
        if value then
            Controller:StartSkinwalkerEvasion()
        end
    elseif entityName == "Springer" then
        self.SpringerImmune = value
        
        -- Thông báo cho Accessibility controller cập nhật lại trạng thái Auto Jump
        local accessibilityController = getgenv().loadModule("NULLSCAPE/Accessibility/controller.luau")
        if accessibilityController and accessibilityController.updateSpringerAutoJumpState then
            pcall(function()
                accessibilityController:updateSpringerAutoJumpState()
            end)
        end
    end

    -- Áp dụng thay đổi tức thời cho thực thể đã tồn tại trong workspace
    if value then
        local function applyImmunityToChild(child)
            if not (child:IsA("Model") or child:IsA("BasePart")) then return end

            -- Husk / Skinwalker dùng module HuskEvasion mới
            if entityName == "Skinwalker" then
                local isHusk = (string.find(child.Name, "Skinwalker") or string.find(child.Name, "Husk")) and child.Name ~= "Skinwalkers"
                if isHusk then
                    HuskEvasion.enableHuskImmunity(GC, child)
                end
                return
            end

            -- Baby / Bell / Mart dùng module TouchInterest Types
            local isTarget = string.find(string.lower(child.Name), string.lower(entityName))
            debugPrint("applyImmunityToChild check for target:", child.Name, "| isTarget:", isTarget ~= nil)
            if isTarget then
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

        if self.EnemiesFolder then
            for _, child in ipairs(self.EnemiesFolder:GetChildren()) do
                applyImmunityToChild(child)
            end
        end
        local skinwalkersFolder = workspace:FindFirstChild("Skinwalkers")
        if skinwalkersFolder and skinwalkersFolder:IsA("Folder") then
            for _, child in ipairs(skinwalkersFolder:GetChildren()) do
                applyImmunityToChild(child)
            end
        end
    else
        if entityName == "Baby" or entityName == "Bell" or entityName == "Mart" then
            Executor.disableImmunityForType(GC, entityName)
        elseif entityName == "Skinwalker" then
            HuskEvasion.disableHuskImmunity(GC)
        end
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
    
    -- Thông báo cho Accessibility controller cập nhật lại trạng thái Auto Jump
    local accessibilityController = getgenv().loadModule("NULLSCAPE/Accessibility/controller.luau")
    if accessibilityController and accessibilityController.updateSpringerAutoJumpState then
        pcall(function()
            accessibilityController:updateSpringerAutoJumpState()
        end)
    end
    
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

local skinwalkerThread = nil
function Controller:StartSkinwalkerEvasion()
    if skinwalkerThread then return end
    skinwalkerThread = task.spawn(function()
        while self.SkinwalkerImmune and not self.Destroyed do
            task.wait(0.01) -- Chạy cực nhanh để dịch chuyển tránh chạm
            local LocalPlayer = game:GetService("Players").LocalPlayer
            local char = LocalPlayer and LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local function checkAndEvade(enemy)
                    if string.find(enemy.Name, "Skinwalker") or string.find(enemy.Name, "Husk") then
                        local head = enemy:FindFirstChild("head") or enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildOfClass("BasePart")
                        if head then
                            local distance = (root.Position - head.Position).Magnitude
                            if distance < 9 then
                                -- Đẩy lùi player ra xa để tránh va chạm vật lý/server-side
                                local direction = (root.Position - head.Position)
                                if direction.Magnitude == 0 then
                                    direction = Vector3.new(0, 0, 1)
                                else
                                    direction = direction.Unit
                                end
                                root.CFrame = root.CFrame + direction * 3
                            end
                        end
                    end
                end
                
                local enemies = workspace:FindFirstChild("Enemies")
                if enemies then
                    for _, enemy in ipairs(enemies:GetChildren()) do
                        checkAndEvade(enemy)
                    end
                end
                local skinwalkersFolder = workspace:FindFirstChild("Skinwalkers")
                if skinwalkersFolder then
                    for _, enemy in ipairs(skinwalkersFolder:GetChildren()) do
                        checkAndEvade(enemy)
                    end
                end
            end
        end
        skinwalkerThread = nil
    end)
end



-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function processEntity(enemy)
    if not enemy or not (enemy:IsA("Model") or enemy:IsA("BasePart")) or enemy.Name == "Skinwalkers" then return end

    -- Tránh việc đăng ký nhiều lần trùng lặp cho cùng một thực thể
    if GC.EntityConnections and GC.EntityConnections[enemy] then return end

    -- Hàm xử lý chính khi kiểm tra tên thực thể
    local function checkAndApply()
        if not enemy or not enemy.Parent then return end
        local name = enemy.Name
        debugPrint("processEntity checkAndApply for:", name)
        
        -- ── Thực thể dùng nguyên lý Xóa TouchInterest (Baby, Bell, Mart,...) ──
        if TouchInterest.isTargetEntity(name) then
            local checkFunc = TouchInterest.getImmunityCheck(name, Controller)
            debugPrint("checkAndApply TargetEntity:", name, "| checkFunc found:", checkFunc ~= nil)
            if checkFunc then
                debugPrint("checkAndApply TargetEntity:", name, "| checkFunc value:", checkFunc())
            end
            if checkFunc and checkFunc() then
                Executor.enableImmunity(GC, enemy)
            end
        end

        -- ── Husk / Skinwalker (đổi tên + CanTouch) ─────────────────────────────
        if HuskEvasion.isHuskEntity(name) or
           (enemy:GetAttribute("OriginalName") and HuskEvasion.isHuskEntity(enemy:GetAttribute("OriginalName"))) then
            if Controller.SkinwalkerImmune then
                HuskEvasion.enableHuskImmunity(GC, enemy)
            end
        end
    end

    -- Đăng ký sự kiện lắng nghe đổi tên của thực thể (Phòng hờ game đổi tên trễ sau khi spawn)
    local nameConn = enemy:GetPropertyChangedSignal("Name"):Connect(checkAndApply)
    GC.registerEntityConnection(enemy, nameConn)

    -- Chạy kiểm tra ngay lập tức
    checkAndApply()

    -- Lắng nghe bộ phận mới được thêm vào cho Husk/Skinwalker
    local descConn = enemy.DescendantAdded:Connect(function(part)
        local name = enemy.Name
        if HuskEvasion.isHuskEntity(name) or
           (enemy:GetAttribute("OriginalName") and HuskEvasion.isHuskEntity(enemy:GetAttribute("OriginalName"))) then
            if Controller.SkinwalkerImmune then
                HuskEvasion.onHuskDescendantAdded(GC, enemy, part)
            end
        end
    end)
    GC.registerEntityConnection(enemy, descConn)

    -- Xử lý vô hiệu hóa shockwave cho Springer (Springer không có TouchInterest, chỉ có ClientEvent và ShockwaveEvent)
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

-- Hàm dọn dẹp tài nguyên riêng cho một thư mục cụ thể khi nó bị xóa khỏi Workspace
function Controller:CleanUpFolder(folder)
    if not folder then return end

    -- 1. Dọn dẹp các thực thể đang tồn tại trong thư mục này
    for _, child in ipairs(folder:GetChildren()) do
        removeEntity(child)
    end

    -- 2. Ngắt kết nối của riêng thư mục này
    local conns = folderConnections[folder]
    if conns then
        for _, conn in ipairs(conns) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        folderConnections[folder] = nil
    end

    -- 3. Cập nhật biến tham chiếu EnemiesFolder nếu cần
    if self.EnemiesFolder == folder then
        self.EnemiesFolder = nil
    end
end

-- Thiết lập quan sát thư mục Enemies trong Workspace
function Controller:ObserveFolder(folder)
    debugPrint("ObserveFolder called for:", folder:GetFullName())
    -- Tránh đăng ký nhiều lần cho cùng một thư mục
    if folderConnections[folder] then 
        debugPrint("Folder already observed, skipping:", folder.Name)
        return 
    end

    if folder.Name == "Enemies" then
        self.EnemiesFolder = folder
    end

    local conns = {}

    -- 1. Lắng nghe khi thực thể mới xuất hiện
    local childAddedConn = folder.ChildAdded:Connect(function(child)
        debugPrint("ObserveFolder: ChildAdded in:", folder.Name, "| Child Name:", child.Name)
        processEntity(child)
    end)
    table.insert(conns, childAddedConn)

    -- 2. Lắng nghe khi thực thể bị xóa khỏi game
    local childRemovedConn = folder.ChildRemoved:Connect(function(child)
        removeEntity(child)
    end)
    table.insert(conns, childRemovedConn)

    -- 3. Xử lý các thực thể đã có sẵn trong thư mục
    debugPrint("ObserveFolder: Existing children in:", folder.Name, "| count:", #folder:GetChildren())
    for _, child in ipairs(folder:GetChildren()) do
        debugPrint("ObserveFolder: Processing existing child:", child.Name)
        processEntity(child)
    end

    -- 4. Cơ chế tự động GC khi thư mục bị xóa/hủy khỏi Workspace
    local destroyingConn = folder.AncestryChanged:Connect(function(_, parent)
        if not parent then
            -- Thư mục đã bị xóa hoàn toàn khỏi trò chơi
            self:CleanUpFolder(folder)
        end
    end)
    table.insert(conns, destroyingConn)

    folderConnections[folder] = conns
end

-- Quét tìm thư mục Enemies và Skinwalkers trong Workspace và lắng nghe sự thay đổi
local function startObservingFolders()
    debugPrint("startObservingFolders called")
    disconnectFolderObservations()
    
    local function checkAndObserve(child)
        if Controller.Destroyed then return end
        if (child.Name == "Enemies" or child.Name == "Skinwalkers") and child:IsA("Folder") then
            Controller:ObserveFolder(child)
        end
    end

    local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
    table.insert(workspaceConnections, wsConn)
    
    -- Xử lý các folder có sẵn
    for _, child in ipairs(workspace:GetChildren()) do
        if (child.Name == "Enemies" or child.Name == "Skinwalkers") and child:IsA("Folder") then
            Controller:ObserveFolder(child)
        end
    end
end

-- Hàm cập nhật trạng thái sảnh chờ và tự động dọn dẹp visual/connections
local function setInLobby(val)
    if inLobby == val then return end
    inLobby = val
    
    pcall(function()
        TouchInterest.setInLobbyState(val)
    end)

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

-- Hook để chặn RemoteEvent báo tử của thực thể Client-side (như ICBM và Springer) một cách an toàn
local hookInitialized = false
local function initializeICBMHook()
    if hookInitialized then return end
    hookInitialized = true
    
    -- Xây dựng bảng tra cứu nhanh O(1) tên các RemoteEvent cần chặn
    local TargetRemoteNames = {
        ["ClientEvent"] = true,
        ["ShockwaveEvent"] = true
    }

    local function handleRemoteCall(self, ...)
        local args = {...}
        
        -- Logger gỡ lỗi an toàn (đã tắt theo yêu cầu)
        --[[
        pcall(function()
            local remoteName = self.Name
            local firstArg = args[1]
            if string.find(remoteName, "Client") or string.find(remoteName, "Kill") or string.find(remoteName, "Damage") or string.find(remoteName, "Hit") or (typeof(firstArg) == "string" and (string.find(firstArg, "Kill") or string.find(firstArg, "Demon") or string.find(firstArg, "Combust"))) then
                print(string.format("[DEBUG Remote] Remote Fired: %s | Arg1: %s", tostring(remoteName), tostring(firstArg)))
                for i = 2, #args do
                    print(string.format("   Arg [%d]: %s (%s)", i, tostring(args[i]), typeof(args[i])))
                end
            end
        end)
        ]]

        -- Kiểm tra nhanh tên remote trước (O(1) lookup)
        if not TargetRemoteNames[self.Name] then
            return false
        end
        
        -- Chạy logic chặn RemoteEvent thống nhất từ RemoteBlocking.luau
        local block = RemoteBlocking.shouldBlockRemoteCall(self, args, Controller)
        if block then
            return true
        end
        
        return false
    end

    -- 1. Hook __namecall (Phương pháp chuẩn và mạnh nhất cho các cuộc gọi dạng Remote:FireServer(...) hoặc Remote:InvokeServer(...))
    local namecallSuccess = false
    if typeof(hookmetamethod) == "function" then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local isRemote = false
                local isRemoteFunction = false
                
                if method == "FireServer" or method == "InvokeServer" then
                    pcall(function()
                        if typeof(self) == "Instance" then
                            if self.ClassName == "RemoteEvent" then
                                isRemote = true
                            elseif self.ClassName == "RemoteFunction" then
                                isRemote = true
                                isRemoteFunction = true
                            end
                        end
                    end)
                end
                
                if isRemote then
                    local success, shouldBlock = pcall(handleRemoteCall, self, ...)
                    if not success then
                        warn("[NULLSCAPE Hook Error] handleRemoteCall failed: " .. tostring(shouldBlock))
                    elseif shouldBlock then
                        if isRemoteFunction then
                            return nil -- Chặn đứng InvokeServer và trả về nil
                        end
                        return -- Chặn đứng FireServer
                    end
                end
                return oldNamecall(self, ...)
            end)
            namecallSuccess = true
        end)
    end

    -- 2. Hook FireServer/InvokeServer prototype (Dự phòng)
    local prototypeSuccess = false
    if typeof(hookfunction) == "function" then
        pcall(function()
            local remoteProto = Instance.new("RemoteEvent")
            local oldFireServer
            oldFireServer = hookfunction(remoteProto.FireServer, function(self, ...)
                local success, shouldBlock = pcall(handleRemoteCall, self, ...)
                if not success then
                    warn("[NULLSCAPE Hook Error] FireServer hook failed: " .. tostring(shouldBlock))
                elseif shouldBlock then
                    return -- Chặn đứng cuộc gọi
                end
                return oldFireServer(self, ...)
            end)
            
            local funcProto = Instance.new("RemoteFunction")
            local oldInvokeServer
            oldInvokeServer = hookfunction(funcProto.InvokeServer, function(self, ...)
                local success, shouldBlock = pcall(handleRemoteCall, self, ...)
                if not success then
                    warn("[NULLSCAPE Hook Error] InvokeServer hook failed: " .. tostring(shouldBlock))
                elseif shouldBlock then
                    return nil -- Chặn đứng cuộc gọi và trả về nil
                end
                return oldInvokeServer(self, ...)
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
