-- [[
--  NULLSCAPE - Accessibility Executor
--  Vai trò: Đầu mối thực thi các logic trợ năng thông qua API của file logic
-- ]]

local SpringerLogic = getgenv().loadModule("NULLSCAPE/Accessibility/Auto jump - Springer.luau")
local InfiniteAirJump = getgenv().loadModule("NULLSCAPE/Accessibility/Infinite Air Jump.luau")
local GrapplerInfiniteStamina = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Infinite Stamina.luau")
local GrappleAimAssist = getgenv().loadModule("NULLSCAPE/Accessibility/Grapple Aim Assist.luau")
local RailAssist = getgenv().loadModule("NULLSCAPE/Accessibility/Rail Assist.luau")
local Executor = {}

-- Thực thi gán tự động nhảy cho Springer
function Executor.setupAutoJump(enemy, shockwave, controller, gc)
    SpringerLogic.setupAutoJump(enemy, shockwave, controller, gc)
end

function Executor.initializeInfiniteAirJump()
    return InfiniteAirJump.initialize()
end

function Executor.initializeGrapplerInfiniteStamina()
    return GrapplerInfiniteStamina.initialize()
end

function Executor.enableGrappleAimAssist()
    return GrappleAimAssist.enable()
end

function Executor.disableGrappleAimAssist()
    GrappleAimAssist.disable()
end

function Executor.enableRailAssist()
    return RailAssist.enable()
end

function Executor.disableRailAssist()
    RailAssist.disable()
end

return Executor
