--[[
    BossClassifier.lua — Auto Boss Type Detection
    ═══════════════════════════════════════════════════
    Phân loại Boss thành 3 loại dựa trên kích thước model:
      • "humanoid"     : Boss dáng người chuẩn (R6/R15)
      • "humanoid_mini": Boss nhỏ hơn người thường
      • "large"        : Boss khổng lồ / không humanoid
    
    Mỗi loại có bộ aim parameters riêng:
      • AimOffset (Y) — điểm ngắm tối ưu
      • Deadzone      — vùng bỏ qua rung
      • LeadScale     — hệ số lead (nhỏ = ít lead)
      • TargetPart    — phần thân ưu tiên aim
]]

local BossClassifier = {}

-- ═══ Ngưỡng để phân loại ═══
local MINI_HEIGHT_MAX = 3.5    -- Model dưới 3.5 studs → mini
local STANDARD_HEIGHT_MAX = 8  -- Model 3.5-8 studs → humanoid chuẩn
-- Trên 8 studs → large boss

-- ═══ Profiles cho từng loại Boss ═══
BossClassifier.Profiles = {
    humanoid = {
        AimOffset = 0,          -- Ngắm chính xác root/torso
        Deadzone = 1.2,         -- Deadzone chuẩn
        LeadScale = 1.0,        -- Lead bình thường
        PreferredPart = "HumanoidRootPart",
        StabilizeAlpha = 0.08,  -- Smoothing chuẩn
    },
    humanoid_mini = {
        AimOffset = -0.5,       -- Ngắm thấp hơn (hitbox nhỏ, center thấp)
        Deadzone = 0.5,         -- Deadzone nhỏ (hitbox nhỏ cần chính xác hơn)
        LeadScale = 0.7,        -- Lead ít hơn (mini boss thường di chuyển nhanh, hitbox nhỏ)
        PreferredPart = "Head", -- Head thường ở trung tâm mini model
        StabilizeAlpha = 0.06,  -- Mượt hơn (tránh aim trượt khỏi hitbox nhỏ)
    },
    large = {
        AimOffset = 2,          -- Ngắm cao hơn (boss to, center cao)
        Deadzone = 2.5,         -- Deadzone lớn (hitbox lớn, không cần aim chính xác)
        LeadScale = 1.2,        -- Lead nhiều hơn (boss to di chuyển quãng dài)
        PreferredPart = "HumanoidRootPart",
        StabilizeAlpha = 0.12,  -- Ít smooth (hitbox lớn, tha thứ lệch nhiều hơn)
    },
}

-- ═══ Đo chiều cao model ═══
function BossClassifier.MeasureModelHeight(model)
    if not model or not model:IsA("Model") then return 5 end -- Mặc định 5 studs
    
    local ok, result = pcall(function()
        -- Dùng GetBoundingBox nếu có
        local _, size = model:GetBoundingBox()
        return size.Y
    end)
    
    if ok and result then
        return result
    end
    
    -- Fallback: đo từ parts
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

-- ═══ Phân loại Boss ═══
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
        -- Không có Humanoid → luôn coi là large
        return "large", height
    end
end

-- ═══ Lấy profile theo loại ═══
function BossClassifier.GetProfile(bossType)
    return BossClassifier.Profiles[bossType] or BossClassifier.Profiles.humanoid
end

return BossClassifier
