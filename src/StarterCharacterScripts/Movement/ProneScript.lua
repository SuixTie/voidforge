local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local char = script.Parent.Parent
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")
local rootJoint = rootPart:WaitForChild("RootJoint")
local animator = humanoid:WaitForChild("Animator")
local player = Players.LocalPlayer

char.Head.CanCollide = true

local RunConfig = require(game.ReplicatedStorage.RunConfig)

-- === STAMINA INTEGRATION ===
local isBreathing = false

task.spawn(function()
	local breathingEvent = char:WaitForChild("BreathingEvent", 10)
	if breathingEvent then
		breathingEvent.Event:Connect(function(breathing)
			isBreathing = breathing
			print("ProneScript: Breathing state changed to", breathing)
		end)
	else
		warn("ProneScript: BreathingEvent not found!")
	end
end)

-- === НАСТРОЙКИ СМЕЩЕНИЯ ===
local PRONE_OFFSET = -2.5
local STAND_OFFSET = 0
local TRANSITION_SPEED = 0.3

local originalC0 = rootJoint.C0
local defaultHipHeight = humanoid.HipHeight

-- === АНИМАЦИИ ===
local proneIdleAnim = Instance.new("Animation")
proneIdleAnim.AnimationId = "rbxassetid://108445839371180"
local proneMoveAnim = Instance.new("Animation")
proneMoveAnim.AnimationId = "rbxassetid://117557870100193"

local proneIdleTrack = animator:LoadAnimation(proneIdleAnim)
local proneMoveTrack = animator:LoadAnimation(proneMoveAnim)
proneIdleTrack.Priority = Enum.AnimationPriority.Action3
proneMoveTrack.Priority = Enum.AnimationPriority.Action3

-- === ЗВУК ПОЛЗАНИЯ ===
local crawlSound = Instance.new("Sound")
crawlSound.Name = "CrawlSound"
crawlSound.SoundId = "rbxassetid://6563562192"  -- Звук ползания (замени на свой ID)
crawlSound.Volume = 0.03
crawlSound.Looped = true
crawlSound.PlaybackSpeed = 0.55
crawlSound.RollOffMode = Enum.RollOffMode.LinearSquare  -- Более мягкое затухание
crawlSound.RollOffMinDistance = 5
crawlSound.RollOffMaxDistance = 20
crawlSound.Parent = rootPart

-- === ЗВУК НАЧАЛА ПОЛЗАНИЯ ===
local proneStartSound = Instance.new("Sound")
proneStartSound.Name = "ProneStartSound"
proneStartSound.SoundId = "rbxassetid://6636232274"  -- Звук ложения (замени на свой ID)
proneStartSound.Volume = 0.05
proneStartSound.PlaybackSpeed = 0.8
proneStartSound.RollOffMinDistance = 5
proneStartSound.RollOffMaxDistance = 20
proneStartSound.Parent = rootPart

-- === ЗВУК НАЧАЛА ПРИСЕДА (для автоматического приседа из prone) ===
local autoCrouchSound = Instance.new("Sound")
autoCrouchSound.Name = "AutoCrouchSound"
autoCrouchSound.SoundId = "rbxassetid://140071470572800"  -- Тот же звук что в CrouchScript
autoCrouchSound.Volume = 0.1
autoCrouchSound.PlaybackSpeed = 1.3
autoCrouchSound.RollOffMinDistance = 5
autoCrouchSound.RollOffMaxDistance = 20
autoCrouchSound.Parent = rootPart

-- === ЗВУК ПОДЪЁМА ===
local standUpSound = Instance.new("Sound")
standUpSound.Name = "StandUpSound"
standUpSound.SoundId = "rbxassetid://101486761816396"  -- Звук подъёма
standUpSound.Volume = 0.08
standUpSound.RollOffMinDistance = 5
standUpSound.RollOffMaxDistance = 20
standUpSound.Parent = rootPart

local function setProneVisual(offset)
	local targetC0 = originalC0 * CFrame.new(0, 0, offset)
	TweenService:Create(rootJoint, TweenInfo.new(TRANSITION_SPEED), {C0 = targetC0}):Play()
end

local function getCeilingData()
	local head = char:FindFirstChild("Head")
	if not head then return nil, 6 end 

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {char}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local rayOrigin = head.Position
	local rayDirection = Vector3.new(0, 6, 0) 

	local result = workspace:Spherecast(rayOrigin, 0.5, rayDirection, raycastParams)
	local distance = result and result.Distance or 6

	return result, distance
end

RunService.RenderStepped:Connect(function()
	local hit, dist = getCeilingData()
	local isMoving = humanoid.MoveDirection.Magnitude > 0.1
	local isCrouchingValue = player:FindFirstChild("IsCrouching")
	local isSlidingValue = player:FindFirstChild("IsSliding")
	local wasSlidingValue = player:FindFirstChild("WasSliding")

	if isSlidingValue and isSlidingValue.Value then return end

	local ENTER_PRONE_DIST = 0.1 
	local EXIT_PRONE_DIST = 2 

	local shouldBeProne = RunConfig.isProne

	-- Проверяем находится ли игрок в воздухе
	local isInAir = humanoid.FloorMaterial == Enum.Material.Air

	-- Если игрок в воздухе - не ложимся автоматически
	if isInAir and not RunConfig.isProne then
		shouldBeProne = false
	-- Блокируем ползание во время отдышки
	elseif isBreathing and not RunConfig.isProne then
		shouldBeProne = false
	elseif hit then
		if dist < ENTER_PRONE_DIST then
			shouldBeProne = true
		elseif dist > EXIT_PRONE_DIST then
			shouldBeProne = false
		end
	else
		shouldBeProne = false
	end

	if shouldBeProne then 
		if not RunConfig.isProne then
			RunConfig.isProne = true
			setProneVisual(PRONE_OFFSET)
			humanoid.JumpHeight = 0
			-- Проигрываем звук начала ползания
			proneStartSound:Play()
		end

		humanoid.HipHeight = -1.8 

		if isMoving then
			if not proneMoveTrack.IsPlaying then
				proneIdleTrack:Stop(0.2)
				proneMoveTrack:Play(0.2)
			end
			-- Включаем звук ползания
			if not crawlSound.IsPlaying then
				crawlSound:Play()
			end
		else
			if proneMoveTrack.IsPlaying then proneMoveTrack:Stop(0.2) end
			if not proneIdleTrack.IsPlaying then proneIdleTrack:Play(0.2) end
			-- Останавливаем звук ползания
			if crawlSound.IsPlaying then
				crawlSound:Stop()
			end
		end
		humanoid.WalkSpeed = RunConfig.ProneSpeed
	else
		if RunConfig.isProne then
			RunConfig.isProne = false
			setProneVisual(STAND_OFFSET)
			proneIdleTrack:Stop(0.3)
			proneMoveTrack:Stop(0.3)
			-- Останавливаем звук ползания при выходе из prone
			if crawlSound.IsPlaying then
				crawlSound:Stop()
			end
			-- Проигрываем звук подъёма (не при перекате и не сразу после него)
			local isSliding = isSlidingValue and isSlidingValue.Value or false
			local wasSliding = wasSlidingValue and wasSlidingValue.Value or false
			if not isSliding and not wasSliding then
				standUpSound:Play()
			end
			humanoid.JumpHeight = humanoid:GetAttribute("DefaultJumpHeight") or 7.2
		end

		if hit and dist < 2 then
			-- Проигрываем звук если входим в присед
			if isCrouchingValue and isCrouchingValue.Value == false then
				autoCrouchSound:Play()
			end
			if isCrouchingValue then isCrouchingValue.Value = true end
			humanoid.HipHeight = -0.5
		else
			if isCrouchingValue and isCrouchingValue.Value == true then
				humanoid.HipHeight = -0.5
			else
				humanoid.HipHeight = defaultHipHeight
				if isCrouchingValue then isCrouchingValue.Value = false end
			end
		end
	end
end)