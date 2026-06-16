-- Script Path: game:GetService("ReplicatedFirst").ClientModules.ProjectileClient.ProjectileClientHandler
-- Took 0.4s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProjectileReplication = ReplicatedStorage.ProjectileShared.Remotes.ProjectileReplication
local CurrentCamera = workspace.CurrentCamera
local Buffer = require(ReplicatedStorage.ProjectileShared.Buffer)
local ProjectileEnums = require(ReplicatedStorage.ProjectileShared.ProjectileEnums)
local t = {
	ProjectileModules = {},
	ProjectileEnums = ProjectileEnums,
	ProjectileIndex = 0,
	Projectiles = {},
	ForceRenderQueue = {},
	HitboxParams = {},
	ProjectileBase = nil,
	HitboxFPS = 0.03333333333333333,
}

function t.new(p1, p2, p3, p4) --[[ new | Line: 38 | Upvalues: ProjectileEnums (copy), t (copy) ]]
	if typeof(p2) == "number" then
		p2 = ProjectileEnums[p2]
	end

	local v1 = t.ProjectileModules[p2]

	if not v1 then
		warn(p2, "has no module on the client")

		return
	end

	if not p1 then
		local v2 = t

		v2.ProjectileIndex = v2.ProjectileIndex + 1
		p1 = t.ProjectileIndex
	end

	if p3 == nil then
		p3 = if p4 then v1:ReadParams(p4) else {}
	end

	if t.HitboxParams[p2] == nil and v1.CreateHitboxParams then
		t.HitboxParams[p2] = v1:CreateHitboxParams()
	end

	t.Projectiles[p1] = v1.new(p1, p2, p3, p4)
end
function t.ClearProjectiles() --[[ ClearProjectiles | Line: 67 | Upvalues: t (copy) ]]
	t.ProjectileIndex = 0

	for k, v in pairs(t.Projectiles) do
		v:Destroy(false)
	end

	table.clear(t.Projectiles)
end

local function UpdateProjectiles(p1) --[[ UpdateProjectiles | Line: 77 | Upvalues: t (copy), CurrentCamera (copy) ]]
	local SavedQualityLevel = UserSettings().GameSettings.SavedQualityLevel.Value

	if SavedQualityLevel == 0 then
		SavedQualityLevel = 5
	end

	local v1 = math.sqrt(SavedQualityLevel / 5) * 768
	local v2 = math.sqrt(SavedQualityLevel / 10) * 256

	debug.profilebegin("ProjectileUpdate")
	debug.profilebegin("UpdateHitboxParams")

	for k, v in pairs(t.ProjectileModules) do
		if v.CreateHitboxParams then
			t.HitboxParams[k] = v:CreateHitboxParams()
		end
	end

	debug.profileend()
	debug.profilebegin("ProjectileMove")

	for k, v in pairs(t.Projectiles) do
		v:Tick((math.min(p1, 0.03333333333333333)))
	end

	debug.profileend()
	debug.profilebegin("SelectProjectiles")

	local LookVector = CurrentCamera.CFrame.LookVector
	local Position = CurrentCamera.CFrame.Position
	local t2 = {}

	for k, v in pairs(t.Projectiles) do
		local v3 = v.Position - Position
		local Magnitude = v3.Magnitude

		if not (v1 < Magnitude or v.Size.Magnitude < Magnitude and LookVector:Dot(v3) < 0) then
			table.insert(t2, { v, Magnitude })
		end
	end

	debug.profileend()
	debug.profilebegin("SortProjectiles")
	table.sort(t2, function(p1, p2) --[[ Line: 145 ]]
		return p1[2] < p2[2]
	end)
	debug.profileend()
	debug.profilebegin("GetRenderCFrames")

	local t3 = {}
	local t4 = {}

	for v4, v5 in t2 do
		local v6 = v5[1]

		if not v6.ForceRendering then
			table.insert(t3, v6.Model)
			table.insert(t4, v6:GetRenderCFrame())

			if v2 <= #t3 then
				break
			end
		end
	end

	debug.profileend()
	debug.profilebegin("ForceRender")

	for k in pairs(t.ForceRenderQueue) do
		local v7 = t.Projectiles[k]

		if v7 and not v7.Destroying then
			v7.ForceRendering = false
			table.insert(t3, v7.Model)
			table.insert(t4, v7:GetRenderCFrame())
		end
	end

	table.clear(t.ForceRenderQueue)
	debug.profileend()
	debug.profilebegin("Render")
	workspace:BulkMoveTo(t3, t4, Enum.BulkMoveMode.FireCFrameChanged)
	debug.profileend()
	debug.profileend()
end

local function Received(p1, p2) --[[ Received | Line: 184 | Upvalues: Buffer (copy), t (copy), ProjectileEnums (copy) ]]
	local v2 = Buffer.new(p1, p2)

	while v2.Offset < v2.Size do
		local v3 = t

		v3.ProjectileIndex = v3.ProjectileIndex + 1
		t.new(t.ProjectileIndex, ProjectileEnums[v2:ReadU8()], nil, v2)
	end
end

function t.Initialize() --[[ Initialize | Line: 198 | Upvalues: t (copy), ProjectileReplication (copy), Received (copy) ]]
	t.ProjectileBase = require(script.ClientProjectileBase)

	for k, v in pairs(script.Projectiles:GetChildren()) do
		t.ProjectileModules[v.Name:gsub("Client", "")] = require(v)
	end

	ProjectileReplication.OnClientEvent:Connect(Received)
	workspace.Beacon:GetAttributeChangedSignal("Beacon"):Connect(function() --[[ Line: 206 | Upvalues: t (ref) ]]
		if workspace.Beacon:GetAttribute("Beacon") then
			return
		end

		t.ClearProjectiles()
	end)
end
RunService:BindToRenderStep("UpdateProjectiles", Enum.RenderPriority.Character.Value + 1, UpdateProjectiles)

return t

-- Script Path: game:GetService("ReplicatedFirst").ClientModules.ProjectileClient.ProjectileClientHandler.Projectiles.BulletClient
-- Took 0.42s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Died = game.ReplicatedStorage.Events.Died
local PoolManager = require(game.ReplicatedStorage.ProjectileShared.PoolManager)
local SettingsHandler = require(game.ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)
local v1 = require(script.Parent.Parent)
local ProjectileBase = v1.ProjectileBase
local v2 = script.Name:gsub("Client", "")
local Bullet = script.Bullet
local BulletColorblind = script.BulletColorblind

PoolManager.CreatePool(v2, Bullet, if RunService:IsStudio() then 16 else 64)

local v4 = setmetatable({}, ProjectileBase)

v4.__index = v4
function v4.new(p1, p2, p3) --[[ new | Line: 23 | Upvalues: ProjectileBase (copy), v4 (copy), v1 (copy), PoolManager (copy), v2 (copy) ]]
    local v12 = ProjectileBase.new(p1, p2)

    setmetatable(v12, v4)
    v12.Position = p3.Position
    v12.Direction = p3.Direction
    v12.Speed = p3.Speed or 56
    v12.Acceleration = p3.Acceleration or Vector3.new(0, 0, 0)
    v12.Velocity = p3.Velocity or v12.Direction * v12.Speed
    v12.Jolt = p3.Jolt or Vector3.new(0, 0, 0)
    v12.Timeout = p3.Timeout
    v12.TimeElapsed = 0
    v12.lastHitboxCheck = 0
    v12.HitboxFPS = v1.HitboxFPS
    v12.HitboxRadius = 0.7
    v12.Model = PoolManager.GetItemFromPool(v2)
    v12.Size = v12.Model.Size
    v12.Model.Transparency = 0
    v12.Model.Aura.Boom.Enabled = true
    v12.Model.Aura.White.Enabled = true
    v12.Model.Sound:Play()
    ColorblindSlop(v12.Model)
    v12:ForceRender()

    return v12
end
function v4.ReadParams(p1, p2) --[[ ReadParams | Line: 65 ]]
    local t = {}
    local v1 = p2:ReadF24()

    t.Position = Vector3.new(v1, p2:ReadF24(), p2:ReadF24())

    local v3 = p2:ReadF16()

    t.Direction = Vector3.new(v3, p2:ReadF16(), p2:ReadF16())
    t.Timeout = p2:ReadF16()
    t.Speed = p2:ReadF16()

    return t
end
function v4.GetRenderCFrame(p1) --[[ GetRenderCFrame | Line: 78 ]]
    return CFrame.new(p1.Position)
end
function v4.CreateHitboxParams(p1) --[[ CreateHitboxParams | Line: 83 ]]
    local t = { workspace.CurrentRooms }

    for v1, v2 in game.Players:GetPlayers() do
        if v2.Character then
            table.insert(t, v2.Character:FindFirstChild("Hitbox"))
        end
    end

    local v3 = RaycastParams.new()

    v3.FilterType = Enum.RaycastFilterType.Include
    v3.FilterDescendantsInstances = t
    v3.RespectCanCollide = true

    return v3
end
function v4.GetHitboxParams(p1) --[[ GetHitboxParams | Line: 98 | Upvalues: v1 (copy), v2 (copy) ]]
    return v1.HitboxParams[v2]
end
function v4.onDestroy(p1, p2) --[[ onDestroy | Line: 103 ]]
    p1.Model.Transparency = 1
    p1.Model.Sound:Stop()
    p1.Model.Aura.Boom.Enabled = false
    p1.Model.Aura.White.Enabled = false

    if p2 then
        p1:ForceRender()
        p1.Model.Impact.Sparkles:Emit(math.random(32, 40))
        p1.Model.Impact.Boom:Emit(2)
        p1.Model.Impact.Wave:Emit(2)
        p1.Model.Impact.Hit:Play()
        task.delay(2, function() --[[ Line: 119 | Upvalues: p1 (copy) ]]
            p1:Return()
        end)
    else
        p1:Return()
    end
end
function v4.onTick(p1, p2) --[[ onTick | Line: 126 | Upvalues: Players (copy), LocalPlayer (copy), Died (copy) ]]
    p1:Move(p2)

    local v1 = false

    if tick() - p1.lastHitboxCheck >= p1.HitboxFPS then
        p1.lastHitboxCheck = tick()

        local v2 = p1.Velocity * p1.HitboxFPS
        local v3 = workspace:Spherecast(p1.Position - v2 * 3, p1.HitboxRadius, v2 * 3, p1:GetHitboxParams())

        if v3 and v3.Instance then
            v1 = true

            if Players:GetPlayerFromCharacter(v3.Instance.Parent) == LocalPlayer then
                Died:FireServer("Guardian", p1.Velocity, game.ReplicatedStorage.Level.Value)
            end
        end
    end

    if not (v1 or (if p1.TimeElapsed >= p1.Timeout then true else false)) then
        return
    end

    p1:Destroy(true)
end
function ColorblindSlop(p1) --[[ ColorblindSlop | Line: 155 | Upvalues: SettingsHandler (copy), BulletColorblind (copy), Bullet (copy) ]]
    if p1:GetAttribute("Colorblind") == SettingsHandler.Get({ "Graphics", "Colorblind" }) then
        return
    end

    p1:SetAttribute("Colorblind", SettingsHandler.Get({ "Graphics", "Colorblind" }))

    if SettingsHandler.Get({ "Graphics", "Colorblind" }) then
        p1.Color = BulletColorblind.Color
        p1.Aura.Boom.Color = BulletColorblind.Aura.Boom.Color
        p1.Aura.White.Color = BulletColorblind.Aura.White.Color
        p1.Impact.Boom.Color = BulletColorblind.Impact.Boom.Color
        p1.Impact.Sparkles.Color = BulletColorblind.Impact.Sparkles.Color
        p1.Impact.Wave.Color = BulletColorblind.Impact.Wave.Color
    else
        p1.Color = Bullet.Color
        p1.Aura.Boom.Color = Bullet.Aura.Boom.Color
        p1.Aura.White.Color = Bullet.Aura.White.Color
        p1.Impact.Boom.Color = Bullet.Impact.Boom.Color
        p1.Impact.Sparkles.Color = Bullet.Impact.Sparkles.Color
        p1.Impact.Wave.Color = Bullet.Impact.Wave.Color
    end
end

return v4

-- Script Path: game:GetService("ReplicatedFirst").ClientModules.ProjectileClient.ProjectileClientHandler.Projectiles.LaserBulletClient
-- Took 0.46s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Died = game.ReplicatedStorage.Events.Died
local PoolManager = require(game.ReplicatedStorage.ProjectileShared.PoolManager)
local v1 = require(script.Parent.Parent)
local ProjectileBase = v1.ProjectileBase
local v2 = script.Name:gsub("Client", "")

PoolManager.CreatePool(v2, script.Bullet, if RunService:IsStudio() then 16 else 64)

local v4 = setmetatable({}, ProjectileBase)

v4.__index = v4
function v4.new(p1, p2, p3) --[[ new | Line: 21 | Upvalues: ProjectileBase (copy), v4 (copy), v1 (copy), PoolManager (copy), v2 (copy) ]]
    local v12 = ProjectileBase.new(p1, p2)

    setmetatable(v12, v4)
    v12.Position = p3.Position
    v12.Direction = p3.Direction
    v12.Speed = p3.Speed or 80
    v12.Acceleration = p3.Acceleration or Vector3.new(0, 0, 0)
    v12.Velocity = p3.Velocity or v12.Direction * v12.Speed
    v12.Jolt = p3.Jolt or Vector3.new(0, 0, 0)
    v12.Timeout = p3.Timeout
    v12.TimeElapsed = 0
    v12.lastHitboxCheck = 0
    v12.HitboxFPS = v1.HitboxFPS
    v12.HitboxRadius = 0.7
    v12.BypassWall = p3.BypassWall or false
    v12.Model = PoolManager.GetItemFromPool(v2)
    v12.Size = v12.Model.Size
    v12.Model.Color = p3.Color or Color3.fromRGB(203, 80, 255)
    v12.Model.Transparency = 0
    v12.Model.ParticleEmitter.Enabled = true
    v12.Model.Sound:Play()
    v12.RotationOffset = math.random(-100000, 100000)
    v12:ForceRender()

    return v12
end
function v4.ReadParams(p1, p2) --[[ ReadParams | Line: 63 ]]
    local t = {}
    local v1 = p2:ReadF24()

    t.Position = Vector3.new(v1, p2:ReadF24(), p2:ReadF24())

    local v3 = p2:ReadF16()

    t.Direction = Vector3.new(v3, p2:ReadF16(), p2:ReadF16())
    t.Timeout = p2:ReadF16()

    return t
end
function v4.GetRenderCFrame(p1) --[[ GetRenderCFrame | Line: 75 ]]
    local v1 = CFrame.new(p1.Position, p1.Position + p1.Direction) * CFrame.new(0, 0, p1.Size.Z / 2 - 0.5)
    local Angles = CFrame.Angles

    return v1 * Angles(math.pi, 0, (math.rad(p1.RotationOffset + p1.TimeElapsed * 50)))
end
function v4.CreateHitboxParams(p1) --[[ CreateHitboxParams | Line: 80 ]]
    local t = { workspace.CurrentRooms }

    for v1, v2 in game.Players:GetPlayers() do
        if v2.Character then
            table.insert(t, v2.Character:FindFirstChild("Hitbox"))
        end
    end

    local v3 = RaycastParams.new()

    v3.FilterType = Enum.RaycastFilterType.Include
    v3.FilterDescendantsInstances = t
    v3.RespectCanCollide = true

    return v3
end
function v4.GetHitboxParams(p1) --[[ GetHitboxParams | Line: 95 | Upvalues: v1 (copy), v2 (copy) ]]
    return v1.HitboxParams[v2]
end
function v4.onDestroy(p1, p2) --[[ onDestroy | Line: 100 ]]
    p1.Model.Transparency = 1
    p1.Model.ParticleEmitter.Enabled = false
    p1.Model.Sound:Stop()

    if p2 then
        p1:ForceRender()
        p1.Model.Impact.Aftereffect:Emit(math.random(21, 27))
        p1.Model.Impact.Boom:Emit(2)
        p1.Model.Impact.Wave:Emit(2)
        p1.Model.Impact.Black:Emit(2)
        p1.Model.Impact.Hit:Play()
        task.delay(2, function() --[[ Line: 116 | Upvalues: p1 (copy) ]]
            p1:Return()
        end)
    else
        p1:Return()
    end
end
function v4.onTick(p1, p2) --[[ onTick | Line: 123 | Upvalues: Players (copy), LocalPlayer (copy), Died (copy) ]]
    p1:Move(p2)

    local v1 = false

    if tick() - p1.lastHitboxCheck >= p1.HitboxFPS then
        p1.lastHitboxCheck = tick()

        local v2 = p1.Velocity * p1.HitboxFPS
        local v3 = workspace:Spherecast(p1.Position - v2 * 3, p1.HitboxRadius, v2 * 3, p1:GetHitboxParams())

        if v3 and v3.Instance then
            v1 = true

            local v4 = Players:GetPlayerFromCharacter(v3.Instance.Parent)

            if v4 and v4 == LocalPlayer then
                Died:FireServer("Skinwalker", p1.Velocity, game.ReplicatedStorage.Level.Value)
            end
        end
    end

    local v5 = if p1.TimeElapsed >= p1.Timeout then true else false

    if p1.BypassWall then
        v1 = false
    end

    if not (v1 or v5) then
        return
    end

    p1:Destroy(true)
end

return v4

-- Script Path: game:GetService("ReplicatedFirst").ClientModules.ProjectileClient.ProjectileClientHandler.Projectiles.RoarBulletClient
-- Took 0.58s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Died = game.ReplicatedStorage.Events.Died
local PoolManager = require(game.ReplicatedStorage.ProjectileShared.PoolManager)
local v1 = require(script.Parent.Parent)
local ProjectileBase = v1.ProjectileBase
local v2 = script.Name:gsub("Client", "")

PoolManager.CreatePool(v2, script.Bullet, if RunService:IsStudio() then 16 else 64)

local v4 = setmetatable({}, ProjectileBase)

v4.__index = v4
function v4.new(p1, p2, p3) --[[ new | Line: 21 | Upvalues: ProjectileBase (copy), v4 (copy), v1 (copy), PoolManager (copy), v2 (copy) ]]
    local v12 = ProjectileBase.new(p1, p2)

    setmetatable(v12, v4)
    v12.Position = p3.Position
    v12.Direction = p3.Direction
    v12.Speed = p3.Speed or 125
    v12.Acceleration = p3.Acceleration or Vector3.new(0, 0, 0)
    v12.Velocity = p3.Velocity or v12.Direction * v12.Speed
    v12.Jolt = p3.Jolt or Vector3.new(0, 0, 0)
    v12.Timeout = p3.Timeout
    v12.TimeElapsed = 0
    v12.lastHitboxCheck = 0
    v12.HitboxFPS = v1.HitboxFPS
    v12.HitboxRadius = 5
    v12.Model = PoolManager.GetItemFromPool(v2)
    v12.Size = v12.Model.Size
    v12.Model.Transparency = 0
    v12.Model.Aura.Boom.Enabled = true
    v12.Model.Aura.Boom2.Enabled = true
    v12.Model.Aura.Boom3.Enabled = true
    v12.Model.Aura.Trail.Enabled = true
    v12.Model.Sound:Play()
    v12:ForceRender()

    return v12
end
function v4.ReadParams(p1, p2) --[[ ReadParams | Line: 63 ]]
    local t = {}
    local v1 = p2:ReadF24()

    t.Position = Vector3.new(v1, p2:ReadF24(), p2:ReadF24())

    local v3 = p2:ReadF16()

    t.Direction = Vector3.new(v3, p2:ReadF16(), p2:ReadF16())
    t.Timeout = p2:ReadF16()

    return t
end
function v4.GetRenderCFrame(p1) --[[ GetRenderCFrame | Line: 75 ]]
    return CFrame.new(p1.Position)
end
function v4.CreateHitboxParams(p1) --[[ CreateHitboxParams | Line: 80 ]]
    local t = { workspace.CurrentRooms }

    for v1, v2 in game.Players:GetPlayers() do
        if v2.Character then
            table.insert(t, v2.Character:FindFirstChild("Hitbox"))
        end
    end

    local v3 = RaycastParams.new()

    v3.FilterType = Enum.RaycastFilterType.Include
    v3.FilterDescendantsInstances = t
    v3.RespectCanCollide = true

    return v3
end
function v4.GetHitboxParams(p1) --[[ GetHitboxParams | Line: 95 | Upvalues: v1 (copy), v2 (copy) ]]
    return v1.HitboxParams[v2]
end
function v4.onDestroy(p1, p2) --[[ onDestroy | Line: 100 ]]
    p1.Model.Transparency = 1
    p1.Model.Sound:Stop()
    p1.Model.Aura.Boom.Enabled = false
    p1.Model.Aura.Boom2.Enabled = false
    p1.Model.Aura.Boom3.Enabled = false
    p1.Model.Aura.Trail.Enabled = false

    if p2 then
        p1:ForceRender()
        p1.Model.Impact.Sparkles:Emit(math.random(32, 40))
        p1.Model.Impact.Boom:Emit(2)
        p1.Model.Impact.Wave:Emit(2)
        p1.Model.Impact.Hit:Play()
        task.delay(2, function() --[[ Line: 118 | Upvalues: p1 (copy) ]]
            p1:Return()
        end)
    else
        p1:Return()
    end
end
function v4.onTick(p1, p2) --[[ onTick | Line: 125 | Upvalues: Players (copy), LocalPlayer (copy), Died (copy) ]]
    p1:Move(p2)

    local v1 = false

    if tick() - p1.lastHitboxCheck >= p1.HitboxFPS then
        p1.lastHitboxCheck = tick()

        local v2 = p1.Velocity * p1.HitboxFPS
        local v3 = workspace:Spherecast(p1.Position - v2 * 3, p1.HitboxRadius, v2 * 3, p1:GetHitboxParams())

        if v3 and v3.Instance then
            v1 = true

            local v4 = Players:GetPlayerFromCharacter(v3.Instance.Parent)

            if v4 and v4 == LocalPlayer then
                Died:FireServer("Celestial", p1.Velocity, game.ReplicatedStorage.Level.Value)
            end
        end
    end

    if not (v1 or (if p1.TimeElapsed >= p1.Timeout then true else false)) then
        return
    end

    p1:Destroy(true)
end

return v4

-- Script Path: game:GetService("ReplicatedFirst").ClientModules.ProjectileClient.ProjectileClientHandler.Projectiles.ShotgunClient
-- Took 0.38s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
game:GetService("RunService")
require(game.ReplicatedStorage.ProjectileShared.PoolManager)

local v1 = require(script.Parent.Parent)

script.Name:gsub("Client", "")

local v2 = setmetatable({}, v1.ProjectileBase)

v2.__index = v2
function v2.new(p1, p2, p3, p4) --[[ new | Line: 14 | Upvalues: v1 (copy) ]]
    local ProjectileType = p3.ProjectileType
    local v12 = v1.ProjectileModules[ProjectileType]

    if not v12 then
        warn("no module for", ProjectileType, "shotgun")

        return
    end

    local v2 = v12:ReadParams(p4)
    local v3 = p3.BulletAmount or 7
    local v4 = CFrame.new(Vector3.new(0, 0, 0), v2.Direction)
    local v5 = 6.283185307179586 / v3

    for i = 1, v3 do
        v2.Direction = (v4 * CFrame.Angles(0, 0, i * v5) * CFrame.Angles(math.pi / p3.Spread, 0, 0)).LookVector
        v2.ShotgunIndex = i
        v1.new(nil, ProjectileType, v2)
    end

    return nil
end
function v2.ReadParams(p1, p2) --[[ ReadParams | Line: 42 | Upvalues: v1 (copy) ]]
    return {
        ProjectileType = v1.ProjectileEnums[p2:ReadU8()],
        Spread = p2:ReadF16(),
        BulletAmount = p2:ReadU8()
    }
end

return v2

-- Script Path: game:GetService("ReplicatedFirst").ClientModules.ProjectileClient.ProjectileClientHandler.Projectiles.SlowdownTest_helloweekendsClient
-- Took 0.5s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Died = game.ReplicatedStorage.Events.Died
local PoolManager = require(game.ReplicatedStorage.ProjectileShared.PoolManager)
local v1 = require(script.Parent.Parent)
local ProjectileBase = v1.ProjectileBase
local v2 = script.Name:gsub("Client", "")

PoolManager.CreatePool(v2, script.Bullet, if RunService:IsStudio() then 16 else 64)

local v4 = setmetatable({}, ProjectileBase)

v4.__index = v4
function v4.new(p1, p2, p3) --[[ new | Line: 31 | Upvalues: ProjectileBase (copy), v4 (copy), v1 (copy), PoolManager (copy), v2 (copy) ]]
    local v12 = ProjectileBase.new(p1, p2)

    setmetatable(v12, v4)
    v12.Position = p3.Position
    v12.Direction = p3.Direction
    v12.Speed = p3.Speed or 56
    v12.Acceleration = p3.Acceleration or Vector3.new(0, 0, 0)
    v12.Velocity = p3.Velocity or v12.Direction * v12.Speed
    v12.Jolt = p3.Jolt or Vector3.new(0, 0, 0)
    v12.TweenInfo = TweenInfo.new(2.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    v12.TweenDelay = 0.5
    v12.Timeout = p3.Timeout
    v12.TimeElapsed = 0
    v12.lastHitboxCheck = 0
    v12.HitboxFPS = v1.HitboxFPS
    v12.HitboxRadius = 0.7
    v12.Model = PoolManager.GetItemFromPool(v2)
    v12.Size = v12.Model.Size
    v12.Model.Transparency = 0
    v12.Model.Aura.Boom.Enabled = true
    v12.Model.Aura.White.Enabled = true
    v12.Model.Sound:Play()
    v12:ForceRender()

    return v12
end
function v4.ReadParams(p1, p2) --[[ ReadParams | Line: 75 ]]
    local t = {}
    local v1 = p2:ReadF24()

    t.Position = Vector3.new(v1, p2:ReadF24(), p2:ReadF24())

    local v3 = p2:ReadF16()

    t.Direction = Vector3.new(v3, p2:ReadF16(), p2:ReadF16())
    t.Timeout = p2:ReadF16()

    return t
end
function v4.GetRenderCFrame(p1) --[[ GetRenderCFrame | Line: 87 ]]
    return CFrame.new(p1.Position)
end
function v4.CreateHitboxParams(p1) --[[ CreateHitboxParams | Line: 92 ]]
    local t = { workspace.CurrentRooms }

    for v1, v2 in game.Players:GetPlayers() do
        if v2.Character then
            table.insert(t, v2.Character:FindFirstChild("Hitbox"))
        end
    end

    local v3 = RaycastParams.new()

    v3.FilterType = Enum.RaycastFilterType.Include
    v3.FilterDescendantsInstances = t
    v3.RespectCanCollide = true

    return v3
end
function v4.GetHitboxParams(p1) --[[ GetHitboxParams | Line: 107 | Upvalues: v1 (copy), v2 (copy) ]]
    return v1.HitboxParams[v2]
end
function v4.onDestroy(p1, p2) --[[ onDestroy | Line: 112 ]]
    p1.Model.Transparency = 1
    p1.Model.Sound:Stop()
    p1.Model.Aura.Boom.Enabled = false
    p1.Model.Aura.White.Enabled = false

    if p2 then
        p1:ForceRender()
        p1.Model.Impact.Sparkles:Emit(math.random(32, 40))
        p1.Model.Impact.Boom:Emit(2)
        p1.Model.Impact.Wave:Emit(2)
        p1.Model.Impact.Hit:Play()
        task.delay(2, function() --[[ Line: 128 | Upvalues: p1 (copy) ]]
            p1:Return()
        end)
    else
        p1:Return()
    end
end
function v4.onTick(p1, p2) --[[ onTick | Line: 135 | Upvalues: TweenService (copy), Players (copy), LocalPlayer (copy), Died (copy) ]]
    p1:Move(p2 * (if p1.TimeElapsed >= p1.TweenDelay then math.lerp(1, 0, (TweenService:GetValue(math.clamp((p1.TimeElapsed - p1.TweenDelay) / p1.TweenInfo.Time, 0, 1), p1.TweenInfo.EasingStyle, p1.TweenInfo.EasingDirection))) else 1))

    local v5 = false

    if tick() - p1.lastHitboxCheck >= p1.HitboxFPS then
        p1.lastHitboxCheck = tick()

        local v6 = p1.Velocity * p1.HitboxFPS
        local v7 = workspace:Spherecast(p1.Position - v6 * 3, p1.HitboxRadius, v6 * 3, p1:GetHitboxParams())

        if v7 and v7.Instance then
            v5 = true

            local v8 = Players:GetPlayerFromCharacter(v7.Instance.Parent)

            if v8 and v8 == LocalPlayer then
                Died:FireServer("Guardian", p1.Velocity, game.ReplicatedStorage.Level.Value)
            end
        end
    end

    if not (v5 or (if p1.TimeElapsed >= p1.Timeout then true else false)) then
        return
    end

    p1:Destroy(true)
end

return v4
