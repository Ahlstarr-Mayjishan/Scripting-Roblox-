-- [[
--  NULLSCAPE - Simulated Upgrades Garbage Collector (GC)
--  Vai trò: Chuyên phụ trách quản lý kết nối sự kiện (Connections), bộ nhớ đệm visual (SavedVisuals)
--  và gọi dọn dẹp giải phóng tài nguyên để tối ưu hóa hiệu năng, giảm tải cho Controller.
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local GC = {
	ActiveConnections = {},
	SavedVisuals = {
		Highlights = {}, -- Danh sách phát sáng
		Beams = {}, -- Danh sách tia sáng chỉ dẫn
		Attachments = {}, -- Danh sách các attachment đính kèm
		Dots = {},
		ActiveTargets = {}, -- Cache lưu các vật thể đang được vẽ ESP để tái sử dụng
		ArrowGift = nil, -- Mũi tên chỉ hộp quà (Màu trắng)
		ArrowCadence = nil, -- Mũi tên chỉ nhạc cụ Cadence (Màu đỏ)
		ArrowAltar = nil, -- Mũi tên chỉ đàn tế / Altar (Màu cam)
	},
}

-- Hàm phụ trợ ngắt kết nối/dọn dẹp đa dạng đối tượng
local function cleanupItem(item)
	if not item then
		return
	end
	local itemType = typeof(item)
	if itemType == "RBXScriptConnection" then
		pcall(function()
			item:Disconnect()
		end)
	elseif itemType == "function" then
		pcall(item)
	elseif itemType == "table" then
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
	elseif itemType == "Instance" then
		pcall(function()
			item:Destroy()
		end)
	end
end

-- Đăng ký một kết nối sự kiện chung vào danh sách dọn dẹp
function GC.registerConnection(conn)
	if conn then
		table.insert(GC.ActiveConnections, conn)
	end
end

-- Thực hiện dọn dẹp và giải phóng tài nguyên cực hạn (GC)
function GC.cleanAll()
	-- Xóa toàn bộ tia sáng & Highlight khỏi game qua Logic module
	local success, err = pcall(function()
		Logic.clearVisuals(GC, false)
	end)
	if not success then
		warn("[Simulated Upgrades GC] Lỗi khi dọn dẹp Visuals: " .. tostring(err))
	end

	-- Ngắt toàn bộ kết nối sự kiện
	for _, conn in ipairs(GC.ActiveConnections) do
		cleanupItem(conn)
	end
	table.clear(GC.ActiveConnections)
end

return GC
