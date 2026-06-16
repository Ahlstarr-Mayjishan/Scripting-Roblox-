-- Script Path: game:GetService("ReplicatedStorage").Movement.SlideManager
-- Took 0.59s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}

t.__index = t

local v1 = workspace:GetAttribute("Null")

function t.new(p1, p2) --[[ new | Line: 9 | Upvalues: t (copy) ]]
	local t2 = {
		Movement = p1,
		Animator = p2,
		SFX = p1.SFX,
	}

	t2.RootPart = t2.Movement.RootPart
	t2.Humanoid = t2.Movement.Humanoid
	t2.storedSlideVel = Vector3.new(0, 0, 0)
	t2.slideStart = time()
	t2.lastFloorSlideDirection = Vector3.new(0, 0, 0)
	t2.Humanoid:SetAttribute("Sliding", false)

	return setmetatable(t2, t)
end
function t.CheckGrounded(p1) --[[ CheckGrounded | Line: 30 ]]
	local v1 = p1.Humanoid:GetState()

	return if v1 == Enum.HumanoidStateType.Running then true else v1 == Enum.HumanoidStateType.Landed
end
function t.FloorCheck(p1, p2) --[[ FloorCheck | Line: 35 ]]
	if not p1.Movement.sliding then
		return
	end

	if not p1:CheckGrounded() and p1.RootPart.Velocity.Y > 4 then
		return
	end

	local sum = Vector3.new(0, -2.5, 0)

	if p1.RootPart.Velocity.Y < 0 then
		sum = sum + Vector3.new(0, 1, 0) * p1.RootPart.Velocity.Y / 100

		if sum.Magnitude > 64 then
			sum = sum.Unit * 64
		end
	end

	local v2 =
		workspace:Spherecast(p1.RootPart.Position + Vector3.new(0, -1.5, 0), 0.15, sum, p1.Movement.moveCastParams)

	if v2 then
		local v3 = v2.Normal:Cross(p1.RootPart.CFrame.RightVector)
		local v4 = v3:Dot(Vector3.new(0, 1, 0))
		local v5 = 1 - v2.Normal:Dot(Vector3.new(0, 1, 0))
		local Y2 = (v2.Position + Vector3.new(0, 3 + v5 * math.clamp(math.abs(p1.RootPart.Velocity.Y) / 50, 0, 1), 0)).Y

		p1.RootPart.CFrame = CFrame.lookAlong(
			Vector3.new(p1.RootPart.Position.X, Y2, p1.RootPart.Position.Z),
			p1.RootPart.CFrame.LookVector
		)

		if v4 < -0.1 then
			local RootPart = p1.RootPart

			RootPart.Velocity = RootPart.Velocity + v3 * 300 * p2

			local Movement = p1.Movement

			Movement.slideSlopeSpeed = Movement.slideSlopeSpeed
				+ math.abs(p1.Movement.storedSlideVel.Y) / 32 * math.abs(v4)

			local Movement2 = p1.Movement

			Movement2.slideSlopeSpeed = Movement2.slideSlopeSpeed
				+ (p1.Movement.storedSlideVel * Vector3.new(1, 0, 1)).Magnitude / 4 * math.abs(v4)
			p1.Movement.friction = 1.5

			local Movement3 = p1.Movement

			Movement3.slideSlopeSpeed = Movement3.slideSlopeSpeed + p2 * 38 * math.abs(v4)
		elseif v4 > 0.1 then
			local RootPart = p1.RootPart

			RootPart.Velocity = RootPart.Velocity - v3 * 300 * p2
			p1.Movement.friction = 1.5

			local Movement = p1.Movement

			Movement.slideSlopeSpeed = Movement.slideSlopeSpeed
				+ math.abs(p1.Movement.storedSlideVel.Y) / 32 * math.abs(v4)

			local Movement2 = p1.Movement

			Movement2.slideSlopeSpeed = Movement2.slideSlopeSpeed
				+ (p1.Movement.storedSlideVel * Vector3.new(1, 0, 1)).Magnitude / 4 * math.abs(v4)

			local Movement3 = p1.Movement

			Movement3.slideSlopeSpeed = Movement3.slideSlopeSpeed - p2 * 24 * math.abs(v4)
		end

		if v2.Normal.Y < 0.99 then
			p1.Movement.WantDirection = v2.Normal * Vector3.new(1, 0, 1) * 2

			if p1.Movement.WantDirection.Magnitude > 1 then
				p1.Movement.WantDirection = p1.Movement.WantDirection.Unit
			end
		end

		p1.Movement.storedSlideVel = Vector3.new(0, 0, 0)
		p1.Movement.slideDir = v3
	else
		p1.Movement.storedSlideVel = Vector3.new(0, 0, 0)
	end

	if v2 then
		return v2.Normal
	end

	return nil
end
function t.WallCheck(p1, p2, p3) --[[ WallCheck | Line: 105 ]]
	if p2 ~= p2 then
		return
	end

	if not p1.Movement.sliding then
		return
	end

	local v1 = p1.RootPart.Position + Vector3.new(0, -2, 0)
	local t = {}

	for i = -0.1, 0.1, 0.1 do
		local v2 = workspace:Raycast(v1 + Vector3.new(0, 1, 0) * i, p2, p1.Movement.moveCastParams)

		if v2 then
			table.insert(t, v2)

			local v4 = math.deg((v2.Normal:Angle(Vector3.new(0, 1, 0))))

			if v4 > 70 and v4 < 170 or p3 then
				if (p1.RootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude > 4 and p3 ~= true then
					p1:EndSlide("Bonk", v2)

					continue
				end

				p1:EndSlide()
			end
		end
	end

	if not (#t > 0) then
		return
	end

	local sum = 0
	local v5 = 0

	for v6, v7 in t do
		sum = sum + math.deg((v7.Normal:Angle(Vector3.new(0, 1, 0))))

		if math.abs(v7.Position.Y - v1.Y) < 0.02 then
			v5 = v6
		end
	end

	local v10 = sum / #t

	if not (v10 > 80 and v10 < 170 or p3) then
		return
	end

	if (p1.RootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude > 4 and p3 ~= true then
		p1:EndSlide("Bonk", if v5 then t[v5] else t[1])
	else
		p1:EndSlide()
	end
end
function t.SlideCancel(p1, p2) --[[ SlideCancel | Line: 154 ]]
	p1.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	if p1.RootPart:FindFirstChild("DiveVelocity") then
		p1.RootPart.DiveVelocity:Destroy()
	end

	local v1 = p1.Movement.PlayerMoveDirection:Dot(p1.Movement.TrueMoveUnit)
	local v2 = if p1.Movement.sliding then 26 else 30
	local v4 = (v2 - v1 * 2) * math.clamp((time() - p1.Movement.diveTime) / 0.05, 0.85, 1)
	local v6 = 1.8 * (v1 + 1) / 2 + 0.2

	if time() - p1.slideStart < 0.07 then
		p1.SFX:PlaySound("PerfectDive")
		v6 = v6 * 1.15
	end

	local v7 = v6 * p1.Movement.TrueMoveDirection.Magnitude

	if not p1.Movement.poweredDive then
		local Movement = p1.Movement

		Movement.TrueMoveDirection = Movement.TrueMoveDirection
			* (
				(16 + p1.Movement.sprintSpeed)
				/ ((16 + p1.Movement.sprintSpeed) * (p1.Movement.movementSpeedMulti + p1.Movement.classSpeedMulti))
			)
	end

	p1.Movement.poweredDive = false
	p1.RootPart.Velocity = p1.RootPart.Velocity * Vector3.new(1, 0, 1) * v7 + Vector3.new(0, v4, 0)
	p1.Movement.diving = false

	if p1.SFX.LoadedSounds.Dive_Alt and p1.SFX.LoadedSounds.Dive_Alt.IsPlaying then
		game.TweenService
			:Create(p1.SFX.LoadedSounds.Dive_Alt, TweenInfo.new(0.2), {
				Volume = 0,
			})
			:Play()
	end

	p1.Movement.sliding = false
	p1.Movement.slideJumped = true
	p1.Movement.sprintSpeed = 8
	p1.Movement.slideJumpSpeed = 12 + v1 * 6

	if p1.Movement.slideJumpSpeed ~= p1.Movement.slideJumpSpeed then
		p1.Movement.slideJumpSpeed = 0
	end

	p1.Animator:StopAnimation("DiveLoop")
	p1.Animator:StopAnimation("DiveStart")
	p1.Animator:PlayAnimation("SlideCancel")
	p1.SFX:PlaySlideCancel()
	p1.Movement:FlipFlop()
end
function t.StartSlide(p1) --[[ StartSlide | Line: 226 ]]
	p1.Humanoid:SetAttribute("Sliding", true)
	p1.Movement.sliding = true
	p1.Animator:StopAnimation("SlideGetUp")
	p1.Animator:StopAnimation("SlideCancel")
	p1.Animator:PlayAnimation("SlideStart")
	p1.Movement:AdjustHitbox(1, -2)
	p1.Movement.Humanoid.JumpPower = game.StarterPlayer.CharacterJumpPower / 1.3
end
function t.EndSlide(p1, p2, p3) --[[ EndSlide | Line: 243 | Upvalues: v1 (copy) ]]
	p1.Humanoid:SetAttribute("Sliding", false)
	p1.Humanoid:SetAttribute("UsingAbility", false)
	p1.Movement.Humanoid.JumpPower = game.StarterPlayer.CharacterJumpPower
	p1.Movement.sliding = false
	p1.Movement:AdjustHitbox(3, 0.5)
	p1.Animator:StopAnimation("SlideStart")

	if p1.Movement:HasUpgrade("FistOfSteel") and v1 then
		game.ReplicatedStorage.Events.MovementGiftMagnet:Fire({
			Reset = "ujiosdfgh",
		})
	end

	if p2 == "SlideCancel" then
		p1:SlideCancel(p3)

		return
	end

	if p2 == "GetUp" then
		p1.Animator:PlayAnimation("SlideGetUp")

		return
	end

	if p2 ~= "Bonk" then
		return
	end

	p1.Movement:DiveBonk(p3)
end
function t.Step(p1, p2) --[[ Step | Line: 275 ]]
	local slideSlopeSpeed = p1.Movement.slideSlopeSpeed

	if p1.Movement.sliding then
		if p1.slideStart == -1000 then
			p1.slideStart = time()
		end

		p1.Movement.slideDir = p1.Movement.TrueMoveDirection

		local v1 = Vector3.new(0, 1, 0)

		if p1:CheckGrounded() then
			p1.Movement.friction = 1
		else
			p1.Movement.friction = 0
		end

		p1.Movement.WantDirection = Vector3.new(0, 0, 0)
		p1.Movement.slideJumpSpeed = 12

		local v2 = p1:FloorCheck(p2)

		p1:WallCheck(p1.RootPart.Velocity.Unit * 3)
		p1:WallCheck(p1.Movement.TrueMoveUnit * 2)
		p1:WallCheck(-p1.RootPart.CFrame.RightVector, true)
		p1:WallCheck(p1.RootPart.CFrame.RightVector, true)

		if p1.Movement.TrueMoveDirection.Magnitude < 0.3 and (p1:CheckGrounded() and (v2 and v2.Y > 0.99)) then
			p1:EndSlide("GetUp")
		end

		if not p1.Movement.sliding then
			return
		end

		if v2 then
			v1 = v2
		end

		p1.Movement.slideNormal = v1
	else
		p1.Movement.slideNormal = Vector3.new(0, 1, 0)
		p1.slideStart = -1000
		p1.Movement.storedSlideVel = Vector3.new(0, 0, 0)
		p1.lastFloorSlideDirection = nil
	end

	if p1.Movement.FloorParticles then
		if p1.Movement.sliding and p1:CheckGrounded() then
			local Magnitude = p1.Movement.TrueMoveDirection.Magnitude

			p1.Movement.FloorParticles.Sliding.Rate = Magnitude * 50
			p1.Movement.FloorParticles.Sliding.Speed = NumberRange.new(Magnitude * 10, Magnitude * 20)
		else
			p1.Movement.FloorParticles.Sliding.Rate = 0
		end
	end

	if not (p1.Movement.slideSlopeSpeed <= slideSlopeSpeed) then
		return
	end

	if p1:CheckGrounded() then
		if p1.Movement.sliding then
			p1.Movement.slideSlopeSpeed = math.max(p1.Movement.slideSlopeSpeed - p2 * 32, 0)
		else
			p1.Movement.slideSlopeSpeed = math.max(p1.Movement.slideSlopeSpeed - p2 * 128, 0)
		end
	else
		p1.Movement.slideSlopeSpeed = math.max(p1.Movement.slideSlopeSpeed - p2 * 16, 0)
	end
end

return t
