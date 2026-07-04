--!nocheck

local Planner = {}
local Distance = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Distance.luau")

local RANGE_BUFFER = 0.75
local MAX_ROUTE_POINTS = 5
local MAX_SEED_CANDIDATES = 48
local MAX_CENTER_ITEMS = 18
local MAX_PAIR_CENTERS = 36
local EDGE_PENALTY_RATIO = 0.92

local function nativeDistanceSq(a, b)
	return Distance.nativeDistanceSq(a, b)
end

local function collectDistanceSq(giftPosition, targetPosition)
	return Distance.collectDistanceSq(giftPosition, targetPosition)
end

local function getSafeRange(range)
	return math.max(5, (tonumber(range) or 60) - RANGE_BUFFER)
end

local function scoreCluster(cluster, targetPosition, seed, origin, range)
	local golden = 0
	local edgePenalty = 0
	local edgeSq = range and (range * EDGE_PENALTY_RATIO) ^ 2 or nil

	for _, item in ipairs(cluster) do
		if item.golden then
			golden += 1
		end
		if edgeSq and targetPosition and collectDistanceSq(item.pos, targetPosition) >= edgeSq then
			edgePenalty += 1
		end
	end

	local targetRootPosition = Distance.getRootPosition(targetPosition or seed.pos)
	local originDistance = origin and nativeDistanceSq(targetRootPosition, origin) or 0
	return {
		Golden = golden,
		Total = #cluster,
		EdgePenalty = edgePenalty,
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
	if score.EdgePenalty ~= bestScore.EdgePenalty then
		return score.EdgePenalty < bestScore.EdgePenalty
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
		if collectDistanceSq(item.pos, position) <= rangeSq then
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

local function addCenter(centers, position)
	if typeof(position) ~= "Vector3" then
		return
	end

	for _, existing in ipairs(centers) do
		if nativeDistanceSq(existing, position) <= 0.25 then
			return
		end
	end

	table.insert(centers, position)
end

local function addPairCenters(centers, seedCluster, range)
	local rangeSq = range * range
	local added = 0
	for index, a in ipairs(seedCluster) do
		for nextIndex = index + 1, #seedCluster do
			local b = seedCluster[nextIndex]
			local distSq = nativeDistanceSq(a.pos, b.pos)
			if distSq <= rangeSq * 4 then
				addCenter(centers, (a.pos + b.pos) * 0.5)
				added += 1
				if added >= MAX_PAIR_CENTERS then
					return
				end
			end
		end
	end
end

local function getSeedCandidates(candidates, origin)
	if #candidates <= MAX_SEED_CANDIDATES then
		return candidates
	end

	local seeds = table.clone(candidates)
	table.sort(seeds, function(a, b)
		if a.golden ~= b.golden then
			return a.golden == true
		end

		if origin then
			local distanceA = nativeDistanceSq(a.pos, origin)
			local distanceB = nativeDistanceSq(b.pos, origin)
			if distanceA ~= distanceB then
				return distanceA < distanceB
			end
		end

		return tostring(a.id or "") < tostring(b.id or "")
	end)

	local limited = {}
	for index = 1, math.min(#seeds, MAX_SEED_CANDIDATES) do
		table.insert(limited, seeds[index])
	end
	return limited
end

local function sortCluster(cluster, targetPosition)
	table.sort(cluster, function(a, b)
		if a.golden ~= b.golden then
			return a.golden == true
		end

		local distanceA = collectDistanceSq(a.pos, targetPosition)
		local distanceB = collectDistanceSq(b.pos, targetPosition)
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
		addCenter(centers, weightedCenter)
	end

	local centerItems = {}
	for index, item in ipairs(seedCluster) do
		if index > MAX_CENTER_ITEMS then
			break
		end
		table.insert(centerItems, item)
		addCenter(centers, item.pos)
	end
	addPairCenters(centers, centerItems, safeRange)

	local bestCluster = nil
	local bestPosition = seed.pos
	local bestScore = nil

	for _, position in ipairs(centers) do
		local cluster = buildAroundPosition(candidates, position, safeRange)
		local score = scoreCluster(cluster, position, seed, nil, safeRange)
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
	local seedCandidates = getSeedCandidates(candidates, origin)

	for _, seed in ipairs(seedCandidates) do
		local cluster = Planner.buildCluster(candidates, seed, range)
		local targetPosition = cluster.TargetPosition or seed.pos
		local score = scoreCluster(cluster, targetPosition, seed, origin, cluster.SafeRange or getSafeRange(range))
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

local function removeClusterItems(remaining, cluster)
	local covered = {}
	for _, item in ipairs(cluster) do
		covered[item] = true
	end

	local nextRemaining = {}
	for _, item in ipairs(remaining) do
		if not covered[item] then
			table.insert(nextRemaining, item)
		end
	end

	return nextRemaining
end

function Planner.planRoute(candidates, range, origin)
	local route = {}
	local remaining = table.clone(candidates or {})
	local currentOrigin = origin

	while #remaining > 0 and #route < MAX_ROUTE_POINTS do
		local cluster, planInfo = Planner.pickBestCluster(remaining, range, currentOrigin)
		if not cluster or #cluster == 0 then
			break
		end

		table.insert(route, {
			Cluster = cluster,
			Info = planInfo,
		})

		remaining = removeClusterItems(remaining, cluster)
		currentOrigin = planInfo and Distance.getRootPosition(planInfo.TargetPosition) or currentOrigin
	end

	return route, remaining
end

return Planner
