-- [[
--  NULLSCAPE - Entities Cleaner Module
--  Chuyên phụ trách xóa các phần chỉ định (TouchInterest, Hitbox) ra khỏi thực thể.
-- ]]

local Cleaner = {}

-- Xóa toàn bộ TouchInterest / TouchTransmitter khỏi thực thể mục tiêu
function Cleaner.removeTouchInterests(entity)
    if not entity then return end
    local count = 0
    for _, part in ipairs(entity:GetDescendants()) do
        if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
            pcall(function()
                part:Destroy()
                count = count + 1
            end)
        elseif part:IsA("BasePart") then
            -- Vô hiệu hóa va chạm canTouch ở phía Client để tăng thêm độ an toàn
            pcall(function()
                part.CanTouch = false
            end)
        end
    end
    if count > 0 then
        warn("[NULLSCAPE Cleaner] Đã dọn dẹp " .. count .. " TouchInterest khỏi thực thể: " .. entity.Name)
    end
end

return Cleaner
