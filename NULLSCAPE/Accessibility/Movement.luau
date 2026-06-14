-- [[
--  NULLSCAPE - Movement Control Logic (Clean Dummy Edition)
--  Vai trò: Tạm thời vô hiệu hóa để nghiên cứu và tìm phương án giảm momentum sau.
--  Trả lại hoàn toàn trạng thái sạch 100% cho game.
-- ]]

local Logic = {
    MomentumReduction = 0
}

function Logic.start(controller, gc)
    -- Tạm thời không thực hiện bất kỳ thay đổi nào để trả lại vật lý mặc định cho game
end

function Logic.stop()
    -- Tạm thời không làm gì
end

function Logic.setReduction(value)
    Logic.MomentumReduction = tonumber(value) or 0
end

return Logic
