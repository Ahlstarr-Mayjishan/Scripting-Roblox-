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
