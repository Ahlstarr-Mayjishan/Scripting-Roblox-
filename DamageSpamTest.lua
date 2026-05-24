--[[
    DamageSpamTest.lua v14 - SILENT REDIRECTOR (Input Bypass)
    Since we cannot find the packet, we will redirect the INPUT that creates it.
    
    HOW TO USE:
    1. Click the Boss (Cube) to LOCK it. 
    2. Turn on "SILENT REDIRECT".
    3. Now, whenever you attack (Click anywhere, fire any skill), the game will 
       think your mouse is exactly on the Boss.
    4. Start attacking manually, and all damage will go to the Boss.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- State
local State = {
    LockedTarget = nil,
    RedirectActive = false,
    OriginalHit = nil,
}

-- 1. INPUT REDIRECTION (SILENT AIM STYLE)
-- This is much more reliable than remote spamming if we can't find the remote.
local function startRedirect()
    local mt = getrawmetatable(game)
    local oldIdx = mt.__index
    local oldNc = mt.__namecall
    setreadonly(mt, false)

    -- Redirect Mouse.Hit and Mouse.Target
    mt.__index = newcclosure(function(self, idx)
        if not checkcaller() and State.RedirectActive and State.LockedTarget then
            if self == Mouse or (typeof(self) == "Instance" and self:IsA("Mouse")) then
                if idx == "Hit" then
                    local targetPos = State.LockedTarget:GetPivot().Position
                    return CFrame.new(targetPos)
                elseif idx == "Target" then
                    return State.LockedTarget.PrimaryPart or State.LockedTarget:FindFirstChildWhichIsA("BasePart")
                end
            end
        end
        return oldIdx(self, idx)
    end)
    
    -- Redirect Viewport Rays (For beams/projectiles)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and State.RedirectActive and State.LockedTarget then
            if (method == "ViewportPointToRay" or method == "ScreenPointToRay") and self:IsA("Camera") then
                local targetPos = State.LockedTarget:GetPivot().Position
                local cam = Workspace.CurrentCamera
                local direction = (targetPos - cam.CFrame.Position).Unit
                return Ray.new(cam.CFrame.Position, direction)
            end
        end
        return oldNc(self, ...)
    end)
    
    print("[V14] Silent Redirector Active.")
end

-- 2. TARGET LOCKING (Manual Click)
Mouse.Button1Down:Connect(function()
    local tar = Mouse.Target
    if tar then
        local model = tar:FindFirstAncestorOfClass("Model") or tar
        State.LockedTarget = model
        print("[V14] Target Set: " .. model.Name)
    end
end)

-- UI
local function createUI()
    local sg = Instance.new("ScreenGui", CoreGui)
    sg.Name = "SilentRedirectV14"
    
    local main = Instance.new("Frame", sg)
    main.Size = UDim2.new(0, 260, 0, 250)
    main.Position = UDim2.new(0.5, -130, 0.4, 0)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    main.Active = true main.Draggable = true
    Instance.new("UICorner", main)
    
    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Text = "SILENT REDIRECTOR V14"
    title.TextColor3 = Color3.fromRGB(100, 255, 150)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.SourceSansBold title.TextSize = 18

    local status = Instance.new("TextLabel", main)
    status.Size = UDim2.new(0.9, 0, 0, 40)
    status.Position = UDim2.new(0.05, 0, 0, 50)
    status.Text = "Target: NONE\n(Click Boss to Lock)"
    status.TextColor3 = Color3.new(1,1,1)
    status.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
    Instance.new("UICorner", status)
    
    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0.9, 0, 0, 50)
    btn.Position = UDim2.new(0.05, 0, 0, 100)
    btn.Text = "ENABLE SILENT REDIRECT"
    btn.BackgroundColor3 = Color3.fromRGB(40, 70, 40)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.SourceSansBold
    Instance.new("UICorner", btn)
    
    btn.MouseButton1Click:Connect(function()
        State.RedirectActive = not State.RedirectActive
        btn.Text = State.RedirectActive and "REDIRECT: ON (Attack Now!)" or "ENABLE SILENT REDIRECT"
        btn.BackgroundColor3 = State.RedirectActive and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(40, 70, 40)
    end)
    
    local hint = Instance.new("TextLabel", main)
    hint.Size = UDim2.new(0.9, 0, 0, 80)
    hint.Position = UDim2.new(0.05, 0, 1, -95)
    hint.Text = "DIRECTIONS: Once active, all your manual attacks will automatically target the locked Boss. Just click anywhere to attack!"
    hint.TextColor3 = Color3.fromRGB(150, 150, 160)
    hint.TextWrapped = true
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.SourceSansItalic
    hint.TextSize = 12

    task.spawn(function()
        while sg.Parent do
            status.Text = "Target: " .. (State.LockedTarget and State.LockedTarget.Name or "NONE")
            task.wait(0.5)
        end
    end)
end

pcall(startRedirect)
pcall(createUI)
print("[Star Glitcher] Silent Redirector v14 Ready.")
