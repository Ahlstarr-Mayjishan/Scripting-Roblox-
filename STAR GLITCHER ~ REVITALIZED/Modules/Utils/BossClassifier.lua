--[[
    BossClassifier.lua - Auto Boss Type Detection
    ===================================================
    Phan loai Boss thanh 3 loai dua tren kich thuoc model:
      * "humanoid"     : Boss dang nguoi chun (R6/R15)
      * "humanoid_mini": Boss nho hon nguoi thuong
      * "large"        : Boss khng lo / khong humanoid
    
    Moi loai co bo aim parameters rieng:
      * AimOffset (Y) - dim ngam toi uu
      * Deadzone      - vung bo qua rung
      * LeadScale     - he so lead (nho = it lead)
      * TargetPart    - phan than uu tien aim
]]

local BossClassifier = {}

-- === Nguong d phan loai ===
local MINI_HEIGHT_MAX = 3.5    -- Model duoi 3.5 studs  mini
local STANDARD_HEIGHT_MAX = 8  -- Model 3.5-8 studs  humanoid chun
-- Tren 8 studs  large boss

-- === Profiles cho tung loai Boss ===
BossClassifier.Profiles = {
    humanoid = {
        AimOffset = 0,          -- Ngam chinh xac root/torso
        Deadzone = 1.2,         -- Deadzone chun
        LeadScale = 1.0,        -- Lead binh thuong
        PreferredPart = "HumanoidRootPart",
        StabilizeAlpha = 0.08,  -- Smoothing chun
    },
    humanoid_mini = {
        AimOffset = -0.5,       -- Ngam thap hon (hitbox nho, center thap)
        Deadzone = 0.5,         -- Deadzone nho (hitbox nho can chinh xac hon)
        LeadScale = 0.7,        -- Lead it hon (mini boss thuong di chuyn nhanh, hitbox nho)
        PreferredPart = "Head", -- Head thuong  trung tam mini model
        StabilizeAlpha = 0.06,  -- Muot hon (tranh aim truot khoi hitbox nho)
    },
    large = {
        AimOffset = 2,          -- Ngam cao hon (boss to, center cao)
        Deadzone = 2.5,         -- Deadzone lon (hitbox lon, khong can aim chinh xac)
        LeadScale = 1.2,        -- Lead nhieu hon (boss to di chuyn quang dai)
        PreferredPart = "HumanoidRootPart",
        StabilizeAlpha = 0.12,  -- it smooth (hitbox lon, tha thu lech nhieu hon)
    },
}

-- === do chieu cao model ===
function BossClassifier.MeasureModelHeight(model)
    if not model or not model:IsA("Model") then return 5 end -- Mac dinh 5 studs
    
    local ok, result = pcall(function()
        -- Dung GetBoundingBox neu co
        local _, size = model:GetBoundingBox()
        return size.Y
    end)
    
    if ok and result then
        return result
    end
    
    -- Fallback: do tu parts
    local minY, maxY = math.huge, -math.huge
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            local pos = part.Position
            local halfSize = part.Size.Y / 2
            minY = math.min(minY, pos.Y - halfSize)
            maxY = math.max(maxY, pos.Y + halfSize)
        end
    end
    
    if minY < maxY then
        return maxY - minY
    end
    return 5
end

-- === Phan loai Boss ===
function BossClassifier.Classify(model)
    local height = BossClassifier.MeasureModelHeight(model)
    
    local hasHumanoid = model:FindFirstChildOfClass("Humanoid") ~= nil
    
    if hasHumanoid then
        if height <= MINI_HEIGHT_MAX then
            return "humanoid_mini", height
        elseif height <= STANDARD_HEIGHT_MAX then
            return "humanoid", height
        else
            return "large", height
        end
    else
        -- Khong co Humanoid  luon coi la large
        return "large", height
    end
end

-- === Lay profile theo loai ===
function BossClassifier.GetProfile(bossType)
    return BossClassifier.Profiles[bossType] or BossClassifier.Profiles.humanoid
end

return BossClassifier

