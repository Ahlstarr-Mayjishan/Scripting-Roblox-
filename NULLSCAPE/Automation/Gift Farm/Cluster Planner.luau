--!nocheck

local Planner = {}

local RANGE_BUFFER = 1.5

local function distanceSq(a, b)
	local offset = a - b
	return offset:Dot(offset)
end

local function getSafeRange(range)
	return math.max(5, (tonumber(range) or 60) - RANGE_BUFFER)
end

local function scoreCluster(cluster, targetPosition, seed, origin)
	local golden = 0
	for _, item in ipairs(cluster) do
		if item.golden then
			golden += 1
		end
	end

	local originDistance = origin and distanceSq(targetPosition or seed.pos, origin) or 0
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

local function buildAroundPosition(candidates, position, range)
	local cluster = {}
	local rangeSq = range * range

	for _, item in ipairs(candidates) do
		if distanceSq(item.pos, position) <= rangeSq then
			table.insert(cluster, item)
		end
	end

	return cluster
end

local function getWeightedCenter(cluster)
	local totalWeight = 0
	local weighted = Vector3.new(0, 0, 0)

	for _, item in ipairs(cluster) do
		local weight = item.golden and 3 or 1
		totalWeight += weight
		weighted += item.pos * weight
	end

	if totalWeight <= 0 then
		return nil
	end

	return weighted / totalWeight
end

local function sortCluster(cluster, targetPosition)
	table.sort(cluster, function(a, b)
		if a.golden ~= b.golden then
			return a.golden == true
		end

		local distanceA = distanceSq(a.pos, targetPosition)
		local distanceB = distanceSq(b.pos, targetPosition)
		if distanceA ~= distanceB then
			return distanceA < distanceB
		end

		return tostring(a.id or "") < tostring(b.id or "")
	end)
end

function Planner.buildCluster(candidates, seed, range)
	local safeRange = getSafeRange(range)
	local seedCluster = buildAroundPosition(candidates, seed.pos, safeRange)
	local centers = { seed.pos }
	local weightedCenter = getWeightedCenter(seedCluster)

	if weightedCenter then
		table.insert(centers, weightedCenter)
	end
	for _, item in ipairs(seedCluster) do
		table.insert(centers, item.pos)
	end

	local bestCluster = nil
	local bestPosition = seed.pos
	local bestScore = nil

	for _, position in ipairs(centers) do
		local cluster = buildAroundPosition(candidates, position, safeRange)
		local score = scoreCluster(cluster, position, seed)
		if isBetterScore(score, bestScore) then
			bestCluster = cluster
			bestPosition = position
			bestScore = score
		end
	end

	local cluster = bestCluster or {}
	sortCluster(cluster, bestPosition)
	cluster.TargetPosition = bestPosition
	cluster.SafeRange = safeRange

	return cluster
end

function Planner.pickBestCluster(candidates, range, origin)
	local bestCluster = nil
	local bestSeed = nil
	local bestScore = nil

	for _, seed in ipairs(candidates) do
		local cluster = Planner.buildCluster(candidates, seed, range)
		local targetPosition = cluster.TargetPosition or seed.pos
		local score = scoreCluster(cluster, targetPosition, seed, origin)
		if isBetterScore(score, bestScore) then
			bestCluster = cluster
			bestSeed = seed
			bestScore = score
		end
	end

	return bestCluster or {}, {
		Seed = bestSeed,
		TargetPosition = bestCluster and bestCluster.TargetPosition or (bestSeed and bestSeed.pos),
		SafeRange = bestCluster and bestCluster.SafeRange or getSafeRange(range),
		Score = bestScore,
	}
end

return Planner
