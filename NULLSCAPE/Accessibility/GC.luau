-- [[
--  NULLSCAPE - Accessibility Garbage Collector (GC)
--  Vai trò: Chuyên phụ trách quản lý các kết nối sự kiện (Connections) cho phần trợ năng.
-- ]]

local GC = {
	ActiveConnections = {},
	EntityConnections = {},
}

-- Hàm phụ trợ ngắt kết nối/dọn dẹp đa dạng đối tượng
local function cleanupItem(item)
	if not item then
		return
	end
	if typeof(item) == "function" then
		pcall(item)
	elseif typeof(item) == "table" then
		if typeof(item.Disconnect) == "function" then
			pcall(function()
				item:Disconnect()
			end)
		elseif typeof(item.disconnect) == "function" then
			pcall(item.disconnect)
		elseif typeof(item.Destroy) == "function" then
			pcall(function()
				item:Destroy()
			end)
		elseif typeof(item.destroy) == "function" then
			pcall(item.destroy)
		end
	elseif typeof(item) == "Instance" then
		if item:IsA("RBXScriptConnection") then
			pcall(function()
				item:Disconnect()
			end)
		else
			pcall(function()
				item:Destroy()
			end)
		end
	end
end

-- Đăng ký một kết nối sự kiện chung vào danh sách dọn dẹp
function GC.registerConnection(conn)
	if conn then
		table.insert(GC.ActiveConnections, conn)
	end
end

-- Đăng ký các kết nối sự kiện của riêng từng thực thể
function GC.registerEntityConnection(enemy, conn)
	if not enemy or not conn then
		return
	end
	GC.EntityConnections[enemy] = GC.EntityConnections[enemy] or {}
	table.insert(GC.EntityConnections[enemy], conn)
end

-- Loại bỏ các kết nối sự kiện của một thực thể cụ thể khi thực thể đó biến mất
function GC.removeEntityConnections(enemy)
	if not enemy then
		return
	end
	local connections = GC.EntityConnections[enemy]
	if connections then
		for _, conn in ipairs(connections) do
			cleanupItem(conn)
		end
		GC.EntityConnections[enemy] = nil
	end
end

-- Thực hiện dọn dẹp và giải phóng tài nguyên cực hạn (GC)
function GC.cleanAll()
	-- 1. Ngắt toàn bộ kết nối của từng thực thể riêng biệt
	for enemy, connections in pairs(GC.EntityConnections) do
		for _, conn in ipairs(connections) do
			cleanupItem(conn)
		end
	end
	table.clear(GC.EntityConnections)

	-- 2. Ngắt toàn bộ kết nối sự kiện chung
	for _, conn in ipairs(GC.ActiveConnections) do
		cleanupItem(conn)
	end
	table.clear(GC.ActiveConnections)
end

return GC
