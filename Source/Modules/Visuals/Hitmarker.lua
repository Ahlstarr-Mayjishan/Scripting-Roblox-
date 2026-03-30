--[[
    Hitmarker.lua — OOP Hit Confirmation Class
    Analogy: Primary Somatosensory Cortex (Processing Hit Perception).
    Logic:
    • Pending Queue: Stores shot fired timestamps and targets.
    • Match Rule: Matches damage remotes with shots within a time window.
    • State Machine: Idle -> ShotPending -> Confirmed -> Expired.
]]

local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local Hitmarker = {}
Hitmarker.__index = Hitmarker

function Hitmarker.new(synapse)
    local self = setmetatable({}, Hitmarker)
    self.Synapse = synapse
    self.ConfirmWindow = 1.0 -- Latency + Travel window
    self.Enabled = true
    
    -- Queue of pending shots: { [targetId] = { muzzlePos, shotTime, status } }
    self._pendingShots = {}
    
    -- Visual stuff
    self.Part = nil -- Reference part to draw on
    self.Drawing = nil
    
    return self
end

function Hitmarker:Init()
    -- Create drawings
    self.Line1 = Drawing.new("Line")
    self.Line2 = Drawing.new("Line")
    self.Line3 = Drawing.new("Line")
    self.Line4 = Drawing.new("Line")
    self.Lines = {self.Line1, self.Line2, self.Line3, self.Line4}
    
    for _, line in ipairs(self.Lines) do
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        line.Visible = false
    end
    
    -- Listen for ShotFired (WeaponController)
    self.Synapse.on("ShotFired", function(targetId, shotTime, muzzlePos)
        if not targetId then return end
        
        -- State: ShotPending
        self._pendingShots[targetId] = {
            shotTime = shotTime,
            muzzlePos = muzzlePos,
            status = "ShotPending"
        }
        
        -- Self-clean after window expiry (State: Expired)
        task.delay(self.ConfirmWindow, function()
            if self._pendingShots[targetId] and self._pendingShots[targetId].status == "ShotPending" then
                self._pendingShots[targetId] = nil
            end
        end)
    end)
    
    -- Listen for DamageApplied (CombatService)
    self.Synapse.on("DamageApplied", function(targetId, hitTime)
        local pending = self._pendingShots[targetId]
        if pending and pending.status == "ShotPending" then
            local timeDiff = hitTime - pending.shotTime
            if timeDiff >= 0 and timeDiff <= self.ConfirmWindow then
                -- Match rule: SUCCESS (State: Confirmed)
                pending.status = "Confirmed"
                self:Show()
                self._pendingShots[targetId] = nil -- Clean after hit
            end
        end
    end)
end

function Hitmarker:Show()
    if not self.Enabled then return end
    
    for _, line in ipairs(self.Lines) do line.Visible = true end
    
    -- Simple fade/draw logic
    local start = os.clock()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local elapsed = os.clock() - start
        if elapsed > 0.4 then
            for _, line in ipairs(self.Lines) do line.Visible = false end
            conn:Disconnect()
            return
        end
        
        local mouse = game:GetService("UserInputService"):GetMouseLocation()
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
    for _, line in ipairs(self.Lines) do pcall(function() line:Remove() end) end
end

return Hitmarker
