-- [[
--  NULLSCAPE - Husk / Skinwalker Evasion
--  Disables contact damage without renaming entities or disrupting native ESP.
-- ]]

local Logic = {}

-- ============================================================
-- Entity configuration
-- ============================================================
Logic.Config = {
	["Skinwalker"] = "SkinwalkerImmune",
	["Husk"] = "SkinwalkerImmune",
}

function Logic.isHuskEntity(name)
	if not name then
		return false
	end
	local lowerName = string.lower(name)
	for configName, _ in pairs(Logic.Config) do
		if string.find(lowerName, string.lower(configName)) then
			return true
		end
	end
	return false
end

function Logic.enableHuskImmunity(gc, enemy)
	if not enemy or not enemy:IsA("Model") then
		return
	end
	
	local controller = gc.Controller or (getgenv().Client and getgenv().Client.Modules and getgenv().Client.Modules.EntitiesController)
	if controller and controller.inLobby then
		return
	end
	if
		not Logic.isHuskEntity(enemy.Name)
		and not (enemy:GetAttribute("OriginalName") and Logic.isHuskEntity(enemy:GetAttribute("OriginalName")))
	then
		return
	end

	if not enemy:GetAttribute("OriginalName") then
		enemy:SetAttribute("OriginalName", enemy.Name)
	end

	local originalName = enemy:GetAttribute("OriginalName") or enemy.Name

	for _, part in ipairs(enemy:GetDescendants()) do
		if part:IsA("BasePart") then
			if not gc.SavedPartsData[part] then
				gc.SavedPartsData[part] = {
					originalCanTouch = part.CanTouch,
					originalName = part.Name,
					enemyName = originalName,
				}
			end
			pcall(function()
				part.CanTouch = false
			end)
		end
	end
end

function Logic.onHuskDescendantAdded(gc, enemy, part)
	if
		not Logic.isHuskEntity(enemy.Name)
		and not (enemy:GetAttribute("OriginalName") and Logic.isHuskEntity(enemy:GetAttribute("OriginalName")))
	then
		return
	end

	local originalName = enemy:GetAttribute("OriginalName") or enemy.Name

	if part:IsA("BasePart") then
		if not gc.SavedPartsData[part] then
			gc.SavedPartsData[part] = {
				originalCanTouch = part.CanTouch,
				originalName = part.Name,
				enemyName = originalName,
			}
		end
		pcall(function()
			part.CanTouch = false
		end)
	end
end

function Logic.disableHuskImmunity(gc)
	for part, data in pairs(gc.SavedPartsData) do
		if data and data.enemyName and Logic.isHuskEntity(data.enemyName) then
			if part and part.Parent then
				if data.originalCanTouch ~= nil then
					pcall(function()
						part.CanTouch = data.originalCanTouch
					end)
				end
			end
			gc.SavedPartsData[part] = nil
		end
	end
end

return Logic
