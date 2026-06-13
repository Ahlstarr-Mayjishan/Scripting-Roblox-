-- [[
--  NULLSCAPE - Entities Garbage Collector (GC)
--  Vai trò: Chuyên phụ trách quản lý kết nối sự kiện (Connections), bộ nhớ đệm (Cache)
--  và gọi dọn dẹp giải phóng tài nguyên vật lý để tối ưu hóa hiệu năng, giảm tải cho Controller.
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest Entities Types.luau")
local GC = {
    ActiveConnections = {},
    EntityConnections = {},
    SavedPartsData = setmetatable({}, { __mode = "k" })
}

-- Đăng ký một kết nối sự kiện chung vào danh sách dọn dẹp
function GC.registerConnection(conn)
    if conn then
        table.insert(GC.ActiveConnections, conn)
    end
end

-- Đăng ký các kết nối sự kiện của riêng từng thực thể
function GC.registerEntityConnection(enemy, conn)
    if not enemy or not conn then return end
    GC.EntityConnections[enemy] = GC.EntityConnections[enemy] or {}
    table.insert(GC.EntityConnections[enemy], conn)
end

-- Loại bỏ các kết nối sự kiện của một thực thể cụ thể khi thực thể đó biến mất
function GC.removeEntityConnections(enemy)
    if not enemy then return end
    local connections = GC.EntityConnections[enemy]
    if connections then
        for _, conn in ipairs(connections) do
            if conn then conn:Disconnect() end
        end
        GC.EntityConnections[enemy] = nil
    end
end

-- Thực hiện dọn dẹp và giải phóng tài nguyên cực hạn (GC)
function GC.cleanAll()
    -- 1. Khôi phục các TouchInterest đã bị thay đổi qua Logic module
    local success, err = pcall(function()
        Logic.restoreAll(GC)
    end)
    if not success then
        warn("[Entities GC] Lỗi khi khôi phục TouchInterest: " .. tostring(err))
    end

    -- 2. Ngắt toàn bộ kết nối của từng thực thể riêng biệt
    for enemy, connections in pairs(GC.EntityConnections) do
        for _, conn in ipairs(connections) do
            if conn then
                pcall(function() conn:Disconnect() end)
            end
        end
    end
    table.clear(GC.EntityConnections)

    -- 3. Ngắt toàn bộ kết nối sự kiện chung
    for _, conn in ipairs(GC.ActiveConnections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
    table.clear(GC.ActiveConnections)
end

return GC
