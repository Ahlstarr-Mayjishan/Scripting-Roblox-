-- [[
--  NULLSCAPE - TouchInterest Entities Immunity
--  Owns reversible CanTouch changes for contact-based entity immunity.
-- ]]

local Logic = {}
local CollectionService = game:GetService("CollectionService")

-- ============================================================
-- Contact immunity configuration
-- ============================================================
Logic.Config = {
	["Baby"] = "BabyImmune",
	["Bell"] = "BellImmune",
	["Flesh"] = "FleshImmune",
	["Mart"] = "MartImmune",
	["Telefragger"] = "TelefraggerImmune",
	["Guardian"] = "GuardianImmune",
	["ShadowGuardian"] = "GuardianImmune",
	["Sigil"] = "SigilImmune",
	["Cadence"] = "CadenceImmune",
	["Catalyst"] = "CatalystImmune",
	["nilEnemy"] = "nilEnemyImmune",
	["nilMirage"] = "nilMirageImmune",
	["Ponderer"] = "PondererImmune",
}

local processedEntities = setmetatable({}, { __mode = "k" })
local descendantConnections = setmetatable({}, { __mode = "k" })
local temporaryAllowUntil = {}

local function getNow()
	return time()
end

local function isTemporaryAllowed(entityName)
	local untilTime = temporaryAllowUntil[entityName]
	if not untilTime then
		return false
	end

	if getNow() > untilTime then
		temporaryAllowUntil[entityName] = nil
		return false
	end

	return true
end

local function isTemporaryAllowedForName(name)
	if isTemporaryAllowed(name) then
		return true
	end

	local lowerName = string.lower(tostring(name or ""))
	for allowedName in pairs(temporaryAllowUntil) do
		if string.find(lowerName, string.lower(tostring(allowedName))) and isTemporaryAllowed(allowedName) then
			return true
		end
	end

	return false
end

local function partMatchesEntity(part, entityName)
	if not (part and entityName) then
		return false
	end

	local lowerName = string.lower(entityName)
	local current = part
	while current do
		if string.find(string.lower(current.Name), lowerName) then
			return true
		end
		current = current.Parent
	end

	return false
end

local function nameMatchesEntity(name, entityName)
	return string.find(string.lower(tostring(name or "")), string.lower(tostring(entityName or ""))) ~= nil
end

local function isNativeCollectiblePath(instance)
	local current = instance
	while current do
		local lowerName = string.lower(tostring(current.Name or ""))
		local hasCadenceTag = false
		pcall(function()
			hasCadenceTag = CollectionService:HasTag(current, "CadenceOrb")
		end)
		if
			hasCadenceTag
			or string.find(lowerName, "cadenceorb", 1, true)
			or string.find(lowerName, "cadence orb", 1, true)
			or string.find(lowerName, "instrument", 1, true)
		then
			return true
		end
		current = current.Parent
	end
	return false
end

local function disconnectConnections(connections)
	for _, conn in ipairs(connections or {}) do
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
end

local function restoreSavedPart(gc, part)
	local data = gc and gc.SavedPartsData and gc.SavedPartsData[part]
	if not data then
		return
	end

	if part and part.Parent then
		disconnectConnections(data.connections)
		pcall(function()
			part.CanTouch = data.originalCanTouch
		end)
	end

	gc.SavedPartsData[part] = nil
end

local function getEntitiesGC()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.NullscapeEntitiesGC or nil
end

local function getStatusImmunity()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.NullscapeStatusImmunity or nil
end

local function clearTable(t)
	if not t then
		return
	end
	if table.clear then
		table.clear(t)
	else
		for k in pairs(t) do
			t[k] = nil
		end
	end
end

function Logic.isTargetEntity(name)
	if not name then
		return false
	end
	local lowerName = string.lower(name)
	if string.find(lowerName, "orb") or string.find(lowerName, "instrument") then
		return false
	end
	for configName, _ in pairs(Logic.Config) do
		if string.find(lowerName, string.lower(configName)) then
			return true
		end
	end
	return false
end

function Logic.getImmunityCheck(name, controller)
	if not name or not controller then
		return nil
	end
	local lowerName = string.lower(name)
	if string.find(lowerName, "orb") or string.find(lowerName, "instrument") then
		return nil
	end
	for configName, immuneKey in pairs(Logic.Config) do
		if string.find(lowerName, string.lower(configName)) then
			return function()
				if isTemporaryAllowedForName(configName) then
					return false
				end

				local isImmune = controller[immuneKey] == true
				if not isImmune and string.lower(configName) == "bell" then
					local StatusImmunity = getStatusImmunity()
					if StatusImmunity and StatusImmunity.isImmune("Bell Knockback") then
						return true
					end
				end
				return isImmune
			end
		end
	end
	return nil
end

local function removeTouchFromPart(gc, enemy, part)
	if not part or not part.Parent then
		return
	end
	local parentPart = part.Parent
	if isNativeCollectiblePath(parentPart) then
		return
	end

	if parentPart and parentPart:IsA("BasePart") then
		if not gc.SavedPartsData[parentPart] then
			gc.SavedPartsData[parentPart] = {
				originalCanTouch = parentPart.CanTouch,
				enemyName = enemy.Name,
				connections = {},
			}

			parentPart.CanTouch = false

			local conn = parentPart:GetPropertyChangedSignal("CanTouch"):Connect(function()
				if parentPart.CanTouch and not isTemporaryAllowedForName(enemy.Name) then
					parentPart.CanTouch = false
				end
			end)
			table.insert(gc.SavedPartsData[parentPart].connections, conn)
			gc.registerEntityConnection(enemy, conn)
		end
	end
end

function Logic.enableImmunity(gc, enemy)
	if not enemy or not (enemy:IsA("Model") or enemy:IsA("BasePart")) then
		return
	end

	local controller = gc.Controller
		or (getgenv().Client and getgenv().Client.Modules and getgenv().Client.Modules.EntitiesController)
	if controller and controller.inLobby then
		return
	end

	local checkFunc = Logic.getImmunityCheck(enemy.Name, controller)

	if checkFunc and checkFunc() then
		if not processedEntities[enemy] then
			processedEntities[enemy] = true

			task.defer(function()
				if not enemy or not enemy.Parent then
					return
				end
				for _, part in ipairs(enemy:GetDescendants()) do
					if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
						removeTouchFromPart(gc, enemy, part)
					end
				end
			end)
		end
	end

	if not descendantConnections[enemy] then
		local descConn = enemy.DescendantAdded:Connect(function(part)
			if part:IsA("TouchTransmitter") or part.Name == "TouchInterest" then
				if checkFunc and checkFunc() then
					removeTouchFromPart(gc, enemy, part)
				end
			end
		end)
		descendantConnections[enemy] = descConn
		gc.registerEntityConnection(enemy, descConn)
	end
end

function Logic.disableImmunityForType(gc, entityName)
	temporaryAllowUntil[entityName] = nil
	for part, data in pairs(gc.SavedPartsData) do
		if data and data.enemyName and nameMatchesEntity(data.enemyName, entityName) then
			restoreSavedPart(gc, part)
		end
	end

	for enemy in pairs(processedEntities) do
		if enemy and nameMatchesEntity(enemy.Name, entityName) then
			processedEntities[enemy] = nil
		end
	end

	for enemy, conn in pairs(descendantConnections) do
		if enemy and nameMatchesEntity(enemy.Name, entityName) then
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
			descendantConnections[enemy] = nil
		end
	end
end

function Logic.reconcile(gc)
	if not (gc and gc.SavedPartsData) then
		return
	end

	local controller = gc.Controller
		or (getgenv().Client and getgenv().Client.Modules and getgenv().Client.Modules.EntitiesController)

	for part, data in pairs(gc.SavedPartsData) do
		local checkFunc = data and Logic.getImmunityCheck(data.enemyName, controller)
		if not (checkFunc and checkFunc()) then
			restoreSavedPart(gc, part)
		end
	end

	for enemy in pairs(processedEntities) do
		local checkFunc = enemy and Logic.getImmunityCheck(enemy.Name, controller)
		if not (checkFunc and checkFunc()) then
			processedEntities[enemy] = nil
		end
	end
end

function Logic.beginTemporaryAllow(entityName, duration)
	entityName = tostring(entityName or "")
	if entityName == "" then
		return false
	end

	temporaryAllowUntil[entityName] =
		math.max(temporaryAllowUntil[entityName] or 0, getNow() + (tonumber(duration) or 1))

	local GC = getEntitiesGC()
	for part, data in pairs(GC and GC.SavedPartsData or {}) do
		if data and data.enemyName and string.find(string.lower(data.enemyName), string.lower(entityName)) then
			if part and part.Parent then
				pcall(function()
					part.CanTouch = true
				end)
			end
		elseif partMatchesEntity(part, entityName) then
			pcall(function()
				part.CanTouch = true
			end)
		end
	end

	return true
end

function Logic.endTemporaryAllow(entityName)
	entityName = tostring(entityName or "")
	if entityName == "" then
		return
	end

	temporaryAllowUntil[entityName] = nil
	local GC = getEntitiesGC()
	local controller = GC and GC.Controller
	local checkFunc = Logic.getImmunityCheck(entityName, controller)
	local shouldRestore = checkFunc and checkFunc()

	for part, data in pairs(GC and GC.SavedPartsData or {}) do
		if data and data.enemyName and string.find(string.lower(data.enemyName), string.lower(entityName)) then
			if shouldRestore and part and part.Parent then
				pcall(function()
					part.CanTouch = false
				end)
			end
		end
	end
end

function Logic.restoreAll(gc)
	if not gc.SavedPartsData then
		return
	end
	for part, data in pairs(gc.SavedPartsData) do
		if data and data.originalCanTouch ~= nil and data.connections then
			if part and part.Parent then
				disconnectConnections(data.connections)
				pcall(function()
					part.CanTouch = data.originalCanTouch
				end)
			end
		end
	end
	clearTable(gc.SavedPartsData)
	clearTable(processedEntities)
	clearTable(descendantConnections)
	clearTable(temporaryAllowUntil)
end

function Logic.setInLobbyState(val)
	if val == false then
		clearTable(processedEntities)
		clearTable(descendantConnections)
	end
end

return Logic
