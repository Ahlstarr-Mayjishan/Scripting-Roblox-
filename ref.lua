-- Script Path: game:GetService("Workspace").Noriko_Ellen.RadarSlop
-- Took 0.49s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local CollectionService = game:GetService("CollectionService")
local UpgradeHandler = require(game.ReplicatedFirst.ClientModules.UpgradeHandler)
local HumanoidRootPart = script.Parent:WaitForChild("HumanoidRootPart")
local Humanoid = script.Parent:WaitForChild("Humanoid")
local AltarColors = require(game.ReplicatedStorage.Altars.AltarColors)
local v1 = Random.new()

local function f2() --[[ Line: 13 | Upvalues: HumanoidRootPart (copy), v1 (copy) ]]
    for v12, v2 in game.Players:GetPlayers() do
        if v2 ~= game.Players.LocalPlayer then
            local Character = v2.Character

            if Character and Character.Parent then
                local HumanoidRootPart2 = Character:FindFirstChild("HumanoidRootPart")

                if HumanoidRootPart2 then
                    local Magnitude = (HumanoidRootPart2.Position - HumanoidRootPart.Position).Magnitude

                    if not (Magnitude > 1024) then
                        task.delay(Magnitude / 1024, function() --[[ Line: 27 | Upvalues: Character (copy), v1 (ref) ]]
                            local Highlight = Instance.new("Highlight")

                            Highlight.FillTransparency = 1

                            if Character.Humanoid:GetState() == Enum.HumanoidStateType.Dead then
                                Highlight.OutlineColor = Color3.new(255/255, 0/255, 0/255)
                            end

                            Highlight.Parent = Character
                            game.TweenService:Create(Highlight, TweenInfo.new(8, Enum.EasingStyle.Linear), {
                                OutlineTransparency = 1
                            }):Play()
                            game.Debris:AddItem(Highlight, 8.1)
                            game.SoundService.SFXFolder.Radar_Player.PlaybackSpeed = v1:NextNumber(0.9, 1.1)
                            game.SoundService.SFXFolder.Radar_Player:Play()
                        end)
                    end
                end
            end
        end
    end
end

local function f3() --[[ Line: 47 | Upvalues: CollectionService (copy), HumanoidRootPart (copy), AltarColors (copy), v1 (copy) ]]
    for k, v in pairs(CollectionService:GetTagged("Altar")) do
        local v12 = v:FindFirstChild("RealName") and v.RealName.Value or ""
        local v2 = v.Parent
        local HitBox = v2:FindFirstChild("HitBox")

        if HitBox and (v2:FindFirstChild("Altar") and not v2:GetAttribute("AltarUsed")) then
            local Magnitude = (v2.HitBox.Position - HumanoidRootPart.Position).Magnitude

            if not (Magnitude > 1024) then
                task.delay(Magnitude / 2048, function() --[[ Line: 58 | Upvalues: HitBox (copy), AltarColors (ref), v12 (copy), v1 (ref) ]]
                    if not HitBox or HitBox.Parent == nil then
                        return
                    end

                    local v13 = script:WaitForChild("AltarPing"):Clone()

                    v13.Parent = HitBox
                    v13.Tweened.ImageColor3 = AltarColors[v12] or Color3.new(0/255, 0/255, 0/255)
                    v13.ImageLabel.ImageColor3 = AltarColors[v12] or Color3.new(0/255, 0/255, 0/255)
                    v13.Enabled = true
                    game.TweenService:Create(v13.Tweened, TweenInfo.new(1), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(12, 12)
                    }):Play()
                    game.TweenService:Create(v13.ImageLabel, TweenInfo.new(10), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(0, 0)
                    }):Play()
                    game.TweenService:Create(v13.Outline, TweenInfo.new(10), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(0, 0)
                    }):Play()
                    game.Debris:AddItem(v13, 10.1)
                    game.SoundService.SFXFolder.Radar_Altar.PlaybackSpeed = v1:NextNumber(0.97, 1.03)
                    game.SoundService.SFXFolder.Radar_Altar:Play()
                end)
            end
        end
    end
end

local function f4() --[[ Line: 79 | Upvalues: CollectionService (copy), HumanoidRootPart (copy), v1 (copy) ]]
    for k, v in pairs(CollectionService:GetTagged("CadenceOrb")) do
        if v.CanTouch then
            local Magnitude = (v.Position - HumanoidRootPart.Position).Magnitude

            if not (Magnitude > 1024) then
                task.delay(Magnitude / 2048, function() --[[ Line: 89 | Upvalues: v (copy), v1 (ref) ]]
                    local v12 = script:WaitForChild("CadencePing"):Clone()

                    v12.Parent = v
                    v12.Enabled = true
                    game.TweenService:Create(v12.Tweened, TweenInfo.new(1), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(12, 12)
                    }):Play()
                    game.TweenService:Create(v12.ImageLabel, TweenInfo.new(10), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(0, 0)
                    }):Play()
                    game.Debris:AddItem(v12, 10.1)
                    game.SoundService.SFXFolder.Radar_Instruments.PlaybackSpeed = v1:NextNumber(1.95, 2.05)
                    game.SoundService.SFXFolder.Radar_Instruments:Play()
                end)
            end
        end
    end
end

while task.wait(12) and Humanoid:GetState() ~= Enum.HumanoidStateType.Dead do
    if UpgradeHandler.IsUpgradeEnabled("RadarPlayer") then
        task.spawn(f2)
    end

    if UpgradeHandler.IsUpgradeEnabled("RadarAltars") then
        task.spawn(f3)
    end

    if UpgradeHandler.IsUpgradeEnabled("RadarInstruments") then
        task.spawn(f4)
    end
end

-- Script Path: game:GetService("ReplicatedFirst").ClientModules.GiftClient.GiftClientHandler
-- Took 1.07s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentCamera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local GiftClient = ReplicatedFirst.ClientModules.GiftClient
local UpgradeHandler = require(ReplicatedFirst.ClientModules.UpgradeHandler)
local SettingsHandler = require(ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)
local InventoryHandler = require(ReplicatedFirst.ClientModules.Core.PlayerData.InventoryHandler)
local StatusEffectHandler = require(ReplicatedFirst.ClientModules.StatusEffectHandler)

require(ReplicatedStorage.GiftShared.GiftEnums)

local GiftCounters = game.ReplicatedStorage.GiftCounters
local GiftValue = game.ReplicatedStorage.GiftValue

t.Assets = script.Assets
t.Util = require(GiftClient.ClientUtil)
t.Octree = require(ReplicatedStorage.Module.Octree).new()
t.GiftClasses = {}
t.GiftCleanup = {}
t.Gifts = {}
t.RenderQueue = {}
t.RenderHandler = require(GiftClient.RenderQueue)
t.GiftsByType = {}
t.GiftCount = {}
t.GiftValue = GiftValue.Value
t.FAR_AWAY = Vector3.new(-100000000000000000000000000000000, -100000000000000000000000000000000, -100000000000000000000000000000000)
t.MAX_FRAME_MILLISECONDS = 0.004

local GiftHighlight = t.Assets.GiftHighlight
local TripmineHighlight = t.Assets.TripmineHighlight

function t.new(p1, p2, p3, p4, p5) --[[ new | Line: 52 | Upvalues: t (copy) ]]
    local v1 = t.GiftClasses[p3]

    if not v1 then
        warn(p3, "doesnt exist")

        return
    end

    if t.Gifts[p2] then
        warn(p3, p2, "already exists what")
    end

    debug.profilebegin("Create" .. p3)
    debug.profilebegin("Read")

    local v2 = if p5 then p5 else v1:ReadParams(p1)

    debug.profileend()
    debug.profilebegin("NewObject")

    local v3 = v1.new(p1, p2, p4, v2)

    debug.profileend()
    debug.profilebegin("Set")
    t.Gifts[p2] = v3
    t.GiftsByType[p3][p2] = true

    local v4 = t.GiftCount[p3]

    v4.Current = v4.Current + 1
    debug.profileend()
    debug.profileend()

    return v3
end
function t.DestroyGift(p1, p2) --[[ DestroyGift | Line: 77 | Upvalues: t (copy) ]]
    local v1 = t.Gifts[p1]

    if not v1 or v1.Destroyed then
        return
    end

    v1.Destroyed = true
    t.Gifts[p1] = nil
    t.GiftsByType[v1.Type][p1] = nil

    local v2 = t.GiftCount[v1.Type]

    v2.Current = v2.Current - 1

    if not v1.onDestroy then
        return
    end

    v1:onDestroy(p2)
end
function t.Collapse() --[[ Collapse | Line: 92 | Upvalues: t (copy) ]]
    local v1 = os.clock()
    local count = 0

    for k in pairs(t.GiftsByType.Gift) do
        count = count + 1

        local v2 = t.Gifts[k]

        v2:Destroy()
        t.new(nil, k, "GoldenGift", false, {
            Position = v2.Position,
            Size = v2.Size,
            Value = v2.Value
        })

        if os.clock() - v1 >= t.MAX_FRAME_MILLISECONDS or count % 50 == 0 then
            task.wait()
            v1 = os.clock()
        end
    end
end
function t.ClearAllGifts() --[[ ClearAllGifts | Line: 115 | Upvalues: t (copy), ReplicatedStorage (copy) ]]
    local v1 = os.clock()
    local count = 0

    for k, v in pairs(t.Gifts) do
        count = count + 1
        v:Destroy(true)

        if os.clock() - v1 >= t.MAX_FRAME_MILLISECONDS or count % 50 == 0 then
            task.wait()
            v1 = os.clock()
        end
    end

    for k, v in pairs(t.GiftCleanup) do
        table.clear(v)
    end

    table.clear(t.GiftCleanup)

    for k in pairs(t.GiftCount) do
        t.GiftCount[k] = {
            Current = 0,
            Collected = 0
        }
    end

    t.Octree = require(ReplicatedStorage.Module.Octree).new()
end
function t.AddCollection(p1) --[[ AddCollection | Line: 144 | Upvalues: t (copy) ]]
    if p1.AddedCollection then
        return
    end

    p1.AddedCollection = true

    local v1 = t.GiftCount[p1.Type]

    v1.Collected = v1.Collected + 1
end
function t.RemoveCollection(p1) --[[ RemoveCollection | Line: 151 | Upvalues: t (copy) ]]
    if not p1.AddedCollection then
        return
    end

    p1.AddedCollection = false

    local v1 = t.GiftCount[p1.Type]

    v1.Collected = v1.Collected - 1
end
function t.ReplicationEnd() --[[ ReplicationEnd | Line: 158 | Upvalues: t (copy) ]]
    if t.PoolManager.GetTotalPoolItems("Gift") - t.PoolManager.GetTotalPoolItems("GoldenGift") <= 0 then
        return
    end

    local v1 = os.clock()

    repeat
        local v2 = t.PoolManager.GetTotalPoolItems("Gift") - t.PoolManager.GetTotalPoolItems("GoldenGift")

        t.PoolManager.AddToPool("GoldenGift", 1)

        if os.clock() - v1 >= 0.1 then
            task.wait()
            v1 = os.clock()
        end
    until v2 <= 0
end

local v1 = 0
local v2 = 1
local v3 = 1
local v4 = 0
local v5 = 1
local v6 = 1
local v7 = 0
local v8 = false
local v9 = nil
local InRound = ReplicatedStorage:WaitForChild("InRound")
local Dead = LocalPlayer:WaitForChild("Dead")
local v10 = 0
local v11 = 0
local identity = CFrame.identity
local GiftArrow = t.Assets.GiftArrow
local v12 = ReplicatedStorage:FindFirstChild("Movement") and ReplicatedStorage.Movement.Events.CollectedGift or Instance.new("BindableEvent")
local MovementGiftMagnet = game.ReplicatedStorage.Events.MovementGiftMagnet
local t2 = {}
local RangeVisualiser = t.Assets.RangeVisualiser
local v13 = nil
local v14 = nil

GiftArrow.Parent = workspace
function GiftMagnetStackChanged() --[[ GiftMagnetStackChanged | Line: 219 | Upvalues: InventoryHandler (copy), v1 (ref), UpgradeHandler (copy), v2 (ref), v4 (ref) ]]
    local v12 = InventoryHandler.GetEquipped("Class")

    v1 = if v12 == "class/Wicked" then 0 elseif v12 == "class/Charger" then 0.75 * UpgradeHandler.GetUpgradeStack("GiftMagnet") else UpgradeHandler.GetUpgradeStack("GiftMagnet") / 2 or 0

    if not game.ReplicatedStorage.Solo.Value then
        v1 = v1 * v2
        v1 = v1 + v4

        return
    end

    v1 = v1 + 0.5
    v1 = v1 * v2
    v1 = v1 + v4
end
function MovementEvent(p1) --[[ MovementEvent | Line: 244 | Upvalues: v2 (ref), v3 (ref), v4 (ref), v5 (ref), v6 (ref), v7 (ref), v8 (ref), v9 (ref) ]]
    if p1.Reset ~= nil then
        v2 = 1
        v3 = 1
        v4 = 0
        v5 = 1
        v6 = 1
        v7 = 0
        v8 = false
    end

    if p1.Multiplier ~= nil then
        v2 = p1.Multiplier
    end

    if p1.Add ~= nil then
        v4 = p1.Add
    end

    if p1.ActualMultiplier ~= nil then
        v3 = p1.ActualMultiplier
    end

    if p1.Squish ~= nil then
        v5 = p1.Squish
    end

    if p1.GlobalDivide ~= nil then
        v6 = p1.GlobalDivide
    end

    if p1.Disable ~= nil then
        v8 = p1.Disable
    end

    if p1.SpiritAdd then
        v7 = p1.SpiritAdd
    end

    if p1.Target ~= nil then
        v9 = p1.Target
    end

    GiftMagnetStackChanged()
end

local function UpdateArrow(p1, p2) --[[ UpdateArrow | Line: 284 | Upvalues: UpgradeHandler (copy), GiftCounters (copy), t (copy), GiftArrow (copy), identity (ref), t2 (copy) ]]
    local v1 = UpgradeHandler.IsUpgradeEnabled("HighlightGifts")
    local v2 = UpgradeHandler.IsUpgradeEnabled("HighlightTripmines")
    local v3

    if v1 then
        v3 = v1
    else
        local v4 = GiftCounters.Gift:GetAttribute("MaxGifts") or 0

        v3 = v4 - t.GiftCount.Gift.Collected <= v4 * 0.2
    end

    local t3 = {}

    if not v3 then
        t.RenderHandler.SetCFrame(GiftArrow, CFrame.new(0, 1e32, 0))

        return
    end

    local v5 = nil
    local v6 = (1 / 0)

    if p1 then
        debug.profilebegin("GiftArrow")
        debug.profilebegin("RadiusSearch")

        local v7, _ = t.Octree:RadiusSearch(p1, 96)

        debug.profileend()

        if v1 then
            debug.profilebegin("GiftEsp")

            for i = 1, #v7 do
                local v8 = t.Gifts[v7[i]]

                if not v8.Golden and (not v8.Tripmine or v2) then
                    t3[v8.Id] = v8
                end
            end

            debug.profileend()
        end

        debug.profilebegin("FindClosest")

        if t.GiftCount.Gift.Current > 0 then
            for j = 1, 6 do
                if v5 then
                    break
                end

                debug.profilebegin("RadiusSearch" .. j)

                local v11, v12 = t.Octree:RadiusSearch(p1, j * 112 + 96, 0)

                debug.profileend()

                for k = 1, #v11 do
                    local v13 = v12[k]

                    if not (v13 > 589824 or v6 < v13) then
                        local v15 = t.Gifts[v11[k]]

                        if not (v15.Tripmine or v15.Golden) then
                            v6 = v13
                            v5 = v15
                        end
                    end
                end
            end
        end

        debug.profileend()
    end

    if v5 then
        t3[v5.Id] = v5

        if p2 then
            identity = identity:Lerp(CFrame.lookAt(p2.Position, v5.RenderCFrame.Position) - p2.Position, 0.1)
            t.RenderHandler.SetCFrame(GiftArrow, identity * CFrame.new(0, 0, -2 - math.min(1, v6 / 9)) + p2.Position)
        end
    else
        t.RenderHandler.SetCFrame(GiftArrow, CFrame.new(0, 1e32, 0))
    end

    debug.profileend()
    debug.profilebegin("SetupHighlights")

    for v16, v17 in t2 do
        if not t3[v16] then
            t2[v16] = nil
            v17.Model.Anchored = true

            if v17.Gift.Size ~= 1 then
                v17.Model.Size = v17.Gift.DefaultSize
            end

            t.PoolManager.ReturnItemToPool(v17.Type .. "Shell", v17.Model)
        end
    end

    for v18, v19 in t3 do
        if not t2[v18] then
            local v20 = t.PoolManager.GetItemFromPool(v19.Type .. "Shell")

            v20.Weld.Part1 = v19.Model
            v20.Anchored = false
            v19.Highlight = v20

            if v19.Size ~= 1 then
                v20.Size = v19.DefaultSize * v19.Size
            end

            t2[v18] = {
                Type = v19.Type,
                Model = v20,
                Gift = v19
            }
        end
    end
end

function UpdateGifts(p1) --[[ UpdateGifts | Line: 434 | Upvalues: LocalPlayer (copy), v14 (ref), v9 (ref), CurrentCamera (copy), InRound (copy), Dead (copy), v1 (ref), v7 (ref), StatusEffectHandler (copy), v3 (ref), v6 (ref), v5 (ref), t (copy), v10 (ref), v11 (ref), v12 (copy), UpdateArrow (copy) ]]
    os.clock()

    local Character = LocalPlayer.Character

    v14 = if Character then Character:FindFirstChild("HumanoidRootPart") else Character

    local v2 = if Character then Character:FindFirstChild("Head") else Character

    if v14 then
        v9 = v14.Position
    end

    local SavedQualityLevel = UserSettings().GameSettings.SavedQualityLevel.Value

    if SavedQualityLevel == 0 then
        SavedQualityLevel = 5
    end

    local v32 = math.sqrt(SavedQualityLevel / 10) * 256
    local v4 = CurrentCamera.CFrame
    local Position = v4.Position
    local LookVector = v4.LookVector
    local v52 = InRound.Value and v9 and not Dead.Value
    local v62 = if LocalPlayer:FindFirstChild("TRIP_IFRAMES") == nil then false else true
    local sum = v1 + (_G.PICKUP_BONUS or 0) + v7

    if StatusEffectHandler.HasStatus("Panic") then
        sum = sum + 2
    end

    local SpiritStatue = workspace:FindFirstChild("SpiritStatue")

    if SpiritStatue and v9 then
        sum = sum + math.min((v9 - SpiritStatue.HumanoidRootPart.Position).Magnitude / 48, 2.5)
    end

    v7 = math.max(v7 - p1 * 6, 0)

    local v92 = (3 + sum) * v3

    UpdateThatOneSetting(v92 / v6)
    debug.profilebegin("SelectGifts")

    if v52 then
        debug.profilebegin("CollectGifts")
        debug.profilebegin("RadiusSearch")

        local v112 = t.Octree:RadiusSearch(v9, 2 + v92 / (0.8 / v5 * v6))

        debug.profileend()

        local v132 = v9 * Vector3.new(1, 0.8 / v5, 1)

        for v142, v15 in v112 do
            local v16 = t.Gifts[v15]

            if not v16.Collected then
                local Type = v16.Type
                local TimeOffset = v16.TimeOffset
                local Tripmine = v16.Tripmine
                local Magnitude = (v132 - v16.Position * Vector3.new(1, 0.8 / v5, 1)).Magnitude

                if Magnitude <= math.clamp((if Tripmine then if v62 then -1 else 2.25 else v92 / v6) * v16.Size, 0, 32) then
                    local v19 = tick()

                    if math.min(1.2, math.pow(1.1, v11) * 0.8) <= v19 - v10 then
                        v11 = 0
                    end

                    if not Tripmine then
                        v11 = v11 + 1
                        v10 = v19
                    end

                    v16:Collect(false, true, v11)
                    v12:Fire()
                end
            end
        end

        debug.profileend()
    end

    debug.profilebegin("RadiusSearch")

    local v23, v24 = t.Octree:RadiusSearch(Position, 256)

    debug.profileend()
    debug.profilebegin("GetVisibleGifts")

    local t2 = {}

    for v25, v26 in v23 do
        local v27 = t.Gifts[v26]

        if not v27.ForceRender and vector.dot(LookVector, v27.Position - Position) >= 0 then
            table.insert(t2, { v27, v24[v25] })
        end
    end

    debug.profileend()
    debug.profileend()
    debug.profilebegin("SortGifts")
    table.sort(t2, function(p1, p2) --[[ Line: 577 ]]
        return p1[2] < p2[2]
    end)
    debug.profileend()
    debug.profilebegin("RenderGifts")

    local v29 = time()

    local function RenderGift(p1, p2) --[[ RenderGift | Line: 587 | Upvalues: v29 (copy), v9 (ref), sum (ref), v3 (ref), v6 (ref), t (ref) ]]
        local Type = p1.Type
        local Position = p1.Position
        local sum2 = v29
        local v1 = math.sin(sum2) / 2
        local v2

        if v9 and not p1.Tripmine then
            local v32 = Position + Vector3.new(0, v1, 0)
            local v62 = 1 / ((v9 - Position).Magnitude / math.clamp(((3 + sum) * v3 - 1.5) / v6 * p1.Size, 0, 32)) ^ 3

            sum2, v2 = sum2 + v62 * 10, v32:Lerp(v9, (math.min(v62, 1)))
        else
            v2 = Position
        end

        local v8 = sum2 + p1.TimeOffset
        local v92 = CFrame.Angles(math.rad(v8 * 60), math.rad(v8 * 45), (math.rad(v8 * 30))) + v2

        t.RenderHandler.SetCFrame(p1.Model, v92)
        p1.RenderCFrame = v92
    end

    for v30, v31 in t2 do
        if v32 <= v30 then
            break
        end

        RenderGift(v31[1])
    end

    debug.profilebegin("ForceRender")

    for k in pairs(t.RenderQueue) do
        local v322 = t.Gifts[k]

        if v322 and not v322.Collected then
            v322.ForceRender = nil
            RenderGift(v322)
        end
    end

    table.clear(t.RenderQueue)
    debug.profileend()
    debug.profileend()
    UpdateArrow(v9, v2)
end

local IdolBeam = t.Assets.IdolBeam
local IdolSound = t.Assets.IdolSound

function t.IdolEffect(p1, p2, p3) --[[ IdolEffect | Line: 674 | Upvalues: LocalPlayer (copy), IdolBeam (copy), SettingsHandler (copy), TweenService (copy), Debris (copy), v12 (copy), t (copy), IdolSound (copy) ]]
    local v1 = if p1 then p1.RenderCFrame and p1.RenderCFrame.Position or p1.Position else Vector3.new(0, 0, 0)
    local Attachment = Instance.new("Attachment")

    Attachment.WorldPosition = v1
    Attachment.Parent = workspace.Terrain

    local v3 = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local v4 = if p3 == LocalPlayer then true else false
    local count = 0

    for v5, v6 in p2 do
        local Attachment2 = Instance.new("Attachment")

        Attachment2.WorldPosition = v6.RenderCFrame and v6.RenderCFrame.Position or v6.Position
        Attachment2.Parent = workspace.Terrain

        local v8 = IdolBeam:Clone()

        v8.Attachment0 = Attachment
        v8.Attachment1 = Attachment2

        if v6.Golden or SettingsHandler.Get({ "Graphics", "Colorblind" }) then
            v8.Color = ColorSequence.new(Color3.fromRGB(255, 191, 0))
        else
            v8.Color = ColorSequence.new(Color3.fromRGB(170, 0, 255))
        end

        v8.Parent = Attachment
        TweenService:Create(v8, v3, {
            Brightness = 0
        }):Play()
        Debris:AddItem(Attachment2, 1)

        if v4 then
            v12:Fire()

            if v6.Golden and not v6.Collected then
                t.UIHandler.AddToStack((v6:GetValue()))
                count = count + 1
            end
        end
    end

    local v10

    if count >= 3 then
        t.UIHandler.AddToStack(0, math.clamp(count / 15 + 1, 1, 1.5), (math.clamp(count / 3 + 3, 3, 7)))
    end

    Debris:AddItem(Attachment, 1)
    v10 = IdolSound:Clone()
    v10.Parent = Attachment
    v10.Ended:Once(function() --[[ Line: 734 | Upvalues: v10 (copy) ]]
        v10:Destroy()
    end)
    v10:Play()
end

local v15 = nil
local v16 = nil
local v17 = nil

function RecheckParticles() --[[ RecheckParticles | Line: 745 | Upvalues: t (copy), SettingsHandler (copy), TripmineHighlight (copy) ]]
    for k, v in pairs(t.Gifts) do
        v:UpdateModel()
    end

    if SettingsHandler.Get({ "Graphics", "Colorblind" }) then
        TripmineHighlight.OutlineColor = Color3.fromRGB(255, 183, 0)
    else
        TripmineHighlight.OutlineColor = Color3.fromRGB(255, 0, 0)
    end
end
function SettingsChanged() --[[ SettingsChanged | Line: 756 | Upvalues: SettingsHandler (copy), v15 (ref), v16 (ref), v17 (ref) ]]
    local v1 = SettingsHandler.Get({ "Graphics", "GiftParticles" })
    local v2 = SettingsHandler.Get({ "Graphics", "GiftRadarBillboard" })
    local v3 = SettingsHandler.Get({ "Graphics", "Colorblind" })
    local v4 = v15 ~= v1
    local v5 = if v16 == v2 then false else true

    if not (if v4 then v4 elseif v5 then v5 elseif v17 == v3 then false else true) then
        return
    end

    v15 = v1
    v16 = v2
    v17 = v3
    RecheckParticles()
end
function GiftHighlightStackChanged() --[[ GiftHighlightStackChanged | Line: 779 ]]
    RecheckParticles()
end
function UpdateThatOneSetting(p1) --[[ UpdateThatOneSetting | Line: 783 | Upvalues: v14 (ref), SettingsHandler (copy), v13 (ref), RangeVisualiser (copy) ]]
    if not v14 then
        return
    end

    if SettingsHandler.Get({ "Misc", "ShowGiftCollection" }) then
        local RangeVisualiser2 = v14:FindFirstChild("RangeVisualiser")

        if not RangeVisualiser2 then
            local v1 = RangeVisualiser:Clone()

            v1.Parent = v14
            v13 = v1
            RangeVisualiser2 = v1
        end

        RangeVisualiser2.Emitter.Size = NumberSequence.new(p1 / 2)
    else
        if not v13 then
            return
        end

        v13:Destroy()
        v13 = nil
    end
end
function t.Init() --[[ Init | Line: 806 | Upvalues: t (copy), GiftClient (copy), GiftHighlight (copy), TripmineHighlight (copy), RunService (copy), UpgradeHandler (copy), MovementGiftMagnet (copy), SettingsHandler (copy), GiftValue (copy) ]]
    t.PoolManager = require(GiftClient.GiftPoolManager)
    t.GiftBase = require(script.ClientGiftBase)
    t.ReplicationClient = require(GiftClient.ReplicationClient)

    local tbl = {}

    for k, v in pairs(script.Gifts:QueryDescendants("> ModuleScript")) do
        table.insert(tbl, { v.Name:gsub("Client", ""), v, v:GetAttribute("Priority") or 0 })
    end

    table.sort(tbl, function(p1, p2) --[[ Line: 818 ]]
        return p1[3] > p2[3]
    end)

    for k, v in pairs(tbl) do
        local v1, v2 = unpack(v)

        t.GiftClasses[v1] = require(v2)
        t.GiftsByType[v1] = {}
        t.GiftCount[v1] = {
            Current = 0,
            Collected = 0
        }
    end

    GiftHighlight.Parent = t.PoolManager.CreatePool("GiftShell", t.Assets.GiftShell, 100, true, true).Folder
    TripmineHighlight.Parent = t.PoolManager.CreatePool("TripmineShell", t.Assets.TripmineShell, 100, true, true).Folder
    GiftMagnetStackChanged()
    RunService:BindToRenderStep("UpdateGifts", Enum.RenderPriority.Character.Value + 1, UpdateGifts)
    UpgradeHandler.GetUpgradeChangedSignal("GiftMagnet"):Connect(GiftMagnetStackChanged)
    MovementGiftMagnet.Event:Connect(MovementEvent)
    SettingsHandler.OnSettingsChanged:Connect(SettingsChanged)
    UpgradeHandler.GetUpgradeChangedSignal("HighlightGifts"):Connect(GiftHighlightStackChanged)
    GiftValue.Changed:Connect(function(p1) --[[ Line: 840 | Upvalues: t (ref) ]]
        t.GiftValue = p1
    end)
    t.GiftValue = GiftValue.Value
    SettingsChanged()
    t.UIHandler = require(script.GiftUIHandler)
end

return t

-- Script Path: game:GetService("ReplicatedStorage").SharedModules.Core.Index.UpgradeIndex.RadarPlayer
-- Took 0.69s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
return {
    Name = "Radar Module: Players",
    Description = {
        Default = "<font color=\"#00FF0D\">Highlights</font> other players every <b>12</b> seconds."
    },
    LongDescription = "I\'m the long description, allow me to tell you the fabled tales of this upgrade..",
    Icon = "rbxassetid://133283711647680",
    MaxStack = 1,
    Price = 150,
    Prerequisites = {
        Class = nil,
        Difficulty = 0,
        PlayerCount = 2,
        Stage = 0,
        Enemies = {},
        Upgrades = { "HighlightGifts" },
        Curses = {}
    }
}

-- Script Path: game:GetService("ReplicatedStorage").SharedModules.Core.Index.UpgradeIndex.RadarInstruments
-- Took 0.42s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
return {
    Name = "Radar Module: Instruments",
    Description = {
        Default = "<font color=\"#00FF0D\">Marks</font> the location of <b>Cadence\'s</b> instruments every <b>12</b> seconds. Gives an arrow which <font color=\"#00FF0D\">points</font> towards the nearest instrument."
    },
    LongDescription = "I\'m the long description, allow me to tell you the fabled tales of this upgrade..",
    Icon = "rbxassetid://109743690264439",
    MaxStack = 1,
    Price = 1000,
    Prerequisites = {
        Class = nil,
        Difficulty = 0,
        PlayerCount = 0,
        Stage = 0,
        Enemies = { "Cadence" },
        Upgrades = { "HighlightGifts" },
        Curses = {}
    }
}

-- Script Path: game:GetService("ReplicatedStorage").SharedModules.Core.Index.UpgradeIndex.RadarAltars
-- Took 0.37s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
return {
    Name = "Radar Module: Altars",
    Description = {
        Default = "<font color=\"#00FF0D\">Marks</font> the location of all unused <font color=\"#FF9D00\">altars</font> every <b>12</b> seconds."
    },
    LongDescription = "I\'m the long description, allow me to tell you the fabled tales of this upgrade..",
    Icon = "rbxassetid://82208376362052",
    MaxStack = 1,
    Price = 300,
    Prerequisites = {
        Class = nil,
        Difficulty = 0,
        PlayerCount = 0,
        Stage = 0,
        Enemies = {},
        Upgrades = { "HighlightGifts" },
        Curses = {}
    }
}

-- Script Path: game:GetService("StarterPlayer").StarterCharacterScripts.RadarSlop
-- Took 0.55s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local CollectionService = game:GetService("CollectionService")
local UpgradeHandler = require(game.ReplicatedFirst.ClientModules.UpgradeHandler)
local HumanoidRootPart = script.Parent:WaitForChild("HumanoidRootPart")
local Humanoid = script.Parent:WaitForChild("Humanoid")
local AltarColors = require(game.ReplicatedStorage.Altars.AltarColors)
local v1 = Random.new()

local function f2() --[[ Line: 13 | Upvalues: HumanoidRootPart (copy), v1 (copy) ]]
    for v12, v2 in game.Players:GetPlayers() do
        if v2 ~= game.Players.LocalPlayer then
            local Character = v2.Character

            if Character and Character.Parent then
                local HumanoidRootPart2 = Character:FindFirstChild("HumanoidRootPart")

                if HumanoidRootPart2 then
                    local Magnitude = (HumanoidRootPart2.Position - HumanoidRootPart.Position).Magnitude

                    if not (Magnitude > 1024) then
                        task.delay(Magnitude / 1024, function() --[[ Line: 27 | Upvalues: Character (copy), v1 (ref) ]]
                            local Highlight = Instance.new("Highlight")

                            Highlight.FillTransparency = 1

                            if Character.Humanoid:GetState() == Enum.HumanoidStateType.Dead then
                                Highlight.OutlineColor = Color3.new(255/255, 0/255, 0/255)
                            end

                            Highlight.Parent = Character
                            game.TweenService:Create(Highlight, TweenInfo.new(8, Enum.EasingStyle.Linear), {
                                OutlineTransparency = 1
                            }):Play()
                            game.Debris:AddItem(Highlight, 8.1)
                            game.SoundService.SFXFolder.Radar_Player.PlaybackSpeed = v1:NextNumber(0.9, 1.1)
                            game.SoundService.SFXFolder.Radar_Player:Play()
                        end)
                    end
                end
            end
        end
    end
end

local function f3() --[[ Line: 47 | Upvalues: CollectionService (copy), HumanoidRootPart (copy), AltarColors (copy), v1 (copy) ]]
    for k, v in pairs(CollectionService:GetTagged("Altar")) do
        local v12 = v:FindFirstChild("RealName") and v.RealName.Value or ""
        local v2 = v.Parent
        local HitBox = v2:FindFirstChild("HitBox")

        if HitBox and (v2:FindFirstChild("Altar") and not v2:GetAttribute("AltarUsed")) then
            local Magnitude = (v2.HitBox.Position - HumanoidRootPart.Position).Magnitude

            if not (Magnitude > 1024) then
                task.delay(Magnitude / 2048, function() --[[ Line: 58 | Upvalues: HitBox (copy), AltarColors (ref), v12 (copy), v1 (ref) ]]
                    if not HitBox or HitBox.Parent == nil then
                        return
                    end

                    local v13 = script:WaitForChild("AltarPing"):Clone()

                    v13.Parent = HitBox
                    v13.Tweened.ImageColor3 = AltarColors[v12] or Color3.new(0/255, 0/255, 0/255)
                    v13.ImageLabel.ImageColor3 = AltarColors[v12] or Color3.new(0/255, 0/255, 0/255)
                    v13.Enabled = true
                    game.TweenService:Create(v13.Tweened, TweenInfo.new(1), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(12, 12)
                    }):Play()
                    game.TweenService:Create(v13.ImageLabel, TweenInfo.new(10), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(0, 0)
                    }):Play()
                    game.TweenService:Create(v13.Outline, TweenInfo.new(10), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(0, 0)
                    }):Play()
                    game.Debris:AddItem(v13, 10.1)
                    game.SoundService.SFXFolder.Radar_Altar.PlaybackSpeed = v1:NextNumber(0.97, 1.03)
                    game.SoundService.SFXFolder.Radar_Altar:Play()
                end)
            end
        end
    end
end

local function f4() --[[ Line: 79 | Upvalues: CollectionService (copy), HumanoidRootPart (copy), v1 (copy) ]]
    for k, v in pairs(CollectionService:GetTagged("CadenceOrb")) do
        if v.CanTouch then
            local Magnitude = (v.Position - HumanoidRootPart.Position).Magnitude

            if not (Magnitude > 1024) then
                task.delay(Magnitude / 2048, function() --[[ Line: 89 | Upvalues: v (copy), v1 (ref) ]]
                    local v12 = script:WaitForChild("CadencePing"):Clone()

                    v12.Parent = v
                    v12.Enabled = true
                    game.TweenService:Create(v12.Tweened, TweenInfo.new(1), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(12, 12)
                    }):Play()
                    game.TweenService:Create(v12.ImageLabel, TweenInfo.new(10), {
                        ImageTransparency = 1,
                        Size = UDim2.fromScale(0, 0)
                    }):Play()
                    game.Debris:AddItem(v12, 10.1)
                    game.SoundService.SFXFolder.Radar_Instruments.PlaybackSpeed = v1:NextNumber(1.95, 2.05)
                    game.SoundService.SFXFolder.Radar_Instruments:Play()
                end)
            end
        end
    end
end

while task.wait(12) and Humanoid:GetState() ~= Enum.HumanoidStateType.Dead do
    if UpgradeHandler.IsUpgradeEnabled("RadarPlayer") then
        task.spawn(f2)
    end

    if UpgradeHandler.IsUpgradeEnabled("RadarAltars") then
        task.spawn(f3)
    end

    if UpgradeHandler.IsUpgradeEnabled("RadarInstruments") then
        task.spawn(f4)
    end
end

-- Script Path: game:GetService("Players").Noriko_Ellen.PlayerScripts.ArrowHandler
-- Took 0.55s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UpgradeHandler = require(game.ReplicatedFirst.ClientModules.UpgradeHandler)
local AltarColors = require(game.ReplicatedStorage.Altars.AltarColors)
local Enemies = workspace.Enemies
local Arrows = Instance.new("Folder")

Arrows.Name = "Arrows"
Arrows.Parent = workspace

local LocalPlayer = Players.LocalPlayer
local t = {}
local t2 = {}
local v1 = nil
local v2 = nil
local v3 = Vector3.new(0, 0, 0)

for v4, v5 in script.Arrows:GetChildren() do
    t[v5.Name] = v5
end

for k, v in pairs(AltarColors) do
    if not t[k] then
        local v6 = script.Template:Clone()

        v6.Name = k
        v6.CFrame = CFrame.new(Vector3.new(0, 1000000, 0))
        v6.Color = v
        t[k] = v6
    end
end

local t3 = {}
local v7 = 0
local v8 = false
local v9 = false
local CadenceArrow = t.CadenceArrow

CadenceArrow.CFrame = CFrame.new(Vector3.new(0, 1000000, 0))
CadenceArrow.Parent = Arrows
function CreateArrow(p1, p2) --[[ CreateArrow | Line: 52 | Upvalues: t (copy), Arrows (copy) ]]
    local v1 = t[p2]

    if v1 then
        local t2 = {
            Target = nil,
            Model = v1:Clone(),
            Rotation = CFrame.identity
        }

        t2.Model.Parent = Arrows

        return t2
    end
end
function DestroyArrow(p1) --[[ DestroyArrow | Line: 68 ]]
    if not p1.Model then
        return
    end

    p1.Model:Destroy()
end
function EnemyAdded(p1) --[[ EnemyAdded | Line: 75 | Upvalues: t (copy), t2 (copy) ]]
    local v1 = p1.Name

    if not t[v1] then
        return
    end

    t2[p1] = {
        UseEnemyPosition = true,
        Arrows = {}
    }
    table.insert(t2[p1].Arrows, CreateArrow(p1, v1))
end
function EnemyRemoved(p1) --[[ EnemyRemoved | Line: 88 | Upvalues: t2 (copy) ]]
    local v1 = t2[p1]

    if not v1 then
        return
    end

    for k, v in pairs(v1.Arrows) do
        DestroyArrow(v)
    end

    t2[p1] = nil
end
function CharacterAdded(p1) --[[ CharacterAdded | Line: 99 | Upvalues: v1 (ref), v2 (ref) ]]
    v1 = p1
    v2 = p1:WaitForChild("Head", 9)
end
function GetClosestInstrument() --[[ GetClosestInstrument | Line: 104 | Upvalues: t3 (copy), v3 (ref) ]]
    local v1 = 99999999
    local v2 = nil

    for v32, v4 in t3 do
        local Position = v4.Position
        local Magnitude = (Position - v3).Magnitude

        if Magnitude < v1 then
            v1 = Magnitude
            v2 = Position
        end
    end

    return v2
end
function Render() --[[ Render | Line: 119 | Upvalues: v3 (ref), v2 (ref), v8 (ref), t2 (copy) ]]
    v3 = if v2 then v2.Position or Vector3.new(0, 1000000, 0) else Vector3.new(0, 1000000, 0)

    if v8 and v3 then
        debug.profilebegin("InstrumentArrow")

        local v22 = GetClosestInstrument()

        if v22 then
            t2.CadenceArrow.Arrows[1].Target = v22
        end

        debug.profileend()
    end

    debug.profilebegin("BossArrows")

    for v32, v4 in t2 do
        local v5 = if v4.UseEnemyPosition then v32.Position or Vector3.new(0, 0, 0) else Vector3.new(0, 0, 0)

        for v6, v7 in v4.Arrows do
            if not v4.UseEnemyPosition then
                v5 = v7.Target
            end

            if v7.Enabled then
                if v7.Enabled == 0 and v7.Visible then
                    v7.Visible = false
                    v7.Model.Transparency = 1
                elseif v7.Enabled > 0 and not v7.Visible then
                    v7.Visible = true
                    v7.Model.Transparency = 0
                end
            end

            if v7.Visible == nil or v7.Visible == true then
                local v82 = CFrame.lookAt(v3, v5) - v3

                v7.Rotation = v7.Rotation:Lerp(v82, 0.1)
                v7.Model.CFrame = v7.Rotation * CFrame.new(0, 0, -2 - math.min(1, (v3 - v5).Magnitude / 9)) + v3
            end
        end
    end

    debug.profileend()
end
function StartCadenceArrow(p1) --[[ StartCadenceArrow | Line: 169 | Upvalues: v8 (ref), v7 (ref), t2 (copy), v3 (ref), CadenceArrow (copy) ]]
    if not v8 and v7 ~= 0 then
        v8 = true
        t2.CadenceArrow = {
            UseEnemyPosition = false,
            Arrows = {
                {
                    Target = p1,
                    Rotation = CFrame.lookAt(v3, p1) - v3,
                    Model = CadenceArrow
                }
            }
        }
    end
end
function StopCadenceArrow() --[[ StopCadenceArrow | Line: 185 | Upvalues: v8 (ref), t2 (copy), CadenceArrow (copy) ]]
    if v8 then
        v8 = false
        t2.CadenceArrow = nil
        CadenceArrow.CFrame = CFrame.new(Vector3.new(0, 1000000, 0))
    end
end
function OrbAdded(p1) --[[ OrbAdded | Line: 194 | Upvalues: t3 (copy), v7 (ref), v9 (ref) ]]
    if t3[p1] then
        return
    end

    v7 = v7 + 1
    t3[p1] = p1

    if v9 and v7 == 1 then
        StartCadenceArrow(t3[p1].Position)
    end

    p1:GetPropertyChangedSignal("CanTouch"):Connect(function() --[[ Line: 204 | Upvalues: p1 (copy) ]]
        OrbRemoved(p1)
    end)
end
function OrbRemoved(p1) --[[ OrbRemoved | Line: 209 | Upvalues: t3 (copy), v7 (ref), v9 (ref) ]]
    if not t3[p1] then
        return
    end

    v7 = v7 - 1
    t3[p1] = nil

    if not v9 or v7 ~= 0 then
        return
    end

    StopCadenceArrow()
end

local function AltarAdded(p1) --[[ AltarAdded | Line: 220 | Upvalues: t2 (copy), t (copy), Arrows (copy), v3 (ref) ]]
    local v1 = p1:GetAttribute("Name") or ""
    local Position = p1:WaitForChild("Hitbox").Position
    local v2 = t2[v1]

    if not v2 then
        local t3 = {
            UseEnemyPosition = false,
            Count = 0,
            Arrows = {}
        }

        t2[v1] = t3
        v2 = t3
    end

    local v32 = t[v1]

    if not v32 then
        return
    end

    local v4 = v32:Clone()

    v4.Parent = Arrows
    v2.Count = v2.Count + 1

    local t3 = {
        Visible = false,
        Target = Position,
        Rotation = CFrame.lookAt(v3, Position) - v3,
        Model = v4
    }

    t3.Enabled = if p1:HasTag("Voting") then 1 else 0
    v2.Arrows[p1] = t3
end

local function AltarRemoved(p1) --[[ AltarRemoved | Line: 252 | Upvalues: t2 (copy) ]]
    local v1 = p1:GetAttribute("Name") or ""
    local v2 = t2[v1]

    if not v2 then
        return
    end

    local v3 = v2.Arrows[p1]

    if v3 then
        DestroyArrow(v3)
        v2.Arrows[p1] = nil
        v2.Count = v2.Count - 1
    end

    if not (v2.Count <= 0) then
        return
    end

    t2[v1] = nil
end

UpgradeHandler.GetUpgradeChangedSignal("RadarInstruments"):Connect(function(p1) --[[ Line: 271 | Upvalues: v9 (ref) ]]
    if p1 == 0 then
        v9 = false
        StopCadenceArrow()
    else
        v9 = true
        StartCadenceArrow(GetClosestInstrument() or Vector3.new(0, 1000000, 0))
    end
end)
CollectionService:GetInstanceAddedSignal("CadenceOrb"):Connect(OrbAdded)
CollectionService:GetInstanceRemovedSignal("CadenceOrb"):Connect(OrbRemoved)
CollectionService:GetInstanceAddedSignal("Altar"):Connect(AltarAdded)
CollectionService:GetInstanceRemovedSignal("Altar"):Connect(AltarRemoved)
CollectionService:GetInstanceAddedSignal("Voting"):Connect(function(p1) --[[ Line: 289 | Upvalues: UpgradeHandler (copy), t2 (copy) ]]
    if not UpgradeHandler.IsUpgradeEnabled("RadarAltars") then
        return
    end

    local v1 = t2[p1:GetAttribute("Name") or ""]

    if not v1 then
        return
    end

    local v2 = v1.Arrows[p1]

    if not v2 then
        return
    end

    v2.Enabled = v2.Enabled + 1
end)
CollectionService:GetInstanceRemovedSignal("Voting"):Connect(function(p1) --[[ Line: 305 | Upvalues: t2 (copy) ]]
    local v1 = t2[p1:GetAttribute("Name") or ""]

    if not v1 then
        return
    end

    local v2 = v1.Arrows[p1]

    if not (v2 and v2.Enabled > 0) then
        return
    end

    v2.Enabled = v2.Enabled - 1
end)
Enemies.ChildAdded:Connect(EnemyAdded)
Enemies.ChildRemoved:Connect(EnemyRemoved)
LocalPlayer.CharacterAdded:Connect(CharacterAdded)

if not LocalPlayer.Character then
    RunService.RenderStepped:Connect(Render)

    return
end

CharacterAdded(LocalPlayer.Character)
RunService.RenderStepped:Connect(Render)
