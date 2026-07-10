-- [[
--  NULLSCAPE - Remote Event Blocking
--  Vai trò: Chặn các cuộc gọi ClientEvent/ShockwaveEvent báo tử/gây hại từ thực thể
-- ]]

local Logic = {}

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

-- ============================================================
--  CẤU HÌNH CHẶN REMOTE EVENT
-- ============================================================
Logic.Config = {
    ["Baby"] = {
        ControllerFlag = "BabyImmune",
        Remotes = { "Died" },
        Keywords = { "Baby" },
        LegitKeywords = { "Baby" }
    },
    ["Mart"] = {
        ControllerFlag = "MartImmune",
        Remotes = { "ClientEvent" },
        Keywords = {},
        LegitKeywords = {},
        BlockEmptyCalls = true
    },
    ["ICBM"] = {
        ControllerFlag = "ICBMImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "kill", "damage", "hit", "combust" },
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
        Remotes = { "ClientEvent", "ShockwaveEvent", "Died" },
        Keywords = { "Springer", "Kill", "DemonKill", "Debuff" },
        LegitKeywords = { "Springer", "Kill", "DemonKill" }
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
        Remotes = { "ClientEvent", "Died" },
        Keywords = { "Kill", "Celestial" },
        LegitKeywords = { "Kill", "Celestial" }
    },
    ["RealityBreak"] = {
        ControllerFlag = "CelestialImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "Kill" },
        LegitKeywords = { "Kill" }
    },
    ["RealityBreaker"] = {
        ControllerFlag = "CelestialImmune",
        Remotes = { "ClientEvent" },
        Keywords = { "Kill" },
        LegitKeywords = { "Kill" }
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

local CELESTIAL_CLIENT_BLOCKLIST = {
    Kill = true,
}

local function hasAncestorName(instance, targetSubName)
    local current = instance and instance.Parent
    local depth = 0
    local lowerTarget = string.lower(tostring(targetSubName or ""))

    while current and current ~= workspace and current ~= game and depth < 50 do
        depth = depth + 1
        local lowerName = string.lower(tostring(current.Name or ""))
        if string.find(lowerName, lowerTarget, 1, true) then
            return true
        end
        current = current.Parent
    end

    return false
end

local function isCelestialKillReport(remote, args)
    if typeof(remote) ~= "Instance" then
        return false
    end

    local remoteName = remote.Name
    local firstArg = tostring(args and args[1] or "")

    if remoteName == "Died" then
        return firstArg == "Celestial"
            or firstArg == "RealityBreak"
            or firstArg == "Reality Break"
            or firstArg == "RealityBreaker"
    end

    if remoteName ~= "ClientEvent" or not CELESTIAL_CLIENT_BLOCKLIST[firstArg] then
        return false
    end

    return hasAncestorName(remote, "Celestial")
        or hasAncestorName(remote, "Reality")
end

local function localPlayerHasStatus(statusName)
    local LocalPlayer = Players.LocalPlayer
    local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
    local handlerModule = clientModules and clientModules:FindFirstChild("StatusEffectHandler")
    if not (LocalPlayer and handlerModule and handlerModule:IsA("ModuleScript")) then
        return false
    end

    local success, StatusEffectHandler = pcall(require, handlerModule)
    if not (success and typeof(StatusEffectHandler) == "table" and typeof(StatusEffectHandler.HasStatus) == "function") then
        return false
    end

    local okWithPlayer, hasWithPlayer = pcall(StatusEffectHandler.HasStatus, LocalPlayer, statusName)
    if okWithPlayer and hasWithPlayer == true then
        return true
    end

    local okStatusOnly, hasStatusOnly = pcall(StatusEffectHandler.HasStatus, statusName)
    return okStatusOnly and hasStatusOnly == true
end

local function isICBMClientReport(remote, args)
    if not (
        remote
        and remote.ClassName == "RemoteEvent"
        and remote.Name == "ClientEvent"
        and (args[1] == "Kill" or args[1] == "Combust")
    ) then
        return false
    end

    local parent = remote.Parent
    return parent and string.find(parent.Name, "ICBM", 1, true) ~= nil
end
-- Helper check xem remote có thuộc Model của thực thể mục tiêu không
local function findEntityParent(obj, targetSubName)
    local current = obj.Parent
    local depth = 0
    local lowerTarget = string.lower(targetSubName)
    while current and current ~= workspace and current ~= game and depth < 50 do
        depth = depth + 1
        local name = current.Name
        if name and string.find(string.lower(name), lowerTarget, 1, true) then
            return current
        end
        current = current.Parent
    end
    return nil
end

-- Helper check xem remote hoặc args có nhắm tới người khác không
local function isTargetsSomeoneElse(args, localPlayer, char)
    for i = 2, #args do
        local arg = args[i]
        if typeof(arg) == "Instance" then
            if arg:IsA("Player") and arg ~= localPlayer then
                return true
            elseif arg:IsA("Model") and arg:FindFirstChildOfClass("Humanoid") and arg ~= char then
                return true
            end
        elseif typeof(arg) == "table" then
            for _, val in pairs(arg) do
                if typeof(val) == "Instance" then
                    if val:IsA("Player") and val ~= localPlayer then
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

function Logic.shouldBlockRemoteCall(remote, args, controller)
    if not controller then
        return false
    end

    if typeof(remote) ~= "Instance" then
        return false
    end

    if controller.CelestialImmune == true and isCelestialKillReport(remote, args) then
        return true
    end

    if isICBMClientReport(remote, args) then
        if args[1] == "Kill" then
            return controller.ICBMImmune == true
        end
        if args[1] == "Combust" then
            return controller.ICBMImmune == true or controller.ICBMBurnImmune == true
        end
    end
    if controller.inLobby then
        return false
    end

    local remoteName = remote.Name
    if remoteName == "LookEvent" then
        if controller.PondererSilentLookat == true and findEntityParent(remote, "Ponderer") then
            if args[1] ~= true then
                local newArgs = table.clone(args)
                newArgs[1] = true
                return true, newArgs
            end
        end
    end

    if remote.ClassName == "RemoteEvent"
        and remote.Name == "ClientEvent"
        and args[1] == "Debuff" then
        local parent = remote.Parent
        if parent and string.find(parent.Name, "Bell", 1, true) then
            controller.LastBellDebuffAt = time()
        end
    end

    if controller.BellOvertunedKillImmune == true
        and remote.ClassName == "RemoteEvent"
        and remote.Name == "ClientEvent"
        and args[1] == "Debuff" then
        local parent = remote.Parent
        if parent and string.find(parent.Name, "Bell", 1, true) and localPlayerHasStatus("Overtuned") then
            return true
        end
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

    remoteName = remote.Name
    if controller.CelestialImmune == true then
        if isCelestialKillReport(remote, args) then
            return true
        end
    end

    if remoteName == "Died" and args[1] == "VoidImplosion" and controller.VoidImplosionImmune == true then
        return true
    end

    if not Logic.TargetRemotes[remoteName] then
        return false
    end

    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character

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
                local keywordsList = config.Keywords or {}

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

                    if isRelated and not isTargetsSomeoneElse(args, LocalPlayer, char) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

return Logic
