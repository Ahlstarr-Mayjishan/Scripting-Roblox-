-- [[
--  Raycast Entities Types & Anti Logic
--  Vai trò: Kiểm tra và chặn các cuộc gọi RemoteEvent gây sát thương từ Springer.
-- ]]

local Logic = {}

local Players = game:GetService("Players")


function Logic.isTargetRemote(remote)
    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false
    end
    return remote.Name == "ClientEvent" or remote.Name == "ShockwaveEvent"
end

function Logic.shouldBlockRemoteCall(remote, args, controller)
    if not controller or not controller.SpringerImmune then
        return false
    end

    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false
    end

    local remoteName = remote.Name
    if remoteName ~= "ClientEvent" and remoteName ~= "ShockwaveEvent" then
        return false
    end

    -- Quét toàn bộ đối số để tìm chuỗi hành động hành vi
    local hasKill = false
    local hasDemonKill = false
    local hasDebuff = false

    for _, arg in ipairs(args) do
        if typeof(arg) == "string" then
            if arg == "Kill" then
                hasKill = true
            elseif arg == "DemonKill" then
                hasDemonKill = true
            elseif arg == "Debuff" then
                hasDebuff = true
            end
        end
    end

    if remoteName == "ClientEvent" then
        if not hasKill and not hasDemonKill then
            return false
        end
    elseif remoteName == "ShockwaveEvent" then
        if not hasDebuff then
            return false
        end
        
        -- Nếu là ShockwaveEvent, chỉ chặn khi SpringerImmunityMode là "Blatant"
        if controller.SpringerImmunityMode ~= "Blatant" then
            return false
        end
    end

    -- Xác định xem cuộc gọi này có thực sự liên quan đến Springer hay không
    local isSpringerRelated = false

    -- 1. Kiểm tra xem remote có nằm trong model Springer không
    local current = remote.Parent
    local depth = 0
    while current and current ~= workspace and current ~= game and depth < 50 do
        depth = depth + 1
        local nameSuccess, name = pcall(function() return current.Name end)
        if nameSuccess and name and string.find(name, "Springer") then
            isSpringerRelated = true
            break
        end
        local parentSuccess, parent = pcall(function() return current.Parent end)
        if parentSuccess then
            current = parent
        else
            break
        end
    end

    -- 2. Kiểm tra các đối số truyền vào xem có chứa Instance hoặc chuỗi "Springer" không
    if not isSpringerRelated then
        for _, arg in ipairs(args) do
            if typeof(arg) == "Instance" then
                local nameSuccess, name = pcall(function() return arg.Name end)
                if nameSuccess and name and string.find(name, "Springer") then
                    isSpringerRelated = true
                    break
                end
            elseif typeof(arg) == "string" then
                if string.find(arg, "Springer") then
                    isSpringerRelated = true
                    break
                end
            end
        end
    end

    -- 3. Nếu không xác định được nhưng remote là ClientEvent/ShockwaveEvent và có Springer trong game, mặc định coi là liên quan
    if not isSpringerRelated then
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                if string.find(enemy.Name, "Springer") then
                    isSpringerRelated = true
                    break
                end
            end
        end
    end

    -- 4. Dự phòng cuối cùng cho ClientEvent/ShockwaveEvent khi SpringerImmune = true
    if not isSpringerRelated then
        isSpringerRelated = true
    end

    if not isSpringerRelated then
        return false
    end

    -- Kiểm tra xem mục tiêu có phải là một người chơi khác hay không
    local targetsSomeoneElse = false
    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character

    for i = 2, #args do
        local arg = args[i]
        if typeof(arg) == "Instance" then
            if arg:IsA("Player") then
                if arg ~= LocalPlayer then
                    targetsSomeoneElse = true
                    break
                end
            elseif arg:IsA("Model") and arg:FindFirstChildOfClass("Humanoid") then
                if arg ~= char then
                    targetsSomeoneElse = true
                    break
                end
            end
        elseif typeof(arg) == "table" then
            for _, val in pairs(arg) do
                if typeof(val) == "Instance" then
                    if val:IsA("Player") then
                        if val ~= LocalPlayer then
                            targetsSomeoneElse = true
                            break
                        end
                    elseif val:IsA("Model") and val:FindFirstChildOfClass("Humanoid") then
                        if val ~= char then
                            targetsSomeoneElse = true
                            break
                        end
                    end
                end
            end
        end
        if targetsSomeoneElse then break end
    end

    -- Nếu không nhắm vào người khác, mặc định là tự tác động lên bản thân (Local Player) -> chặn
    return not targetsSomeoneElse
end

return Logic
