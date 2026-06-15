-- [[
--  NULLSCAPE - Accessibility Executor
--  Vai trò: Đầu mối thực thi các logic trợ năng thông qua API của file logic
-- ]]

local SpringerLogic = getgenv().loadModule("NULLSCAPE/Accessibility/Auto jump - Springer.luau")
local InfiniteAirJump = getgenv().loadModule("NULLSCAPE/Accessibility/Infinite Air Jump.luau")
local Executor = {}

-- Thực thi gán tự động nhảy cho Springer
function Executor.setupAutoJump(enemy, shockwave, controller, gc)
    SpringerLogic.setupAutoJump(enemy, shockwave, controller, gc)
end

function Executor.initializeInfiniteAirJump()
    return InfiniteAirJump.initialize()
end

return Executor
