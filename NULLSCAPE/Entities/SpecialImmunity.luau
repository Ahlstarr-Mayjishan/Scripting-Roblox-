--!nocheck
-- [[
--  NULLSCAPE - Special Entity Immunity Router
--  Handles entities that do not fit the generic TouchInterest core.
-- ]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local RAZORBLOOM_CLEANUP_DELAY = 1.0
local RAZORBLOOM_RETRY_WINDOW = 2.5
local RAZORBLOOM_RETRY_STEP = 0.1

local Logic = {
    Connections = {},
    SavedVoidbreakerHitbox = nil,
    SavedGuardianHitbox = nil,
    RazorbloomDisabled = setmetatable({}, { __mode = "k" }),
    LoopToken = nil,
}

local SPECIAL_FLAGS = {
    Kolona = "KolonaImmune",
    Oblivion = "OblivionImmune",
    ShadowBaby = "ShadowBabyImmune",
    Quartz = "QuartzImmune",
    Sigil = "SigilImmune",
    Slicer = "SlicerImmune",
    Voidbreaker = "VoidbreakerImmune",
    Razorbloom = "RazorbloomImmune",
}

local function getController()
    local globals = getgenv()._NULLSCAPE_Globals
    return globals and globals.activeEntitiesController
end

local function isEnabled(name)
    local controller = getController()
    if not controller or controller.inLobby then
        return false
    end
    if name == "Guardian" then
        return controller.GuardianImmune == true
    end

    local flag = SPECIAL_FLAGS[name]
    return flag and controller[flag] == true
end

local function anySpecialEnabled()
    local controller = getController()
    if not controller then
        return false
    end

    if controller.GuardianImmune == true then
        return true
    end

    for _, flag in pairs(SPECIAL_FLAGS) do
        if controller[flag] == true then
            return true
        end
    end

    return false
end

function Logic.isSpecialEntity(name)
    if not name then
        return false
    end

    local lowerName = string.lower(name)
    for entityName in pairs(SPECIAL_FLAGS) do
        if string.find(lowerName, string.lower(entityName)) then
            return true
        end
    end

    return false
end

function Logic.getFlag(entityName)
    return SPECIAL_FLAGS[entityName]
end

function Logic.getEntityNames()
    local names = {}
    for entityName in pairs(SPECIAL_FLAGS) do
        table.insert(names, entityName)
    end
    table.sort(names)
    return names
end

local function saveVoidbreakerHitbox(part)
    if Logic.SavedVoidbreakerHitbox and Logic.SavedVoidbreakerHitbox.Part == part then
        return
    end

    Logic.SavedVoidbreakerHitbox = {
        Part = part,
        CanQuery = part.CanQuery,
        Transparency = part.Transparency,
    }
end

local function applyVoidbreakerHitboxBypass()
    if not isEnabled("Voidbreaker") then
        return
    end

    local hitbox = Workspace:FindFirstChild("PlayerVoidbreakerHitbox")
    if not (hitbox and hitbox:IsA("BasePart")) then
        return
    end

    saveVoidbreakerHitbox(hitbox)

    if hitbox.CanQuery then
        pcall(function()
            hitbox.CanQuery = false
        end)
    end
end

local function saveGuardianHitbox(part)
    if Logic.SavedGuardianHitbox and Logic.SavedGuardianHitbox.Part == part then
        return
    end

    Logic.SavedGuardianHitbox = {
        Part = part,
        CanQuery = part.CanQuery,
    }
end

local function applyGuardianProjectileBypass()
    if not isEnabled("Guardian") then
        return
    end

    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    local hitbox = character and character:FindFirstChild("Hitbox")
    if not (hitbox and hitbox:IsA("BasePart")) then
        return
    end

    saveGuardianHitbox(hitbox)

    if hitbox.CanQuery then
        pcall(function()
            hitbox.CanQuery = false
        end)
    end
end

local function isDescendantOrSelf(instance, root)
    if not (instance and root) then
        return false
    end

    local current = instance
    while current do
        if current == root then
            return true
        end
        current = current.Parent
    end

    return false
end

local function detachRazorbloom(razorbloom)
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    if not (character and razorbloom) then
        return
    end

    for _, child in ipairs(character:GetDescendants()) do
        if child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("Motor6D") then
            local part0 = child.Part0
            local part1 = child.Part1
            if isDescendantOrSelf(part0, razorbloom) or isDescendantOrSelf(part1, razorbloom) then
                pcall(function()
                    child:Destroy()
                end)
            end
        end
    end
end

local function cleanupRazorbloom(razorbloom)
    if not (razorbloom and razorbloom.Parent) then
        return
    end

    pcall(function()
        detachRazorbloom(razorbloom)
        razorbloom:Destroy()
    end)
end

local function findRazorbloomBindable(razorbloom)
    local bindable = razorbloom:FindFirstChild("ClientBindable")
    if bindable and bindable:IsA("BindableEvent") then
        return bindable
    end

    bindable = razorbloom:FindFirstChild("ClientBindable", true)
    if bindable and bindable:IsA("BindableEvent") then
        return bindable
    end

    return nil
end

local function disableRazorbloom(razorbloom)
    if not isEnabled("Razorbloom") then
        return
    end
    if not (razorbloom and razorbloom.Parent) then
        return
    end
    if Logic.RazorbloomDisabled[razorbloom] then
        return
    end

    Logic.RazorbloomDisabled[razorbloom] = true

    task.spawn(function()
        local startedAt = time()
        local firedNativeDisable = false
        while razorbloom and razorbloom.Parent and time() - startedAt <= RAZORBLOOM_RETRY_WINDOW do
            if not isEnabled("Razorbloom") then
                Logic.RazorbloomDisabled[razorbloom] = nil
                return
            end

            local bindable = findRazorbloomBindable(razorbloom)
            if bindable then
                pcall(function()
                    bindable:Fire("Disable")
                end)
                firedNativeDisable = true
                break
            end

            task.wait(RAZORBLOOM_RETRY_STEP)
        end

        if firedNativeDisable then
            task.delay(RAZORBLOOM_CLEANUP_DELAY, function()
                cleanupRazorbloom(razorbloom)
            end)
        else
            cleanupRazorbloom(razorbloom)
        end
    end)
end

local function scanCharacterForRazorbloom(character)
    if not character then
        return
    end

    local existing = character:FindFirstChild("Razorbloom")
    if existing then
        task.defer(disableRazorbloom, existing)
    end

    for _, child in ipairs(character:GetDescendants()) do
        if child.Name == "Razorbloom" then
            task.defer(disableRazorbloom, child)
        end
    end
end

local function applyRazorbloomBypass()
    if not isEnabled("Razorbloom") then
        return
    end

    local player = Players.LocalPlayer
    local character = player and player.Character
    scanCharacterForRazorbloom(character)
end

local function watchCharacter(character)
    if not character then
        return
    end

    scanCharacterForRazorbloom(character)

    table.insert(Logic.Connections, character.ChildAdded:Connect(function(child)
        if child.Name == "Razorbloom" then
            task.defer(disableRazorbloom, child)
        end
    end))

    table.insert(Logic.Connections, character.DescendantAdded:Connect(function(child)
        if child.Name == "Razorbloom" then
            task.defer(disableRazorbloom, child)
        elseif child.Name == "ClientBindable" then
            local current = child.Parent
            while current and current ~= character do
                if current.Name == "Razorbloom" then
                    task.defer(disableRazorbloom, current)
                    break
                end
                current = current.Parent
            end
        end
    end))
end

function Logic.enable()
    if Logic.Enabled then
        return true
    end

    Logic.Enabled = true
    local loopToken = {}
    Logic.LoopToken = loopToken
    task.spawn(function()
        while Logic.Enabled and Logic.LoopToken == loopToken do
            local active = anySpecialEnabled()
            if active then
                applyVoidbreakerHitboxBypass()
                applyGuardianProjectileBypass()
                applyRazorbloomBypass()
            end
            task.wait(active and 0.25 or 1.0)
        end
    end)

    table.insert(Logic.Connections, Workspace.ChildAdded:Connect(function(child)
        if child.Name == "PlayerVoidbreakerHitbox" then
            task.defer(applyVoidbreakerHitboxBypass)
        end
    end))

    local player = Players.LocalPlayer
    if player then
        watchCharacter(player.Character)
        table.insert(Logic.Connections, player.CharacterAdded:Connect(function(character)
            task.defer(watchCharacter, character)
        end))
    end

    return true
end

function Logic.restoreVoidbreakerHitbox()
    local saved = Logic.SavedVoidbreakerHitbox
    if not saved then
        return
    end

    local part = saved.Part
    if part and part.Parent then
        pcall(function()
            part.CanQuery = saved.CanQuery
            part.Transparency = saved.Transparency
        end)
    end

    Logic.SavedVoidbreakerHitbox = nil
end

function Logic.restoreGuardianHitbox()
    local saved = Logic.SavedGuardianHitbox
    if not saved then
        return
    end

    local part = saved.Part
    if part and part.Parent then
        pcall(function()
            part.CanQuery = saved.CanQuery
        end)
    end

    Logic.SavedGuardianHitbox = nil
end

function Logic.disable()
    for _, connection in ipairs(Logic.Connections) do
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
    table.clear(Logic.Connections)
    Logic.Enabled = false
    Logic.LoopToken = nil
    Logic.restoreVoidbreakerHitbox()
    Logic.restoreGuardianHitbox()
    Logic.RazorbloomDisabled = setmetatable({}, { __mode = "k" })
end

function Logic.disableForType(entityName)
    if entityName == "Voidbreaker" then
        Logic.restoreVoidbreakerHitbox()
    elseif entityName == "Guardian" then
        Logic.restoreGuardianHitbox()
    end
end

return Logic
