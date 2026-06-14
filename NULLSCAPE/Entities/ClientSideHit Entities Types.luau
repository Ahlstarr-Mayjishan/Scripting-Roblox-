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
    -- Dùng remote.ClassName để tránh kích hoạt __namecall đệ quy
    if not remote or remote.ClassName ~= "RemoteEvent" then
        return false
    end
    
    local remoteName = remote.Name
    local entities = Logic.TargetEntities[remoteName]
    if entities then
        for entityName, _ in pairs(entities) do
            -- Kiểm tra từ cha trực tiếp ngược lên tổ tiên có tên chứa entityName
            local current = remote.Parent
            while current and current ~= game do
                if string.find(current.Name, entityName) then
                    return true
                end
                current = current.Parent
            end
        end
    end
    
    return false
end

-- Kiểm tra xem RemoteEvent có thuộc diện cần chặn hay không
function Logic.shouldBlockRemoteCall(remote, args)
    -- Dùng remote.ClassName để tránh kích hoạt __namecall đệ quy
    if not remote or remote.ClassName ~= "RemoteEvent" then
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
        -- Kiểm tra tổ tiên chứa tên thực thể (hỗ trợ RemoteEvent lồng sâu trong KillPart)
        local hasEntityAncestor = false
        local current = remote.Parent
        while current and current ~= game do
            if string.find(current.Name, entityName) then
                hasEntityAncestor = true
                break
            end
            current = current.Parent
        end
        
        if hasEntityAncestor then
            -- Chỉ chặn nếu tham số đầu tiên khớp chính xác với danh sách chặn
            if blockedArgs[firstArg] then
                -- Bảo đảm chỉ chặn khi mục tiêu tác động là local player
                -- Để tránh chặn nhầm gói tin của các player khác
                local targetsLocal = false
                local Players = game:GetService("Players")
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
                    -- Không có tham số target cụ thể nào khác, mặc định tác động lên người chơi hiện tại (local player)
                    targetsLocal = true
                else
                    -- Duyệt qua các tham số tiếp theo để kiểm tra xem có chỉ định local player/character không
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
                            -- Nếu tham số là một bảng (ví dụ: {Character = game.Workspace.Noriko_Ellen}), kiểm tra các phần tử bên trong
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
