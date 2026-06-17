-- Script Path: game:GetService("StarterPlayer").StarterPlayerScripts.ChunkRenderer.BiomeEffects
-- Took 0.39s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local LocalPlayer = game.Players.LocalPlayer
local t = {
    Inside = nil,
    currentChunk = nil,
    currentPosition = nil,
    Biomes = {},
    Loaded = false
}

if t.Loaded == false then
    t.Loaded = true

    for k, v in pairs(script:GetChildren()) do
        t.Biomes[v.Name] = require(v)
    end
end

function t.chunkRender(p1, p2, p3) --[[ chunkRender | Line: 20 | Upvalues: t (copy) ]]
    local v1 = t.Biomes[p1]

    if v1 then
        return v1.Appear(p2, p3)
    end

    return true
end
function t.chunkUnrender(p1, p2, p3) --[[ chunkUnrender | Line: 27 | Upvalues: t (copy) ]]
    local v1 = t.Biomes[p1]

    if v1 then
        return v1.Disappear(p2, p3)
    end

    return true
end
function t.Update(p1, p2, p3) --[[ Update | Line: 34 | Upvalues: t (copy) ]]
    t.currentChunk = p3
    t.currentPosition = p2

    local v1 = t.Biomes[p1]

    if v1 then
        v1.Update(p2, p3)
    end
end
function t.Enter(p1, p2, p3) --[[ Enter | Line: 44 | Upvalues: t (copy) ]]
    t.Inside = p1
    t.currentChunk = p3
    t.currentPosition = p2

    local v1 = t.Biomes[p1]

    if v1 then
        v1.Enter(p2, p3)
    end
end
function t.Exit(p1, p2, p3) --[[ Exit | Line: 55 | Upvalues: t (copy) ]]
    t.Inside = nil
    t.currentChunk = nil
    t.currentPosition = nil

    local v1 = t.Biomes[p1]

    if v1 then
        v1.Exit(p2, p3)
    end
end

return t
-- Script Path: game:GetService("StarterPlayer").StarterPlayerScripts.ChunkRenderer.BiomeEffects.Ice
-- Took 0.38s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}
local LocalPlayer = game.Players.LocalPlayer
local Chunks = script.Parent.Parent.Chunks
local v1 = Chunks:FindFirstChild(script.Name) or Chunks.Default
local v2 = Color3.fromRGB(200, 255, 255)
local Transparency = v1.Transparency
local IceExampleEffect = Instance.new("ColorCorrectionEffect")

IceExampleEffect.Name = "IceExampleEffect"
IceExampleEffect.Parent = game:GetService("Lighting")

local v3 = game:GetService("TweenService"):Create(IceExampleEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    TintColor = v2
})
local v4 = game:GetService("TweenService"):Create(IceExampleEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    TintColor = Color3.new(255/255, 255/255, 255/255)
})
local v5 = nil

local function UpdateChunk(p1, p2) --[[ UpdateChunk | Line: 30 | Upvalues: v5 (ref), Transparency (copy) ]]
    v5 = p1

    if p2 then
        p1.Transparency = 0.7
    else
        p1.Transparency = Transparency
    end
end

function t.Update(p1, p2) --[[ Update | Line: 43 | Upvalues: v5 (ref), Transparency (copy) ]]
    v5.Transparency = Transparency
    v5 = p2
    p2.Transparency = 0.7
end
function t.Enter(p1, p2) --[[ Enter | Line: 49 | Upvalues: v3 (copy), v5 (ref) ]]
    v3:Play()
    v5 = p2
    p2.Transparency = 0.7
end
function t.Exit(p1, p2) --[[ Exit | Line: 69 | Upvalues: v4 (copy), v5 (ref), Transparency (copy) ]]
    v4:Play()
    v5.Transparency = Transparency
end
function t.Appear(p1, p2) --[[ Appear | Line: 89 | Upvalues: Transparency (copy) ]]
    task.spawn(function() --[[ Line: 90 | Upvalues: p2 (copy), Transparency (ref) ]]
        for i = 1, 10 do
            p2.Transparency = math.lerp(1, Transparency, i / 10)
            task.wait()
        end
    end)

    return true
end
function t.Disappear(p1, p2) --[[ Disappear | Line: 101 | Upvalues: Transparency (copy) ]]
    task.spawn(function() --[[ Line: 102 | Upvalues: p2 (copy), Transparency (ref) ]]
        for i = 1, 10 do
            p2.Transparency = math.lerp(Transparency, 1, i / 10)
            task.wait()
        end

        p2:Destroy()
    end)

    return false
end

return t
-- Script Path: game:GetService("StarterPlayer").StarterPlayerScripts.ChunkRenderer.BiomeEffects.Highrise
-- Took 0.4s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}
local LocalPlayer = game.Players.LocalPlayer
local Chunks = script.Parent.Parent.Chunks
local v1 = Chunks:FindFirstChild(script.Name) or Chunks.Default
local v2 = Color3.fromRGB(255, 200, 255)
local Transparency = v1.Transparency
local HighriseCorrection = Instance.new("ColorCorrectionEffect")

HighriseCorrection.Name = "HighriseCorrection"
HighriseCorrection.Parent = game:GetService("Lighting")

local v3 = game:GetService("TweenService"):Create(HighriseCorrection, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    TintColor = v2
})
local v4 = game:GetService("TweenService"):Create(HighriseCorrection, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    TintColor = Color3.new(255/255, 255/255, 255/255)
})
local v5 = nil

local function UpdateChunk(p1, p2) --[[ UpdateChunk | Line: 30 | Upvalues: v5 (ref), Transparency (copy) ]]
    v5 = p1

    if p2 then
        p1.Transparency = 0.7
    else
        p1.Transparency = Transparency
    end
end

function t.Update(p1, p2) --[[ Update | Line: 43 | Upvalues: v5 (ref), Transparency (copy) ]]
    v5.Transparency = Transparency
    v5 = p2
    p2.Transparency = 0.7
end
function t.Enter(p1, p2) --[[ Enter | Line: 49 | Upvalues: v3 (copy), v5 (ref), LocalPlayer (copy) ]]
    v3:Play()
    v5 = p2
    p2.Transparency = 0.7

    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then
        return
    end

    LocalPlayer.Character:SetAttribute("Highrise", true)

    local HighriseLowGravity = Instance.new("VectorForce")

    HighriseLowGravity.Attachment0 = LocalPlayer.Character.HumanoidRootPart.RootAttachment
    HighriseLowGravity.Force = Vector3.new(0, 150, 0)
    HighriseLowGravity.Enabled = true
    HighriseLowGravity.Name = "HighriseLowGravity"
    HighriseLowGravity.Parent = LocalPlayer.Character.HumanoidRootPart
end
function t.Exit(p1, p2) --[[ Exit | Line: 72 | Upvalues: v4 (copy), v5 (ref), Transparency (copy), LocalPlayer (copy) ]]
    v4:Play()
    v5.Transparency = Transparency

    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then
        return
    end

    LocalPlayer.Character:SetAttribute("Highrise", nil)

    local HumanoidRootPart = LocalPlayer.Character.HumanoidRootPart

    if not HumanoidRootPart:FindFirstChild("HighriseLowGravity") then
        return
    end

    HumanoidRootPart.HighriseLowGravity:Destroy()
end
function t.Appear(p1, p2) --[[ Appear | Line: 94 | Upvalues: Transparency (copy) ]]
    task.spawn(function() --[[ Line: 95 | Upvalues: p2 (copy), Transparency (ref) ]]
        for i = 1, 10 do
            p2.Transparency = math.lerp(1, Transparency, i / 10)
            task.wait()
        end
    end)

    return true
end
function t.Disappear(p1, p2) --[[ Disappear | Line: 106 | Upvalues: Transparency (copy) ]]
    task.spawn(function() --[[ Line: 107 | Upvalues: p2 (copy), Transparency (ref) ]]
        for i = 1, 10 do
            p2.Transparency = math.lerp(Transparency, 1, i / 10)
            task.wait()
        end

        p2:Destroy()
    end)

    return false
end

return t
