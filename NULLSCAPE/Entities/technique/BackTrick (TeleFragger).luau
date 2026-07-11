local BackTrick = {}

function BackTrick.trigger(controller)
	if controller then
		controller.LastBackTrickSuppressedAt = os.clock()
	end
end

function BackTrick.revert(controller)
	BackTrick.cleanup(controller)
end

function BackTrick.cleanup(controller)
	if not controller then
		return
	end

	if controller.BackTrickConnection then
		pcall(function()
			controller.BackTrickConnection:Disconnect()
		end)
		controller.BackTrickConnection = nil
	end

	local char = game.Players.LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			if controller.OriginalAutoRotate ~= nil then
				humanoid.AutoRotate = controller.OriginalAutoRotate
			else
				humanoid.AutoRotate = true
			end
		end)
	end

	if controller.RedirectRootJoint and controller.RedirectOriginalC0 then
		pcall(function()
			controller.RedirectRootJoint.C0 = controller.RedirectOriginalC0
		end)
	end

	controller.WasRedirectingTelefragger = false
	controller.FlickFakeSpectatorEnabled = false
	controller.CurrentFlickAngle = nil
	controller.BackTrickState = nil
	controller.FlickInStartTime = nil
	controller.OriginalAutoRotate = nil
	controller.RedirectRootJoint = nil
	controller.RedirectOriginalC0 = nil
end

return BackTrick
