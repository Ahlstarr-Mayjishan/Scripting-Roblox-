--[[
    NPCPrediction.lua — NPC-Specific Prediction Profile
    ═══════════════════════════════════════════════════
    Kế thừa PredictionCore, tuning cho Boss/NPC:
      • Kalman tiêu chuẩn (không boost Q)
      • Ping bù 1x (NPC không có ping riêng)
      • Lead cap cao (Boss di chuyển quãng dài, thuật sĩ bay xa)
      • Reversal penalty nhẹ (Boss ít zigzag hơn Player)
      • Không có Jump Arc prediction
]]

return function(PredictionCore)
    local NPCPrediction = setmetatable({}, { __index = PredictionCore })
    NPCPrediction.__index = NPCPrediction
    NPCPrediction.__Legacy = true

    function NPCPrediction.new(config, npcTracker)
        local self = PredictionCore.new(config, npcTracker)
        setmetatable(self, NPCPrediction)

        -- ═══ NPC PROFILE ═══
        self.Profile = {
            KalmanQBoost      = 0,           -- Không boost: NPC movement ổn định hơn
            PingMultiplier    = 1,            -- Server-side NPC, không cần bù ping thêm
            ReversalPenalty   = 0.6,          -- Confidence giảm 40% khi đổi hướng
            LeadCap           = config.Prediction.MAX_LEAD_DIST,  -- 340 studs
            JumpArcEnabled    = false,        -- NPC không jump theo kiểu Player
            JumpGravity       = -196.2,
            JumpArcBlend      = 0,
        }

        return self
    end

    return NPCPrediction
end
