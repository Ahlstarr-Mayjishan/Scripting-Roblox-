--!nocheck
--[[
 NULLSCAPE - Grappler Assist Physics Profile
 Normalizes upgrade, curse, debuff, and biome signals into values used by assist policy.
]]

local PhysicsProfile = {}

local DEFAULT_TTL = 0.2

local cache = {
    Grapple = nil,
    At = 0,
    Profile = nil,
}

local function safeCall(callback, ...)
    if typeof(callback) ~= "function" then
        return nil
    end

    local success, result = pcall(callback, ...)
    if success then
        return result
    end

    return nil
end

local function hasUpgrade(movement, upgradeName)
    if not (movement and typeof(movement.HasUpgrade) == "function") then
        return false
    end

    local success, result = pcall(function()
        return movement:HasUpgrade(upgradeName)
    end)
    return success and result == true
end

local function hasMovementFlag(movement, flagName)
    if not movement then
        return false
    end

    local value = movement[flagName]
    if value == true then
        return true
    end

    return typeof(value) == "number" and value > 0
end

local function characterHas(character, name)
    return character and character:FindFirstChild(name) ~= nil
end

local function getCharacter(grapple)
    local rootPart = grapple and grapple.RootPart
    return rootPart and rootPart.Parent or nil
end

function PhysicsProfile.clear()
    cache.Grapple = nil
    cache.At = 0
    cache.Profile = nil
end

function PhysicsProfile.get(deps, grapple, force)
    deps = deps or {}
    local now = (deps.now and deps.now()) or time()
    local ttl = tonumber(deps.ttl) or DEFAULT_TTL
    if not force and cache.Profile and cache.Grapple == grapple and now - (cache.At or 0) <= ttl then
        return cache.Profile
    end

    local movement = grapple and grapple.Movement
    local character = getCharacter(grapple)
    local level = tonumber(safeCall(deps.getLevel)) or 0
    local curseEnabled = deps.isCurseEnabled or function()
        return false
    end

    local helmet = hasUpgrade(movement, "Helmet")
    local graceWings = hasUpgrade(movement, "GraceWings")
    local steelToed = hasUpgrade(movement, "SteelToed")
    local realWings = hasUpgrade(movement, "RealWings")
    local advancedGravityCoil = hasUpgrade(movement, "AdvancedGravityCoil")
    local weakJumpPads = curseEnabled("WeakJumpPads") == true
    local lowerGravity = curseEnabled("LowerGravity") == true
    local medal = characterHas(character, "Medal") or hasMovementFlag(movement, "Medal")
    local concussion = characterHas(character, "Concussion") or hasMovementFlag(movement, "Concussion")
    local flesh = characterHas(character, "Flesh") or hasMovementFlag(movement, "Flesh")
    local highrise = characterHas(character, "HighriseLowGravity")
        or characterHas(character, "Highrise")
        or hasMovementFlag(movement, "HighriseLowGravity")
        or level >= 23
    local lowGravity = lowerGravity or advancedGravityCoil or highrise

    local jumpPadMaxSpeed = weakJumpPads and 140 or 180
    local canTrustJumpPadBoost = not medal
    local canUseJumpFallback = not concussion
    local airControlScale = 1
    if graceWings then
        airControlScale += 0.35
    end
    if lowGravity then
        airControlScale += 0.2
    end

    local summaryParts = {
        lowGravity and "LowG" or "NormalG",
    }
    if helmet then
        table.insert(summaryParts, "Helmet")
    end
    if graceWings then
        table.insert(summaryParts, "GraceWings")
    end
    if weakJumpPads then
        table.insert(summaryParts, "WeakPads")
    end
    if medal then
        table.insert(summaryParts, "Medal")
    end
    if concussion then
        table.insert(summaryParts, "Concussion")
    end
    if flesh then
        table.insert(summaryParts, "Flesh")
    end

    local profile = {
        Helmet = helmet,
        GraceWings = graceWings,
        SteelToed = steelToed,
        RealWings = realWings,
        AdvancedGravityCoil = advancedGravityCoil,
        WeakJumpPads = weakJumpPads,
        LowerGravity = lowerGravity,
        Medal = medal,
        Concussion = concussion,
        Flesh = flesh,
        HighriseLowGravity = highrise,
        LowGravity = lowGravity,
        BonkTolerance = helmet and 1000000 or 110,
        AirControlScale = airControlScale,
        JumpPadMaxSpeed = jumpPadMaxSpeed,
        CanUseJumpFallback = canUseJumpFallback,
        CanTrustJumpPadBoost = canTrustJumpPadBoost,
        GravityScale = lowGravity and 0.72 or 1,
        PredictionScale = lowGravity and 1.28 or 1,
        RescueCooldownScale = lowGravity and 1.35 or 1,
        PullScale = lowGravity and 0.78 or 1,
        LandingFallSpeedScale = lowGravity and 0.72 or 1,
        RouteRiskScale = flesh and 1.35 or 1,
        Level = level,
        Summary = table.concat(summaryParts, "/"),
    }

    cache.Grapple = grapple
    cache.At = now
    cache.Profile = profile
    return profile
end

function PhysicsProfile.describe(profile)
    if not profile then
        return "Profile:pending"
    end

    return tostring(profile.Summary or "Profile")
        .. ":JP"
        .. tostring(profile.JumpPadMaxSpeed or "?")
        .. ":AC"
        .. string.format("%.2f", tonumber(profile.AirControlScale) or 1)
end

return PhysicsProfile
