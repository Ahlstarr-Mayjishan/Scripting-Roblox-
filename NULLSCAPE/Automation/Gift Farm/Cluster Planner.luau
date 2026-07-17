--!nocheck

local Planner = {}
local Distance = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Distance.luau")

local RANGE_BUFFER = 3.5
local MAX_ROUTE_POINTS = 36
local MAX_TAIL_ROUTE_POINTS = 32
local MAX_REFINED_CENTERS = 6
local EDGE_PENALTY_RATIO = 0.92
local Y_SCALE = 0.8
local ROOT_OFFSET = Vector3.new(0, 3, 0)

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
	local passage = 0
	local golden = 0
	local bonusTilePriority = 0
	local collapseUrgency = 0
	local collapseCount = 0
	local edgePenalty = 0
	local edgeSq = range and (range * EDGE_PENALTY_RATIO) ^ 2 or nil

	for _, item in ipairs(cluster) do
		if item.passage then
			passage += 1
		end
		if item.golden then
			golden += 1
		end
		bonusTilePriority += tonumber(item.bonusTilePriority) or 0
		local itemCollapse = tonumber(item.collapsePriority) or 0
		if itemCollapse > 0 then
			collapseUrgency += itemCollapse
			collapseCount += 1
		end
		if edgeSq and targetPosition and collectDistanceSq(item.pos, targetPosition) >= edgeSq then
			edgePenalty += 1
		end
	end

	local targetRootPosition = Distance.getRootPosition(targetPosition or seed.pos)
	local originDistance = origin and nativeDistanceSq(targetRootPosition, origin) or 0
	return {
		Passage = passage,
		Golden = golden,
		BonusTilePriority = bonusTilePriority,
		CollapseUrgency = collapseUrgency,
		CollapseCount = collapseCount,
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
	if score.Passage ~= bestScore.Passage then
		return score.Passage > bestScore.Passage
	end
	if score.Golden ~= bestScore.Golden then
		return score.Golden > bestScore.Golden
	end
	if score.BonusTilePriority ~= bestScore.BonusTilePriority then
		return score.BonusTilePriority > bestScore.BonusTilePriority
	end
	if score.CollapseUrgency ~= bestScore.CollapseUrgency then
		return score.CollapseUrgency > bestScore.CollapseUrgency
	end
	if score.CollapseCount ~= bestScore.CollapseCount then
		return score.CollapseCount > bestScore.CollapseCount
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

local function sortCluster(cluster, targetPosition)
	table.sort(cluster, function(a, b)
		if a.passage ~= b.passage then
			return a.passage == true
		end
		if a.golden ~= b.golden then
			return a.golden == true
		end
		if a.bonusTilePriority ~= b.bonusTilePriority then
			return (a.bonusTilePriority or 0) > (b.bonusTilePriority or 0)
		end
		if a.collapsePriority ~= b.collapsePriority then
			return (a.collapsePriority or 0) > (b.collapsePriority or 0)
		end

		local distanceA = collectDistanceSq(a.pos, targetPosition)
		local distanceB = collectDistanceSq(b.pos, targetPosition)
		if distanceA ~= distanceB then
			return distanceA < distanceB
		end

		return tostring(a.id or "") < tostring(b.id or "")
	end)
end

local function getCellCoordinates(position, cellSize)
	return math.floor(position.X / cellSize),
		math.floor(position.Y * Y_SCALE / cellSize),
		math.floor(position.Z / cellSize)
end

local function getBucket(grid, x, y, z, create)
	local xGrid = grid[x]
	if not xGrid then
		if not create then return nil end
		xGrid = {}
		grid[x] = xGrid
	end

	local yGrid = xGrid[y]
	if not yGrid then
		if not create then return nil end
		yGrid = {}
		xGrid[y] = yGrid
	end

	local bucket = yGrid[z]
	if not bucket and create then
		bucket = {}
		yGrid[z] = bucket
	end
	return bucket
end

local function buildIndex(candidates, cellSize)
	local index = {
		Grid = {},
		Active = {},
		Candidates = candidates or {},
		CellSize = cellSize,
		Count = 0,
	}

	for _, item in ipairs(index.Candidates) do
		if typeof(item.pos) == "Vector3" then
			local x, y, z = getCellCoordinates(item.pos, cellSize)
			local bucket = getBucket(index.Grid, x, y, z, true)
			bucket[#bucket + 1] = item
			index.Active[item] = true
			index.Count += 1
		end
	end

	return index
end

local function queryIndex(index, targetPosition, range)
	local cluster = {}
	if typeof(targetPosition) ~= "Vector3" or index.Count <= 0 then
		return cluster
	end

	local rootPosition = targetPosition + ROOT_OFFSET
	local x, y, z = getCellCoordinates(rootPosition, index.CellSize)
	local cellSpan = math.max(1, math.ceil(range / index.CellSize))
	local rangeSq = range * range

	for offsetX = -cellSpan, cellSpan do
		for offsetY = -cellSpan, cellSpan do
			for offsetZ = -cellSpan, cellSpan do
				local bucket = getBucket(index.Grid, x + offsetX, y + offsetY, z + offsetZ, false)
				if bucket then
					for _, item in ipairs(bucket) do
						if index.Active[item] and collectDistanceSq(item.pos, targetPosition) <= rangeSq then
							cluster[#cluster + 1] = item
						end
					end
				end
			end
		end
	end

	return cluster
end

local function getWeightedCenter(cluster)
	local totalWeight = 0
	local weighted = Vector3.new(0, 0, 0)

	for _, item in ipairs(cluster) do
		local weight = item.passage and 5 or (item.golden and 3 or 1)
		if (tonumber(item.collapsePriority) or 0) > 0 then
			weight += math.min(4, item.collapsePriority)
		end
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
	centers[#centers + 1] = position
end

local function isBetterSeed(candidate, best, origin)
	if not best then
		return true
	end
	if candidate.passage ~= best.passage then
		return candidate.passage == true
	end
	if candidate.golden ~= best.golden then
		return candidate.golden == true
	end

	local candidatePriority = tonumber(candidate.priority) or 0
	local bestPriority = tonumber(best.priority) or 0
	if candidatePriority ~= bestPriority then
		return candidatePriority < bestPriority
	end
	if candidate.bonusTilePriority ~= best.bonusTilePriority then
		return (candidate.bonusTilePriority or 0) > (best.bonusTilePriority or 0)
	end
	if candidate.collapsePriority ~= best.collapsePriority then
		return (candidate.collapsePriority or 0) > (best.collapsePriority or 0)
	end
	if origin then
		local candidateDistance = nativeDistanceSq(candidate.pos, origin)
		local bestDistance = nativeDistanceSq(best.pos, origin)
		if candidateDistance ~= bestDistance then
			return candidateDistance < bestDistance
		end
	end
	return tostring(candidate.id or "") < tostring(best.id or "")
end

local function pickSeed(index, origin)
	local best = nil
	for _, item in ipairs(index.Candidates) do
		if index.Active[item] and isBetterSeed(item, best, origin) then
			best = item
		end
	end
	return best
end

local function buildIndexedCluster(index, seed, safeRange, origin)
	local seedCluster = queryIndex(index, seed.pos, safeRange)
	if #seedCluster == 0 then
		return {}, nil
	end

	local centers = { seed.pos }
	addCenter(centers, getWeightedCenter(seedCluster))
	sortCluster(seedCluster, seed.pos)
	for itemIndex = 1, math.min(#seedCluster, MAX_REFINED_CENTERS - #centers) do
		addCenter(centers, seedCluster[itemIndex].pos)
	end

	local bestCluster = seedCluster
	local bestPosition = seed.pos
	local bestScore = scoreCluster(seedCluster, seed.pos, seed, origin, safeRange)
	for centerIndex = 2, #centers do
		local position = centers[centerIndex]
		local cluster = queryIndex(index, position, safeRange)
		local score = scoreCluster(cluster, position, seed, origin, safeRange)
		if isBetterScore(score, bestScore) then
			bestCluster = cluster
			bestPosition = position
			bestScore = score
		end
	end

	sortCluster(bestCluster, bestPosition)
	bestCluster.TargetPosition = bestPosition
	bestCluster.SafeRange = safeRange
	return bestCluster, {
		Seed = seed,
		TargetPosition = bestPosition,
		SafeRange = safeRange,
		Score = bestScore,
	}
end

local function deactivateCluster(index, cluster)
	for _, item in ipairs(cluster) do
		if index.Active[item] then
			index.Active[item] = nil
			index.Count -= 1
		end
	end
end

local function getRemaining(index)
	local remaining = {}
	for _, item in ipairs(index.Candidates) do
		if index.Active[item] then
			remaining[#remaining + 1] = item
		end
	end
	return remaining
end

function Planner.buildCluster(candidates, seed, range)
	local safeRange = getSafeRange(range)
	local index = buildIndex(candidates or {}, safeRange)
	local cluster = buildIndexedCluster(index, seed, safeRange, nil)
	return cluster
end

function Planner.pickBestCluster(candidates, range, origin)
	local safeRange = getSafeRange(range)
	local index = buildIndex(candidates or {}, safeRange)
	local seed = pickSeed(index, origin)
	if not seed then
		return {}, {
			TargetPosition = nil,
			SafeRange = safeRange,
			Score = nil,
		}
	end
	return buildIndexedCluster(index, seed, safeRange, origin)
end

local function planIndexedRoute(candidates, range, origin, maxRoutePoints, tailCleanup)
	local route = {}
	local safeRange = getSafeRange(range)
	local index = buildIndex(candidates or {}, safeRange)
	local currentOrigin = origin

	while index.Count > 0 and #route < maxRoutePoints do
		local seed = pickSeed(index, currentOrigin)
		if not seed then
			break
		end

		local cluster, planInfo = buildIndexedCluster(index, seed, safeRange, currentOrigin)
		if #cluster == 0 then
			index.Active[seed] = nil
			index.Count -= 1
			continue
		end

		if tailCleanup then
			planInfo.TailCleanup = true
		end
		route[#route + 1] = {
			Cluster = cluster,
			Info = planInfo,
		}
		deactivateCluster(index, cluster)
		currentOrigin = Distance.getRootPosition(planInfo.TargetPosition)
	end

	return route, getRemaining(index)
end

function Planner.planRoute(candidates, range, origin)
	return planIndexedRoute(candidates, range, origin, MAX_ROUTE_POINTS, false)
end

function Planner.planTailRoute(candidates, range, origin)
	return planIndexedRoute(candidates, range, origin, MAX_TAIL_ROUTE_POINTS, true)
end

return Planner
