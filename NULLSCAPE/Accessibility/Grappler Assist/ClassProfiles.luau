--!nocheck
-- [[
--  NULLSCAPE - Grappler Assist Class Profiles
--  Scope: class/Grappler only.
-- ]]

local ClassProfiles = {}

ClassProfiles.GRAPPLER_CLASS_ID = "class/Grappler"

local PROFILES = {
    [ClassProfiles.GRAPPLER_CLASS_ID] = {
        Name = "Grappler",
        Capabilities = {
            AimAssist = true,
            RescueAssist = true,
            EmergencyRescue = true,
            VoidRescue = true,
            SmartReel = true,
            SharkTail = true,
            MomentumGuard = true,
            AirControl = true,
            JumpPadBypass = true,
            BellBypass = true,
            StaminaAssist = true,
        },
    },
}

local CAPABILITY_NAMES = {
    "AimAssist",
    "RescueAssist",
    "EmergencyRescue",
    "StaminaAssist",
    "SmartReel",
    "SharkTail",
    "MomentumGuard",
    "AirControl",
    "JumpPadBypass",
    "BellBypass",
}

function ClassProfiles.getAttributeString(instance, attributeName)
    if not instance then
        return nil
    end

    local success, value = pcall(function()
        return instance:GetAttribute(attributeName)
    end)
    if success and type(value) == "string" and value ~= "" then
        return value
    end

    return nil
end

function ClassProfiles.getClassIdFromMovement(movement)
    if not movement then
        return nil
    end

    if type(movement.ClassID) == "string" and movement.ClassID ~= "" then
        return movement.ClassID
    end

    local character = movement.Character
    local classId = ClassProfiles.getAttributeString(character, "Class")
    if classId then
        return classId
    end

    local humanoid = movement.Humanoid
    classId = ClassProfiles.getAttributeString(humanoid and humanoid.Parent, "Class")
    if classId then
        return classId
    end

    return nil
end

function ClassProfiles.getClassId(grapple)
    local movement = grapple and grapple.Movement
    local classId = ClassProfiles.getClassIdFromMovement(movement)
    if classId then
        return classId
    end

    return ClassProfiles.getAttributeString(grapple and grapple.Character, "Class")
end

function ClassProfiles.getProfile(grapple)
    local classId = ClassProfiles.getClassId(grapple)
    local profile = classId and PROFILES[classId]
    if profile then
        return profile, classId
    end

    return {
        Name = "Unknown",
        Capabilities = {},
    }, classId or "Unknown"
end

function ClassProfiles.hasCapability(grapple, capability)
    local profile = ClassProfiles.getProfile(grapple)
    return profile and profile.Capabilities and profile.Capabilities[capability] == true
end

function ClassProfiles.hasAnyCapability(grapple)
    for _, capability in ipairs(CAPABILITY_NAMES) do
        if ClassProfiles.hasCapability(grapple, capability) then
            return true
        end
    end

    return false
end

function ClassProfiles.isActiveSpecial(grapple)
    local movement = grapple and grapple.Movement
    return movement and movement.ActiveSpecial == grapple
end

return ClassProfiles