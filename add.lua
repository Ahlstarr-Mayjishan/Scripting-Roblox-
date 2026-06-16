-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Sigil.Sigil_ClientAI.HitboxHelper
-- Took 0.42s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}
local Laser = script:WaitForChild("Laser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PoolManager = require(ReplicatedStorage:WaitForChild("ProjectileShared"):WaitForChild("PoolManager"))
local ReplicatedFirst = game:GetService("ReplicatedFirst")

game:GetService("Debris")
game:GetService("RunService")
game:GetService("TweenService")

local PlayerData = ReplicatedFirst:WaitForChild("ClientModules"):WaitForChild("Core"):WaitForChild("PlayerData")
local SpacialOperationHelper = require(ReplicatedStorage.Module.SpacialOperationHelper)
local SettingsHandler = require(PlayerData:WaitForChild("SettingsHandler"))

t.poolPartGroup = "SigilPartsGroup"
t.poolLaserBeamGroup = "SigilBeamGroup"
t.poolBlastGroup = "SigilBlastGroup"
t.DebrisPool = {
    SigilPartsGroup = {},
    SigilBeamGroup = {},
    SigilBlastGroup = {}
}

local v1 = OverlapParams.new()

v1.FilterType = Enum.RaycastFilterType.Include
v1.MaxParts = 1

local function Lerp(p1, p2, p3) --[[ Lerp | Line: 43 ]]
    return p1 + (p2 - p1) * p3
end

local v2 = nil

local function Initialize() --[[ Initialize | Line: 49 | Upvalues: PoolManager (copy), ReplicatedStorage (copy), t (copy), SettingsHandler (copy), v2 (ref) ]]
    local Part = Instance.new("Part")

    Part.Anchored = true
    PoolManager.CreatePool("SigilPartsGroup", Part, 60)
    PoolManager.CreatePool("SigilBeamGroup", ReplicatedStorage.SigilBeam, 25)
    PoolManager.CreatePool("SigilBlastGroup", ReplicatedStorage.SigilBlast, 20)

    local InRound = ReplicatedStorage:WaitForChild("InRound")
    local v1 = nil

    v1 = InRound.Changed:Connect(function() --[[ Line: 60 | Upvalues: InRound (copy), t (ref), PoolManager (ref), v1 (ref) ]]
        if InRound.Value ~= false then
            return
        end

        for k, v in pairs(t.DebrisPool) do
            for v12, v2 in v do
                PoolManager.ReturnItemToPool(k, v2)
            end

            table.clear(t.DebrisPool[k])
        end

        v1:Disconnect()
        v1 = nil
    end)
    SettingsHandler.WaitForSettings()

    local function updateSetting() --[[ updateSetting | Line: 75 | Upvalues: v2 (ref), SettingsHandler (ref) ]]
        v2 = SettingsHandler.Get({ "Graphics", "Colorblind" })
    end

    v2 = SettingsHandler.Get({ "Graphics", "Colorblind" })
    SettingsHandler.OnSettingsChanged:Connect(updateSetting)
end

local function Debris(p1, p2, p3) --[[ Debris | Line: 82 | Upvalues: PoolManager (copy), t (copy) ]]
    if not p1 or p1:GetAttribute("Debris") ~= p3 then
        return
    end

    PoolManager.ReturnItemToPool(p2, p1)

    local v1 = table.find(t.DebrisPool[p2], p1)

    if not v1 then
        return
    end

    table.remove(t.DebrisPool[p2], v1)
end

local function CreatePart(p1, p2) --[[ CreatePart | Line: 96 | Upvalues: PoolManager (copy), t (copy), v2 (ref) ]]
    local v1 = PoolManager.GetItemFromPool("SigilPartsGroup")

    v1:ClearAllChildren()
    t.Debris(60, v1, "SigilPartsGroup")
    v1.CFrame = CFrame.new(Vector3.new(0, 0, 0))
    v1.Size = p1
    v1.Material = Enum.Material.Neon
    v1.Anchored = true
    v1.CanCollide = false
    v1.CanTouch = false
    v1.Transparency = 1
    v1.CanQuery = false
    v1.CastShadow = false
    v1.Color = v2 and Color3.new(0.258824, 1, 0.878431) or Color3.new(1, 0.603922, 0.258824)
    v1.Shape = if p2 then p2 else Enum.PartType.Block

    return v1
end

function t.CreateLaser(p1, p2) --[[ Line: 118 | Upvalues: CreatePart (copy), PoolManager (copy), v2 (ref), Laser (copy) ]]
    local v1 = CreatePart((Vector3.new(p1 + 4, p1 + 4, 2048)))
    local v22 = PoolManager.GetItemFromPool("SigilBeamGroup")
    local v3 = PoolManager.GetItemFromPool("SigilBlastGroup")
    local v4 = CreatePart(Vector3.new(p2, 2, 2), Enum.PartType.Cylinder)

    v22.Color = v2 and Color3.fromRGB(74, 255, 195) or Color3.fromRGB(255, 186, 74)
    v3.Color = v2 and Color3.fromRGB(74, 255, 195) or Color3.fromRGB(255, 186, 74)

    local t = {}

    for i = 1, 2 do
        local v7
        local v8 = CreatePart(Vector3.new(p2 / 2, 2, 2), Enum.PartType.Cylinder)
        local v9 = Laser.ParticleEmitter:Clone()
        local v10 = Laser.ParticleEmitter2:Clone()
        local v11 = Laser.Tears:Clone()

        v9.Color = v2 and ColorSequence.new(Color3.fromRGB(98, 203, 255)) or ColorSequence.new(Color3.fromRGB(255, 211, 98))
        v10.Color = v2 and ColorSequence.new(Color3.fromRGB(53, 255, 205)) or ColorSequence.new(Color3.fromRGB(255, 134, 53))

        local v14, v15, v16, v17, v18, v19, v20, v21, v222, v23, v24, v25, v26

        if v2 then
            v7 = ColorSequence.new(Color3.fromRGB(53, 255, 205))

            if not v7 then
                v14 = ColorSequence.new
                v15 = {}
                v16 = ColorSequenceKeypoint.new
                v17 = 0
                v18 = v2 and Color3.fromRGB(53, 225, 255) or Color3.fromRGB(255, 137, 53)
                v19 = v16(v17, v18)
                v20 = ColorSequenceKeypoint.new
                v21 = 0.435
                v222 = v2 and Color3.fromRGB(51, 238, 255) or Color3.fromRGB(255, 134, 51)
                v23 = v20(v21, v222)
                v24 = ColorSequenceKeypoint.new
                v25 = 1
                v26 = v2 and Color3.fromRGB(7, 255, 193) or Color3.fromRGB(255, 77, 7)
                v15[1] = v19
                v15[2] = v23
                v15[3] = v24(v25, v26)
                v7 = v14(v15)
            end
        else
            v14 = ColorSequence.new
            v15 = {}
            v16 = ColorSequenceKeypoint.new
            v17 = 0
            v18 = v2 and Color3.fromRGB(53, 225, 255) or Color3.fromRGB(255, 137, 53)
            v19 = v16(v17, v18)
            v20 = ColorSequenceKeypoint.new
            v21 = 0.435
            v222 = v2 and Color3.fromRGB(51, 238, 255) or Color3.fromRGB(255, 134, 51)
            v23 = v20(v21, v222)
            v24 = ColorSequenceKeypoint.new
            v25 = 1
            v26 = v2 and Color3.fromRGB(7, 255, 193) or Color3.fromRGB(255, 77, 7)
            v15[1] = v19
            v15[2] = v23
            v15[3] = v24(v25, v26)
            v7 = v14(v15)
        end

        v11.Color = v7
        v9.Enabled = true
        v10.Enabled = true
        v11.Enabled = true
        v9.Parent = v8
        v10.Parent = v8
        v11.Parent = v8
        v8.Color = v2 and Color3.fromRGB(74, 255, 195) or Color3.fromRGB(255, 186, 74)
        t[i] = v8
    end

    return v1, v22, v3, t, v4
end
function t.CreateCylinder(p1) --[[ Line: 168 | Upvalues: CreatePart (copy) ]]
    local v1 = CreatePart(p1, Enum.PartType.Cylinder)

    v1.Transparency = 0
    v1.Parent = workspace

    return v1
end
function t.CreateSphere(p1) --[[ Line: 176 | Upvalues: CreatePart (copy) ]]
    local v1 = CreatePart(p1, Enum.PartType.Ball)

    v1.Transparency = 0
    v1.Parent = workspace.CatalystDebris

    return v1
end
function t.CreateLaserBubble(p1) --[[ Line: 184 | Upvalues: PoolManager (copy), v2 (ref) ]]
    local v1 = PoolManager.GetItemFromPool("SigilPartsGroup")

    v1.Size = Vector3.new(1, 1, 1) * p1 * 1.2
    v1.Color = v2 and Color3.fromRGB(35, 218, 255) or Color3.fromRGB(255, 145, 35)
    v1.Anchored = true
    v1.CanCollide = false
    v1.CanQuery = false
    v1.CanTouch = false
    v1.CastShadow = false
    v1.Material = Enum.Material.Neon
    v1.Shape = Enum.PartType.Ball

    return v1
end
function t.GetItemFromPool(p1) --[[ Line: 200 | Upvalues: PoolManager (copy) ]]
    return PoolManager.GetItemFromPool(p1)
end
function t.CheckBounds(p1, p2, p3) --[[ Line: 205 | Upvalues: SpacialOperationHelper (copy) ]]
    return SpacialOperationHelper.OBBIntersectHitbox(p1, p2, p3)
end
function t.CheckRadius(p1, p2, p3) --[[ Line: 214 | Upvalues: v1 (copy) ]]
    v1.FilterDescendantsInstances = { p1 }

    return #workspace:GetPartBoundsInRadius(p2, p3, v1) > 0
end
function t.CheckPart(p1, p2) --[[ Line: 222 | Upvalues: v1 (copy) ]]
    local CanQuery = p2.CanQuery

    p2.CanQuery = true
    v1.FilterDescendantsInstances = { p2 }

    local v12 = workspace:GetPartsInPart(p1, v1)

    p2.CanQuery = CanQuery

    return #v12 > 0
end
function t.Destroy(p1, p2) --[[ Line: 234 | Upvalues: PoolManager (copy), t (copy) ]]
    if not p1 then
        return
    end

    PoolManager.ReturnItemToPool(p2, p1)

    local v1 = table.find(t.DebrisPool[p2], p1)

    if not v1 then
        return
    end

    table.remove(t.DebrisPool[p2], v1)
end
function t.Debris(p1, p2, p3) --[[ Line: 248 | Upvalues: t (copy), Debris (copy) ]]
    local v1 = p2:GetAttribute("Debris")
    local v2 = p2:GetAttribute("Debris") and v1 + 1 or 0

    p2:SetAttribute("Debris", v2)
    table.insert(t.DebrisPool[p3], p2)
    task.delay(p1, Debris, p2, p3, v2)
end
Initialize()

return t

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Quartz.Quartz_ClientAI.HitboxHelper
-- Took 0.49s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}
local Laser = script:WaitForChild("Laser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PoolManager = require(ReplicatedStorage:WaitForChild("ProjectileShared"):WaitForChild("PoolManager"))
local ReplicatedFirst = game:GetService("ReplicatedFirst")

game:GetService("Debris")
game:GetService("RunService")
game:GetService("TweenService")

local PlayerData = ReplicatedFirst:WaitForChild("ClientModules"):WaitForChild("Core"):WaitForChild("PlayerData")
local SpacialOperationHelper = require(ReplicatedStorage.Module.SpacialOperationHelper)

require(PlayerData:WaitForChild("SettingsHandler"))
t.poolPartGroup = "SigilPartsGroup"
t.poolLaserBeamGroup = "SigilBeamGroup"
t.poolBlastGroup = "SigilBlastGroup"
t.DebrisPool = {
    SigilPartsGroup = {},
    SigilBeamGroup = {},
    SigilBlastGroup = {}
}

local v1 = OverlapParams.new()

v1.FilterType = Enum.RaycastFilterType.Include
v1.MaxParts = 1

local function Lerp(p1, p2, p3) --[[ Lerp | Line: 47 ]]
    return p1 + (p2 - p1) * p3
end

local function Initialize() --[[ Initialize | Line: 52 | Upvalues: PoolManager (copy), ReplicatedStorage (copy), t (copy) ]]
    local Part = Instance.new("Part")

    Part.Anchored = true
    PoolManager.CreatePool("SigilPartsGroup", Part, 60)
    PoolManager.CreatePool("SigilBeamGroup", ReplicatedStorage.SigilBeam, 25)
    PoolManager.CreatePool("SigilBlastGroup", ReplicatedStorage.SigilBlast, 10)

    local InRound = ReplicatedStorage:WaitForChild("InRound")
    local v1 = nil

    v1 = InRound.Changed:Connect(function() --[[ Line: 63 | Upvalues: InRound (copy), t (ref), PoolManager (ref), v1 (ref) ]]
        if InRound.Value ~= false then
            return
        end

        for k, v in pairs(t.DebrisPool) do
            for v12, v2 in v do
                PoolManager.ReturnItemToPool(k, v2)
            end

            table.clear(t.DebrisPool[k])
        end

        v1:Disconnect()
        v1 = nil
    end)
end

local function Debris(p1, p2, p3) --[[ Debris | Line: 79 | Upvalues: PoolManager (copy), t (copy) ]]
    if not p1 or p1:GetAttribute("Debris") ~= p3 then
        return
    end

    PoolManager.ReturnItemToPool(p2, p1)

    local v1 = table.find(t.DebrisPool[p2], p1)

    if not v1 then
        return
    end

    table.remove(t.DebrisPool[p2], v1)
end

local function CreatePart(p1, p2) --[[ CreatePart | Line: 93 | Upvalues: PoolManager (copy), t (copy) ]]
    local v1 = PoolManager.GetItemFromPool("SigilPartsGroup")

    v1:ClearAllChildren()
    t.Debris(60, v1, "SigilPartsGroup")
    v1.CFrame = CFrame.new(Vector3.new(0, 0, 0))
    v1.Size = p1
    v1.Material = Enum.Material.Neon
    v1.Anchored = true
    v1.CanCollide = false
    v1.CanTouch = false
    v1.Transparency = 1
    v1.CanQuery = false
    v1.CastShadow = false
    v1.Shape = if p2 then p2 else Enum.PartType.Block

    return v1
end

function t.CreateLaser(p1, p2) --[[ Line: 115 | Upvalues: CreatePart (copy), PoolManager (copy), Laser (copy) ]]
    local v1 = CreatePart((Vector3.new(p1 + 4, p1 + 4, 2048)))
    local v2 = PoolManager.GetItemFromPool("SigilBeamGroup")
    local v3 = PoolManager.GetItemFromPool("SigilBlastGroup")
    local v4 = CreatePart(Vector3.new(p2, 2, 2), Enum.PartType.Cylinder)
    local t = {}

    for i = 1, 2 do
        local v5 = CreatePart(Vector3.new(p2 / 2, 2, 2), Enum.PartType.Cylinder)
        local v6 = Laser.ParticleEmitter:Clone()
        local v7 = Laser.ParticleEmitter2:Clone()
        local v8 = Laser.Tears:Clone()

        v6.Enabled = true
        v7.Enabled = true
        v8.Enabled = true
        v6.Parent = v5
        v7.Parent = v5
        v8.Parent = v5
        t[i] = v5
    end

    return v1, v2, v3, t, v4
end
function t.CreateCylinder(p1) --[[ Line: 166 | Upvalues: CreatePart (copy) ]]
    local v1 = CreatePart(p1, Enum.PartType.Cylinder)

    v1.Transparency = 0
    v1.Parent = workspace

    return v1
end
function t.CreateSphere(p1) --[[ Line: 174 | Upvalues: CreatePart (copy) ]]
    local v1 = CreatePart(p1, Enum.PartType.Ball)

    v1.Transparency = 0
    v1.Parent = workspace.CatalystDebris

    return v1
end
function t.CreateLaserBubble(p1) --[[ Line: 182 | Upvalues: PoolManager (copy) ]]
    local v1 = PoolManager.GetItemFromPool("SigilPartsGroup")

    v1.Size = Vector3.new(1, 1, 1) * p1 * 1.2
    v1.Anchored = true
    v1.CanCollide = false
    v1.CanQuery = false
    v1.CanTouch = false
    v1.CastShadow = false
    v1.Material = Enum.Material.Neon
    v1.Shape = Enum.PartType.Ball

    return v1
end
function t.GetItemFromPool(p1) --[[ Line: 198 | Upvalues: PoolManager (copy) ]]
    return PoolManager.GetItemFromPool(p1)
end
function t.CheckBounds(p1, p2, p3) --[[ Line: 203 | Upvalues: SpacialOperationHelper (copy) ]]
    return SpacialOperationHelper.OBBIntersectHitbox(p1, p2, p3)
end
function t.CheckRadius(p1, p2, p3) --[[ Line: 212 | Upvalues: v1 (copy) ]]
    v1.FilterDescendantsInstances = { p1 }

    return #workspace:GetPartBoundsInRadius(p2, p3, v1) > 0
end
function t.CheckPart(p1, p2) --[[ Line: 220 | Upvalues: v1 (copy) ]]
    local CanQuery = p2.CanQuery

    p2.CanQuery = true
    v1.FilterDescendantsInstances = { p2 }

    local v12 = workspace:GetPartsInPart(p1, v1)

    p2.CanQuery = CanQuery

    return #v12 > 0
end
function t.Destroy(p1, p2) --[[ Line: 232 | Upvalues: PoolManager (copy), t (copy) ]]
    if not p1 then
        return
    end

    PoolManager.ReturnItemToPool(p2, p1)

    local v1 = table.find(t.DebrisPool[p2], p1)

    if not v1 then
        return
    end

    table.remove(t.DebrisPool[p2], v1)
end
function t.Debris(p1, p2, p3) --[[ Line: 246 | Upvalues: t (copy), Debris (copy) ]]
    local v1 = p2:GetAttribute("Debris")
    local v2 = p2:GetAttribute("Debris") and v1 + 1 or 0

    p2:SetAttribute("Debris", v2)
    table.insert(t.DebrisPool[p3], p2)
    task.delay(p1, Debris, p2, p3, v2)
end
Initialize()

return t
