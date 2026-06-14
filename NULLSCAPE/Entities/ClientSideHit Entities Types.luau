-- [[
--  NULLSCAPE - Client-Side Hit (RemoteEvent) Entities Types
--  Vai trò: Định nghĩa danh sách các thực thể gây sát thương thông qua cơ chế
--  báo tử client-side (RemoteEvent), cùng danh sách các event và tham số cần chặn.
-- ]]

local Logic = {}

-- Danh sách các thực thể gây sát thương client-side và cấu hình chặn của chúng
Logic.TargetEntities = {
    ["ClientEvent"] = {
        ["ICBM"] = {
            ["Kill"] = true,
            ["Combust"] = true
        },
        ["Springer"] = {
            ["Kill"] = true,
            ["DemonKill"] = true
        }
    },
    ["ShockwaveEvent"] = {
        ["Springer"] = {
            ["Debuff"] = true
        }
    }
}

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

-- Kiểm tra nhanh xem RemoteEvent có khớp với cấu hình không (Pre-filter để tối ưu hiệu năng)
function Logic.isTargetRemote(remote)
    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false
    end
    
    local remoteName = remote.Name
    if Logic.TargetEntities[remoteName] then
        return true
    end
    
    return false
end

local Players = game:GetService("Players")

-- Kiểm tra xem RemoteEvent có thuộc diện cần chặn hay không
function Logic.shouldBlockRemoteCall(remote, args)
    if typeof(remote) ~= "Instance" or remote.ClassName ~= "RemoteEvent" then
        return false, nil
    end
    
    local firstArg = args[1]
    if typeof(firstArg) ~= "string" then
        return false, nil
    end
    
    local remoteName = remote.Name
    local entities = Logic.TargetEntities[remoteName]
    if not entities then
        return false, nil
    end
    
    for entityName, blockedArgs in pairs(entities) do
        -- Chỉ chặn nếu tham số đầu tiên khớp chính xác với danh sách chặn
        if blockedArgs[firstArg] then
            local isEntityRelated = false
            
            -- 1. Kiểm tra tổ tiên chứa tên thực thể (giới hạn Workspace, tối đa 50 cấp để tránh treo/crash client)
            local current = remote.Parent
            local depth = 0
            while current and current ~= workspace and current ~= game and depth < 50 do
                depth = depth + 1
                local nameSuccess, name = pcall(function() return current.Name end)
                if nameSuccess and name and string.find(name, entityName) then
                    isEntityRelated = true
                    break
                end
                local parentSuccess, parent = pcall(function() return current.Parent end)
                if parentSuccess then
                    current = parent
                else
                    break
                end
            end
            
            -- 2. Fallback 1: Kiểm tra các tham số truyền vào có chứa Instance của thực thể hoặc tên thực thể không
            if not isEntityRelated then
                for _, arg in ipairs(args) do
                    if typeof(arg) == "Instance" then
                        local nameSuccess, name = pcall(function() return arg.Name end)
                        if nameSuccess and name and string.find(name, entityName) then
                            isEntityRelated = true
                            break
                        end
                    elseif typeof(arg) == "string" then
                        if string.find(arg, entityName) then
                            isEntityRelated = true
                            break
                        end
                    end
                end
            end
            
            -- 3. Fallback 2: Nếu tên remote là "ClientEvent", mặc định khớp với bất kỳ ICBM/Springer nào
            -- vì ClientEvent thường nằm ở ReplicatedStorage và dùng chung cho toàn bộ client-side hit
            if not isEntityRelated and remoteName == "ClientEvent" then
                isEntityRelated = true
            end
            
            if isEntityRelated then
                -- Bảo đảm chỉ chặn khi mục tiêu tác động là local player
                local targetsLocal = false
                local LocalPlayer = Players.LocalPlayer
                local char = LocalPlayer and LocalPlayer.Character
                
                -- Đếm xem có tham số target cụ thể nào khác không
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
                
                if targetsLocal then
                    return true, entityName
                end
            end
        end
    end
    
    return false, nil
end

return Logic

