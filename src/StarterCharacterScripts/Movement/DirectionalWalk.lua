local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local RunConfig = require(game.ReplicatedStorage.RunConfig)
local LedgeGrabConfig = require(game.ReplicatedStorage.LedgeGrabConfig)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)

-- === STAMINA STATE ===
local isBreathing = false
local staminaSpeedMultiplier = 1.0  -- Множитель скорости от стамины

-- === LOW HEALTH STATE ===
local isLowHealth = false
local LOW_HEALTH_THRESHOLD = 0.15  -- 15% здоровья (синхронизировано с HealthSystem)

-- Подключаемся к событию отдышки
task.spawn(function()
	local breathingEvent = character:WaitForChild("BreathingEvent", 10)
	if breathingEvent then
		breathingEvent.Event:Connect(function(breathing)
			isBreathing = breathing
			print("DirectionalWalk: Breathing state changed to", breathing)
		end)
	else
		warn("DirectionalWalk: BreathingEvent not found!")
	end
end)

-- Подключаемся к событию обновления скорости
task.spawn(function()
	local speedUpdateEvent = character:WaitForChild("SpeedUpdateEvent", 10)
	if speedUpdateEvent then
		speedUpdateEvent.Event:Connect(function(multiplier)
			staminaSpeedMultiplier = multiplier
		end)
	else
		warn("DirectionalWalk: SpeedUpdateEvent not found!")
	end
end)

-- === НАСТРОЙКИ ===
local BLEND_SPEED = 0.15 -- Чуть быстрее для четкости бега
local NORMAL_SPEED = 12

-- === ТАБЛИЦЫ ID ===
local WALK_ANIMS = {
	Forward = "rbxassetid://90733220824264",
	Backward = "rbxassetid://75967322245566",
	Left = "rbxassetid://111619228646270",
	Right = "rbxassetid://114737629823246"
}

local END_ANIMS = {
	Forward = "rbxassetid://125269299545835",
	Backward = "rbxassetid://132273856179946",
	Left = "rbxassetid://90183864903078",
	Right = "rbxassetid://107029946980347"
}

local RUN_ANIMS = {
	Forward = "rbxassetid://104126574030880", 
	Backward = "rbxassetid://80559142556346",
	Left = "rbxassetid://134446214120490", 
	Right = "rbxassetid://94930257853261"
}

-- === LOW HP АНИМАЦИИ (замени на свои ID) ===
local LOW_HP_WALK_ANIMS = {
	Forward = "rbxassetid://96197866915360",
	Backward = "rbxassetid://75967322245566",
	Left = "rbxassetid://111619228646270",
	Right = "rbxassetid://114737629823246"
}

local LOW_HP_RUN_ANIMS = {
	Forward = "rbxassetid://89154706805270",
	Backward = "rbxassetid://80559142556346",
	Left = "rbxassetid://134446214120490",
	Right = "rbxassetid://94930257853261"
}

-- Low HP Idle анимация (замени на свой ID)
local LOW_HP_IDLE_ANIM_ID = "rbxassetid://84023586174403"

local walkTracks = {}
local runTracks = {}
local endTracks = {} -- Общие треки для остановки
local activeSet = nil 
local lastDirection = "Forward"
local tracksPlaying = false

local animator = humanoid:WaitForChild("Animator")

-- Функция загрузки
local function loadSet(animTable, priority, looped)
	local targetTable = {}
	for name, id in pairs(animTable) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		track.Priority = priority
		track.Looped = looped
		targetTable[name] = track
	end
	return targetTable
end

walkTracks = loadSet(WALK_ANIMS, Enum.AnimationPriority.Movement, true)
runTracks = loadSet(RUN_ANIMS, Enum.AnimationPriority.Action, true) 
endTracks = loadSet(END_ANIMS, Enum.AnimationPriority.Movement, false)

-- Low HP треки
local lowHpWalkTracks = loadSet(LOW_HP_WALK_ANIMS, Enum.AnimationPriority.Movement, true)
local lowHpRunTracks = loadSet(LOW_HP_RUN_ANIMS, Enum.AnimationPriority.Action, true)

-- Low HP Idle трек
local lowHpIdleAnim = Instance.new("Animation")
lowHpIdleAnim.AnimationId = LOW_HP_IDLE_ANIM_ID
local lowHpIdleTrack = animator:LoadAnimation(lowHpIdleAnim)
lowHpIdleTrack.Priority = Enum.AnimationPriority.Idle
lowHpIdleTrack.Looped = true

local wasLowHealthIdle = false  -- Для отслеживания состояния idle

-- === ФУНКЦИЯ ОСТАНОВКИ ТРЕКОВ (определяем ДО checkHealth) ===
local function stopAllTracks(fade)
	for _, t in pairs(walkTracks) do t:Stop(fade) end
	for _, t in pairs(runTracks) do t:Stop(fade) end
	for _, t in pairs(lowHpWalkTracks) do t:Stop(fade) end
	for _, t in pairs(lowHpRunTracks) do t:Stop(fade) end
	-- НЕ останавливаем lowHpIdleTrack здесь - он управляется отдельно
end

-- === ПРОВЕРКА ЗДОРОВЬЯ ===
local function checkHealth()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	local wasLowHealth = isLowHealth
	isLowHealth = healthPercent <= LOW_HEALTH_THRESHOLD

	if isLowHealth ~= wasLowHealth then
		print("DirectionalWalk: Low health mode =", isLowHealth)
		-- Сбрасываем ВСЕ треки чтобы принудительно переключить анимации
		stopAllTracks(0.15)
		activeSet = nil
		tracksPlaying = false
	end
end

humanoid:GetPropertyChangedSignal("Health"):Connect(checkHealth)
checkHealth()  -- Проверяем начальное здоровье

local function updateWeights(localDir, isShiftLock, currentTracks)
	local isRunning = RunConfig.Running or RunConfig.Sprinting
	local isCrouchingValue = player:FindFirstChild("IsCrouching")
	local isCrouching = isCrouchingValue and isCrouchingValue.Value == true
	-- Добавляем проверку на ползание из RunConfig
	local isProne = RunConfig.isProne == true 

	-- Получаем чистые значения направлений
	local rawF = math.clamp(-localDir.Z, 0, 1)
	local rawB = math.clamp(localDir.Z, 0, 1)
	local rawL = math.clamp(-localDir.X, 0, 1)
	local rawR = math.clamp(localDir.X, 0, 1)

	local forwardW, backwardW, leftW, rightW = 0, 0, 0, 0

	if not isShiftLock then
		forwardW = 1
	else
		local maxWeight = math.max(rawF, rawB, rawL, rawR)
		if maxWeight > 0 then
			forwardW = (rawF == maxWeight) and 1 or 0
			backwardW = (rawB == maxWeight) and 1 or 0
			leftW = (rawL == maxWeight) and 1 or 0
			rightW = (rawR == maxWeight) and 1 or 0
		end
	end

	currentTracks.Forward:AdjustWeight(forwardW, BLEND_SPEED)
	currentTracks.Backward:AdjustWeight(backwardW, BLEND_SPEED)
	currentTracks.Left:AdjustWeight(leftW, BLEND_SPEED)
	currentTracks.Right:AdjustWeight(rightW, BLEND_SPEED)

	-- 🔥 ИСПРАВЛЕННАЯ ЛОГИКА СКОРОСТИ 🔥
	-- Если игрок НЕ приседает и НЕ ползает, управляем скоростью здесь
	-- НЕ меняем скорость если игрок атакует, блокирует или в диалоге (боевая система/диалог управляет скоростью)
	local inDialogue = player:FindFirstChild("InDialogue")
	local isInDialogue = inDialogue and inDialogue.Value == true
	if not isCrouching and not isProne and not CombatConfig.IsAttacking and not CombatConfig.IsBlocking and not isInDialogue then
		local baseSpeed = isRunning and (RunConfig.Sprinting and RunConfig.SprintSpeed or RunConfig.RunSpeed) or NORMAL_SPEED
		-- Применяем множитель скорости от стамины
		baseSpeed = baseSpeed * staminaSpeedMultiplier
		if backwardW > 0.5 and isShiftLock then
			humanoid.WalkSpeed = baseSpeed * 0.7
		else
			humanoid.WalkSpeed = baseSpeed
		end
	end

	-- Обновляем lastDirection для анимации остановки
	if forwardW == 1 then lastDirection = "Forward"
	elseif backwardW == 1 then lastDirection = "Backward"
	elseif leftW == 1 then lastDirection = "Left"
	elseif rightW == 1 then lastDirection = "Right" end
end

RunService.RenderStepped:Connect(function()
	local isCrouchingValue = player:FindFirstChild("IsCrouching")
	local isSlidingValue = player:FindFirstChild("IsSliding")
	local inDialogue = player:FindFirstChild("InDialogue")
	local isProne = RunConfig.isProne == true
	local isHanging = LedgeGrabConfig.IsHanging == true

	-- Если приседаем, скользим, ползем, висим, в переходе, ОТДЫШКА или В ДИАЛОГЕ - выключаем этот скрипт
	if (isCrouchingValue and isCrouchingValue.Value == true) or 
		(isSlidingValue and isSlidingValue.Value == true) or 
		(inDialogue and inDialogue.Value == true) or
		isProne or 
		isHanging or
		isBreathing or
		RunConfig.IsTransitioning then
		stopAllTracks(0.1)
		for _, et in pairs(endTracks) do et:Stop(0.1) end
		tracksPlaying = false
		activeSet = nil
		return 
	end

	local isMoving = humanoid.MoveDirection.Magnitude > 0.1
	local isRunning = RunConfig.Running or RunConfig.Sprinting

	-- Выбираем набор анимаций в зависимости от здоровья
	local nextSet
	if isLowHealth then
		nextSet = isRunning and lowHpRunTracks or lowHpWalkTracks
	else
		nextSet = isRunning and runTracks or walkTracks
	end

	if not isMoving then
		if tracksPlaying then
			stopAllTracks(0.15)
			-- НЕ проигрываем end анимацию при отдышке или при low HP для Forward
			if not isBreathing then
				local isShiftLock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
				local directionToPlay = isShiftLock and lastDirection or "Forward"
				-- Не проигрываем Forward end анимацию при low HP (будет low HP idle)
				local shouldPlayEndAnim = not (isLowHealth and directionToPlay == "Forward")
				if endTracks[directionToPlay] and shouldPlayEndAnim then 
					endTracks[directionToPlay]:Play(0.1) 
				end
			end
			tracksPlaying = false
			activeSet = nil
		end

		-- Управление Low HP Idle анимацией
		if isLowHealth then
			if not lowHpIdleTrack.IsPlaying then
				lowHpIdleTrack:Play(0.2)
				wasLowHealthIdle = true
			end
		else
			if lowHpIdleTrack.IsPlaying then
				lowHpIdleTrack:Stop(0.2)
				wasLowHealthIdle = false
			end
		end

		return
	end

	-- Останавливаем low HP idle СРАЗУ когда начинаем двигаться (быстрый fade)
	if lowHpIdleTrack.IsPlaying then
		lowHpIdleTrack:Stop(0.05)  -- Очень быстрая остановка
		wasLowHealthIdle = false
	end
	
	-- Останавливаем END анимации СРАЗУ, если начали движение
	for _, et in pairs(endTracks) do 
		if et.IsPlaying then 
			et:Stop(0.05) 
		end 
	end

	-- Смена наборов (ходьба/бег)
	if activeSet ~= nextSet then
		-- Останавливаем ВСЕ треки движения, не только текущий набор
		stopAllTracks(BLEND_SPEED)
		
		for _, t in pairs(nextSet) do t:Play(BLEND_SPEED) t:AdjustWeight(0) end
		activeSet = nextSet
		tracksPlaying = true
		
		-- Debug для отладки
		local setName = "unknown"
		if nextSet == walkTracks then setName = "walkTracks"
		elseif nextSet == runTracks then setName = "runTracks"
		elseif nextSet == lowHpWalkTracks then setName = "lowHpWalkTracks"
		elseif nextSet == lowHpRunTracks then setName = "lowHpRunTracks"
		end
		print("DirectionalWalk: Switched to", setName, "isLowHealth=", isLowHealth, "isRunning=", isRunning)
	end

	-- Настраиваем скорость анимации в зависимости от множителя стамины
	if activeSet then
		for _, t in pairs(activeSet) do
			t:AdjustSpeed(staminaSpeedMultiplier)
		end
	end

	local localDir = rootPart.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
	updateWeights(localDir, UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter, activeSet)
end)
