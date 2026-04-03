--[[
    CheckGame.lua - Place ID Validation
    Job: Ensures the script only executes in the intended game environment.
    Target: Star Glitcher ~ Revitalized (ID: 11380216916)
]]

local TARGET_PLACE_ID = 11380216916
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function Check()
    if game.PlaceId ~= TARGET_PLACE_ID then
        local errorMsg = " Access Denied: This script only supports Star Glitcher! (Place ID: " .. tostring(TARGET_PLACE_ID) .. ")"
        
        -- Attempt to notify via executor if possible
        if Rayfield and Rayfield.Notify then
            Rayfield:Notify({
                Title = "Wrong Game Detected",
                Content = errorMsg,
                Duration = 10,
                Image = 4483362458,
            })
        end
        
        warn(errorMsg)
        -- Kick the player to prevent unexpected behavior in wrong games
        LocalPlayer:Kick(errorMsg)
        return false
    end
    return true
end

return Check()

