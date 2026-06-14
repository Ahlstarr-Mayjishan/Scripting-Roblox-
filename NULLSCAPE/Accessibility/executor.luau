-- [[
--  NULLSCAPE - Accessibility Executor
--  Vai trò: Đầu mối thực thi các logic trợ năng thông qua API của file logic
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Accessibility/Auto jump - Springer.luau")
local Executor = {}

-- Thực thi gán tự động nhảy cho Springer
function Executor.setupAutoJump(enemy, shockwave, controller, gc)
    Logic.setupAutoJump(enemy, shockwave, controller, gc)
end

return Executor
