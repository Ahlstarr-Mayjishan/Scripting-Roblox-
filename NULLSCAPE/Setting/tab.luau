--!nocheck
--[[
	NULLSCAPE - Settings Tab
	Loaded after gameplay tabs so startup prioritizes active features.
]]

return function(Client)
	local Window = Client and Client.Window
	if not Window then
		return
	end

	local SettingsTab = Window:CreateTab("Settings", 4483362458)
	Client.Tabs.Settings = SettingsTab
	local characterActions = Client.Modules and Client.Modules.CharacterActions
	if not characterActions then
		local loaded, result = pcall(function()
			return getgenv().loadModule("NULLSCAPE/Setting/Character Actions.luau")
		end)
		if loaded and typeof(result) == "table" then
			characterActions = result
			Client.Modules.CharacterActions = result
		else
			warn("[NULLSCAPE] Character actions unavailable: " .. tostring(result))
		end
	end

	SettingsTab:CreateSection("Character")

	SettingsTab:CreateButton({
		Name = "Respawn",
		Callback = function()
			if characterActions and typeof(characterActions.respawn) == "function" then
				local ok, message = characterActions.respawn()
				if not ok and getgenv().Rayfield then
					getgenv().Rayfield:Notify({
						Title = "Respawn Failed",
						Content = message,
						Duration = 3,
					})
				end
			end
		end,
	})

	SettingsTab:CreateToggle({
		Name = "Unlock Reset Button",
		CurrentValue = false,
		Flag = "UnlockResetButtonToggle",
		Callback = function(value)
			if characterActions and typeof(characterActions.setResetUnlocked) == "function" then
				characterActions.setResetUnlocked(value)
			end
		end,
	})

	SettingsTab:CreateSection("Interface")

	SettingsTab:CreateButton({
		Name = "Destroy UI",
		Callback = function()
			local destroyLogic = Client.Modules and Client.Modules.DestroyLogic
			if destroyLogic and typeof(destroyLogic.request) == "function" then
				destroyLogic.request(Client)
			else
				Client:Destroy("User")
			end
		end,
	})

	SettingsTab:CreateSection("Performance")

	SettingsTab:CreateDropdown({
		Name = "FPS Boost",
		Options = { "Low Graphics", "VFX", "Enemies", "Map" },
		CurrentOption = {},
		MultipleOptions = true,
		Flag = "PerformanceCullingDropdown",
		Callback = function(options)
			local fpsBoost = Client.Modules and Client.Modules.FPSBoost
			if fpsBoost and typeof(fpsBoost.setSelections) == "function" then
				fpsBoost.setSelections(options)
			end
		end,
	})

	SettingsTab:CreateSection("Runtime Updates")

	SettingsTab:CreateToggle({
		Name = "Auto Runtime Update",
		CurrentValue = false,
		Flag = "RuntimeUpdaterEnabledToggle",
		Callback = function(value)
			local updater = Client.Modules and Client.Modules.RuntimeUpdater
			if updater and typeof(updater.setAutoUpdateEnabled) == "function" then
				updater:setAutoUpdateEnabled(value)
			end
		end,
	})

	SettingsTab:CreateToggle({
		Name = "Silent Update Install",
		CurrentValue = false,
		Flag = "RuntimeUpdaterSilentToggle",
		Callback = function(value)
			local updater = Client.Modules and Client.Modules.RuntimeUpdater
			if updater and typeof(updater.setSilentInstall) == "function" then
				updater:setSilentInstall(value)
			end
		end,
	})

	SettingsTab:CreateButton({
		Name = "Check Runtime Update",
		Callback = function()
			local updater = Client.Modules and Client.Modules.RuntimeUpdater
			if updater and typeof(updater.checkAndInstall) == "function" then
				task.spawn(function()
					updater:checkAndInstall(true)
				end)
			end
		end,
	})
end
