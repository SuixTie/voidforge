local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local camera = workspace.CurrentCamera

local RunConfig = require(game.ReplicatedStorage.RunConfig)
local LedgeGrabConfig = require(game.ReplicatedStorage.LedgeGrabConfig)
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- === STAMINA STATE ===
local isBreathing = false
local staminaSpeedMultiplier = 1.0  -- Множитель скорости от стамины
local landingSpeedMultiplier = 1.0  -- Множитель скорости от падения

-- === LOW HEALTH STATE ===
local isLowHealth = false
local LOW_HEALTH_THRESHOLD = 0.15  -- 15% здоровья (синхронизировано с HealthSystem)

-- Проверка здоровья
local function checkHealth()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	isLowHealth = healthPercent <= LOW_HEALTH_THRESHOLD
end

humanoid:GetPropertyChangedSignal("Health"):Connect(checkHealth)
checkHealth()  -- Проверяем начальное здоровье

-- === НАСТРОЙКИ ПЕРЕХОДОВ ===
local WALK_TO_RUN_ID = "rbxassetid://119280851918210"
local RUN_TO_WALK_ID = "rbxassetid://84292577972465"

local walkToRunAnim = Instance.new("Animation")
walkToRunAnim.AnimationId = WALK_TO_RUN_ID
local runToWalkAnim = Instance.new("Animation")
runToWalkAnim.AnimationId = RUN_TO_WALK_ID

local walkToRunTrack = animator:LoadAnimation(walkToRunAnim)
local runToWalkTrack = animator:LoadAnimation(runToWalkAnim)

walkToRunTrack.Priority = Enum.AnimationPriority.Action2
runToWalkTrack.Priority = Enum.AnimationPriority.Action2
walkToRunTrack.Looped = false
runToWalkTrack.Looped = false

-- Состояния
local isSliding = false
local isCrouching = false
local isTransitioning = false
local isHanging = false
local isHardLanding = false
local isSoftLanding = false

local function Run()
	if LedgeGrabConfig.IsHanging then return end
	-- Блокируем бег только при отдышке (0 стамины), не при низкой стамине
	if isBreathing then return end
	-- Блокируем бег при приземлении
	if isHardLanding or isSoftLanding then return end
	if humanoid.MoveDirection.Magnitude > 0.1 and RunConfig.Walking and RunConfig.CanRun and not isSliding and not isCrouching and not RunConfig.Running then
		isTransitioning = true
		-- Не проигрываем анимацию перехода при low HP
		if not isLowHealth then
			walkToRunTrack:Play(0.1)
			-- Замедляем анимацию перехода при низкой стамине
			walkToRunTrack:AdjustSpeed(math.max(0.5, staminaSpeedMultiplier))
		end

		task.delay(0.2, function()
			if humanoid.MoveDirection.Magnitude > 0.1 then
				RunConfig.Running = true
				-- Применяем множители скорости от стамины и падения
				local targetSpeed = RunConfig.RunSpeed * staminaSpeedMultiplier * landingSpeedMultiplier
				local runTween = TweenService:Create(humanoid, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {WalkSpeed = targetSpeed})
				local FovTween = TweenService:Create(camera, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = RunConfig.RunFov})
				runTween:Play()
				FovTween:Play()
			end
		end)

		local connection
		connection = RunService.Heartbeat:Connect(function()
			if humanoid.MoveDirection.Magnitude <= 0.1 then
				if not isLowHealth then
					walkToRunTrack:Stop(0.1)
				end
				isTransitioning = false
				connection:Disconnect()
			end
		end)

		if not isLowHealth then
			walkToRunTrack.Stopped:Wait()
			if connection.Connected then connection:Disconnect() end
		else
			task.wait(0.2)  -- Небольшая задержка вместо ожидания анимации
			if connection.Connected then connection:Disconnect() end
		end
		isTransitioning = false
	end
end

local function Walk()
	-- Переход в ходьбу нужен только если мы продолжаем двигаться, но уже без Shift
	if RunConfig.Running then
		local shouldPlayTransition = humanoid.MoveDirection.Magnitude > 0.1

		RunConfig.Running = false
		RunConfig.Sprinting = false

		local walkTween = TweenService:Create(humanoid, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {WalkSpeed = RunConfig.WalkSpeed})
		local fovTween = TweenService:Create(camera, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = RunConfig.WalkFov})
		walkTween:Play()
		fovTween:Play()

		if shouldPlayTransition and not isLowHealth then
			isTransitioning = true
			runToWalkTrack:Play(0.1)

			-- Если во время замедления игрок бросил все кнопки - стопаем переход
			local connection
			connection = RunService.Heartbeat:Connect(function()
				if humanoid.MoveDirection.Magnitude <= 0.1 then
					runToWalkTrack:Stop(0.1)
					isTransitioning = false
					connection:Disconnect()
				end
			end)

			runToWalkTrack.Stopped:Wait()
			if connection.Connected then connection:Disconnect() end
			isTransitioning = false
		end
	end
end

-- Спринт оставляем как усиление бега
local function Sprint()
	if RunConfig.Walking and RunConfig.Running and RunConfig.CanSprint and not isSliding and not isCrouching then
		RunConfig.Sprinting = true
		local sprintTween = TweenService:Create(humanoid, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {WalkSpeed = RunConfig.SprintSpeed})
		local fovTween = TweenService:Create(camera, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = RunConfig.SprintFov})
		sprintTween:Play()
		fovTween:Play()
	end
end

-- Слушаем флаг тяжёлого приземления (после определения Walk)
task.spawn(function()
	local isHardLandingValue = player:WaitForChild("IsHardLanding", 10)
	if isHardLandingValue then
		isHardLandingValue.Changed:Connect(function(value)
			isHardLanding = value
			if value and RunConfig.Running then
				Walk()  -- Останавливаем бег при тяжёлом приземлении
			end
		end)
	end
end)

-- Слушаем флаг лёгкого приземления
task.spawn(function()
	local isSoftLandingValue = player:WaitForChild("IsSoftLanding", 10)
	if isSoftLandingValue then
		isSoftLandingValue.Changed:Connect(function(value)
			isSoftLanding = value
			if value and RunConfig.Running then
				Walk()  -- Останавливаем бег при лёгком приземлении
			end
		end)
	end
end)

-- === STAMINA INTEGRATION ===
task.spawn(function()
	local breathingEvent = character:WaitForChild("BreathingEvent", 10)
	if breathingEvent then
		breathingEvent.Event:Connect(function(breathing)
			isBreathing = breathing
			if breathing and RunConfig.Running then
				Walk()
			end
		end)
	end
end)

task.spawn(function()
	local speedUpdateEvent = character:WaitForChild("SpeedUpdateEvent", 10)
	if speedUpdateEvent then
		speedUpdateEvent.Event:Connect(function(multiplier)
			staminaSpeedMultiplier = multiplier
			-- Обновляем скорость в реальном времени если бежим
			if RunConfig.Running and not isTransitioning then
				local targetSpeed = RunConfig.RunSpeed * staminaSpeedMultiplier * landingSpeedMultiplier
				humanoid.WalkSpeed = targetSpeed
			end
		end)
	end
end)

-- Слушаем замедление от падения
task.spawn(function()
	local landingSlowEvent = character:WaitForChild("LandingSlowEvent", 10)
	if landingSlowEvent then
		landingSlowEvent.Event:Connect(function(multiplier)
			landingSpeedMultiplier = multiplier
			-- Обновляем скорость в реальном времени
			if RunConfig.Running and not isTransitioning then
				local targetSpeed = RunConfig.RunSpeed * staminaSpeedMultiplier * landingSpeedMultiplier
				humanoid.WalkSpeed = targetSpeed
			elseif RunConfig.Walking and not RunConfig.Running then
				humanoid.WalkSpeed = RunConfig.WalkSpeed * landingSpeedMultiplier
			end
		end)
	end
end)

-- === ВВОД ===
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	-- Блокируем если меню настроек открыто
	local settingsOpen = player:FindFirstChild("SettingsMenuOpen")
	if settingsOpen and settingsOpen.Value then return end
	-- Блокируем бег во время диалога
	local inDialogue = player:FindFirstChild("InDialogue")
	if inDialogue and inDialogue.Value then return end
	
	if input.KeyCode == RunConfig.RunKey then
		if humanoid.MoveDirection.Magnitude > 0 then
			Run()
		end
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == RunConfig.RunKey then
		Walk()
	end
end)

RunService.RenderStepped:Connect(function()
	local isMoving = humanoid.MoveDirection.Magnitude > 0.1
	isHanging = LedgeGrabConfig.IsHanging == true

	RunConfig.IsTransitioning = isTransitioning 

	-- Если висим - останавливаем все анимации бега
	if isHanging then
		if RunConfig.Running then
			RunConfig.Running = false
			RunConfig.Sprinting = false
			walkToRunTrack:Stop(0.1)
			runToWalkTrack:Stop(0.1)
		end
		return
	end

	if isMoving then
		RunConfig.Walking = true

		-- Логика старта бега
		if UIS:IsKeyDown(RunConfig.RunKey) and not RunConfig.Running and not isSliding and not isCrouching and not isTransitioning and not isHardLanding and not isSoftLanding then
			Run()
		end

		-- Плавная скорость назад/вперед с учётом множителей
		if RunConfig.Running and not isSliding and not isCrouching and not isTransitioning then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local localMove = root.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
				local baseSpeed = RunConfig.Sprinting and RunConfig.SprintSpeed or RunConfig.RunSpeed
				-- Применяем множители скорости от стамины и падения
				baseSpeed = baseSpeed * staminaSpeedMultiplier * landingSpeedMultiplier
				local finalTargetSpeed = localMove.Z > 0.5 and (baseSpeed * 0.7) or baseSpeed
				humanoid.WalkSpeed = humanoid.WalkSpeed * 0.9 + finalTargetSpeed * 0.1
			end
		end
	else
		-- Если игрок СТОИТ
		RunConfig.Walking = false
		if RunConfig.Running then
			RunConfig.Running = false
			RunConfig.Sprinting = false

			-- ПЛАВНЫЙ СБРОС FOV И СКОРОСТИ ПРИ ОСТАНОВКЕ
			local stopTweenInfo = TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

			TweenService:Create(humanoid, stopTweenInfo, {WalkSpeed = RunConfig.WalkSpeed}):Play()
			TweenService:Create(camera, stopTweenInfo, {FieldOfView = RunConfig.WalkFov}):Play()

			-- Останавливаем переходы, если они играли
			walkToRunTrack:Stop(0.2)
			runToWalkTrack:Stop(0.2)
			isTransitioning = false
		end
	end
end)

-- === ПЕРЕКАТ ===
local slideAnimationId = "rbxassetid://103470705707880"
local slideTrack = nil

humanoid.AnimationPlayed:Connect(function(track)
	if track.Animation.AnimationId == slideAnimationId then
		isSliding = true
		slideTrack = track

		-- 🔥 ИСПРАВЛЕНИЕ: Вместо обращения к несуществующим переменным, 
		-- останавливаем все анимации движения игрока, чтобы они не мешали перекату
		for _, playingTrack in ipairs(animator:GetPlayingAnimationTracks()) do
			if playingTrack.Priority == Enum.AnimationPriority.Action or 
				playingTrack.Priority == Enum.AnimationPriority.Movement then
				playingTrack:Stop(0.1)
			end
		end

		local conn
		conn = track.Stopped:Connect(function()
			isSliding = false
			slideTrack = nil
			conn:Disconnect()

			if UIS:IsKeyDown(RunConfig.RunKey) and RunConfig.Walking and not isCrouching then
				Run() 
				if RunConfig.Sprinting then
					Sprint()
				end
			else
				Walk() 
			end
		end)
	end
end)

-- === СИНХРОНИЗАЦИЯ С ПРИСЕДОМ (надёжная версия) ===
local crouchScript = script.Parent:FindFirstChild("CrouchScript")  -- подкорректируй путь, если нужно
if not crouchScript then warn("CrouchScript not found!") return end

local crouchWalkAnimId = crouchScript:WaitForChild("CrouchWalkAnim").AnimationId
local crouchIdleAnimId = crouchScript:WaitForChild("CrouchIdleAnim").AnimationId

RunService.RenderStepped:Connect(function()
	local stillCrouching = false
	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Animation.AnimationId == crouchWalkAnimId or track.Animation.AnimationId == crouchIdleAnimId then
			stillCrouching = true
			break
		end
	end

	if stillCrouching and not isCrouching then
		isCrouching = true
		Walk()  -- сбрасываем бег при приседании
	elseif not stillCrouching and isCrouching then
		isCrouching = false  -- разрешаем бег при вставании
	end
end)

-- === РЕСПАВН (Чистый) ===
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")

	-- Перезагружаем треки переходов, так как аниматор обновился
	walkToRunTrack = animator:LoadAnimation(walkToRunAnim)
	runToWalkTrack = animator:LoadAnimation(runToWalkAnim)
	walkToRunTrack.Priority = Enum.AnimationPriority.Action2
	runToWalkTrack.Priority = Enum.AnimationPriority.Action2

	isSliding = false
	isCrouching = false
	isTransitioning = false
	slideTrack = nil
end)