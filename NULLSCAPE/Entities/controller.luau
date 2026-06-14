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
local ICBMEntitiesTypes = getgenv().loadModule("NULLSCAPE/Entities/Magnitude Types.luau")
local SpringerEntitiesTypes = getgenv().loadModule("NULLSCAPE/Entities/Raycast - Magnitude.luau")
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
    StartSkinwalkerEvasion = nil :: any
}

local skinwalkerNear = false

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
            local isTarget = false
            if entityName == "Skinwalker" then
                isTarget = (string.find(child.Name, "Skinwalker") or string.find(child.Name, "Husk")) and child.Name ~= "Skinwalkers"
            else
                isTarget = child.Name == entityName or string.find(child.Name, entityName)
            end
            
            if isTarget and child:IsA("Model") then
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
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name ~= "Enemies" and child.Name ~= "Skinwalkers" then
                applyImmunityToChild(child)
            end
        end
    else
        if entityName == "Baby" or entityName == "Bell" or entityName == "Mart" or entityName == "Skinwalker" then
            Executor.disableImmunityForType(GC, entityName)
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
            if not root then continue end
            
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
            for _, child in ipairs(workspace:GetChildren()) do
                checkAndEvade(child)
            end
        end
        skinwalkerThread = nil
    end)
end

-- Vòng lặp quét phát hiện cận cảnh Skinwalker phục vụ gỡ lỗi logs
task.spawn(function()
    while not Controller.Destroyed do
        task.wait(0.1)
        local LocalPlayer = game:GetService("Players").LocalPlayer
        local char = LocalPlayer and LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            skinwalkerNear = false
            continue
        end
        
        local foundNear = false
        local function checkNear(enemy)
            if string.find(enemy.Name, "Skinwalker") or string.find(enemy.Name, "Husk") then
                local head = enemy:FindFirstChild("head") or enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildOfClass("BasePart")
                if head then
                    local distance = (root.Position - head.Position).Magnitude
                    if distance < 25 then
                        foundNear = true
                    end
                end
            end
        end
        
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                checkNear(enemy)
                if foundNear then break end
            end
        end
        
        if not foundNear then
            for _, child in ipairs(workspace:GetChildren()) do
                checkNear(child)
                if foundNear then break end
            end
        end
        
        skinwalkerNear = foundNear
    end
end)

-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function processEntity(enemy)
    if not enemy or not enemy:IsA("Model") or enemy.Name == "Skinwalkers" then return end
    
    local name = enemy.Name
    if Logic.isTargetEntity(name) then
        local checkFunc = Logic.getImmunityCheck(name, Controller)
        if checkFunc and checkFunc() then
            Executor.enableImmunity(GC, enemy)
        end

        -- Lắng nghe các bộ phận mới được thêm vào thực thể sau này (tránh sót hitbox khi đang replicate)
        local descConn = enemy.DescendantAdded:Connect(function(part)
            local checkFunc = Logic.getImmunityCheck(enemy.Name, Controller)
            if checkFunc and checkFunc() then
                local isSkinwalker = string.find(enemy.Name, "Skinwalker") or string.find(enemy.Name, "Husk") or (enemy:GetAttribute("OriginalName") and (string.find(enemy:GetAttribute("OriginalName"), "Skinwalker") or string.find(enemy:GetAttribute("OriginalName"), "Husk")))
                
                if isSkinwalker then
                    if part:IsA("BasePart") then
                        if not GC.SavedPartsData[part] then
                            GC.SavedPartsData[part] = {
                                touch = nil,
                                originalCanTouch = part.CanTouch,
                                originalName = part.Name,
                                enemyName = enemy:GetAttribute("OriginalName") or enemy.Name
                            }
                        end
                        pcall(function() part.CanTouch = false end)
                        if part.Name == "head" then
                            pcall(function() part.Name = "SafeHead" end)
                        end
                    elseif part:IsA("Decal") or part:IsA("Texture") then
                        if part.Name == "sprite" then
                            if not GC.SavedPartsData[part] then
                                GC.SavedPartsData[part] = {
                                    originalName = part.Name,
                                    enemyName = enemy:GetAttribute("OriginalName") or enemy.Name
                                }
                            end
                            pcall(function() part.Name = "SafeSprite" end)
                        end
                    end
                else
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
                            pcall(function() parentPart.CanTouch = false end)
                        end
                    end
                end
            end
        end)
        GC.registerEntityConnection(enemy, descConn)
    end

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

-- Quét tìm thư mục Enemies và Skinwalkers trong Workspace và lắng nghe sự thay đổi
local function startObservingFolders()
    disconnectFolderObservations()
    
    local function checkAndObserve(child)
        if Controller.Destroyed then return end
        if (child.Name == "Enemies" or child.Name == "Skinwalkers") and child:IsA("Folder") then
            Controller:ObserveFolder(child)
        else
            -- Đề phòng thực thể spawn trực tiếp ở workspace
            processEntity(child)
        end
    end

    local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
    table.insert(folderConnections, wsConn)
    
    local initialFolder = workspace:FindFirstChild("Enemies")
    if initialFolder and initialFolder:IsA("Folder") then
        Controller:ObserveFolder(initialFolder)
    end
    
    local skinwalkersFolder = workspace:FindFirstChild("Skinwalkers")
    if skinwalkersFolder and skinwalkersFolder:IsA("Folder") then
        Controller:ObserveFolder(skinwalkersFolder)
    end

    -- Xử lý các con có sẵn ở workspace
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name ~= "Enemies" and child.Name ~= "Skinwalkers" then
            processEntity(child)
        end
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
        
        -- Logger gỡ lỗi an toàn (không gọi method nào trên self để tránh đệ quy __namecall)
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

        -- Kiểm tra nhanh tên remote trước (O(1) lookup)
        if not TargetRemoteNames[self.Name] then
            return false
        end
        
        -- 1. Chạy logic chống ICBM
        local blockICBM = ICBMEntitiesTypes.shouldBlockRemoteCall(self, args, Controller)
        if blockICBM then
            return true
        end
        
        -- 2. Chạy logic chống Springer
        local blockSpringer = SpringerEntitiesTypes.shouldBlockRemoteCall(self, args, Controller)
        if blockSpringer then
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
