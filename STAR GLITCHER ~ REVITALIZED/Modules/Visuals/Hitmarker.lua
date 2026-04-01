--[[
    Hitmarker.lua - OOP Hit Confirmation Class
    Logic:
    - Pending Queue: Stores shot fired timestamps and targets.
    - Match Rule: Matches damage remotes with shots within a time window.
    - State Machine: Idle -> ShotPending -> Confirmed -> Expired.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local clock = os.clock

local Hitmarker = {}
Hitmarker.__index = Hitmarker

function Hitmarker.new(synapse)
    local self = setmetatable({}, Hitmarker)
    self.Synapse = synapse
    self.ConfirmWindow = 1.0
    self.Enabled = true

    self._pendingShots = {}
    self._fadeConnection = nil
    self._fadeUntil = 0

    self.Part = nil
    self.Drawing = nil

    return self
end

function Hitmarker:Init()
    self.Line1 = Drawing.new("Line")
    self.Line2 = Drawing.new("Line")
    self.Line3 = Drawing.new("Line")
    self.Line4 = Drawing.new("Line")
    self.Lines = { self.Line1, self.Line2, self.Line3, self.Line4 }

    for _, line in ipairs(self.Lines) do
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        line.Visible = false
    end

    self.Synapse.on("ShotFired", function(targetId, shotTime, muzzlePos)
        if not targetId then
            return
        end

        self._pendingShots[targetId] = {
            shotTime = shotTime,
            muzzlePos = muzzlePos,
            status = "ShotPending",
        }

        task.delay(self.ConfirmWindow, function()
            local pending = self._pendingShots[targetId]
            if pending and pending.status == "ShotPending" then
                self._pendingShots[targetId] = nil
            end
        end)
    end)

    self.Synapse.on("DamageApplied", function(targetId, hitTime)
        local pending = self._pendingShots[targetId]
        if pending and pending.status == "ShotPending" then
            local timeDiff = hitTime - pending.shotTime
            if timeDiff >= 0 and timeDiff <= self.ConfirmWindow then
                pending.status = "Confirmed"
                self:Show()
                self._pendingShots[targetId] = nil
            end
        end
    end)
end

function Hitmarker:Show()
    if not self.Enabled or not self.Lines then
        return
    end

    for _, line in ipairs(self.Lines) do
        line.Visible = true
    end

    self._fadeUntil = clock() + 0.4
    if self._fadeConnection then
        return
    end

    self._fadeConnection = RunService.RenderStepped:Connect(function()
        if clock() > self._fadeUntil then
            for _, line in ipairs(self.Lines) do
                line.Visible = false
            end
            self._fadeConnection:Disconnect()
            self._fadeConnection = nil
            return
        end

        local mouse = UserInputService:GetMouseLocation()
        local x, y = mouse.X, mouse.Y
        local size = 8
        local gap = 4

        self.Line1.From = Vector2.new(x - gap, y - gap)
        self.Line1.To = Vector2.new(x - gap - size, y - gap - size)

        self.Line2.From = Vector2.new(x + gap, y - gap)
        self.Line2.To = Vector2.new(x + gap + size, y - gap - size)

        self.Line3.From = Vector2.new(x - gap, y + gap)
        self.Line3.To = Vector2.new(x - gap - size, y + gap + size)

        self.Line4.From = Vector2.new(x + gap, y + gap)
        self.Line4.To = Vector2.new(x + gap + size, y + gap + size)
    end)
end

function Hitmarker:Destroy()
    if self._fadeConnection then
        self._fadeConnection:Disconnect()
        self._fadeConnection = nil
    end
    for _, line in ipairs(self.Lines or {}) do
        pcall(function()
            line:Remove()
        end)
    end
end

return Hitmarker
