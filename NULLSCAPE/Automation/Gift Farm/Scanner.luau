--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Progress = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Progress.luau")

local Scanner = {}
local SPAWN_SETTLE = 0.35
local GOLDEN_SPAWN_SETTLE = 0.1
local seenGifts = setmetatable({}, { __mode = "k" })

function Scanner.reset()
	seenGifts = setmetatable({}, { __mode = "k" })
end

function Scanner.scan(controller, gch)
	local gifts = {}
	local goldenGifts = {}
	local normalGifts = {}
	local now = os.clock()
	local _, _, normalRatio = Progress.getNormalGiftProgress(gch)
	local rawGolden = 0
	local rawNormal = 0

	for _, gift in pairs(gch.Gifts or {}) do
		if gift and not gift.Destroyed and not gift.Collected and not gift.Tripmine then
			local pos = Context.getGiftPosition(gift)
			local priority = Progress.getGiftPriority(gift, normalRatio, controller)
			if pos and priority ~= nil then
				if gift.Golden then
					rawGolden += 1
				else
					rawNormal += 1
				end
				if not seenGifts[gift] then
					seenGifts[gift] = now
				end
				local settleTime = gift.Golden and GOLDEN_SPAWN_SETTLE or SPAWN_SETTLE
				if now - seenGifts[gift] >= settleTime then
					local entry = {
						rawObj = gift,
						pos = pos,
						priority = priority,
						id = gift.Id or 0,
						golden = gift.Golden == true,
					}
					if gift.Golden then
						table.insert(goldenGifts, entry)
					else
						table.insert(normalGifts, entry)
					end
				end
			end
		end
	end

	if #goldenGifts > 0 then
		gifts = goldenGifts
	else
		gifts = normalGifts
	end

	table.sort(gifts, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return tostring(a.id) < tostring(b.id)
	end)

	return gifts, {
		Golden = #goldenGifts,
		Normal = #normalGifts,
		RawGolden = rawGolden,
		RawNormal = rawNormal,
		GoldenLocked = #goldenGifts > 0,
	}
end

return Scanner
