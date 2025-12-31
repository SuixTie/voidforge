--[[
	HealthSystem - Система восстановления здоровья и эффекты Low HP
	
	Особенности:
	- Медленное восстановление здоровья
	- Быстрее восстанавливается когда игрок стоит
	- Зависит от стамины (больше стамины = быстрее регенерация)
	- При low HP: биение сердца, отдышка, blur, потемнение
	- Интеграция с другими системами
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local head = character:WaitForChild("Head")
local camera = workspace.CurrentCamera

-- === КОНФИГУРАЦИЯ ===
local CONFIG = {
	-- Пороги здоровья
	LOW_HEALTH_THRESHOLD = 0.15,      -- 15% - начало эффектов
	CRITICAL_HEALTH_THRESHOLD = 0.10, -- 10% - критическое состояние
	VERY_LOW_THRESHOLD = 0.05,        -- 5% - очень низкое (для анимаций)

	-- Восстановление здоровья
	BaseRegenPerSecond = 0.15,        -- Базовое восстановление HP/сек (было 0.5)
	IdleRegenMultiplier = 3.0,        -- Множитель при стоянии (x3)
	WalkRegenMultiplier = 1.5,        -- Множитель при ходьбе (x1.5)
	RunRegenMultiplier = 0.2,         -- Множитель при беге (x0.2, было 0.3)
	SprintRegenMultiplier = 0.0,      -- При спринте НЕ восстанавливается

	-- Влияние стамины на регенерацию
	StaminaRegenBonus = 1.5,          -- Бонус при полной стамине (x1.5)
	LowStaminaPenalty = 0.3,          -- Штраф при низкой стамине (x0.3)
	StaminaThreshold = 0.5,           -- Порог "низкой" стамины (50%)

	-- Задержка восстановления после урона
	RegenDelayAfterDamage = 5.0,      -- Секунд до начала регенерации

	-- Звуки сердцебиения
	HeartbeatVolumeLow = 0.15,        -- Громкость при 25% HP
	HeartbeatVolumeCritical = 0.4,    -- Громкость при 10% HP
	HeartbeatSpeedLow = 1.0,          -- Скорость при 25% HP
	HeartbeatSpeedCritical = 1.5,     -- Скорость при 10% HP

	-- Звуки дыхания
	BreathingVolumeLow = 0.08,
	BreathingVolumeCritical = 0.2,

	-- Визуальные эффекты
	BlurSizeLow = 4,                  -- Blur при 25% HP
	BlurSizeCritical = 12,            -- Blur при 10% HP

	VignetteLow = 0.3,                -- Затемнение краёв при 25%
	VignetteCritical = 0.6,           -- Затемнение при 10%

	-- Пульсация эффектов
	PulseSpeed = 1.2,                 -- Скорость пульсации
	PulseIntensity = 0.3,             -- Интенсивность пульсации
}

-- === СОСТОЯНИЕ ===
local lastDamageTime = 0
local lastHealth = humanoid.Health
local isLowHealth = false
local isCriticalHealth = false
local currentStaminaPercent = 1.0
local isBreathing = false  -- Отдышка от стамины (0%)
local isLowStaminaBreathing = false  -- Отдышка при низкой стамине (20%)

-- === СОЗДАНИЕ ЗВУКОВ ===
-- Звук сердцебиения
local heartbeatSound = Instance.new("Sound")
heartbeatSound.Name = "HeartbeatSound"
heartbeatSound.SoundId = "rbxassetid://2867269913"  -- Heartbeat sound
heartbeatSound.Volume = 0
heartbeatSound.Looped = true
heartbeatSound.RollOffMode = Enum.RollOffMode.InverseTapered
heartbeatSound.RollOffMinDistance = 1
heartbeatSound.RollOffMaxDistance = 5
heartbeatSound.Parent = head

-- Эквалайзер для сердцебиения (глубокий бас)
local heartbeatEQ = Instance.new("EqualizerSoundEffect")
heartbeatEQ.LowGain = 6
heartbeatEQ.MidGain = -3
heartbeatEQ.HighGain = -6
heartbeatEQ.Parent = heartbeatSound

-- === СОЗДАНИЕ ВИЗУАЛЬНЫХ ЭФФЕКТОВ ===
-- Blur эффект
local blurEffect = Lighting:FindFirstChild("LowHealthBlur")
if not blurEffect then
	blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "LowHealthBlur"
	blurEffect.Size = 0
	blurEffect.Enabled = true
	blurEffect.Parent = Lighting
end

-- ColorCorrection для затемнения
local colorCorrection = Lighting:FindFirstChild("LowHealthCC")
if not colorCorrection then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "LowHealthCC"
	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0
	colorCorrection.Saturation = 0
	colorCorrection.TintColor = Color3.new(1, 1, 1)
	colorCorrection.Enabled = true
	colorCorrection.Parent = Lighting
end

-- === GUI ДЛЯ ВИНЬЕТКИ ===
local playerGui = player:WaitForChild("PlayerGui")

local vignetteGui = playerGui:FindFirstChild("VignetteGui")
if not vignetteGui then
	vignetteGui = Instance.new("ScreenGui")
	vignetteGui.Name = "VignetteGui"
	vignetteGui.IgnoreGuiInset = true
	vignetteGui.DisplayOrder = 100
	vignetteGui.ResetOnSpawn = false
	vignetteGui.Parent = playerGui
end

local vignetteFrame = vignetteGui:FindFirstChild("Vignette")
if not vignetteFrame then
	vignetteFrame = Instance.new("ImageLabel")
	vignetteFrame.Name = "Vignette"
	vignetteFrame.Size = UDim2.new(1, 0, 1, 0)
	vignetteFrame.Position = UDim2.new(0, 0, 0, 0)
	vignetteFrame.BackgroundTransparency = 1
	vignetteFrame.Image = "rbxassetid://1084400362"  -- Vignette texture
	vignetteFrame.ImageColor3 = Color3.new(0, 0, 0)
	vignetteFrame.ImageTransparency = 1
	vignetteFrame.ScaleType = Enum.ScaleType.Stretch
	vignetteFrame.ZIndex = 10
	vignetteFrame.Parent = vignetteGui
end

-- Красная пульсация по краям при критическом здоровье
local redPulseFrame = vignetteGui:FindFirstChild("RedPulse")
if not redPulseFrame then
	redPulseFrame = Instance.new("ImageLabel")
	redPulseFrame.Name = "RedPulse"
	redPulseFrame.Size = UDim2.new(1, 0, 1, 0)
	redPulseFrame.Position = UDim2.new(0, 0, 0, 0)
	redPulseFrame.BackgroundTransparency = 1
	redPulseFrame.Image = "rbxassetid://1084400362"
	redPulseFrame.ImageColor3 = Color3.new(0.5, 0, 0)  -- Тёмно-красный
	redPulseFrame.ImageTransparency = 1
	redPulseFrame.ScaleType = Enum.ScaleType.Stretch
	redPulseFrame.ZIndex = 11
	redPulseFrame.Parent = vignetteGui
end

-- === ИНТЕГРАЦИЯ СО СТАМИНОЙ ===
task.spawn(function()
	local speedUpdateEvent = character:WaitForChild("SpeedUpdateEvent", 10)
	if speedUpdateEvent then
		speedUpdateEvent.Event:Connect(function(multiplier)
			-- Примерно конвертируем множитель скорости в процент стамины
			-- multiplier 1.0 = 100% стамины, 0.5 = 0% стамины
			currentStaminaPercent = math.clamp((multiplier - 0.5) / 0.5, 0, 1)

			-- Проверяем низкую стамину (≤20%) - когда играет звук отдышки от стамины
			-- multiplier < 1.0 означает стамина ниже 20%
			isLowStaminaBreathing = multiplier < 1.0
		end)
	end
end)

task.spawn(function()
	local breathingEvent = character:WaitForChild("BreathingEvent", 10)
	if breathingEvent then
		breathingEvent.Event:Connect(function(breathing)
			isBreathing = breathing
		end)
	end
end)

-- === ФУНКЦИИ ОПРЕДЕЛЕНИЯ СОСТОЯНИЯ ===
local RunConfig = nil
task.spawn(function()
	local success, result = pcall(function()
		return require(game.ReplicatedStorage.RunConfig)
	end)
	if success then RunConfig = result end
end)

local function isPlayerIdle()
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
	return horizontalSpeed < 0.5 and humanoid.FloorMaterial ~= Enum.Material.Air
end

local function isPlayerWalking()
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
	local isRunning = RunConfig and (RunConfig.Running or RunConfig.Sprinting) or false
	return horizontalSpeed > 0.5 and not isRunning
end

local function isPlayerRunning()
	return RunConfig and RunConfig.Running and not RunConfig.Sprinting
end

local function isPlayerSprinting()
	return RunConfig and RunConfig.Sprinting
end

-- === ФУНКЦИИ ЭФФЕКТОВ ===
local pulseTime = 0

local function updateLowHealthEffects(healthPercent, dt)
	pulseTime = pulseTime + dt * CONFIG.PulseSpeed
	local pulse = (math.sin(pulseTime * math.pi * 2) + 1) / 2  -- 0 to 1

	-- Если игрок мёртв (0 HP), убираем все эффекты
	if healthPercent <= 0 then
		if heartbeatSound.IsPlaying then
			heartbeatSound:Stop()
		end
		blurEffect.Size = 0
		colorCorrection.Brightness = 0
		colorCorrection.Saturation = 0
		vignetteFrame.ImageTransparency = 1
		redPulseFrame.ImageTransparency = 1
		isCriticalHealth = false
		isLowHealth = false
		return
	end

	if healthPercent <= CONFIG.CRITICAL_HEALTH_THRESHOLD then
		-- Критическое здоровье (≤10%)
		isCriticalHealth = true
		isLowHealth = true

		local intensity = 1 - (healthPercent / CONFIG.CRITICAL_HEALTH_THRESHOLD)
		local pulseEffect = pulse * CONFIG.PulseIntensity * intensity

		-- Сердцебиение - быстрое и громкое
		if not heartbeatSound.IsPlaying then heartbeatSound:Play() end
		local targetHeartVolume = CONFIG.HeartbeatVolumeCritical * (1 + pulseEffect * 0.5)
		heartbeatSound.Volume = heartbeatSound.Volume + (targetHeartVolume - heartbeatSound.Volume) * 0.1
		heartbeatSound.PlaybackSpeed = CONFIG.HeartbeatSpeedCritical

		-- Blur с пульсацией
		local targetBlur = CONFIG.BlurSizeCritical * (1 + pulseEffect * 0.3)
		blurEffect.Size = blurEffect.Size + (targetBlur - blurEffect.Size) * 0.15

		-- Затемнение и десатурация
		colorCorrection.Brightness = colorCorrection.Brightness + (-0.15 * intensity - colorCorrection.Brightness) * 0.1
		colorCorrection.Saturation = colorCorrection.Saturation + (-0.4 * intensity - colorCorrection.Saturation) * 0.1

		-- Виньетка
		local targetVignette = 1 - CONFIG.VignetteCritical * (1 + pulseEffect * 0.2)
		vignetteFrame.ImageTransparency = vignetteFrame.ImageTransparency + (targetVignette - vignetteFrame.ImageTransparency) * 0.1

		-- Красная пульсация
		local redPulseTarget = 1 - (0.3 * pulse * intensity)
		redPulseFrame.ImageTransparency = redPulseFrame.ImageTransparency + (redPulseTarget - redPulseFrame.ImageTransparency) * 0.15

	elseif healthPercent <= CONFIG.LOW_HEALTH_THRESHOLD then
		-- Низкое здоровье (≤25%)
		isCriticalHealth = false
		isLowHealth = true

		-- Интенсивность от 0 (при 25%) до 1 (при 10%)
		local intensity = 1 - ((healthPercent - CONFIG.CRITICAL_HEALTH_THRESHOLD) / (CONFIG.LOW_HEALTH_THRESHOLD - CONFIG.CRITICAL_HEALTH_THRESHOLD))
		local pulseEffect = pulse * CONFIG.PulseIntensity * intensity * 0.5

		-- Сердцебиение - умеренное
		if not heartbeatSound.IsPlaying then heartbeatSound:Play() end
		local targetHeartVolume = CONFIG.HeartbeatVolumeLow + (CONFIG.HeartbeatVolumeCritical - CONFIG.HeartbeatVolumeLow) * intensity
		heartbeatSound.Volume = heartbeatSound.Volume + (targetHeartVolume - heartbeatSound.Volume) * 0.1
		heartbeatSound.PlaybackSpeed = CONFIG.HeartbeatSpeedLow + (CONFIG.HeartbeatSpeedCritical - CONFIG.HeartbeatSpeedLow) * intensity

		-- Blur
		local targetBlur = CONFIG.BlurSizeLow + (CONFIG.BlurSizeCritical - CONFIG.BlurSizeLow) * intensity
		blurEffect.Size = blurEffect.Size + (targetBlur - blurEffect.Size) * 0.1

		-- Затемнение
		colorCorrection.Brightness = colorCorrection.Brightness + (-0.05 * intensity - colorCorrection.Brightness) * 0.1
		colorCorrection.Saturation = colorCorrection.Saturation + (-0.2 * intensity - colorCorrection.Saturation) * 0.1

		-- Виньетка
		local targetVignette = 1 - CONFIG.VignetteLow * intensity
		vignetteFrame.ImageTransparency = vignetteFrame.ImageTransparency + (targetVignette - vignetteFrame.ImageTransparency) * 0.1

		-- Красная пульсация (слабая)
		redPulseFrame.ImageTransparency = redPulseFrame.ImageTransparency + (1 - redPulseFrame.ImageTransparency) * 0.1

	else
		-- Нормальное здоровье
		isCriticalHealth = false
		isLowHealth = false

		-- Плавно убираем все эффекты
		if heartbeatSound.IsPlaying then
			heartbeatSound.Volume = heartbeatSound.Volume * 0.95
			if heartbeatSound.Volume < 0.01 then
				heartbeatSound:Stop()
			end
		end

		blurEffect.Size = blurEffect.Size * 0.9
		colorCorrection.Brightness = colorCorrection.Brightness * 0.9
		colorCorrection.Saturation = colorCorrection.Saturation * 0.9
		vignetteFrame.ImageTransparency = vignetteFrame.ImageTransparency + (1 - vignetteFrame.ImageTransparency) * 0.1
		redPulseFrame.ImageTransparency = redPulseFrame.ImageTransparency + (1 - redPulseFrame.ImageTransparency) * 0.1
	end
end

-- === ФУНКЦИЯ РЕГЕНЕРАЦИИ ===
local function calculateRegenRate()
	local baseRate = CONFIG.BaseRegenPerSecond

	-- Множитель от движения
	local movementMultiplier = 1.0
	if isBreathing then
		movementMultiplier = 0  -- Не восстанавливаем при отдышке от стамины
	elseif isPlayerSprinting() then
		movementMultiplier = CONFIG.SprintRegenMultiplier
	elseif isPlayerRunning() then
		movementMultiplier = CONFIG.RunRegenMultiplier
	elseif isPlayerWalking() then
		movementMultiplier = CONFIG.WalkRegenMultiplier
	elseif isPlayerIdle() then
		movementMultiplier = CONFIG.IdleRegenMultiplier
	end

	-- Множитель от стамины
	local staminaMultiplier = 1.0
	if currentStaminaPercent >= CONFIG.StaminaThreshold then
		-- Бонус при высокой стамине
		local bonus = (currentStaminaPercent - CONFIG.StaminaThreshold) / (1 - CONFIG.StaminaThreshold)
		staminaMultiplier = 1.0 + (CONFIG.StaminaRegenBonus - 1.0) * bonus
	else
		-- Штраф при низкой стамине
		local penalty = currentStaminaPercent / CONFIG.StaminaThreshold
		staminaMultiplier = CONFIG.LowStaminaPenalty + (1.0 - CONFIG.LowStaminaPenalty) * penalty
	end

	return baseRate * movementMultiplier * staminaMultiplier
end

-- === ОТСЛЕЖИВАНИЕ УРОНА ===
humanoid:GetPropertyChangedSignal("Health"):Connect(function()
	local currentHealth = humanoid.Health
	if currentHealth < lastHealth then
		-- Получили урон
		lastDamageTime = tick()
	end
	lastHealth = currentHealth
end)

-- === ГЛАВНЫЙ ЦИКЛ ===
RunService.Heartbeat:Connect(function(dt)
	local healthPercent = humanoid.Health / humanoid.MaxHealth

	-- Обновляем визуальные эффекты
	updateLowHealthEffects(healthPercent, dt)

	-- Регенерация здоровья
	if humanoid.Health < humanoid.MaxHealth then
		local timeSinceDamage = tick() - lastDamageTime

		if timeSinceDamage >= CONFIG.RegenDelayAfterDamage then
			local regenRate = calculateRegenRate()

			if regenRate > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + regenRate * dt)
			end
		end
	end
end)

-- === ОЧИСТКА ПРИ СМЕРТИ ===
humanoid.Died:Connect(function()
	heartbeatSound:Stop()
	blurEffect.Size = 0
	colorCorrection.Brightness = 0
	colorCorrection.Saturation = 0
	vignetteFrame.ImageTransparency = 1
	redPulseFrame.ImageTransparency = 1
end)

-- === ЭКСПОРТ ===
local HealthSystem = {}

HealthSystem.IsLowHealth = function()
	return isLowHealth
end

HealthSystem.IsCriticalHealth = function()
	return isCriticalHealth
end

HealthSystem.GetHealthPercent = function()
	return humanoid.Health / humanoid.MaxHealth
end

HealthSystem.GetRegenRate = function()
	return calculateRegenRate()
end

print("--- HealthSystem loaded ---")
return HealthSystem
