--[[
	FallDamage - Урон от падения
	
	Особенности:
	- Урон зависит от высоты падения
	- Минимальная высота для урона
	- Звук приземления при сильном падении
	- Эффект тряски камеры
	- Анимация лёгкого приземления
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = script.Parent.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local animator = humanoid:WaitForChild("Animator")

-- === НАСТРОЙКИ ===
local CONFIG = {
	-- Высоты падения
	SoftLandingHeight = 5,       -- Минимальная высота для лёгкого приземления
	MinFallHeight = 20,          -- Минимальная высота для урона (studs)
	MaxFallHeight = 80,          -- Высота для максимального урона

	-- Урон
	MinDamage = 5,               -- Минимальный урон
	MaxDamage = 9999,            -- Без предела урона
	DamagePerStud = 1.5,         -- Урон за каждый stud выше минимума

	-- Перекат при падении
	RollDamageReduction = 0.7,   -- Снижение урона при перекате (70%)
	RollVolumeReduction = 0.3,   -- Снижение громкости звука при перекате (30% от нормальной)
	RollWindowTime = 0.3,        -- Окно времени для переката после приземления (сек)

	-- Звуки
	HardLandingSoundId = "rbxassetid://100741742443373",  -- Звук жёсткого приземления
	HardLandingVolume = 0.05,
	SoftLandingSoundId = "rbxassetid://137033663835090",  -- Звук лёгкого приземления
	SoftLandingVolume = 0.05,

	-- Эффекты
	CameraShakeIntensity = 3.0,  -- Интенсивность тряски камеры (УВЕЛИЧЕНО с 1.5 до 3.0)
	CameraShakeDuration = 0.6,   -- Длительность тряски

	-- Замедление при тяжёлом приземлении
	HardLandingSlowdown = 0.2,   -- Скорость при тяжёлом приземлении (20% от нормальной)
	HardLandingSlowDuration = 0.8, -- Длительность замедления (сек)

	-- Анимации
	SoftLandingAnimId = "rbxassetid://115761520192088",  -- Анимация лёгкого приземления
	HardLandingAnimId = "rbxassetid://76661603336750",  -- Анимация тяжёлого приземления
}

-- === СОСТОЯНИЕ ===
local isFalling = false
local fallStartHeight = 0
local lastFloorMaterial = humanoid.FloorMaterial
local isDead = false  -- Флаг смерти для предотвращения повторного урона

-- Флаг для блокировки бега во время тяжёлого приземления
local isHardLandingValue = player:FindFirstChild("IsHardLanding") or Instance.new("BoolValue")
isHardLandingValue.Name = "IsHardLanding"
isHardLandingValue.Parent = player

-- Флаг для блокировки бега во время лёгкого приземления
local isSoftLandingValue = player:FindFirstChild("IsSoftLanding") or Instance.new("BoolValue")
isSoftLandingValue.Name = "IsSoftLanding"
isSoftLandingValue.Parent = player

-- === ПРОВЕРКА ПЕРЕКАТА ===
local isSlidingValue = player:WaitForChild("IsSliding", 5)

local function isPlayerRolling()
	-- Проверяем через IsSliding (устанавливается в DashAbility)
	if isSlidingValue and isSlidingValue.Value then
		return true
	end
	return false
end

-- === АНИМАЦИИ ===
local softLandingAnim = Instance.new("Animation")
softLandingAnim.AnimationId = CONFIG.SoftLandingAnimId
local softLandingTrack = animator:LoadAnimation(softLandingAnim)
softLandingTrack.Priority = Enum.AnimationPriority.Action2

local hardLandingAnim = Instance.new("Animation")
hardLandingAnim.AnimationId = CONFIG.HardLandingAnimId
local hardLandingTrack = animator:LoadAnimation(hardLandingAnim)
hardLandingTrack.Priority = Enum.AnimationPriority.Action3

-- === ЗВУКИ ===
local hardLandingSound = Instance.new("Sound")
hardLandingSound.Name = "HardLandingSound"
hardLandingSound.SoundId = CONFIG.HardLandingSoundId
hardLandingSound.Volume = CONFIG.HardLandingVolume
hardLandingSound.RollOffMinDistance = 5
hardLandingSound.RollOffMaxDistance = 20
hardLandingSound.Parent = rootPart

local softLandingSound = Instance.new("Sound")
softLandingSound.Name = "SoftLandingSound"
softLandingSound.SoundId = CONFIG.SoftLandingSoundId
softLandingSound.Volume = CONFIG.SoftLandingVolume
softLandingSound.RollOffMinDistance = 5
softLandingSound.RollOffMaxDistance = 20
softLandingSound.Parent = rootPart

-- === ТРЯСКА КАМЕРЫ (напрямую через Camera.CFrame) ===
local camera = workspace.CurrentCamera
local isShaking = false

local function shakeCamera(intensity, duration)
	if isShaking then return end
	isShaking = true
	
	print("FallDamage: Starting camera shake, intensity =", intensity, "duration =", duration)
	
	local startTime = tick()
	
	-- Используем RenderStepped для тряски камеры напрямую
	local shakeConnection
	shakeConnection = game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		
		if elapsed >= duration then
			shakeConnection:Disconnect()
			isShaking = false
			print("FallDamage: Camera shake ended")
			return
		end
		
		local progress = elapsed / duration
		local currentIntensity = intensity * (1 - progress)  -- Затухание

		local shakeX = (math.random() - 0.5) * 2 * currentIntensity
		local shakeY = (math.random() - 0.5) * 2 * currentIntensity
		
		-- Применяем тряску напрямую к камере
		camera.CFrame = camera.CFrame * CFrame.Angles(
			math.rad(shakeY * 2),
			math.rad(shakeX * 2),
			math.rad(shakeX)
		)
	end)
end

-- === ЗАМЕДЛЕНИЕ ПРИ ТЯЖЁЛОМ ПРИЗЕМЛЕНИИ ===
local isSlowedDown = false
local landingSpeedMultiplier = 1.0

-- Создаём событие для передачи множителя скорости от падения
local landingSlowEvent = character:FindFirstChild("LandingSlowEvent")
if not landingSlowEvent then
	landingSlowEvent = Instance.new("BindableEvent")
	landingSlowEvent.Name = "LandingSlowEvent"
	landingSlowEvent.Parent = character
end

local function applyHardLandingSlowdown(intensity)
	if isSlowedDown then return end
	isSlowedDown = true
	
	-- Замедляем игрока (интенсивность влияет на силу замедления)
	local slowdownFactor = CONFIG.HardLandingSlowdown + (1 - intensity) * 0.3  -- От 20% до 50%
	landingSpeedMultiplier = slowdownFactor
	landingSlowEvent:Fire(landingSpeedMultiplier)
	
	-- Плавно восстанавливаем скорость
	local duration = CONFIG.HardLandingSlowDuration * intensity  -- Дольше при сильном падении
	duration = math.max(0.3, duration)
	
	task.spawn(function()
		local startTime = tick()
		local startMultiplier = landingSpeedMultiplier
		
		while tick() - startTime < duration do
			local progress = (tick() - startTime) / duration
			-- Плавное восстановление (ease out)
			local easedProgress = 1 - math.pow(1 - progress, 2)
			landingSpeedMultiplier = startMultiplier + (1.0 - startMultiplier) * easedProgress
			landingSlowEvent:Fire(landingSpeedMultiplier)
			task.wait()
		end
		
		landingSpeedMultiplier = 1.0
		landingSlowEvent:Fire(landingSpeedMultiplier)
		isSlowedDown = false
	end)
end

-- === РАСЧЁТ УРОНА ===
local function calculateDamage(fallHeight)
	if fallHeight < CONFIG.MinFallHeight then
		return 0
	end

	local effectiveHeight = fallHeight - CONFIG.MinFallHeight
	local damage = CONFIG.MinDamage + (effectiveHeight * CONFIG.DamagePerStud)

	return math.clamp(damage, 0, CONFIG.MaxDamage)
end

-- === ОБРАБОТКА ПАДЕНИЯ ===
local function onFloorMaterialChanged()
	-- Не обрабатываем если игрок мёртв
	if isDead then return end
	
	local currentFloor = humanoid.FloorMaterial

	-- Начало падения (был на земле, теперь в воздухе)
	if lastFloorMaterial ~= Enum.Material.Air and currentFloor == Enum.Material.Air then
		isFalling = true
		fallStartHeight = rootPart.Position.Y
	end

	-- Приземление (был в воздухе, теперь на земле)
	if lastFloorMaterial == Enum.Material.Air and currentFloor ~= Enum.Material.Air then
		if isFalling then
			local fallEndHeight = rootPart.Position.Y
			local fallDistance = fallStartHeight - fallEndHeight

			if fallDistance > 0 then
				local damage = calculateDamage(fallDistance)

				if damage > 0 then
					-- Проверяем перекат для снижения урона
					local finalDamage = damage
					local rolledLanding = isPlayerRolling()

					if rolledLanding then
						-- Снижаем урон на 70%
						finalDamage = damage * (1 - CONFIG.RollDamageReduction)

						-- Перекат не спасает от смертельного урона
						if damage >= humanoid.Health then
							finalDamage = damage  -- Полный урон если смертельный
							rolledLanding = false
						end
					end

					-- Тяжёлое приземление с уроном
					humanoid:TakeDamage(finalDamage)

					-- Звук жёсткого приземления (тише при перекате)
					local calculatedVolume = finalDamage / CONFIG.MaxDamage * CONFIG.HardLandingVolume
					calculatedVolume = math.max(0.01, math.min(calculatedVolume, CONFIG.HardLandingVolume))
					if rolledLanding then
						calculatedVolume = calculatedVolume * CONFIG.RollVolumeReduction
					end
					hardLandingSound.Volume = calculatedVolume
					hardLandingSound:Play()

					-- Анимация тяжёлого приземления (только если не перекат)
					if not rolledLanding then
						isHardLandingValue.Value = true
						hardLandingTrack:Play(0.1)
						
						-- Сбрасываем флаг когда анимация закончится
						task.spawn(function()
							hardLandingTrack.Stopped:Wait()
							isHardLandingValue.Value = false
						end)
					end

					-- Тряска камеры (меньше если перекат)
					-- Используем 100 как "нормальный" максимальный урон для расчёта интенсивности
					local shakeIntensity = math.min(1, finalDamage / 100) * CONFIG.CameraShakeIntensity
					if rolledLanding then
						shakeIntensity = shakeIntensity * 0.3
					end
					-- Минимальная интенсивность чтобы тряска была заметна
					shakeIntensity = math.max(0.5, shakeIntensity)
					shakeCamera(shakeIntensity, CONFIG.CameraShakeDuration)

					-- Замедление при тяжёлом приземлении (не при перекате)
					if not rolledLanding then
						local slowIntensity = finalDamage / CONFIG.MaxDamage
						applyHardLandingSlowdown(slowIntensity)
					end

					if rolledLanding then
						print(string.format("FallDamage: Fell %.1f studs, ROLL reduced damage from %.1f to %.1f", fallDistance, damage, finalDamage))
					else
						print(string.format("FallDamage: Fell %.1f studs, took %.1f damage", fallDistance, finalDamage))
					end

				elseif fallDistance >= CONFIG.SoftLandingHeight then
					-- Лёгкое приземление (без урона, но с анимацией)
					if not isPlayerRolling() then
						isSoftLandingValue.Value = true
						softLandingTrack:Play(0.1)
						softLandingSound:Play()
						
						-- Сбрасываем флаг когда анимация закончится
						task.spawn(function()
							softLandingTrack.Stopped:Wait()
							isSoftLandingValue.Value = false
						end)
					end
				end
			end

			isFalling = false
		end
	end

	lastFloorMaterial = currentFloor
end

-- === ПОДКЛЮЧЕНИЕ ===
humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(onFloorMaterialChanged)

-- Отслеживаем смерть
humanoid.Died:Connect(function()
	isDead = true
end)

-- Также проверяем через StateChanged для надёжности
humanoid.StateChanged:Connect(function(oldState, newState)
	-- Не обрабатываем если игрок мёртв
	if isDead then return end
	
	if newState == Enum.HumanoidStateType.Freefall then
		if not isFalling then
			isFalling = true
			fallStartHeight = rootPart.Position.Y
		end
	elseif newState == Enum.HumanoidStateType.Landed then
		-- Дополнительная проверка при приземлении
		if isFalling then
			local fallEndHeight = rootPart.Position.Y
			local fallDistance = fallStartHeight - fallEndHeight

			if fallDistance > CONFIG.MinFallHeight then
				local damage = calculateDamage(fallDistance)

				if damage > 0 and humanoid.Health > 0 then
					-- Проверяем перекат
					local finalDamage = damage
					local rolledLanding = isPlayerRolling()

					if rolledLanding then
						finalDamage = damage * (1 - CONFIG.RollDamageReduction)

						-- Перекат не спасает от смертельного урона
						if damage >= humanoid.Health then
							finalDamage = damage
							rolledLanding = false
						end
					end

					humanoid:TakeDamage(finalDamage)

					-- Звук жёсткого приземления (тише при перекате)
					local calculatedVolume = finalDamage / CONFIG.MaxDamage * CONFIG.HardLandingVolume
					calculatedVolume = math.max(0.01, math.min(calculatedVolume, CONFIG.HardLandingVolume))
					if rolledLanding then
						calculatedVolume = calculatedVolume * CONFIG.RollVolumeReduction
					end
					hardLandingSound.Volume = calculatedVolume
					hardLandingSound:Play()

					-- Анимация тяжёлого приземления (только если не перекат)
					if not rolledLanding then
						isHardLandingValue.Value = true
						hardLandingTrack:Play(0.1)
						
						-- Сбрасываем флаг когда анимация закончится
						task.spawn(function()
							hardLandingTrack.Stopped:Wait()
							isHardLandingValue.Value = false
						end)
					end

					local shakeIntensity = math.min(1, finalDamage / 100) * CONFIG.CameraShakeIntensity
					if rolledLanding then
						shakeIntensity = shakeIntensity * 0.3
					end
					-- Минимальная интенсивность чтобы тряска была заметна
					shakeIntensity = math.max(0.5, shakeIntensity)
					shakeCamera(shakeIntensity, CONFIG.CameraShakeDuration)

					-- Замедление при тяжёлом приземлении (не при перекате)
					if not rolledLanding then
						local slowIntensity = finalDamage / CONFIG.MaxDamage
						applyHardLandingSlowdown(slowIntensity)
					end
				end
			elseif fallDistance >= CONFIG.SoftLandingHeight then
				-- Лёгкое приземление
				if not isPlayerRolling() then
					isSoftLandingValue.Value = true
					softLandingTrack:Play(0.1)
					softLandingSound:Play()
					
					-- Сбрасываем флаг когда анимация закончится
					task.spawn(function()
						softLandingTrack.Stopped:Wait()
						isSoftLandingValue.Value = false
					end)
				end
			end

			isFalling = false
		end
	end
end)

print("--- FallDamage loaded ---")
