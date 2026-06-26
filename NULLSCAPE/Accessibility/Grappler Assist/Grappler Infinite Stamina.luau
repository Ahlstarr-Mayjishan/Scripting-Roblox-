--!nocheck
local Logic = {}

function Logic.initialize()
    local success, grappleAssist = pcall(function()
        return getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/Grapple Aim Assist.luau")
    end)
    return success and typeof(grappleAssist) == "table" and grappleAssist.enable()
end

return Logic
