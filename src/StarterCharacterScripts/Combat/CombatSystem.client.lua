--[[
	CombatSystem - Souls-like боевая система
	Voidforge: Eclipse Legacy
	
	Особенности:
	- Комбо система с 4 ударами
	- Тяжёлые атаки с зажатием
	- Парирование с точным таймингом
	- Блокирование
	- Интеграция со стаминой
	- Реалистичная тряска камеры при ударах
	- Lock-on система
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local animator = humanoid:WaitForChild("Animator")

local CombatConfig = require(game.ReplicatedStorage.CombatConfig)

-- RemoteEvent для серверного урона
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local damageEvent = ReplicatedStorage:WaitForChild("DamageEvent", 10)

-- Подключаем конфиги для проверки состояний
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

-- === СОСТОЯНИЕ ===
local isAttacking = false
local isBlocking = false
local isParrying = false
local isStaggered = false
local comboCount = 0
local lastAttackTime = 0
local currentAttackTrack = nil
local lockedTarget = nil
local canAttack = true
local holdingHeavy = false
local heavyChargeStart = 0
local holdingLightAttack = false -- Зажата ли ЛКМ
local comboCooldown = false -- Кулдаун после полного комбо
local COMBO_COOLDOWN_TIME = 1.5 -- Время кулдауна после 4 ударов

-- Настройки скорости
local NORMAL_WALK_SPEED = 16
local ATTACK_WALK_SPEED = 6 -- Скорость при атаке
local BLOCK_WALK_SPEED = 4 -- Скорость при блоке

-- === ЗВУКИ ===
local function createSound(parent, soundId, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 5
	sound.RollOffMaxDistance = 50
	sound.Parent = parent
	return sound
end

local swingSound = createSound(rootPart, "rbxassetid://8907343824", 0.4)
local heavySwingSound = createSound(rootPart, "rbxassetid://9076453292", 0.5)

-- Звуки попадания по врагам
local lightHitSound = createSound(rootPart, "rbxassetid://3932505367", 0.5) -- Лёгкий удар по телу
local heavyHitSound = createSound(rootPart, "rbxassetid://4810807775", 0.6) -- Тяжёлый удар по телу

-- Звуки попадания по стенам/объектам
local wallHitSound = createSound(rootPart, "rbxassetid://3932505554", 0.4) -- Удар по камню/бетону
local metalHitSound = createSound(rootPart, "rbxassetid://3932506197", 0.4) -- Удар по металлу
local woodHitSound = createSound(rootPart, "rbxassetid://3932505696", 0.4) -- Удар по дереву

local parrySound = createSound(rootPart, "rbxassetid://110940207848321", 0.7)
local blockSound = createSound(rootPart, "rbxassetid://4549835866", 0.5)

-- === АНИМАЦИИ (R6) ===
local function loadAnimation(animId)
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	return animator:LoadAnimation(anim)
end

-- Базовые анимации атак для R6 - Лёгкие атаки
local lightAttackAnims = {
	loadAnimation("rbxassetid://137575236164710"), -- Light Punch 1
	loadAnimation("rbxassetid://121638502161356"), -- Light Punch 2
	loadAnimation("rbxassetid://129891425687355"), -- Light Punch 3
	loadAnimation("rbxassetid://95780408707133"), -- Light Punch 4
}

-- Тяжёлые атаки
local heavyAttackAnims = {
	loadAnimation("rbxassetid://139627771045628"), -- Heavy Punch 1
	loadAnimation("rbxassetid://106072166770452"), -- Heavy Punch 2
	loadAnimation("rbxassetid://124496557087153"), -- Heavy Punch 3
}

for _, track in ipairs(lightAttackAnims) do
	track.Priority = Enum.AnimationPriority.Action2
end

for _, track in ipairs(heavyAttackAnims) do
	track.Priority = Enum.AnimationPriority.Action2
end

-- Анимация блока
local blockAnim = loadAnimation("rbxassetid://73242144324267") -- Блок (руки перед собой)
blockAnim.Priority = Enum.AnimationPriority.Action
blockAnim.Looped = true
local blockTrack = blockAnim

-- Анимация парирования
local parryAnim = loadAnimation("rbxassetid://100628491515908") -- Парирование (быстрый отбив)
parryAnim.Priority = Enum.AnimationPriority.Action2
local parryTrack = parryAnim

-- === СОБЫТИЯ ===
local combatEvent = Instance.new("BindableEvent")
combatEvent.Name = "CombatEvent"
combatEvent.Parent = character

-- Событие для стамины
local dashEvent = character:FindFirstChild("DashEvent")

-- === ТРЯСКА КАМЕРЫ ПРИ УДАРЕ ===
local cameraShakeValue = character:FindFirstChild("CameraShakeOffset")
if not cameraShakeValue then
	cameraShakeValue = Instance.new("Vector3Value")
	cameraShakeValue.Name = "CameraShakeOffset"
	cameraShakeValue.Value = Vector3.new(0, 0, 0)
	cameraShakeValue.Parent = character
end

local function shakeCamera(intensity, duration)
	task.spawn(function()
		local startTime = tick()
		while tick() - startTime < duration do
			local progress = (tick() - startTime) / duration
			local decay = 1 - progress
			local shake = Vector3.new(
				(math.random() - 0.5) * intensity * decay,
				(math.random() - 0.5) * intensity * decay,
				0
			)
			cameraShakeValue.Value = shake
			task.wait()
		end
		cameraShakeValue.Value = Vector3.new(0, 0, 0)
	end)
end

-- === ПРОВЕРКА СТАМИНЫ ===
local function getStamina()
	local staminaEvent = player:FindFirstChild("StaminaUpdateEvent")
	-- Используем глобальное значение стамины
	local staminaValue = character:FindFirstChild("CurrentStamina")
	if staminaValue then
		return staminaValue.Value
	end
	return 100 -- По умолчанию
end

local function useStamina(amount)
	if dashEvent then
		dashEvent:Fire("combat", amount)
	end
end

local function canAffordStamina(cost)
	return getStamina() > cost
end

-- === VFX ПОПАДАНИЯ ===
local function createHitEffect(position, attackType)
	local isHeavy = attackType == "Heavy"
	
	-- Основной контейнер эффекта
	local effect = Instance.new("Part")
	effect.Name = "HitEffect"
	effect.Size = Vector3.new(0.5, 0.5, 0.5)
	effect.Position = position
	effect.Anchored = true
	effect.CanCollide = false
	effect.Transparency = 1
	effect.Parent = workspace

	-- 1. Основные частицы удара (искры/брызги)
	local impactParticles = Instance.new("ParticleEmitter")
	impactParticles.Name = "ImpactParticles"
	impactParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 150)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 50, 50)),
	})
	impactParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, isHeavy and 0.5 or 0.3),
		NumberSequenceKeypoint.new(0.3, isHeavy and 0.3 or 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	impactParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	impactParticles.Lifetime = NumberRange.new(0.2, 0.5)
	impactParticles.Speed = NumberRange.new(isHeavy and 15 or 8, isHeavy and 30 or 18)
	impactParticles.SpreadAngle = Vector2.new(180, 180)
	impactParticles.Acceleration = Vector3.new(0, -30, 0) -- Гравитация
	impactParticles.Drag = 3
	impactParticles.Rate = 0
	impactParticles.LightEmission = 0.4
	impactParticles.LightInfluence = 0.3
	impactParticles.Parent = effect
	impactParticles:Emit(isHeavy and 25 or 15)

	-- 2. Кровь/тёмные частицы
	local bloodParticles = Instance.new("ParticleEmitter")
	bloodParticles.Name = "BloodParticles"
	bloodParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 30, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 10, 10)),
	})
	bloodParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, isHeavy and 0.25 or 0.15),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	bloodParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	bloodParticles.Lifetime = NumberRange.new(0.3, 0.7)
	bloodParticles.Speed = NumberRange.new(5, 15)
	bloodParticles.SpreadAngle = Vector2.new(120, 120)
	bloodParticles.Acceleration = Vector3.new(0, -50, 0)
	bloodParticles.Drag = 2
	bloodParticles.Rate = 0
	bloodParticles.Parent = effect
	bloodParticles:Emit(isHeavy and 20 or 10)

	-- 3. Вспышка света при ударе
	local flashPart = Instance.new("Part")
	flashPart.Name = "HitFlash"
	flashPart.Size = Vector3.new(0.1, 0.1, 0.1)
	flashPart.Position = position
	flashPart.Anchored = true
	flashPart.CanCollide = false
	flashPart.Transparency = 1
	flashPart.Parent = workspace
	
	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.fromRGB(255, 150, 100)
	pointLight.Brightness = isHeavy and 3 or 2
	pointLight.Range = isHeavy and 8 or 5
	pointLight.Parent = flashPart
	
	-- Затухание света
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.02)
			pointLight.Brightness = pointLight.Brightness * 0.7
		end
		flashPart:Destroy()
	end)

	-- 4. Ударная волна (кольцо)
	local shockwave = Instance.new("Part")
	shockwave.Name = "Shockwave"
	shockwave.Shape = Enum.PartType.Cylinder
	shockwave.Size = Vector3.new(0.1, isHeavy and 2 or 1.5, isHeavy and 2 or 1.5)
	shockwave.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.Material = Enum.Material.Neon
	shockwave.Color = Color3.fromRGB(255, 200, 150)
	shockwave.Transparency = 0.5
	shockwave.Parent = workspace
	
	-- Анимация расширения ударной волны
	task.spawn(function()
		local startSize = shockwave.Size
		local endSize = Vector3.new(0.05, isHeavy and 6 or 4, isHeavy and 6 or 4)
		for i = 1, 15 do
			local alpha = i / 15
			shockwave.Size = startSize:Lerp(endSize, alpha)
			shockwave.Transparency = 0.5 + (alpha * 0.5)
			task.wait(0.015)
		end
		shockwave:Destroy()
	end)

	-- 5. Дымка после удара
	local smokeParticles = Instance.new("ParticleEmitter")
	smokeParticles.Name = "SmokeParticles"
	smokeParticles.Color = ColorSequence.new(Color3.fromRGB(80, 80, 80))
	smokeParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, isHeavy and 1 or 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	smokeParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	smokeParticles.Lifetime = NumberRange.new(0.4, 0.8)
	smokeParticles.Speed = NumberRange.new(1, 3)
	smokeParticles.SpreadAngle = Vector2.new(360, 360)
	smokeParticles.Rotation = NumberRange.new(0, 360)
	smokeParticles.RotSpeed = NumberRange.new(-100, 100)
	smokeParticles.Rate = 0
	smokeParticles.Parent = effect
	smokeParticles:Emit(isHeavy and 8 or 4)

	-- 6. Линии удара (speed lines эффект)
	for i = 1, (isHeavy and 6 or 3) do
		local line = Instance.new("Part")
		line.Name = "HitLine"
		line.Size = Vector3.new(0.05, 0.05, math.random(10, 20) / 10)
		local angle = math.rad(math.random(0, 360))
		local offset = Vector3.new(math.cos(angle), math.random(-5, 5) / 10, math.sin(angle)) * 0.5
		line.CFrame = CFrame.lookAt(position + offset, position + offset * 2)
		line.Anchored = true
		line.CanCollide = false
		line.Material = Enum.Material.Neon
		line.Color = Color3.fromRGB(255, 220, 180)
		line.Transparency = 0.3
		line.Parent = workspace
		
		task.spawn(function()
			for j = 1, 8 do
				task.wait(0.02)
				line.Transparency = 0.3 + (j / 8) * 0.7
				line.Size = line.Size * 0.9
			end
			line:Destroy()
		end)
	end

	Debris:AddItem(effect, 1.5)
end

-- === VFX СВИНГА (СЛЕД ОТ УДАРА) ===
local function createSwingEffect(attackType, attackIndex)
	-- Определяем какая рука бьёт
	-- Лёгкие: 1-правая, 2-левая, 3-правая, 4-правая
	-- Тяжёлые: всегда левая
	local armName
	if attackType == "Heavy" then
		armName = "Left Arm"
	else
		-- Light attacks: 1=right, 2=left, 3=right, 4=right
		if attackIndex == 2 then
			armName = "Left Arm"
		else
			armName = "Right Arm"
		end
	end
	
	local arm = character:FindFirstChild(armName)
	if not arm then return end
	
	-- Настройки в зависимости от типа атаки
	local swingColor = attackType == "Heavy" 
		and Color3.fromRGB(255, 255, 255)  -- Белый для тяжёлых
		or Color3.fromRGB(200, 200, 255)   -- Светло-голубой для лёгких
	
	local trailEndColor = attackType == "Heavy"
		and Color3.fromRGB(200, 200, 200)  -- Светло-серый для тяжёлых
		or Color3.fromRGB(100, 100, 150)   -- Тёмно-голубой для лёгких
	
	local trailLength = attackType == "Heavy" and 0.4 or 0.25
	local trailWidth = attackType == "Heavy" and 1.2 or 0.8
	
	-- Создаём attachment'ы для trail
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "SwingTrailStart"
	attachment0.Position = Vector3.new(0, -0.8, 0) -- Низ руки
	attachment0.Parent = arm
	
	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "SwingTrailEnd"
	attachment1.Position = Vector3.new(0, 0.8, 0) -- Верх руки
	attachment1.Parent = arm
	
	-- Создаём Trail
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = trailLength
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = attackType == "Heavy" and 0.5 or 0.3
	trail.LightInfluence = 0.5
	
	-- Градиент цвета (яркий -> прозрачный)
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, swingColor),
		ColorSequenceKeypoint.new(0.5, swingColor),
		ColorSequenceKeypoint.new(1, trailEndColor),
	})
	
	-- Градиент прозрачности
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	
	-- Ширина следа
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, trailWidth),
		NumberSequenceKeypoint.new(0.5, trailWidth * 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	
	trail.Parent = arm
	
	-- Также добавляем частицы на руку
	local swingParticles = Instance.new("ParticleEmitter")
	swingParticles.Name = "SwingParticles"
	swingParticles.Color = ColorSequence.new(swingColor)
	swingParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	swingParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	swingParticles.Lifetime = NumberRange.new(0.1, 0.2)
	swingParticles.Speed = NumberRange.new(2, 5)
	swingParticles.SpreadAngle = Vector2.new(30, 30)
	swingParticles.Rate = 50
	swingParticles.LightEmission = attackType == "Heavy" and 0.4 or 0.2
	swingParticles.Parent = arm
	
	-- Удаляем эффекты после атаки
	local duration = attackType == "Heavy" and 0.6 or 0.35
	task.delay(duration, function()
		swingParticles.Rate = 0
		task.delay(0.3, function()
			if trail and trail.Parent then trail:Destroy() end
			if attachment0 and attachment0.Parent then attachment0:Destroy() end
			if attachment1 and attachment1.Parent then attachment1:Destroy() end
			if swingParticles and swingParticles.Parent then swingParticles:Destroy() end
		end)
	end)
end


-- === ФУНКЦИЯ ВОСПРОИЗВЕДЕНИЯ ЗВУКА ПОПАДАНИЯ ===
local function playHitSound(attackType, material)
	-- Если указан материал - это удар по стене/объекту
	if material then
		if material == Enum.Material.Metal or material == Enum.Material.DiamondPlate or material == Enum.Material.CorrodedMetal then
			metalHitSound.PlaybackSpeed = 0.9 + math.random() * 0.2
			metalHitSound:Play()
		elseif material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
			woodHitSound.PlaybackSpeed = 0.9 + math.random() * 0.2
			woodHitSound:Play()
		else
			-- Камень, бетон, пластик и т.д.
			wallHitSound.PlaybackSpeed = 0.9 + math.random() * 0.2
			wallHitSound:Play()
		end
	else
		-- Удар по врагу
		if attackType == "Heavy" then
			heavyHitSound.PlaybackSpeed = 0.85 + math.random() * 0.2
			heavyHitSound:Play()
		else
			lightHitSound.PlaybackSpeed = 0.9 + math.random() * 0.2
			lightHitSound:Play()
		end
	end
end

-- === VFX УДАРА ПО СТЕНЕ ===
local function createWallHitEffect(position, normal, material)
	local effect = Instance.new("Part")
	effect.Name = "WallHitEffect"
	effect.Size = Vector3.new(0.5, 0.5, 0.5)
	effect.Position = position
	effect.Anchored = true
	effect.CanCollide = false
	effect.Transparency = 1
	effect.Parent = workspace

	-- Цвет частиц в зависимости от материала
	local particleColor
	if material == Enum.Material.Metal or material == Enum.Material.DiamondPlate then
		particleColor = Color3.fromRGB(255, 200, 100) -- Искры
	elseif material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
		particleColor = Color3.fromRGB(180, 140, 90) -- Щепки
	else
		particleColor = Color3.fromRGB(150, 150, 150) -- Пыль/камень
	end

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(particleColor)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Lifetime = NumberRange.new(0.2, 0.5)
	particles.Speed = NumberRange.new(5, 15)
	particles.SpreadAngle = Vector2.new(60, 60)
	particles.Acceleration = Vector3.new(0, -30, 0)
	particles.Rate = 0
	particles.LightEmission = material == Enum.Material.Metal and 0.5 or 0.1
	particles.Parent = effect
	particles:Emit(12)

	-- Пыль
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(100, 100, 100))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(0.5, 1)
	dust.Speed = NumberRange.new(1, 3)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Rate = 0
	dust.Parent = effect
	dust:Emit(8)

	Debris:AddItem(effect, 1.5)
end

-- === ПРОВЕРКА УДАРА ПО СТЕНЕ ===
local function checkWallHit(range, attackType)
	local rayOrigin = rootPart.Position
	local rayDirection = rootPart.CFrame.LookVector * (range + 1)
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	
	local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
	
	if result and result.Instance then
		-- Проверяем что это не персонаж
		local parent = result.Instance.Parent
		if not parent:FindFirstChild("Humanoid") then
			-- Это стена/объект
			playHitSound(attackType, result.Material)
			createWallHitEffect(result.Position, result.Normal, result.Material)
			shakeCamera(0.15, 0.1)
			return true
		end
	end
	
	return false
end


-- === HITBOX СИСТЕМА ===
local function createHitbox(range, damage, knockback, attackType)
	local hitTargets = {}
	local hitEnemy = false

	-- Позиция и размер хитбокса
	local hitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, -range/2)
	local hitboxSize = Vector3.new(range, 4, range)

	-- Параметры для поиска
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {character}

	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlapParams)

	for _, part in ipairs(parts) do
		local targetChar = part.Parent
		if targetChar and targetChar:FindFirstChild("Humanoid") and not hitTargets[targetChar] then
			local targetHumanoid = targetChar:FindFirstChild("Humanoid")
			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")

			if targetHumanoid and targetHumanoid.Health > 0 then
				hitTargets[targetChar] = true
				hitEnemy = true

				-- Направление отталкивания
				local knockbackDir = Vector3.new(0, 0, 0)
				if targetRoot then
					knockbackDir = (targetRoot.Position - rootPart.Position).Unit
				end

				-- Отправляем урон на сервер (для NPC/дамми)
				if damageEvent then
					damageEvent:FireServer(targetChar, damage, knockbackDir, knockback or 10)
				end

				-- Звук попадания по врагу
				playHitSound(attackType, nil)

				-- Тряска камеры при попадании
				shakeCamera(0.3, 0.15)

				-- VFX попадания
				createHitEffect(part.Position, attackType)

				-- Оповещаем о попадании
				combatEvent:Fire("hit", targetChar, damage)
			end
		end
	end

	-- Если не попали по врагу - проверяем стену
	if not hitEnemy then
		checkWallHit(range, attackType)
	end

	return hitEnemy
end

-- === ПРОВЕРКА МОЖНО ЛИ АТАКОВАТЬ ===
local function canPerformAttack()
	-- Проверяем бег
	if RunConfig and RunConfig.Running then return false end
	
	-- Проверяем присед
	local isCrouchingValue = player:FindFirstChild("IsCrouching")
	if isCrouchingValue and isCrouchingValue.Value then return false end
	
	-- Проверяем ползание
	if RunConfig and RunConfig.isProne then return false end
	
	-- Проверяем вис на уступе
	if LedgeGrabConfig and LedgeGrabConfig.IsHanging then return false end
	
	-- Проверяем блок
	if isBlocking then return false end
	
	return true
end

-- === АТАКА ===
local function performAttack(attackType)
	if isAttacking or isStaggered or not canAttack then return end
	if comboCooldown and attackType == "Light" then return end -- Кулдаун после комбо
	if not canPerformAttack() then return end -- Проверяем состояния

	local attacks = CombatConfig.Attacks[attackType]
	if not attacks then return end

	-- Определяем какой удар в комбо
	local timeSinceLastAttack = tick() - lastAttackTime
	if timeSinceLastAttack > CombatConfig.Combo.Window then
		comboCount = 0
	end

	local attackIndex = (comboCount % #attacks) + 1
	local attackData = attacks[attackIndex]

	-- Проверяем стамину
	if not canAffordStamina(attackData.staminaCost) then
		-- Недостаточно стамины - слабый удар
		return
	end

	isAttacking = true
	CombatConfig.IsAttacking = true
	lastAttackTime = tick()
	comboCount = comboCount + 1
	
	-- Замедляем движение при атаке
	humanoid.WalkSpeed = ATTACK_WALK_SPEED

	-- Проверяем завершение комбо (4 удара для Light)
	if attackType == "Light" and comboCount >= #attacks then
		comboCooldown = true
		task.delay(COMBO_COOLDOWN_TIME, function()
			comboCooldown = false
			comboCount = 0
			-- Если ЛКМ всё ещё зажата после кулдауна - начинаем новое комбо
			if holdingLightAttack and not isAttacking then
				performAttack("Light")
			end
		end)
	end

	-- Тратим стамину
	useStamina(attackData.staminaCost)

	-- Звук взмаха
	if attackType == "Light" then
		swingSound.PlaybackSpeed = 0.9 + math.random() * 0.2
		swingSound:Play()
	else
		heavySwingSound.PlaybackSpeed = 0.8 + math.random() * 0.2
		heavySwingSound:Play()
	end

	-- Анимация - выбираем из нужного массива
	local animArray = attackType == "Light" and lightAttackAnims or heavyAttackAnims
	local animIndex = math.min(attackIndex, #animArray)
	currentAttackTrack = animArray[animIndex]
	currentAttackTrack:Play(0.1)
	currentAttackTrack:AdjustSpeed(attackType == "Light" and 1.2 or 1.0) -- Тяжёлые медленнее

	-- VFX свинга (след от удара)
	createSwingEffect(attackType, attackIndex)

	-- Тряска камеры при взмахе
	shakeCamera(0.1, 0.1)

	-- Небольшой рывок вперёд
	local dashForce = Instance.new("BodyVelocity")
	dashForce.Velocity = rootPart.CFrame.LookVector * 10
	dashForce.MaxForce = Vector3.new(20000, 0, 20000)
	dashForce.Parent = rootPart
	Debris:AddItem(dashForce, 0.1)

	-- Хитбокс с задержкой (момент удара)
	task.delay(attackData.hitTime, function()
		if isAttacking then
			local damage = attackData.damage
			-- Бонус урона за комбо
			damage = damage * (1 + (comboCount - 1) * 0.1)

			local knockback = attackType == "Heavy" and 20 or 10
			local didHit = createHitbox(attackData.range, damage, knockback, attackType)

			if didHit then
				-- Сильная тряска при попадании
				shakeCamera(0.4, 0.2)
			end
		end
	end)

	-- Завершение атаки
	task.delay(attackData.duration, function()
		isAttacking = false
		CombatConfig.IsAttacking = false
		
		-- Восстанавливаем скорость (если не блокируем)
		if not isBlocking then
			humanoid.WalkSpeed = NORMAL_WALK_SPEED
		end

		if currentAttackTrack then
			currentAttackTrack:Stop(0.2)
		end

		-- Если ЛКМ всё ещё зажата и нет кулдауна - продолжаем атаковать
		if holdingLightAttack and not comboCooldown then
			task.delay(0.05, function()
				if holdingLightAttack and not comboCooldown then
					performAttack("Light")
				end
			end)
		end
	end)

	-- Оповещаем
	combatEvent:Fire("attack", attackType, attackIndex)
end


-- === БЛОКИРОВАНИЕ ===
local function startBlock()
	if isAttacking or isStaggered then return end

	isBlocking = true
	CombatConfig.IsBlocking = true

	-- Замедляем движение при блоке
	humanoid.WalkSpeed = BLOCK_WALK_SPEED

	-- Анимация блока
	blockTrack:Play(0.15)

	blockSound:Play()
	combatEvent:Fire("block", true)
end

local function stopBlock()
	if not isBlocking then return end

	isBlocking = false
	CombatConfig.IsBlocking = false

	-- Останавливаем анимацию блока
	blockTrack:Stop(0.2)

	-- Восстанавливаем скорость (если не атакуем)
	if not isAttacking then
		humanoid.WalkSpeed = NORMAL_WALK_SPEED
	end

	combatEvent:Fire("block", false)
end

-- === ПАРИРОВАНИЕ ===
local parryWindow = false
local parryWindowStart = 0

local function attemptParry()
	if isAttacking or isStaggered or isParrying then return end
	if not canAffordStamina(CombatConfig.Parry.StaminaCost) then return end

	isParrying = true
	CombatConfig.IsParrying = true
	parryWindow = true
	parryWindowStart = tick()

	useStamina(CombatConfig.Parry.StaminaCost)

	-- Анимация парирования
	parryTrack:Play(0.05)
	parryTrack:AdjustSpeed(1.5) -- Быстрое парирование

	parrySound:Play()

	-- Окно парирования
	task.delay(CombatConfig.Parry.Window, function()
		parryWindow = false
	end)

	-- Остановка анимации и кулдаун
	task.delay(0.3, function()
		parryTrack:Stop(0.15)
	end)

	-- Кулдаун
	task.delay(CombatConfig.Parry.Cooldown, function()
		isParrying = false
		CombatConfig.IsParrying = false
	end)

	combatEvent:Fire("parry", true)
end

-- Проверка успешного парирования (вызывается при получении урона)
local function checkParry(attackTime)
	if not parryWindow then return false end

	local timeSinceParry = tick() - parryWindowStart

	if timeSinceParry <= CombatConfig.Parry.PerfectWindow then
		-- Идеальное парирование!
		shakeCamera(0.5, 0.3)
		combatEvent:Fire("perfectParry")
		return "perfect"
	elseif timeSinceParry <= CombatConfig.Parry.Window then
		-- Обычное парирование
		shakeCamera(0.3, 0.2)
		combatEvent:Fire("normalParry")
		return "normal"
	end

	return false
end

-- === LOCK-ON СИСТЕМА ===
local lockOnIndicator = nil

local function findNearestTarget()
	local nearestTarget = nil
	local nearestDistance = CombatConfig.LockOn.MaxDistance

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
			local otherHumanoid = otherPlayer.Character:FindFirstChild("Humanoid")

			if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
				local distance = (otherRoot.Position - rootPart.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestTarget = otherPlayer.Character
				end
			end
		end
	end

	-- Также ищем NPC
	for _, npc in ipairs(workspace:GetDescendants()) do
		if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") then
			if npc ~= character then
				local npcHumanoid = npc:FindFirstChild("Humanoid")
				local npcRoot = npc:FindFirstChild("HumanoidRootPart")

				if npcHumanoid.Health > 0 then
					local distance = (npcRoot.Position - rootPart.Position).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestTarget = npc
					end
				end
			end
		end
	end

	return nearestTarget
end

local function toggleLockOn()
	if lockedTarget then
		-- Отключаем lock-on
		lockedTarget = nil
		if lockOnIndicator then
			lockOnIndicator:Destroy()
			lockOnIndicator = nil
		end
		combatEvent:Fire("lockOn", false)
	else
		-- Включаем lock-on
		lockedTarget = findNearestTarget()
		if lockedTarget then
			-- Создаём индикатор
			lockOnIndicator = Instance.new("BillboardGui")
			lockOnIndicator.Name = "LockOnIndicator"
			lockOnIndicator.Size = UDim2.new(2, 0, 2, 0)
			lockOnIndicator.StudsOffset = Vector3.new(0, 3, 0)
			lockOnIndicator.Adornee = lockedTarget:FindFirstChild("HumanoidRootPart")
			lockOnIndicator.Parent = player.PlayerGui

			local indicator = Instance.new("ImageLabel")
			indicator.Size = UDim2.new(1, 0, 1, 0)
			indicator.BackgroundTransparency = 1
			indicator.Image = "rbxassetid://6031075938" -- Круглый индикатор
			indicator.ImageColor3 = Color3.fromRGB(255, 50, 50)
			indicator.Parent = lockOnIndicator

			combatEvent:Fire("lockOn", true, lockedTarget)
		end
	end
end

-- Обновление lock-on
RunService.RenderStepped:Connect(function()
	if lockedTarget then
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart")
		local targetHumanoid = lockedTarget:FindFirstChild("Humanoid")

		if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
			toggleLockOn() -- Отключаем если цель мертва
			return
		end

		local distance = (targetRoot.Position - rootPart.Position).Magnitude
		if distance > CombatConfig.LockOn.BreakDistance then
			toggleLockOn() -- Отключаем если слишком далеко
			return
		end

		-- Поворачиваем персонажа к цели
		local direction = (targetRoot.Position - rootPart.Position)
		direction = Vector3.new(direction.X, 0, direction.Z).Unit

		local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
		rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, 0.1)
	end
end)


-- === ВВОД ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- Проверяем не открыто ли меню
	local settingsOpen = player:FindFirstChild("SettingsMenuOpen")
	local inventoryOpen = player:FindFirstChild("InventoryMenuOpen")
	if (settingsOpen and settingsOpen.Value) or (inventoryOpen and inventoryOpen.Value) then
		return
	end

	-- ЛКМ - Лёгкая атака (зажатие для автоатаки)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holdingLightAttack = true
		performAttack("Light")
	end

	-- ПКМ - Тяжёлая атака
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		performAttack("Heavy")
	end

	-- R - Парирование
	if input.KeyCode == Enum.KeyCode.R then
		attemptParry()
	end

	-- F (зажатие) - Блок
	if input.KeyCode == Enum.KeyCode.F then
		startBlock()
	end

	-- G - Lock-on
	if input.KeyCode == Enum.KeyCode.G then
		toggleLockOn()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	-- ЛКМ отпущен - прекращаем автоатаку
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holdingLightAttack = false
	end

	-- F отпущен - прекращаем блок
	if input.KeyCode == Enum.KeyCode.F then
		stopBlock()
	end
end)

-- === ПОЛУЧЕНИЕ УРОНА ===
humanoid.HealthChanged:Connect(function(newHealth)
	-- Тряска камеры при получении урона
	shakeCamera(0.4, 0.25)
end)

-- === СМЕРТЬ ===
humanoid.Died:Connect(function()
	isAttacking = false
	isBlocking = false
	isParrying = false
	isStaggered = false
	lockedTarget = nil

	if lockOnIndicator then
		lockOnIndicator:Destroy()
	end

	if currentAttackTrack then
		currentAttackTrack:Stop()
	end
	
	blockTrack:Stop()
	parryTrack:Stop()
end)

-- === ЭКСПОРТ ===
local CombatSystem = {}

CombatSystem.IsAttacking = function() return isAttacking end
CombatSystem.IsBlocking = function() return isBlocking end
CombatSystem.IsParrying = function() return isParrying end
CombatSystem.GetComboCount = function() return comboCount end
CombatSystem.GetLockedTarget = function() return lockedTarget end
CombatSystem.CheckParry = checkParry
CombatSystem.GetCombatEvent = function() return combatEvent end

-- Для внешнего вызова атаки
CombatSystem.Attack = function(attackType)
	performAttack(attackType or "Light")
end

CombatSystem.Block = function(state)
	if state then
		startBlock()
	else
		stopBlock()
	end
end

CombatSystem.Parry = attemptParry
CombatSystem.ToggleLockOn = toggleLockOn

print("--- CombatSystem loaded ---")
print("Controls: LMB = Light Attack, RMB = Heavy Attack, R = Parry, F = Block, G = Lock-On")

return CombatSystem
