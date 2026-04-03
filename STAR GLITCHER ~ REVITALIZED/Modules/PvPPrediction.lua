--[[
    PvPPrediction.lua - PvP-Specific Prediction Profile
    ===================================================
    Ke thua PredictionCore, tuning cho Player thuc:
      * Kalman Q boost +0.3 (nhay hon cho human input)
      * Ping bu 2x (player co latency rieng + reconciliation)
      * Lead cap thap (player di chuyn ngan, di huong nhieu)
      * Zigzag dampen manh (confidence giam 45% khi dao chieu)
      * Jump Arc prediction (du doan cung nhay parabola)
]]

return function(PredictionCore)
    local PvPPrediction = setmetatable({}, { __index = PredictionCore })
    PvPPrediction.__index = PvPPrediction
    PvPPrediction.__Legacy = true

    function PvPPrediction.new(config, npcTracker)
        local self = PredictionCore.new(config, npcTracker)
        setmetatable(self, PvPPrediction)

        -- === PVP PROFILE ===
        self.Profile = {
            KalmanQBoost      = 0.3,          -- Kalman nhay hon cho input nguoi that
            PingMultiplier    = 2.0,          -- Bu ping gap doi (player ping + reconciliation)
            ReversalPenalty   = 0.55,         -- Zigzag penalty manh hon
            LeadCap           = 180,          -- Lead cap thap (player di chuyn ngan)
            JumpArcEnabled    = true,         -- Du doan cung nhay parabola
            JumpGravity       = -196.2,       -- Gia toc trong luc chun Roblox
            JumpArcBlend      = 0.7,          -- 70% ap dung du doan cung nhay
        }

        return self
    end

    return PvPPrediction
end

