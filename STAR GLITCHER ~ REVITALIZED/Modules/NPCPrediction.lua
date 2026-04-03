--[[
    NPCPrediction.lua - NPC-Specific Prediction Profile
    ===================================================
    Ke thua PredictionCore, tuning cho Boss/NPC:
      * Kalman tieu chun (khong boost Q)
      * Ping bu 1x (NPC khong co ping rieng)
      * Lead cap cao (Boss di chuyn quang dai, thuat si bay xa)
      * Reversal penalty nhe (Boss it zigzag hon Player)
      * Khong co Jump Arc prediction
]]

return function(PredictionCore)
    local NPCPrediction = setmetatable({}, { __index = PredictionCore })
    NPCPrediction.__index = NPCPrediction
    NPCPrediction.__Legacy = true

    function NPCPrediction.new(config, npcTracker)
        local self = PredictionCore.new(config, npcTracker)
        setmetatable(self, NPCPrediction)

        -- === NPC PROFILE ===
        self.Profile = {
            KalmanQBoost      = 0,           -- Khong boost: NPC movement n dinh hon
            PingMultiplier    = 1,            -- Server-side NPC, khong can bu ping them
            ReversalPenalty   = 0.6,          -- Confidence giam 40% khi di huong
            LeadCap           = config.Prediction.MAX_LEAD_DIST,  -- 340 studs
            JumpArcEnabled    = false,        -- NPC khong jump theo kiu Player
            JumpGravity       = -196.2,
            JumpArcBlend      = 0,
        }

        return self
    end

    return NPCPrediction
end

