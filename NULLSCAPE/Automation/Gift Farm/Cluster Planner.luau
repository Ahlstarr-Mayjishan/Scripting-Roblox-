--!nocheck

local Planner = {}

local function distanceSq(a, b)
	local offset = a - b
	return offset:Dot(offset)
end

local function scoreCluster(cluster, seed, origin)
	local golden = 0
	for _, item in ipairs(cluster) do
		if item.golden then
			golden += 1
		end
	end

	local originDistance = origin and distanceSq(seed.pos, origin) or 0
	return {
		Golden = golden,
		Total = #cluster,
		OriginDistance = originDistance,
		SeedId = tostring(seed.id or ""),
	}
end

local function isBetterScore(score, bestScore)
	if not bestScore then
		return true
	end
	if score.Golden ~= bestScore.Golden then
		return score.Golden > bestScore.Golden
	end
	if score.Total ~= bestScore.Total then
		return score.Total > bestScore.Total
	end
	if score.OriginDistance ~= bestScore.OriginDistance then
		return score.OriginDistance < bestScore.OriginDistance
	end
	return score.SeedId < bestScore.SeedId
end

function Planner.buildCluster(candidates, seed, range)
	local cluster = {}
	local rangeSq = range * range

	for _, item in ipairs(candidates) do
		if distanceSq(item.pos, seed.pos) <= rangeSq then
			table.insert(cluster, item)
		end
	end

	table.sort(cluster, function(a, b)
		if a.golden ~= b.golden then
			return a.golden == true
		end
		return tostring(a.id or "") < tostring(b.id or "")
	end)

	return cluster
end

function Planner.pickBestCluster(candidates, range, origin)
	local bestCluster = nil
	local bestSeed = nil
	local bestScore = nil

	for _, seed in ipairs(candidates) do
		local cluster = Planner.buildCluster(candidates, seed, range)
		local score = scoreCluster(cluster, seed, origin)
		if isBetterScore(score, bestScore) then
			bestCluster = cluster
			bestSeed = seed
			bestScore = score
		end
	end

	return bestCluster or {}, {
		Seed = bestSeed,
		Score = bestScore,
	}
end

return Planner
