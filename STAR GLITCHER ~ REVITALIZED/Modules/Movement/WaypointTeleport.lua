local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WaypointTeleport = {}
WaypointTeleport.__index = WaypointTeleport

local DEFAULT_SPEED = 150
local MIN_SPEED = 10
local MAX_SPEED = 1000
local EMPTY_OPTION = "(No waypoints yet)"

function WaypointTeleport.new(options, localCharacter)
    local self = setmetatable({}, WaypointTeleport)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Status = "Idle"
    self.Waypoints = {}
    self.SelectedWaypointName = nil
    self.Dropdown = nil
    self._tweenConnection = nil
    return self
end

function WaypointTeleport:_getCharacterState()
    if self.LocalCharacter and self.LocalCharacter.GetState then
        return self.LocalCharacter:GetState()
    end

    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

function WaypointTeleport:_getRoot()
    local character, _, root = self:_getCharacterState()
    return character, root
end

function WaypointTeleport:_refreshDropdown()
    if not self.Dropdown then
        return
    end

    local options = self:GetWaypointNames()
    local currentOption = self.SelectedWaypointName or options[1]

    local ok = pcall(function()
        if type(self.Dropdown.Refresh) == "function" then
            self.Dropdown:Refresh(options, true)
        elseif type(self.Dropdown.SetOptions) == "function" then
            self.Dropdown:SetOptions(options)
        else
            self.Dropdown.Options = options
        end
    end)

    if not ok and typeof(self.Dropdown) == "Instance" then
        local textLabel = self.Dropdown:FindFirstChildWhichIsA("TextLabel", true)
        if textLabel then
            textLabel.Text = tostring(currentOption)
        end
    end

    if type(self.Dropdown.Set) == "function" then
        pcall(function()
            self.Dropdown:Set(currentOption)
        end)
    end
end

function WaypointTeleport:SetDropdown(dropdown)
    self.Dropdown = dropdown
    self:_refreshDropdown()
end

function WaypointTeleport:GetWaypointNames()
    if #self.Waypoints == 0 then
        return { EMPTY_OPTION }
    end

    local names = table.create(#self.Waypoints)
    for i = 1, #self.Waypoints do
        names[i] = self.Waypoints[i].Name
    end
    return names
end

function WaypointTeleport:SetSelectedWaypoint(name)
    if not name or name == EMPTY_OPTION then
        self.SelectedWaypointName = nil
        return
    end

    self.SelectedWaypointName = name
end

function WaypointTeleport:_findWaypointByName(name)
    if not name then
        return self.Waypoints[1]
    end

    for i = 1, #self.Waypoints do
        local waypoint = self.Waypoints[i]
        if waypoint.Name == name then
            return waypoint
        end
    end

    return self.Waypoints[1]
end

function WaypointTeleport:_formatWaypointName(root)
    local pos = root.Position
    return string.format("%s | %.0f, %.0f, %.0f", os.date("%H:%M:%S"), pos.X, pos.Y, pos.Z)
end

function WaypointTeleport:SetWaypoint()
    local _, root = self:_getRoot()
    if not root then
        self.Status = "Body Missing"
        return false, "Character body is not available."
    end

    local name = self:_formatWaypointName(root)
    table.insert(self.Waypoints, 1, {
        Name = name,
        CFrame = root.CFrame,
        CreatedAt = os.clock(),
    })

    self.SelectedWaypointName = name
    self.Status = "Saved Waypoint"
    self:_refreshDropdown()
    return true, name
end

function WaypointTeleport:_stopTween(status)
    if self._tweenConnection then
        self._tweenConnection:Disconnect()
        self._tweenConnection = nil
    end

    if status then
        self.Status = status
    end
end

function WaypointTeleport:_startTween(targetCFrame)
    self:_stopTween()
    self.Status = "Tweening"

    self._tweenConnection = RunService.Heartbeat:Connect(function(dt)
        local character, root = self:_getRoot()
        if not character or not root then
            self:_stopTween("Body Missing")
            return
        end

        local current = root.CFrame
        local delta = targetCFrame.Position - current.Position
        local distance = delta.Magnitude
        if distance <= 2 then
            character:PivotTo(targetCFrame)
            self:_stopTween("Arrived")
            return
        end

        local speed = math.clamp(tonumber(self.Options.TeleportTweenSpeed) or DEFAULT_SPEED, MIN_SPEED, MAX_SPEED)
        local alpha = math.clamp((speed * dt) / math.max(distance, 0.001), 0, 1)
        character:PivotTo(current:Lerp(targetCFrame, alpha))
    end)
end

function WaypointTeleport:GotoSelectedWaypoint()
    local waypoint = self:_findWaypointByName(self.SelectedWaypointName)
    if not waypoint then
        self.Status = "No Waypoint"
        return false, "No waypoint has been saved yet."
    end

    local character, root = self:_getRoot()
    if not character or not root then
        self.Status = "Body Missing"
        return false, "Character body is not available."
    end

    local method = tostring(self.Options.TeleportMethod or "Tween")
    if method == "Teleport" then
        character:PivotTo(waypoint.CFrame)
        self.Status = "Teleported"
        self:_stopTween()
        return true, waypoint.Name
    end

    self:_startTween(waypoint.CFrame)
    return true, waypoint.Name
end

function WaypointTeleport:Destroy()
    self:_stopTween("Destroyed")
    self.Dropdown = nil
end

return WaypointTeleport
