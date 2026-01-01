--[[
	StaminaSystem - Система стамины
	
	Особенности:
	- Игрок может бегать до 0 стамины
	- С 20% стамины скорость плавно снижается (влияет на ВСЁ движение)
	- Перекаты требуют стамины > стоимости (нельзя делать если стамины <= стоимости)
	- Скорость влияет на скорость перекатов
	- Отдышка при 0 стамины
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- === СОБЫТИЯ ===
local exhaustionEvent = Instance.new("BindableEvent")
exhaustionEvent.Name = "ExhaustionEvent"
exhaustionEvent.Parent = character

local breathingEvent = Instance.new("BindableEvent")
breathingEvent.Name = "BreathingEvent"
breathingEvent.Parent = character

local dashEvent = character:FindFirstChild("DashEvent")
if not dashEvent then
	dashEvent = Instance.new("BindableEvent")
	dashEvent.Name = "DashEvent"
	dashEvent.Parent = character
end

-- Событие для обновления скорости (другие скрипты слушают)
local speedUpdateEvent = Instance.new("BindableEvent")
speedUpdateEvent.Name = "SpeedUpdateEvent"
speedUpdateEvent.Parent = character

print("StaminaSystem: Events created")

-- === НАСТРОЙКИ СТАМИНЫ ===
local CONFIG = {
	MaxStamina = 100,

	-- Затраты стамины
	JumpCost = 5,                -- Прыжок (было 8)
	WalkCostPerSecond = 0,       -- Ходьба НЕ тратит стамину
	RunCostPerSecond = 3,        -- Бег тратит стамину
	SprintCostPerSecond = 5,     -- Спринт тратит больше
	RollCost = 10,               -- Перекат (было 15)
	DashCost = 15,               -- Дэш (было 20)
	ClimbCost = 8,               -- Забирание на уступ (было 10)
	HangCostPerSecond = 1,       -- Вис на уступе
	
	-- Боевые затраты (базовые, реальные в CombatConfig)
	LightAttackCost = 8,         -- Лёгкая атака
	HeavyAttackCost = 18,        -- Тяжёлая атака
	BlockCostPerSecond = 2,      -- Блокирование
	ParryCost = 5,               -- Парирование

	-- Восстановление стамины
	RegenPerSecond = 10,          -- Базовое восстановление
	RegenIdleMultiplier = 1.5,    -- Множитель при стоянии
	RegenDelay = 0.3,             -- Задержка перед восстановлением

	-- Порог замедления (20%)
	SlowdownThreshold = 0.20,     -- С 20% начинается замедление
	MinSpeedMultiplier = 0.5,     -- Минимальный множитель скорости при 0%
	MinJumpMultiplier = 0.5,      -- Минимальный множитель высоты прыжка при 0%

	-- Базовые значения
	NormalWalkSpeed = 16,
	NormalJumpHeight = 7.2,
	NormalJumpPower = 50,

	-- Отдышка при 0 стамины
	BreathingDuration = 2.5,
	BreathingRegenPerSecond = 15,
}

-- === СОСТОЯНИЕ ===
local currentStamina = CONFIG.MaxStamina
local lastStaminaUseTime = 0
local isRunning = false
local isBreathing = false
local skipRegenDelay = false
local currentSpeedMultiplier = 1.0
local isDead = false  -- Флаг смерти

-- Значение стамины для других скриптов (боевая система)
local staminaValue = character:FindFirstChild("CurrentStamina")
if not staminaValue then
	staminaValue = Instance.new("NumberValue")
	staminaValue.Name = "CurrentStamina"
	staminaValue.Value = currentStamina
	staminaValue.Parent = character
end

-- === АНИМАЦИЯ И ЗВУК ОТДЫШКИ ===
local animator = humanoid:WaitForChild("Animator")

local breathingAnim = Instance.new("Animation")
breathingAnim.AnimationId = "rbxassetid://507768375"
local breathingTrack = animator:LoadAnimation(breathingAnim)
breathingTrack.Priority = Enum.AnimationPriority.Action4
breathingTrack.Looped = true

local breathingSound = Instance.new("Sound")
breathingSound.Name = "BreathingSound"
breathingSound.SoundId = "rbxassetid://6814463121"
breathingSound.Volume = 0  -- Начинаем с 0 для плавного fade in
breathingSound.Looped = true
breathingSound.RollOffMode = Enum.RollOffMode.InverseTapered
breathingSound.RollOffMinDistance = 2
breathingSound.RollOffMaxDistance = 20
breathingSound.Parent = character:WaitForChild("Head")

-- Добавляем эквалайзер для объёмности
local breathingEqualizer = Instance.new("EqualizerSoundEffect")
breathingEqualizer.LowGain = 3
breathingEqualizer.MidGain = 0
breathingEqualizer.HighGain = -2
breathingEqualizer.Parent = breathingSound

-- === ЗВУК ОТДЫШКИ ПРИ НИЗКОЙ СТАМИНЕ ===
local lowStaminaBreathingSound = Instance.new("Sound")
lowStaminaBreathingSound.Name = "LowStaminaBreathingSound"
lowStaminaBreathingSound.SoundId = "rbxassetid://70462061841057"
lowStaminaBreathingSound.Volume = 0
lowStaminaBreathingSound.Looped = true
lowStaminaBreathingSound.RollOffMode = Enum.RollOffMode.InverseTapered
lowStaminaBreathingSound.RollOffMinDistance = 2
lowStaminaBreathingSound.RollOffMaxDistance = 20
lowStaminaBreathingSound.Parent = character:WaitForChild("Head")

local equalizerEffect = Instance.new("EqualizerSoundEffect")
equalizerEffect.LowGain = 3
equalizerEffect.MidGain = 0
equalizerEffect.HighGain = -2
equalizerEffect.Parent = lowStaminaBreathingSound

local isLowStaminaSoundPlaying = false

local function updateLowStaminaSound()
	local staminaPercent = currentStamina / CONFIG.MaxStamina

	if staminaPercent <= CONFIG.SlowdownThreshold and staminaPercent > 0 and not isBreathing then
		local intensity = 1 - (staminaPercent / CONFIG.SlowdownThreshold)
		local targetVolume = 0.02 + (intensity * 0.06)

		if not isLowStaminaSoundPlaying then
			lowStaminaBreathingSound:Play()
			isLowStaminaSoundPlaying = true
		end
		TweenService:Create(lowStaminaBreathingSound, TweenInfo.new(0.3), {Volume = targetVolume}):Play()
	else
		if isLowStaminaSoundPlaying then
			TweenService:Create(lowStaminaBreathingSound, TweenInfo.new(1.0), {Volume = 0}):Play()
			task.delay(1.0, function()
				if lowStaminaBreathingSound.Volume <= 0.01 then
					lowStaminaBreathingSound:Stop()
					isLowStaminaSoundPlaying = false
				end
			end)
		end
	end
end

-- === HUD EVENT ===
local staminaEvent = nil

-- === ФУНКЦИИ СТАМИНЫ ===
local function updateHUD()
	-- Обновляем значение для других скриптов
	if staminaValue then
		staminaValue.Value = currentStamina
	end
	
	-- Всегда ищем актуальное событие (может быть пересоздано после ресета)
	local event = player:FindFirstChild("StaminaUpdateEvent")
	if event then
		staminaEvent = event
		event:Fire(currentStamina, CONFIG.MaxStamina, true)
	end
	updateLowStaminaSound()
end

local function getStaminaEvent()
	-- Всегда ищем заново, т.к. событие может быть пересоздано после ресета
	local event = player:FindFirstChild("StaminaUpdateEvent")
	if event then 
		staminaEvent = event 
		return staminaEvent
	end
	
	-- Ждём если ещё не создано
	event = player:WaitForChild("StaminaUpdateEvent", 5)
	if event then staminaEvent = event end
	return staminaEvent
end

-- Ищем событие сразу при старте
task.spawn(function()
	task.wait(0.5)
	getStaminaEvent()
	if staminaEvent then
		updateHUD()
		print("StaminaSystem: Connected to HUD event")
	end
end)

local function useStamina(amount)
	currentStamina = math.max(0, currentStamina - amount)
	lastStaminaUseTime = tick()
	skipRegenDelay = false  -- Сбрасываем флаг при трате стамины
	updateHUD()
end

-- Проверка: можно ли использовать стамину (для действий типа перекат)
-- Требует БОЛЬШЕ стамины чем стоимость действия
local function canAffordAction(cost)
	if isBreathing then return false end
	return currentStamina > cost  -- СТРОГО больше, не равно
end

local function regenStamina(dt, multiplier)
	if isBreathing then return end
	
	-- Не восстанавливаем стамину в воздухе
	if humanoid.FloorMaterial == Enum.Material.Air then return end

	if not skipRegenDelay then
		local timeSinceUse = tick() - lastStaminaUseTime
		if timeSinceUse < CONFIG.RegenDelay then return end
	end
	-- skipRegenDelay сбрасывается только когда lastStaminaUseTime обновляется в useStamina

	local regenRate = CONFIG.RegenPerSecond * (multiplier or 1)
	currentStamina = math.min(CONFIG.MaxStamina, currentStamina + regenRate * dt)
	updateHUD()
end

-- === СИСТЕМА СКОРОСТИ ===
-- Плавное снижение скорости от 20% до 0%
local function calculateSpeedMultiplier()
	local staminaPercent = currentStamina / CONFIG.MaxStamina

	if isBreathing then
		return 0
	elseif staminaPercent <= 0 then
		return CONFIG.MinSpeedMultiplier
	elseif staminaPercent <= CONFIG.SlowdownThreshold then
		-- Плавное снижение от 1.0 до MinSpeedMultiplier
		-- При 20% = 1.0, при 0% = MinSpeedMultiplier
		local progress = staminaPercent / CONFIG.SlowdownThreshold
		return CONFIG.MinSpeedMultiplier + (progress * (1.0 - CONFIG.MinSpeedMultiplier))
	else
		return 1.0
	end
end

-- Плавное снижение высоты прыжка от 20% до 0%
local function calculateJumpMultiplier()
	local staminaPercent = currentStamina / CONFIG.MaxStamina

	if isBreathing then
		return 0
	elseif staminaPercent <= 0 then
		return CONFIG.MinJumpMultiplier
	elseif staminaPercent <= CONFIG.SlowdownThreshold then
		-- Плавное снижение от 1.0 до MinJumpMultiplier
		local progress = staminaPercent / CONFIG.SlowdownThreshold
		return CONFIG.MinJumpMultiplier + (progress * (1.0 - CONFIG.MinJumpMultiplier))
	else
		return 1.0
	end
end

local function updateSpeed()
	currentSpeedMultiplier = calculateSpeedMultiplier()
	local jumpMultiplier = calculateJumpMultiplier()
	
	-- Проверяем диалог - не меняем прыжок во время диалога
	local inDialogue = player:FindFirstChild("InDialogue")
	local isInDialogue = inDialogue and inDialogue.Value == true
	
	-- Обновляем высоту прыжка (только если не в отдышке, не в диалоге и можем прыгать)
	if not isBreathing and not isInDialogue and currentStamina > CONFIG.JumpCost then
		humanoid.JumpHeight = CONFIG.NormalJumpHeight * jumpMultiplier
		humanoid.JumpPower = CONFIG.NormalJumpPower * jumpMultiplier
	elseif not isBreathing and not isInDialogue then
		-- Недостаточно стамины для прыжка - отключаем прыжок
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
	end
	-- Если в диалоге - не трогаем JumpHeight/JumpPower (NPCInteraction управляет)
	
	-- Оповещаем другие скрипты
	speedUpdateEvent:Fire(currentSpeedMultiplier)
	
	-- Обновляем событие истощения для совместимости
	local staminaPercent = currentStamina / CONFIG.MaxStamina
	if staminaPercent <= CONFIG.SlowdownThreshold then
		exhaustionEvent:Fire(true, currentSpeedMultiplier)
	elseif staminaPercent > CONFIG.SlowdownThreshold + 0.05 then
		exhaustionEvent:Fire(false, 1.0)
	end
end

-- === СИСТЕМА ОТДЫШКИ ===
local breathingConnection = nil
local pendingBreathing = false

local function stopAllAnimations()
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track ~= breathingTrack then
			track:Stop(0.1)
		end
	end
end

local function isOnGround()
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

local function executeBreathing()
	if isDead then return end  -- Не выполняем отдышку если мертвы
	
	if rootPart then
		rootPart.Anchored = true
	end

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	stopAllAnimations()
	breathingTrack:Play(0.2)
	
	-- Плавный fade in для звука отдышки
	breathingSound.Volume = 0
	breathingSound:Play()
	TweenService:Create(breathingSound, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Volume = 0.1}):Play()

	breathingConnection = RunService.Heartbeat:Connect(function(dt)
		if isBreathing then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track ~= breathingTrack and track.IsPlaying then
					track:Stop(0)
				end
			end
			currentStamina = math.min(CONFIG.MaxStamina, currentStamina + CONFIG.BreathingRegenPerSecond * dt)
			updateHUD()
			updateSpeed()
		end
	end)

	-- breathingEvent:Fire(true) уже вызван в startBreathing()

	task.delay(CONFIG.BreathingDuration, function()
		if not isBreathing then return end

		if breathingConnection then
			breathingConnection:Disconnect()
			breathingConnection = nil
		end

		-- ВАЖНО: Сначала устанавливаем флаги для мгновенного восстановления
		-- ДО того как isBreathing станет false (чтобы главный цикл не добавил задержку)
		skipRegenDelay = true
		lastStaminaUseTime = 0
		isRunning = false  -- Сбрасываем флаг бега после отдышки

		breathingTrack:Stop(0.3)
		
		-- Плавный fade out для звука отдышки
		TweenService:Create(breathingSound, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Volume = 0}):Play()
		task.delay(1.0, function()
			breathingSound:Stop()
		end)

		if rootPart then
			rootPart.Anchored = false
		end

		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)

		humanoid.JumpPower = CONFIG.NormalJumpPower
		humanoid.JumpHeight = CONFIG.NormalJumpHeight
		humanoid.WalkSpeed = CONFIG.NormalWalkSpeed

		-- isBreathing = false ПОСЛЕ установки флагов
		isBreathing = false
		updateSpeed()
		breathingEvent:Fire(false)
	end)
end

local function startBreathing()
	if isBreathing then return end
	if isDead then return end  -- Не начинаем отдышку если мертвы
	isBreathing = true
	isRunning = false

	-- Сразу оповещаем о начале отдышки (чтобы LedgeGrab отпустил стену)
	breathingEvent:Fire(true)

	if not isOnGround() then
		pendingBreathing = true
		return
	end

	executeBreathing()
end

local function checkBreathing()
	if currentStamina <= 0 and not isBreathing then
		isRunning = false
		startBreathing()
	end
end

-- === ОПРЕДЕЛЕНИЕ СОСТОЯНИЯ ===
local function isPlayerIdle()
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
	return horizontalSpeed < 0.5 and humanoid.FloorMaterial ~= Enum.Material.Air
end

local function isPlayerMoving()
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
	return horizontalSpeed > 0.5
end

-- === ПОЛУЧЕНИЕ СОСТОЯНИЙ ===
local RunConfig = nil
local LedgeGrabConfig = nil

task.spawn(function()
	local success, result = pcall(function()
		return require(game.ReplicatedStorage.RunConfig)
	end)
	if success then RunConfig = result end
end)

task.spawn(function()
	local success, result = pcall(function()
		return require(game.ReplicatedStorage.LedgeGrabConfig)
	end)
	if success then LedgeGrabConfig = result end
end)

local function getPlayerState()
	local isCrouchingValue = player:FindFirstChild("IsCrouching")
	local isSlidingValue = player:FindFirstChild("IsSliding")
	
	return {
		isCrouching = isCrouchingValue and isCrouchingValue.Value or false,
		isSliding = isSlidingValue and isSlidingValue.Value or false,
		isProne = RunConfig and RunConfig.isProne or false,
		isHanging = LedgeGrabConfig and LedgeGrabConfig.IsHanging or false,
		isRunning = RunConfig and RunConfig.Running or false,
		isSprinting = RunConfig and RunConfig.Sprinting or false,
	}
end

-- === ОБРАБОТКА ПРЫЖКА ===
humanoid.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Jumping then
		if isBreathing then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
			return
		end
		-- Прыжок требует стамина > стоимости (как перекаты)
		if currentStamina > CONFIG.JumpCost then
			useStamina(CONFIG.JumpCost)
		else
			-- Недостаточно стамины - отменяем прыжок
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end
end)

-- === ОБРАБОТКА БЕГА ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if not isBreathing then
			isRunning = true
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isRunning = false
	end
end)

-- === ОБРАБОТКА ПЕРЕКАТА/ДЭША/БОЕВЫХ ДЕЙСТВИЙ ===
dashEvent.Event:Connect(function(dashType, canPerform)
	-- canPerform передаётся из DashAbility после проверки
	if dashType == "roll" then
		useStamina(CONFIG.RollCost)
	elseif dashType == "dash" then
		useStamina(CONFIG.DashCost)
	elseif dashType == "climb" then
		useStamina(CONFIG.ClimbCost)
	elseif dashType == "combat" then
		-- Боевые действия передают стоимость напрямую
		if canPerform and type(canPerform) == "number" then
			useStamina(canPerform)
		end
	end
end)

-- === ГЛАВНЫЙ ЦИКЛ ===
RunService.Heartbeat:Connect(function(dt)
	checkBreathing()

	if pendingBreathing and isOnGround() then
		pendingBreathing = false
		executeBreathing()
		return
	end

	if isBreathing then return end

	local state = getPlayerState()
	local idle = isPlayerIdle()
	local moving = isPlayerMoving()

	-- Обновляем скорость
	updateSpeed()

	-- Трата стамины за движение
	if state.isHanging then
		useStamina(CONFIG.HangCostPerSecond * dt)
	elseif state.isSprinting and moving then
		useStamina(CONFIG.SprintCostPerSecond * dt)
	elseif (isRunning or state.isRunning) and moving then
		useStamina(CONFIG.RunCostPerSecond * dt)
	end

	-- Восстановление стамины
	if not moving and not state.isHanging then
		regenStamina(dt, idle and CONFIG.RegenIdleMultiplier or 1)
	elseif moving and not isRunning and not state.isRunning and not state.isSprinting then
		-- Восстановление при ходьбе
		local timeSinceUse = tick() - lastStaminaUseTime
		if timeSinceUse > CONFIG.RegenDelay then
			regenStamina(dt * 0.5, 1)
		end
	end
end)


-- === ЭКСПОРТ ===
local StaminaSystem = {}

StaminaSystem.GetStamina = function()
	return currentStamina
end

StaminaSystem.GetMaxStamina = function()
	return CONFIG.MaxStamina
end

StaminaSystem.GetStaminaPercent = function()
	return currentStamina / CONFIG.MaxStamina
end

StaminaSystem.GetSpeedMultiplier = function()
	return currentSpeedMultiplier
end

StaminaSystem.IsBreathing = function()
	return isBreathing
end

-- Проверка: можно ли выполнить перекат (стамина > стоимости)
StaminaSystem.CanRoll = function()
	return not isBreathing and currentStamina > CONFIG.RollCost
end

-- Проверка: можно ли выполнить дэш (стамина > стоимости)
StaminaSystem.CanDash = function()
	return not isBreathing and currentStamina > CONFIG.DashCost
end

-- Проверка: можно ли забраться (стамина > стоимости)
StaminaSystem.CanClimb = function()
	return not isBreathing and currentStamina > CONFIG.ClimbCost
end

-- Проверка: можно ли прыгнуть (стамина > стоимости)
StaminaSystem.CanJump = function()
	return not isBreathing and currentStamina > CONFIG.JumpCost
end

StaminaSystem.GetBreathingEvent = function()
	return breathingEvent
end

StaminaSystem.GetExhaustionEvent = function()
	return exhaustionEvent
end

StaminaSystem.GetSpeedUpdateEvent = function()
	return speedUpdateEvent
end

StaminaSystem.GetRollCost = function()
	return CONFIG.RollCost
end

StaminaSystem.GetDashCost = function()
	return CONFIG.DashCost
end

-- Инициализация
task.delay(1.5, function()
	local event = getStaminaEvent()
	if event then
		updateHUD()
	end
end)

-- === ОБРАБОТКА СМЕРТИ ===
humanoid.Died:Connect(function()
	isDead = true
	isBreathing = false
	pendingBreathing = false
	
	-- Останавливаем все звуки отдышки
	breathingSound:Stop()
	lowStaminaBreathingSound:Stop()
	
	-- Останавливаем анимацию отдышки
	breathingTrack:Stop(0)
	
	-- Отключаем соединение если есть
	if breathingConnection then
		breathingConnection:Disconnect()
		breathingConnection = nil
	end
	
	-- Разблокируем персонажа
	if rootPart then
		rootPart.Anchored = false
	end
end)

print("--- StaminaSystem loaded ---")
return StaminaSystem
