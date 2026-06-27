--!nocheck
-- [[
--  NULLSCAPE - Special Entity Immunity Router
--  Handles entities that do not fit the generic TouchInterest core.
-- ]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

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
    VoidImplosion = "VoidImplosionImmune",
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

    local bindable = razorbloom:FindFirstChild("ClientBindable")
    if not (bindable and bindable:IsA("BindableEvent")) then
        return
    end

    Logic.RazorbloomDisabled[razorbloom] = true
    pcall(function()
        bindable:Fire("Disable")
    end)

    -- Force clean up to prevent it from getting stuck on the player's head (delay to 1.5s to preserve the departure animation)
    task.delay(1.5, function()
        if razorbloom and razorbloom.Parent then
            pcall(function()
                -- Clear any weld/attachment holding it to the head
                local char = Players.LocalPlayer.Character
                local head = char and char:FindFirstChild("Head")
                if head then
                    for _, child in ipairs(head:GetChildren()) do
                        if child:IsA("Weld") or child:IsA("WeldConstraint") then
                            if child.Part0 == razorbloom or child.Part1 == razorbloom then
                                child:Destroy()
                            end
                        end
                    end
                end
                razorbloom:Destroy()
            end)
        end
    end)
end

local function applyRazorbloomBypass()
    if not isEnabled("Razorbloom") then
        return
    end

    local player = Players.LocalPlayer
    local character = player and player.Character
    local razorbloom = character and character:FindFirstChild("Razorbloom")
    if razorbloom then
        disableRazorbloom(razorbloom)
    end
end

local function watchCharacter(character)
    if not character then
        return
    end

    local existing = character:FindFirstChild("Razorbloom")
    if existing then
        task.defer(disableRazorbloom, existing)
    end

    table.insert(Logic.Connections, character.ChildAdded:Connect(function(child)
        if child.Name == "Razorbloom" then
            task.defer(disableRazorbloom, child)
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
