--[[
    PvPPrediction.lua — PvP-Specific Prediction Profile
    ═══════════════════════════════════════════════════
    Kế thừa PredictionCore, tuning cho Player thực:
      • Kalman Q boost +0.3 (nhạy hơn cho human input)
      • Ping bù 2x (player có latency riêng + reconciliation)
      • Lead cap thấp (player di chuyển ngắn, đổi hướng nhiều)
      • Zigzag dampen mạnh (confidence giảm 45% khi đảo chiều)
      • Jump Arc prediction (dự đoán cung nhảy parabola)
]]

return function(PredictionCore)
    local PvPPrediction = setmetatable({}, { __index = PredictionCore })
    PvPPrediction.__index = PvPPrediction
    PvPPrediction.__Legacy = true

    function PvPPrediction.new(config, npcTracker)
        local self = PredictionCore.new(config, npcTracker)
        setmetatable(self, PvPPrediction)

        -- ═══ PVP PROFILE ═══
        self.Profile = {
            KalmanQBoost      = 0.3,          -- Kalman nhạy hơn cho input người thật
            PingMultiplier    = 2.0,          -- Bù ping gấp đôi (player ping + reconciliation)
            ReversalPenalty   = 0.55,         -- Zigzag penalty mạnh hơn
            LeadCap           = 180,          -- Lead cap thấp (player di chuyển ngắn)
            JumpArcEnabled    = true,         -- Dự đoán cung nhảy parabola
            JumpGravity       = -196.2,       -- Gia tốc trọng lực chuẩn Roblox
            JumpArcBlend      = 0.7,          -- 70% áp dụng dự đoán cung nhảy
        }

        return self
    end

    return PvPPrediction
end
