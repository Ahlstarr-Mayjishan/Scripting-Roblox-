-- [[
--  NULLSCAPE - ICBM Entities Types & Anti Logic
--  Vai trò: Kiểm tra và chặn các cuộc gọi RemoteEvent gây sát thương từ ICBM.
-- ]]

local Logic = {}

local Players = game:GetService("Players")

-- Hàm bổ trợ duyệt cây cha-con tránh gọi method namecall (chống đệ quy vô hạn trong __namecall hook)
local function isDescendantOrSelf(child, parent)
    if not child or not parent then return false end
    local current = child
    while current do
        if current == parent then
            return true
        end
        current = current.Parent
    end
    return false
end

function Logic.isTargetRemote(remote)
    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false
    end
    return remote.Name == "ClientEvent"
end

function Logic.shouldBlockRemoteCall(remote, args, controller)
    if not controller or not controller.ICBMImmune then
        return false
    end

    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false
    end

    if remote.Name ~= "ClientEvent" then
        return false
    end

    local firstArg = args[1]
    if typeof(firstArg) ~= "string" then
        return false
    end

    -- ICBM sử dụng tham số "Kill" hoặc "Combust" để báo tử client-side
    if firstArg ~= "Kill" and firstArg ~= "Combust" then
        return false
    end

    -- Xác định xem cuộc gọi này có thực sự liên quan đến ICBM hay không
    local isICBMRelated = false

    -- 1. Kiểm tra xem remote có nằm trong model ICBM không
    local current = remote.Parent
    local depth = 0
    while current and current ~= workspace and current ~= game and depth < 50 do
        depth = depth + 1
        local nameSuccess, name = pcall(function() return current.Name end)
        if nameSuccess and name and string.find(name, "ICBM") then
            isICBMRelated = true
            break
        end
        local parentSuccess, parent = pcall(function() return current.Parent end)
        if parentSuccess then
            current = parent
        else
            break
        end
    end

    -- 2. Kiểm tra các đối số truyền vào xem có chứa Instance hoặc chuỗi "ICBM" không
    if not isICBMRelated then
        for _, arg in ipairs(args) do
            if typeof(arg) == "Instance" then
                local nameSuccess, name = pcall(function() return arg.Name end)
                if nameSuccess and name and string.find(name, "ICBM") then
                    isICBMRelated = true
                    break
                end
            elseif typeof(arg) == "string" then
                if string.find(arg, "ICBM") then
                    isICBMRelated = true
                    break
                end
            end
        end
    end

    -- 3. Nếu không xác định được nhưng remote là ClientEvent và có ICBM trong game, mặc định coi là liên quan
    if not isICBMRelated then
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                if string.find(enemy.Name, "ICBM") then
                    isICBMRelated = true
                    break
                end
            end
        end
    end

    -- 4. Dự phòng cuối cùng cho ClientEvent khi ICBMImmune = true
    if not isICBMRelated then
        isICBMRelated = true
    end

    if not isICBMRelated then
        return false
    end

    -- Kiểm tra xem mục tiêu có phải local player không
    local targetsLocal = false
    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character

    local hasTarget = false
    for i = 2, #args do
        if args[i] ~= nil then
            hasTarget = true
            break
        end
    end

    if not hasTarget then
        targetsLocal = true
    else
        for i = 2, #args do
            local arg = args[i]
            if arg == LocalPlayer or arg == char then
                targetsLocal = true
                break
            end
            if typeof(arg) == "Instance" then
                if char and isDescendantOrSelf(arg, char) then
                    targetsLocal = true
                    break
                end
            elseif typeof(arg) == "table" then
                for _, val in pairs(arg) do
                    if val == LocalPlayer or val == char then
                        targetsLocal = true
                        break
                    end
                    if typeof(val) == "Instance" and char and isDescendantOrSelf(val, char) then
                        targetsLocal = true
                        break
                    end
                end
            end
            if targetsLocal then break end
        end
    end

    return targetsLocal
end

return Logic
