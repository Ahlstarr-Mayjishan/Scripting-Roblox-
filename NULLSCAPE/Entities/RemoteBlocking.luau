-- [[
--  NULLSCAPE - Remote Event Blocking
--  Vai trò: Chặn các cuộc gọi ClientEvent/ShockwaveEvent báo tử/gây hại từ thực thể
-- ]]

local Logic = {}

local Players = game:GetService("Players")

-- ============================================================
--  CẤU HÌNH CHẶN REMOTE EVENT
-- ============================================================
Logic.Config = {
    ["ICBM"] = {
        ControllerFlag = "ICBMImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "kill", "damage", "hit" },
        LegitKeywords = { "kill" }
    },
    ["Guardian"] = {
        ControllerFlag = "GuardianImmune",
        Remotes = { "ClientEvent", "Died" },
        Keywords = { "Kill", "Guardian" },
        LegitKeywords = { "Kill", "Guardian" }
    },
    ["ShadowGuardian"] = {
        ControllerFlag = "GuardianImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "Kill" },
        LegitKeywords = { "Kill" }
    },
    ["Springer"] = {
        ControllerFlag = "SpringerImmune",
        Remotes = { "ClientEvent", "ShockwaveEvent" },
        Keywords = { "Kill", "DemonKill", "Debuff" },
        LegitKeywords = { "Kill", "DemonKill" }
    },
    ["Bell"] = {
        ControllerFlag = "BellCurseImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "debuff" },
        LegitKeywords = { "debuff" }
    },
    ["Kolona"] = {
        ControllerFlag = "KolonaImmune",
        Remotes = { "DiedFunc" },
        Keywords = { "Kolona" },
        LegitKeywords = { "Kolona" }
    },
    ["Oblivion"] = {
        ControllerFlag = "OblivionImmune",
        Remotes = { "DiedFunc", "OblivionEvent" },
        Keywords = { "Oblivion" },
        LegitKeywords = { "Oblivion" },
        BlockEmptyCalls = true
    },
    ["ShadowBaby"] = {
        ControllerFlag = "ShadowBabyImmune",
        Remotes = { "Died" },
        Keywords = { "ShadowBaby" },
        LegitKeywords = { "ShadowBaby" }
    },
    ["Quartz"] = {
        ControllerFlag = "QuartzImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "Kill", "Combust" },
        LegitKeywords = { "Kill", "Combust" }
    },
    ["Sigil"] = {
        ControllerFlag = "SigilImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "Kill", "Combust" },
        LegitKeywords = { "Kill", "Combust" }
    },
    ["Slicer"] = {
        ControllerFlag = "SlicerImmune",
        Remotes = { "ClientEvent" },
        Keywords = {},
        LegitKeywords = {},
        BlockEmptyCalls = true
    },
    ["Voidbreaker"] = {
        ControllerFlag = "VoidbreakerImmune",
        Remotes = { "Died" },
        Keywords = { "Voidbreaker" },
        LegitKeywords = { "Voidbreaker" }
    },
    ["Razorbloom"] = {
        ControllerFlag = "RazorbloomImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "Fail" },
        LegitKeywords = { "Fail" }
    },
    ["VoidImplosion"] = {
        ControllerFlag = "VoidImplosionImmune",
        Remotes = { "Died" },
        Keywords = { "VoidImplosion" },
        LegitKeywords = { "VoidImplosion" }
    },
    ["Celestial"] = {
        ControllerFlag = "CelestialImmune",
        Remotes = { "Died" },
        Keywords = { "Celestial" },
        LegitKeywords = { "Celestial" }
    },
    ["Scrapmaw"] = {
        ControllerFlag = "ScrapmawImmune",
        Remotes = { "Died" },
        Keywords = { "Scrapmaw" },
        LegitKeywords = { "Scrapmaw" }
    },
    ["Skinwalker"] = {
        ControllerFlag = "SkinwalkerImmune",
        Remotes = { "Died" },
        Keywords = { "Skinwalker" },
        LegitKeywords = { "Skinwalker" }
    },
    ["Seamine"] = {
        ControllerFlag = "SeamineImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "Kill" },
        LegitKeywords = { "Kill" }
    },
    ["SeamineUNC"] = {
        ControllerFlag = "SeamineImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "Kill" },
        LegitKeywords = { "Kill" }
    }
}

-- Bảng tra cứu nhanh tên các RemoteEvent cần chặn (Tự động xây dựng từ cấu hình để tối ưu O(1))
Logic.TargetRemotes = {}
for _, data in pairs(Logic.Config) do
    if data.Remotes then
        for _, rName in ipairs(data.Remotes) do
            Logic.TargetRemotes[rName] = true
        end
    end
end

function Logic.shouldBlockRemoteCall(remote, args, controller)
    if not controller or controller.inLobby then
        return false
    end

    if typeof(remote) ~= "Instance" then
        return false
    end

    -- Chặn riêng biệt hiệu ứng cháy (Burn curse) của ICBM nếu tùy chọn được bật
    if remote.ClassName == "RemoteEvent"
        and remote.Name == "ClientEvent"
        and args[1] == "Combust" then
        local parent = remote.Parent
        if parent and string.find(parent.Name, "ICBM", 1, true) then
            return controller.ICBMBurnImmune == true
        end
    end

    -- Operator is entirely client-driven and reports its kill through the BroSecureMethod RemoteEvent or DiedFunc.
    if controller.OperatorImmune == true then
        if (remote.Name == "BroSecureMethod" and args[1] == 1112)
            or (remote.ClassName == "RemoteFunction" and remote.Name == "DiedFunc" and args[1] == "Operator") then
            return true
        end
    end

    if controller.KolonaImmune == true
        and remote.ClassName == "RemoteFunction"
        and remote.Name == "DiedFunc"
        and args[1] == "Kolona" then
        return true
    end

    if remote.ClassName ~= "RemoteEvent" and remote.ClassName ~= "RemoteFunction" then
        return false
    end

    local remoteName = remote.Name
    if remoteName == "Died" and args[1] == "VoidImplosion" and controller.VoidImplosionImmune == true then
        return true
    end

    if not Logic.TargetRemotes[remoteName] then
        return false
    end

    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character

    -- Helper check xem remote có thuộc Model của thực thể mục tiêu không
    local function findEntityParent(obj, targetSubName)
        local current = obj.Parent
        local depth = 0
        while current and current ~= workspace and current ~= game and depth < 50 do
            depth = depth + 1
            local nameSuccess, name = pcall(function()
                return current.Name
            end)
            if nameSuccess and name and string.find(string.lower(name), string.lower(targetSubName), 1, true) then
                return current
            end
            local parentSuccess, parent = pcall(function()
                return current.Parent
            end)
            if parentSuccess then
                current = parent
            else
                break
            end
        end
        return nil
    end

    -- Helper check xem remote hoặc args có nhắm tới người khác không
    local function isTargetsSomeoneElse()
        for i = 2, #args do
            local arg = args[i]
            if typeof(arg) == "Instance" then
                if arg:IsA("Player") and arg ~= LocalPlayer then
                    return true
                elseif arg:IsA("Model") and arg:FindFirstChildOfClass("Humanoid") and arg ~= char then
                    return true
                end
            elseif typeof(arg) == "table" then
                for _, val in pairs(arg) do
                    if typeof(val) == "Instance" then
                        if val:IsA("Player") and val ~= LocalPlayer then
                            return true
                        elseif val:IsA("Model") and val:FindFirstChildOfClass("Humanoid") and val ~= char then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- Quét qua các cấu hình chặn remote
    for entityName, config in pairs(Logic.Config) do
        local controllerFlag = config.ControllerFlag
        if controller[controllerFlag] == true then
            local isMatchingRemote = false
            for _, rName in ipairs(config.Remotes) do
                if rName == remoteName then
                    isMatchingRemote = true
                    break
                end
            end

            if isMatchingRemote then
                local hasKeyword = false
                local isBlatant = (controller.SpringerImmunityMode == "Blatant")
                local keywordsList = isBlatant and config.Keywords or config.LegitKeywords

                if config.BlockEmptyCalls and #args == 0 then
                    hasKeyword = true
                else
                    for _, arg in ipairs(args) do
                        if typeof(arg) == "string" then
                            local lowerArg = string.lower(arg)
                            for _, kw in ipairs(keywordsList) do
                                if string.lower(kw) == lowerArg or string.find(lowerArg, string.lower(kw), 1, true) then
                                    hasKeyword = true
                                    break
                                end
                            end
                        end
                        if hasKeyword then break end
                    end
                end

                if hasKeyword then
                    local isRelated = false
                    if findEntityParent(remote, entityName) then
                        isRelated = true
                    else
                        for _, arg in ipairs(args) do
                            if (typeof(arg) == "Instance" and string.find(string.lower(arg.Name), string.lower(entityName), 1, true))
                                or (typeof(arg) == "string" and string.find(string.lower(arg), string.lower(entityName), 1, true)) then
                                isRelated = true
                                break
                            end
                        end
                    end

                    if isRelated and not isTargetsSomeoneElse() then
                        return true
                    end
                end
            end
        end
    end

    return false
end

return Logic
