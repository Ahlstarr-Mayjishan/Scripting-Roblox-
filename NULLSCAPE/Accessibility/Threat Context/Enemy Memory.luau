--!nocheck
-- [[
--  NULLSCAPE - Threat Context Enemy Memory
--  Tracks moving enemy parts and exposes short-horizon threat queries.
-- ]]

local Workspace = game:GetService("Workspace")

local EnemyMemory = {
	Entries = {},
	LastRefreshAt = 0,
}

local REFRESH_INTERVAL = 0.08
local DEFAULT_RADIUS = 48
local enemyIds = setmetatable({}, { __mode = "k" })
local nextEnemyId = 0
local PREFERRED_PARTS = {
	"HumanoidRootPart",
	"RootPart",
	"HitBox",
	"Hitbox",
	"Torso",
	"Head",
	"head",
	"Part",
	"Mesh",
}

local function isAlive(instance)
	return instance and instance.Parent and instance:IsDescendantOf(Workspace)
end

local function getEnemyPart(enemy)
	if not isAlive(enemy) then
		return nil
	end

	if enemy:IsA("BasePart") then
		return enemy
	end

	if enemy:IsA("Model") and enemy.PrimaryPart then
		return enemy.PrimaryPart
	end

	for _, name in ipairs(PREFERRED_PARTS) do
		local part = enemy:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end

	return enemy:FindFirstChildWhichIsA("BasePart", true)
end

local function getPartVelocity(part, previous, now)
	local velocity = part.AssemblyLinearVelocity or part.Velocity
	if velocity and velocity.Magnitude > 0.05 then
		return velocity
	end

	if previous and previous.Position and previous.SeenAt and now > previous.SeenAt then
		local dt = math.max(now - previous.SeenAt, 1 / 240)
		return (part.Position - previous.Position) / dt
	end

	return Vector3.zero
end

local function getEnemyId(enemy)
	if not enemy then
		return nil
	end

	local existing = enemyIds[enemy]
	if existing then
		return existing
	end

	nextEnemyId += 1
	local id = "enemy:" .. tostring(nextEnemyId)
	enemyIds[enemy] = id
	return id
end

local function rememberEnemy(enemy, now)
	local part = getEnemyPart(enemy)
	if not part then
		return nil
	end

	local id = getEnemyId(enemy)
	local previous = EnemyMemory.Entries[id]
	local entry = {
		Id = id,
		Enemy = enemy,
		Part = part,
		Name = enemy.Name,
		Position = part.Position,
		Velocity = getPartVelocity(part, previous, now),
		Size = part.Size,
		SeenAt = now,
	}

	EnemyMemory.Entries[id] = entry
	return entry
end

local function pruneDead()
	for id, entry in pairs(EnemyMemory.Entries) do
		if not (isAlive(entry.Enemy) and isAlive(entry.Part)) then
			EnemyMemory.Entries[id] = nil
		end
	end
end

function EnemyMemory.refresh(force)
	local now = time()
	if not force and now - EnemyMemory.LastRefreshAt < REFRESH_INTERVAL then
		pruneDead()
		return true
	end

	EnemyMemory.LastRefreshAt = now
	pruneDead()

	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return false
	end

	for _, enemy in ipairs(enemies:GetChildren()) do
		rememberEnemy(enemy, now)
	end

	return true
end

function EnemyMemory.getNearbyThreats(position, radius)
	EnemyMemory.refresh(false)

	local results = {}
	local queryRadius = tonumber(radius) or DEFAULT_RADIUS
	for _, entry in pairs(EnemyMemory.Entries) do
		if isAlive(entry.Part) then
			entry.Position = entry.Part.Position
			local offset = entry.Position - position
			local distance = offset.Magnitude
			if distance <= queryRadius then
				entry.Distance = distance
				table.insert(results, entry)
			end
		end
	end

	table.sort(results, function(a, b)
		return (a.Distance or math.huge) < (b.Distance or math.huge)
	end)

	return results
end

function EnemyMemory.clear()
	table.clear(EnemyMemory.Entries)
	EnemyMemory.LastRefreshAt = 0
end

return EnemyMemory
