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
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local animator = humanoid:WaitForChild("Animator")

local CombatConfig = require(game.ReplicatedStorage.CombatConfig)

local CombatVFX = nil
local vfxSuccess, vfxResult = pcall(function()
	return require(game.ReplicatedStorage:WaitForChild("CombatVFX"))
end)
if vfxSuccess then
	CombatVFX = vfxResult
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local damageEvent = ReplicatedStorage:WaitForChild("DamageEvent", 10)

-- RemoteEvent для получения информации об активном оружии
local remoteFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local switchWeaponEvent = remoteFolder and remoteFolder:WaitForChild("SwitchWeapon", 10)
local getEquippedFunc = remoteFolder and remoteFolder:WaitForChild("GetEquipped", 10)
local getActiveWeaponFunc = remoteFolder and remoteFolder:WaitForChild("GetActiveWeapon", 10)
local equipItemEvent = remoteFolder and remoteFolder:WaitForChild("EquipItem", 10)

-- === СИСТЕМА ОРУЖИЯ ===
local activeWeaponSlot = nil -- "PRIMARY", "SECONDARY" или nil (кулаки)
local equippedWeapons = {} -- {PRIMARY = itemData, SECONDARY = itemData}

-- Функция проверки есть ли оружие в руках (проверяем визуально на персонаже)
local function hasWeaponInHand()
	-- Проверяем есть ли экипированное оружие на персонаже в руке
	local equippedPrimary = character:FindFirstChild("Equipped_PRIMARY")
	local equippedSecondary = character:FindFirstChild("Equipped_SECONDARY")

	-- Проверяем прикреплено ли оружие к руке (IN_HAND позиция)
	if equippedPrimary then
		local weld = equippedPrimary:FindFirstChildWhichIsA("Weld", true)
		if weld and weld.Part0 and weld.Part0.Name == "Right Arm" then
			return true, equippedPrimary, "PRIMARY"
		end
	end

	if equippedSecondary then
		local weld = equippedSecondary:FindFirstChildWhichIsA("Weld", true)
		if weld and weld.Part0 and weld.Part0.Name == "Right Arm" then
			return true, equippedSecondary, "SECONDARY"
		end
	end

	-- Также проверяем через activeWeaponSlot
	if activeWeaponSlot and equippedWeapons[activeWeaponSlot] then
		return true, nil, activeWeaponSlot
	end

	return false, nil, nil
end

-- Функция получения данных активного оружия
local function getActiveWeaponData()
	local hasWeapon, weaponModel, slot = hasWeaponInHand()
	if not hasWeapon then return nil end

	if slot and equippedWeapons[slot] then
		return equippedWeapons[slot]
	end

	return nil
end

-- Получаем начальное состояние экипировки и активного оружия
task.spawn(function()
	task.wait(1) -- Ждём загрузки

	-- Получаем экипировку
	if getEquippedFunc then
		local success, result = pcall(function()
			return getEquippedFunc:InvokeServer()
		end)
		if success and result then
			equippedWeapons = result
			print("CombatSystem: Initial equipment loaded:", equippedWeapons.PRIMARY and "PRIMARY" or "none", equippedWeapons.SECONDARY and "SECONDARY" or "none")
		end
	end

	-- Получаем активное оружие
	if getActiveWeaponFunc then
		local success, result = pcall(function()
			return getActiveWeaponFunc:InvokeServer()
		end)
		if success then
			activeWeaponSlot = result
			print("CombatSystem: Initial active weapon:", activeWeaponSlot or "none (fists)")
		end
	end
end)

-- Слушаем обновления активного оружия
if switchWeaponEvent then
	switchWeaponEvent.OnClientEvent:Connect(function(newActiveSlot)
		activeWeaponSlot = newActiveSlot
		print("CombatSystem: Active weapon slot changed to", activeWeaponSlot or "none (fists)")
	end)
else
	warn("CombatSystem: SwitchWeapon event not found!")
end

-- Слушаем обновления экипировки
if equipItemEvent then
	equipItemEvent.OnClientEvent:Connect(function(newEquipped)
		equippedWeapons = newEquipped or {}
		print("CombatSystem: Equipment updated - PRIMARY:", equippedWeapons.PRIMARY and equippedWeapons.PRIMARY.itemId or "none", "SECONDARY:", equippedWeapons.SECONDARY and equippedWeapons.SECONDARY.itemId or "none")

		-- Проверяем есть ли оружие в активном слоте
		if activeWeaponSlot and not equippedWeapons[activeWeaponSlot] then
			-- Оружие убрали - переключаемся на другое или на кулаки
			if equippedWeapons.PRIMARY then
				activeWeaponSlot = "PRIMARY"
			elseif equippedWeapons.SECONDARY then
				activeWeaponSlot = "SECONDARY"
			else
				activeWeaponSlot = nil
			end
		end
	end)
else
	warn("CombatSystem: EquipItem event not found!")
end

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

-- Звуки свинга меча
local swordSwingSound = createSound(rootPart, "rbxassetid://6241709963", 0.5) -- Свист меча
local swordHeavySwingSound = createSound(rootPart, "rbxassetid://135315310485417", 0.6) -- Тяжёлый свист меча

-- Звуки попадания по врагам (кулаки)
local lightHitSound = createSound(rootPart, "rbxassetid://3932505023", 0.5) -- Лёгкий удар по телу
local heavyHitSound = createSound(rootPart, "rbxassetid://4306980885", 0.6) -- Тяжёлый удар по телу

-- Звуки попадания меча по врагам
local swordLightHitSound = createSound(rootPart, "rbxassetid://6216173737", 0.5) -- Лёгкий удар мечом
local swordHeavyHitSound = createSound(rootPart, "rbxassetid://7171761940", 0.6) -- Тяжёлый удар мечом

-- Звуки попадания по стенам/объектам
local wallHitSound = createSound(rootPart, "rbxassetid://1476374050", 0.4) -- Удар по камню/бетону
local metalHitSound = createSound(rootPart, "rbxassetid://108682776074559", 0.4) -- Удар по металлу
local woodHitSound = createSound(rootPart, "rbxassetid://9120917813", 0.4) -- Удар по дереву

-- Звуки попадания меча по стенам
local swordMetalHitSound = createSound(rootPart, "rbxassetid://9116689911", 0.5) -- Меч по металлу
local swordStoneHitSound = createSound(rootPart, "rbxassetid://9116689224", 0.3) -- Меч по камню

-- Звуки блока и парирования (кулаки)
local parrySound = createSound(rootPart, "rbxassetid://110940207848321", 0.7)
local blockSound = createSound(rootPart, "rbxassetid://4549835866", 0.5)

-- Звуки блока и парирования (меч)
local swordParrySound = createSound(rootPart, "rbxassetid://9116689911", 0.7) -- Металлический звон парирования
local swordBlockSound = createSound(rootPart, "rbxassetid://9116689224", 0.6) -- Звук блока мечом

-- === АНИМАЦИИ (R6) ===
local function loadAnimation(animId)
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	return animator:LoadAnimation(anim)
end

-- Загружаем анимации из CombatConfig
local function loadAnimationsFromConfig()
	local anims = {
		Fist = {Light = {}, Heavy = {}},
		Weapons = {}
	}

	-- Загружаем анимации кулаков
	for i, animId in ipairs(CombatConfig.FistAnimations.Light) do
		local track = loadAnimation(animId)
		track.Priority = Enum.AnimationPriority.Action2
		anims.Fist.Light[i] = track
	end

	for i, animId in ipairs(CombatConfig.FistAnimations.Heavy) do
		local track = loadAnimation(animId)
		track.Priority = Enum.AnimationPriority.Action2
		anims.Fist.Heavy[i] = track
	end

	-- Загружаем анимации оружия
	for weaponName, weaponData in pairs(CombatConfig.WeaponAttacks) do
		if weaponData.Animations then
			anims.Weapons[weaponName] = {Light = {}, Heavy = {}}

			if weaponData.Animations.Light then
				for i, animId in ipairs(weaponData.Animations.Light) do
					local track = loadAnimation(animId)
					track.Priority = Enum.AnimationPriority.Action2
					anims.Weapons[weaponName].Light[i] = track
				end
			end

			if weaponData.Animations.Heavy then
				for i, animId in ipairs(weaponData.Animations.Heavy) do
					local track = loadAnimation(animId)
					track.Priority = Enum.AnimationPriority.Action2
					anims.Weapons[weaponName].Heavy[i] = track
				end
			end

			-- Загружаем анимации блока и парирования для оружия
			if weaponData.Animations.Block then
				local blockTrack = loadAnimation(weaponData.Animations.Block)
				blockTrack.Priority = Enum.AnimationPriority.Action
				blockTrack.Looped = true
				anims.Weapons[weaponName].Block = blockTrack
			end

			if weaponData.Animations.Parry then
				local parryTrack = loadAnimation(weaponData.Animations.Parry)
				parryTrack.Priority = Enum.AnimationPriority.Action2
				anims.Weapons[weaponName].Parry = parryTrack
			end
		end
	end

	return anims
end

local loadedAnimations = loadAnimationsFromConfig()

-- Для обратной совместимости
local lightAttackAnims = loadedAnimations.Fist.Light
local heavyAttackAnims = loadedAnimations.Fist.Heavy

-- Анимации блока и парирования (кулаки - дефолтные)
local fistBlockAnim = loadAnimation(CombatConfig.FistBlock or "rbxassetid://73242144324267")
fistBlockAnim.Priority = Enum.AnimationPriority.Action
fistBlockAnim.Looped = true

local fistParryAnim = loadAnimation(CombatConfig.FistParry or "rbxassetid://73242144324267")
fistParryAnim.Priority = Enum.AnimationPriority.Action2

-- Текущие активные треки блока/парирования (меняются в зависимости от оружия)
local currentBlockTrack = fistBlockAnim
local currentParryTrack = fistParryAnim

-- Функция получения правильной анимации блока/парирования
local function getBlockParryAnims()
	local hasWeapon, _, weaponSlot = hasWeaponInHand()
	local weaponData = getActiveWeaponData()

	if hasWeapon and weaponData then
		local weaponName = weaponData.itemId or weaponData.modelName
		if weaponName and loadedAnimations.Weapons[weaponName] then
			local weaponAnims = loadedAnimations.Weapons[weaponName]
			local blockAnim = weaponAnims.Block or fistBlockAnim
			local parryAnim = weaponAnims.Parry or fistParryAnim
			return blockAnim, parryAnim
		end
	end

	return fistBlockAnim, fistParryAnim
end

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
-- Папка с эффектами
local FxFolder = ReplicatedStorage:FindFirstChild("Fx")

local function createHitEffect(hitPart, attackType, attackIndex, hasWeapon)
	-- hitPart - часть тела, в которую попал удар

	if not FxFolder then
		warn("CombatSystem: Fx folder not found in ReplicatedStorage")
		return
	end

	if not hitPart then return end

	local effectName
	local bloodEffectName = nil
	local effectIndex = attackIndex or 1

	if hasWeapon then
		-- Для меча используем Slash-Impact-01
		effectName = "Slash-Impact-01"
		-- Добавляем эффект крови для меча
		if attackType == "Heavy" then
			bloodEffectName = "Blood-01"
		else
			bloodEffectName = "Blood-02"
		end
	else
		-- Для кулаков используем Punch эффекты
		effectName = string.format("Punch-%02d", effectIndex)
	end

	-- Функция для создания и запуска эффекта
	local function spawnEffect(fxName)
		local effectTemplate = FxFolder:FindFirstChild(fxName)
		if not effectTemplate then
			warn("CombatSystem: Effect not found:", fxName)
			return
		end

		-- Клонируем эффект
		local effectClone = effectTemplate:Clone()

		-- Сохраняем ссылку на часть тела для отслеживания
		local targetPart = hitPart

		-- Эффект - это Part с Attachment внутри
		if effectClone:IsA("BasePart") then
			effectClone.Transparency = 1
			effectClone.CanCollide = false
			effectClone.Massless = true
			effectClone.Anchored = true

			-- Позиционируем Part в позицию hitPart
			effectClone.CFrame = targetPart.CFrame

			-- Помещаем в workspace
			effectClone.Parent = workspace

			-- Следуем за targetPart пока эффект существует
			local connection
			local isConnected = true
			connection = RunService.Heartbeat:Connect(function()
				if not isConnected then return end

				if effectClone and effectClone.Parent then
					if targetPart and targetPart.Parent then
						effectClone.CFrame = targetPart.CFrame
					else
						-- targetPart удалён - отключаемся
						isConnected = false
						connection:Disconnect()
					end
				else
					-- effectClone удалён - отключаемся
					isConnected = false
					connection:Disconnect()
				end
			end)

			-- Отключаем соединение когда эффект удаляется
			task.delay(2.1, function()
				if isConnected and connection then
					isConnected = false
					connection:Disconnect()
				end
			end)
		else
			-- Fallback для других типов
			effectClone.Parent = workspace
		end

		-- Находим все ParticleEmitter внутри и запускаем их ОДИН раз
		for _, child in ipairs(effectClone:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				-- Отключаем автоматическую эмиссию
				child.Enabled = false
				child.Rate = 0
				-- Частицы следуют за Part'ом
				child.LockedToPart = true
				-- Запускаем частицы один раз
				local emitCount = child:GetAttribute("EmitCount") or 15
				child:Emit(emitCount)
			end
		end

		-- Удаляем эффект через некоторое время
		Debris:AddItem(effectClone, 2)
	end

	-- Создаём основной эффект удара
	spawnEffect(effectName)

	-- Создаём эффект крови (только для меча)
	if bloodEffectName then
		spawnEffect(bloodEffectName)
	end
end

-- === VFX СВИНГА (СЛЕД ОТ УДАРА) ===
local function createSwingEffect(attackType, attackIndex, hasWeapon)
	-- === SLASH VFX ДЛЯ МЕЧА ===
	if hasWeapon and FxFolder then
		local slashEffect = FxFolder:FindFirstChild("Slash-01")
		if slashEffect then
			-- Находим меч в руке
			local weaponModel = character:FindFirstChild("Equipped_PRIMARY") or character:FindFirstChild("Equipped_SECONDARY")
			local targetPart = weaponModel and weaponModel:FindFirstChild("Handle") or character:FindFirstChild("Right Arm")
			
			if targetPart then
				-- Клонируем только ParticleEmitter и Attachment на оружие/руку
				local attachment = Instance.new("Attachment")
				attachment.Name = "SlashVFXAttachment"
				attachment.Parent = targetPart

				-- Копируем все ParticleEmitter из эффекта
				for _, child in ipairs(slashEffect:GetDescendants()) do
					if child:IsA("ParticleEmitter") then
						local emitterClone = child:Clone()
						emitterClone.Enabled = false
						emitterClone.Rate = 0
						emitterClone.Parent = attachment
						local emitCount = child:GetAttribute("EmitCount") or (attackType == "Heavy" and 12 or 8)
						emitterClone:Emit(emitCount)
					end
				end

				-- Удаляем через время
				local duration = attackType == "Heavy" and 0.8 or 0.5
				task.delay(duration, function()
					if attachment and attachment.Parent then
						attachment:Destroy()
					end
				end)
			end
		end
		return -- Для меча не создаём trail эффект
	end

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

	-- === WIND-01 VFX ДЛЯ ЛЁГКИХ УДАРОВ КУЛАКАМИ ===
	if attackType == "Light" and FxFolder then
		local windEffect = FxFolder:FindFirstChild("Wind-01")
		if windEffect then
			-- Клонируем только ParticleEmitter и Attachment на руку
			local attachment = Instance.new("Attachment")
			attachment.Name = "WindVFXAttachment"
			attachment.Parent = arm

			-- Копируем все ParticleEmitter из эффекта
			for _, child in ipairs(windEffect:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					local emitterClone = child:Clone()
					emitterClone.Enabled = false
					emitterClone.Rate = 0
					emitterClone.Parent = attachment
					emitterClone:Emit(child:GetAttribute("EmitCount") or 5)
				end
			end

			-- Удаляем через время
			task.delay(0.5, function()
				if attachment and attachment.Parent then
					attachment:Destroy()
				end
			end)
		end
	end

	-- === WIND-02 VFX ДЛЯ ТЯЖЁЛЫХ УДАРОВ КУЛАКАМИ ===
	if attackType == "Heavy" and FxFolder then
		local windEffect = FxFolder:FindFirstChild("Wind-02")
		if windEffect then
			-- Клонируем только ParticleEmitter и Attachment на руку
			local attachment = Instance.new("Attachment")
			attachment.Name = "WindVFXAttachment"
			attachment.Parent = arm

			-- Копируем все ParticleEmitter из эффекта
			for _, child in ipairs(windEffect:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					local emitterClone = child:Clone()
					emitterClone.Enabled = false
					emitterClone.Rate = 0
					emitterClone.Parent = attachment
					emitterClone:Emit(child:GetAttribute("EmitCount") or 8)
				end
			end

			-- Удаляем через время
			task.delay(0.7, function()
				if attachment and attachment.Parent then
					attachment:Destroy()
				end
			end)
		end
	end

	-- Настройки в зависимости от типа атаки
	local swingColor = attackType == "Heavy" 
		and Color3.fromRGB(255, 255, 255)  -- Белый для тяжёлых
		or Color3.fromRGB(200, 200, 255)   -- Светло-голубой для лёгких

	local trailEndColor = attackType == "Heavy"
		and Color3.fromRGB(200, 200, 200)  -- Светло-серый для тяжёлых
		or Color3.fromRGB(100, 100, 150)   -- Тёмно-голубой для лёгких
	local trailLength = attackType == "Heavy" and 0.4 or 0.25
	local trailWidth = attackType == "Heavy" and 1.2 or 0.8

	-- Эффект только на руке (кулаки)
	local effectPart = arm

	-- Создаём attachment'ы для trail
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "SwingTrailStart"
	attachment0.Position = Vector3.new(0, -0.8, 0)
	attachment0.Parent = effectPart

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "SwingTrailEnd"
	attachment1.Position = Vector3.new(0, 0.8, 0)
	attachment1.Parent = effectPart

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

	-- Градиент прозрачности (более прозрачный)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.3, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- Ширина следа
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, trailWidth),
		NumberSequenceKeypoint.new(0.5, trailWidth * 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})

	trail.Parent = effectPart

	-- Также добавляем частицы
	local swingParticles = Instance.new("ParticleEmitter")
	swingParticles.Name = "SwingParticles"
	swingParticles.Color = ColorSequence.new(swingColor)
	swingParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	swingParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	swingParticles.Lifetime = NumberRange.new(0.1, 0.2)
	swingParticles.Speed = NumberRange.new(2, 5)
	swingParticles.SpreadAngle = Vector2.new(30, 30)
	swingParticles.Rate = 50
	swingParticles.LightEmission = attackType == "Heavy" and 0.4 or 0.2
	swingParticles.Parent = effectPart

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
local function playHitSound(attackType, material, hasWeapon)
	-- Если указан материал - это удар по стене/объекту
	if material then
		if hasWeapon then
			-- Звуки меча по поверхностям
			if material == Enum.Material.Metal or material == Enum.Material.DiamondPlate or material == Enum.Material.CorrodedMetal then
				swordMetalHitSound.PlaybackSpeed = 0.9 + math.random() * 0.2
				swordMetalHitSound:Play()
			else
				-- Камень, дерево и т.д.
				swordStoneHitSound.PlaybackSpeed = 0.9 + math.random() * 0.2
				swordStoneHitSound:Play()
			end
		else
			-- Звуки кулаков по поверхностям
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
		end
	else
		-- Удар по врагу
		if hasWeapon then
			-- Звуки меча по врагу
			if attackType == "Heavy" then
				swordHeavyHitSound.PlaybackSpeed = 0.85 + math.random() * 0.2
				swordHeavyHitSound:Play()
			else
				swordLightHitSound.PlaybackSpeed = 0.9 + math.random() * 0.2
				swordLightHitSound:Play()
			end
		else
			-- Звуки кулаков по врагу
			if attackType == "Heavy" then
				heavyHitSound.PlaybackSpeed = 0.85 + math.random() * 0.2
				heavyHitSound:Play()
			else
				lightHitSound.PlaybackSpeed = 0.9 + math.random() * 0.2
				lightHitSound:Play()
			end
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

-- === DAMAGE LABEL (ВСПЛЫВАЮЩИЙ УРОН) ===
local function createDamageLabel(position, damage, isCritical)
	local damageGui = Instance.new("BillboardGui")
	damageGui.Name = "DamageLabel"
	damageGui.Size = UDim2.new(0, 100, 0, 50)
	damageGui.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 2, 0) -- Случайное смещение
	damageGui.AlwaysOnTop = true
	damageGui.MaxDistance = 100

	-- Создаём Part для привязки
	local anchor = Instance.new("Part")
	anchor.Name = "DamageLabelAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	damageGui.Adornee = anchor
	damageGui.Parent = player.PlayerGui

	-- Текст урона
	local damageText = Instance.new("TextLabel")
	damageText.Name = "DamageText"
	damageText.Size = UDim2.new(1, 0, 1, 0)
	damageText.BackgroundTransparency = 1
	damageText.Text = tostring(math.floor(damage))
	damageText.TextScaled = true
	damageText.Font = Enum.Font.GothamBold

	-- Цвет в зависимости от урона
	if isCritical or damage >= 30 then
		damageText.TextColor3 = Color3.fromRGB(255, 50, 50) -- Красный для крита/большого урона
		damageText.Text = tostring(math.floor(damage)) .. "!"
	elseif damage >= 20 then
		damageText.TextColor3 = Color3.fromRGB(255, 150, 50) -- Оранжевый
	else
		damageText.TextColor3 = Color3.fromRGB(255, 255, 255) -- Белый
	end

	damageText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	damageText.TextStrokeTransparency = 0.3
	damageText.Parent = damageGui

	-- Анимация: поднимается вверх и исчезает
	task.spawn(function()
		local startY = damageGui.StudsOffset.Y
		local duration = 1.0
		local startTime = tick()

		while tick() - startTime < duration do
			local progress = (tick() - startTime) / duration
			local easeOut = 1 - (1 - progress) ^ 2 -- Ease out quad

			-- Поднимаем вверх
			damageGui.StudsOffset = Vector3.new(
				damageGui.StudsOffset.X,
				startY + (easeOut * 2),
				0
			)

			-- Уменьшаем прозрачность в конце
			if progress > 0.5 then
				local fadeProgress = (progress - 0.5) / 0.5
				damageText.TextTransparency = fadeProgress
				damageText.TextStrokeTransparency = 0.3 + (fadeProgress * 0.7)
			end

			task.wait()
		end

		damageGui:Destroy()
		anchor:Destroy()
	end)
end

-- === ПРОВЕРКА УДАРА ПО СТЕНЕ ===
local function checkWallHit(range, attackType, hasWeapon)
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
			playHitSound(attackType, result.Material, hasWeapon)
			createWallHitEffect(result.Position, result.Normal, result.Material)
			shakeCamera(0.15, 0.1)
			return true
		end
	end

	return false
end


-- === HITBOX СИСТЕМА ===
local function createHitbox(range, damage, knockback, attackType, hasWeapon, attackIndex)
	local hitTargets = {}
	local hitEnemy = false

	-- Позиция и размер хитбокса
	local hitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, -range/2)
	local hitboxSize = Vector3.new(range, 4, range)
	local hitboxCenter = hitboxCFrame.Position

	-- Параметры для поиска
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {character}

	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlapParams)

	-- Группируем части по персонажам и находим ближайшую часть для каждого
	local targetPartsMap = {} -- {targetChar = {parts = {}, closestPart = nil, closestDist = math.huge}}

	for _, part in ipairs(parts) do
		local targetChar = part.Parent
		if targetChar and targetChar:FindFirstChild("Humanoid") then
			-- Пропускаем неуязвимых NPC (диалоговые NPC)
			if CollectionService:HasTag(targetChar, "InvulnerableNPC") or CollectionService:HasTag(targetChar, "DialogueNPC") then
				continue
			end

			if not targetPartsMap[targetChar] then
				targetPartsMap[targetChar] = {parts = {}, closestPart = nil, closestDist = math.huge}
			end

			table.insert(targetPartsMap[targetChar].parts, part)

			-- Вычисляем расстояние от центра хитбокса до части
			local dist = (part.Position - hitboxCenter).Magnitude
			if dist < targetPartsMap[targetChar].closestDist then
				targetPartsMap[targetChar].closestDist = dist
				targetPartsMap[targetChar].closestPart = part
			end
		end
	end

	-- Обрабатываем каждого персонажа
	for targetChar, data in pairs(targetPartsMap) do
		if hitTargets[targetChar] then continue end

		local targetHumanoid = targetChar:FindFirstChild("Humanoid")
		local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")

		if targetHumanoid and targetHumanoid.Health > 0 then
			hitTargets[targetChar] = true
			hitEnemy = true

			local knockbackDir = Vector3.new(0, 0, 0)
			if targetRoot then
				knockbackDir = (targetRoot.Position - rootPart.Position).Unit
			end

			if damageEvent then
				damageEvent:FireServer(targetChar, damage, knockbackDir, knockback or 10)
			end

			-- Звук попадания по врагу (с учётом оружия)
			playHitSound(attackType, nil, hasWeapon)

			shakeCamera(0.3, 0.15)

			-- VFX попадания - используем ближайшую часть к центру хитбокса
			local hitPart = data.closestPart
			createHitEffect(hitPart, attackType, attackIndex, hasWeapon)

			-- Всплывающий урон
			local isCritical = attackType == "Heavy" and damage >= 30
			createDamageLabel(hitPart.Position, damage, isCritical)

			-- Оповещаем о попадании
			combatEvent:Fire("hit", targetChar, damage)
		end
	end

	-- Если не попали по врагу - проверяем стену
	if not hitEnemy then
		checkWallHit(range, attackType, hasWeapon)
	end

	return hitEnemy
end

-- === ПРОВЕРКА МОЖНО ЛИ АТАКОВАТЬ ===
local function canPerformAttack()
	-- Проверяем диалог
	local inDialogue = player:FindFirstChild("InDialogue")
	if inDialogue and inDialogue.Value then return false end

	-- Проверяем открыта ли панель персонажа
	local characterPanelOpen = player:FindFirstChild("CharacterPanelOpen")
	if characterPanelOpen and characterPanelOpen.Value then return false end

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

	-- Определяем какие атаки использовать (оружие или кулаки)
	local attacks
	local hasWeapon, weaponModel, weaponSlot = hasWeaponInHand()
	local weaponData = getActiveWeaponData()
	local weaponName = nil

	-- Отладка
	print("CombatSystem: Attack - hasWeapon:", hasWeapon, "weaponSlot:", weaponSlot, "weaponData:", weaponData and weaponData.itemId or "nil")

	if hasWeapon and weaponData then
		-- Есть оружие в руках - используем атаки оружия
		weaponName = weaponData.itemId or weaponData.modelName
		print("CombatSystem: Using weapon attacks for", weaponName)
		local weaponAttacks = CombatConfig.WeaponAttacks[weaponName]
		if weaponAttacks and weaponAttacks[attackType] then
			attacks = weaponAttacks[attackType]
			print("CombatSystem: Found specific weapon attacks")
		else
			-- Нет специальных атак для этого оружия - используем базовые с бонусом урона
			attacks = CombatConfig.Attacks[attackType]
			print("CombatSystem: Using base attacks with weapon damage bonus")
			-- Добавляем бонус урона от оружия
			if weaponData.damage then
				-- Создаём копию с увеличенным уроном
				local modifiedAttacks = {}
				for i, attack in ipairs(attacks) do
					modifiedAttacks[i] = {
						name = attack.name,
						damage = attack.damage + weaponData.damage,
						staminaCost = attack.staminaCost,
						duration = attack.duration,
						range = attack.range + 1, -- Оружие даёт +1 к дальности
						hitTime = attack.hitTime,
					}
				end
				attacks = modifiedAttacks
			end
		end
	else
		-- Нет оружия - бьём кулаками
		print("CombatSystem: Using fist attacks")
		attacks = CombatConfig.Attacks[attackType]
	end

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

	-- Звук взмаха (разные для кулаков и меча)
	if hasWeapon then
		-- Звуки меча
		if attackType == "Light" then
			swordSwingSound.PlaybackSpeed = 0.9 + math.random() * 0.2
			swordSwingSound:Play()
		else
			swordHeavySwingSound.PlaybackSpeed = 0.8 + math.random() * 0.2
			swordHeavySwingSound:Play()
		end
	else
		-- Звуки кулаков
		if attackType == "Light" then
			swingSound.PlaybackSpeed = 0.9 + math.random() * 0.2
			swingSound:Play()
		else
			heavySwingSound.PlaybackSpeed = 0.8 + math.random() * 0.2
			heavySwingSound:Play()
		end
	end

	-- Анимация - выбираем из нужного массива в зависимости от оружия
	local animArray
	if hasWeapon and weaponName and loadedAnimations.Weapons[weaponName] then
		-- Используем анимации оружия из конфига
		animArray = loadedAnimations.Weapons[weaponName][attackType]
		print("CombatSystem: Using", weaponName, "animations for", attackType)
	end

	-- Если нет анимаций для оружия - используем базовые (кулаки)
	if not animArray or #animArray == 0 then
		animArray = attackType == "Light" and lightAttackAnims or heavyAttackAnims
		print("CombatSystem: Using fist animations for", attackType)
	end

	-- VFX свинга (след от удара) - вызываем ДО анимации чтобы слэш появлялся раньше
	createSwingEffect(attackType, attackIndex, hasWeapon)

	local animIndex = math.min(attackIndex, #animArray)
	currentAttackTrack = animArray[animIndex]
	currentAttackTrack:Play(0.1)
	currentAttackTrack:AdjustSpeed(attackType == "Light" and 1.2 or 1.0) -- Тяжёлые медленнее

	-- Тряска камеры при взмахе
	shakeCamera(0.1, 0.1)

	-- Небольшой рывок вперёд
	local dashForce = Instance.new("BodyVelocity")
	dashForce.Velocity = rootPart.CFrame.LookVector * 10
	dashForce.MaxForce = Vector3.new(20000, 0, 20000)
	dashForce.Parent = rootPart
	Debris:AddItem(dashForce, 0.1)

	-- Хитбокс с задержкой (момент удара)
	local currentAttackIndex = attackIndex -- Сохраняем для использования в task.delay
	task.delay(attackData.hitTime, function()
		if isAttacking then
			local damage = attackData.damage
			-- Бонус урона за комбо
			damage = damage * (1 + (comboCount - 1) * 0.1)

			local knockback = attackType == "Heavy" and 20 or 10
			-- Оружие даёт больше отталкивания
			if hasWeapon then
				knockback = knockback * 1.3
			end

			local didHit = createHitbox(attackData.range, damage, knockback, attackType, hasWeapon, currentAttackIndex)

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
	combatEvent:Fire("attack", attackType, attackIndex, hasWeapon)
end


-- === БЛОКИРОВАНИЕ ===
-- Создаём значение для сервера
local blockingValue = character:FindFirstChild("IsBlocking")
if not blockingValue then
	blockingValue = Instance.new("BoolValue")
	blockingValue.Name = "IsBlocking"
	blockingValue.Value = false
	blockingValue.Parent = character
end

local blockShield = nil
local blockShieldConnection = nil

local function startBlock()
	if isAttacking or isStaggered then return end

	-- Проверяем диалог
	local inDialogue = player:FindFirstChild("InDialogue")
	if inDialogue and inDialogue.Value then return end

	-- Проверяем открыта ли панель персонажа
	local characterPanelOpen = player:FindFirstChild("CharacterPanelOpen")
	if characterPanelOpen and characterPanelOpen.Value then return end

	-- Нельзя блокировать во время приседа
	local isCrouchingValue = player:FindFirstChild("IsCrouching")
	if isCrouchingValue and isCrouchingValue.Value then return end

	-- Нельзя блокировать во время бега
	if RunConfig and RunConfig.Running then return end

	isBlocking = true
	CombatConfig.IsBlocking = true
	blockingValue.Value = true

	humanoid.WalkSpeed = BLOCK_WALK_SPEED

	-- Отключаем прыжок во время блока
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	-- Получаем правильную анимацию блока (в зависимости от оружия)
	currentBlockTrack, currentParryTrack = getBlockParryAnims()

	-- Анимация блока
	if currentBlockTrack then
		currentBlockTrack:Play(0.15)
	end

	-- Звук блока (разный для кулаков и меча)
	local hasWeapon = hasWeaponInHand()
	if hasWeapon then
		swordBlockSound.PlaybackSpeed = 0.9 + math.random() * 0.2
		swordBlockSound:Play()
	else
		blockSound:Play()
	end

	combatEvent:Fire("block", true)
end

local function stopBlock()
	if not isBlocking then return end

	isBlocking = false
	CombatConfig.IsBlocking = false
	blockingValue.Value = false

	-- Останавливаем анимацию блока
	if currentBlockTrack then
		currentBlockTrack:Stop(0.2)
	end

	if blockShield then
		blockShield:Destroy()
		blockShield = nil
	end
	if blockShieldConnection then
		blockShieldConnection:Disconnect()
		blockShieldConnection = nil
	end

	if not isAttacking then
		humanoid.WalkSpeed = NORMAL_WALK_SPEED
	end

	-- Восстанавливаем прыжок
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

	combatEvent:Fire("block", false)
end

-- === ПАРИРОВАНИЕ ===
local parryWindow = false
local parryWindowStart = 0

local function attemptParry()
	if isAttacking or isStaggered or isParrying then return end
	if not canAffordStamina(CombatConfig.Parry.StaminaCost) then return end

	-- Нельзя парировать во время блока
	if isBlocking then return end

	-- Проверяем открыта ли панель персонажа
	local characterPanelOpen = player:FindFirstChild("CharacterPanelOpen")
	if characterPanelOpen and characterPanelOpen.Value then return end

	-- Нельзя парировать во время приседа
	local isCrouchingValue = player:FindFirstChild("IsCrouching")
	if isCrouchingValue and isCrouchingValue.Value then return end

	-- Нельзя парировать во время бега
	if RunConfig and RunConfig.Running then return end

	-- Проверяем диалог
	local inDialogue = player:FindFirstChild("InDialogue")
	if inDialogue and inDialogue.Value then return end

	isParrying = true
	CombatConfig.IsParrying = true
	parryWindow = true
	parryWindowStart = tick()

	useStamina(CombatConfig.Parry.StaminaCost)

	-- Получаем правильную анимацию парирования (в зависимости от оружия)
	currentBlockTrack, currentParryTrack = getBlockParryAnims()

	-- Анимация парирования
	if currentParryTrack then
		currentParryTrack:Play(0.05)
		currentParryTrack:AdjustSpeed(1.5) -- Быстрое парирование
	end

	-- Звук парирования (разный для кулаков и меча)
	local hasWeapon = hasWeaponInHand()
	if hasWeapon then
		swordParrySound.PlaybackSpeed = 0.9 + math.random() * 0.2
		swordParrySound:Play()
	else
		parrySound:Play()
	end

	-- Окно парирования
	task.delay(CombatConfig.Parry.Window, function()
		parryWindow = false
	end)

	-- Остановка анимации и кулдаун
	task.delay(0.3, function()
		if currentParryTrack then
			currentParryTrack:Stop(0.15)
		end
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
		shakeCamera(0.5, 0.3)
		if CombatVFX then
			CombatVFX:CreateParryEffect(rootPart.Position + rootPart.CFrame.LookVector * 2, true)
		end
		combatEvent:Fire("perfectParry")
		return "perfect"
	elseif timeSinceParry <= CombatConfig.Parry.Window then
		shakeCamera(0.3, 0.2)
		if CombatVFX then
			CombatVFX:CreateParryEffect(rootPart.Position + rootPart.CFrame.LookVector * 2, false)
		end
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

	-- Также ищем NPC (кроме неуязвимых)
	for _, npc in ipairs(workspace:GetDescendants()) do
		if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") then
			if npc ~= character then
				-- Пропускаем неуязвимых NPC (нельзя lock-on на них)
				if CollectionService:HasTag(npc, "InvulnerableNPC") then
					continue
				end

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
	-- Не включаем lock-on если игрок висит
	if LedgeGrabConfig and LedgeGrabConfig.IsHanging then
		-- Если уже есть lock-on - отключаем его
		if lockedTarget then
			lockedTarget = nil
			CombatConfig.IsLockedOn = false
			if lockOnIndicator then
				lockOnIndicator:Destroy()
				lockOnIndicator = nil
			end
			combatEvent:Fire("lockOn", false)
		end
		return
	end

	if lockedTarget then
		-- Отключаем lock-on
		lockedTarget = nil
		CombatConfig.IsLockedOn = false -- Сообщаем другим скриптам
		if lockOnIndicator then
			lockOnIndicator:Destroy()
			lockOnIndicator = nil
		end
		combatEvent:Fire("lockOn", false)
	else
		-- Включаем lock-on
		lockedTarget = findNearestTarget()
		if lockedTarget then
			CombatConfig.IsLockedOn = true -- Сообщаем другим скриптам
			-- Создаём индикатор
			lockOnIndicator = Instance.new("BillboardGui")
			lockOnIndicator.Name = "LockOnIndicator"
			lockOnIndicator.Size = UDim2.new(1.2, 0, 1.2, 0)
			lockOnIndicator.StudsOffset = Vector3.new(0, 3, 0)
			lockOnIndicator.Adornee = lockedTarget:FindFirstChild("HumanoidRootPart")
			lockOnIndicator.Parent = player.PlayerGui

			local indicator = Instance.new("ImageLabel")
			indicator.Size = UDim2.new(1, 0, 1, 0)
			indicator.BackgroundTransparency = 1
			indicator.Image = "rbxassetid://302248702" -- Lock-on метка
			indicator.ImageColor3 = Color3.fromRGB(255, 50, 50)
			indicator.Parent = lockOnIndicator

			combatEvent:Fire("lockOn", true, lockedTarget)
		end
	end
end

-- Обновление lock-on
RunService.RenderStepped:Connect(function()
	if lockedTarget then
		-- Отключаем lock-on если игрок начал висеть
		if LedgeGrabConfig and LedgeGrabConfig.IsHanging then
			toggleLockOn()
			return
		end

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

-- Тряска камеры только при получении урона (не при регенерации)
local lastHealth = humanoid.Health
humanoid.HealthChanged:Connect(function(newHealth)
	-- Только если здоровье уменьшилось (получили урон)
	if newHealth < lastHealth then
		shakeCamera(0.4, 0.25)
	end
	lastHealth = newHealth
end)

humanoid.Died:Connect(function()
	isAttacking = false
	isBlocking = false
	isParrying = false
	isStaggered = false
	lockedTarget = nil

	if lockOnIndicator then
		lockOnIndicator:Destroy()
	end

	if blockShield then
		blockShield:Destroy()
		blockShield = nil
	end
	if blockShieldConnection then
		blockShieldConnection:Disconnect()
		blockShieldConnection = nil
	end

	if currentAttackTrack then
		currentAttackTrack:Stop()
	end

	-- Останавливаем все анимации блока/парирования
	currentBlockTrack:Stop()
	currentParryTrack:Stop()
	fistBlockAnim:Stop()
	fistParryAnim:Stop()

	-- Останавливаем анимации оружия
	for _, weaponAnims in pairs(loadedAnimations.Weapons) do
		if weaponAnims.Block then weaponAnims.Block:Stop() end
		if weaponAnims.Parry then weaponAnims.Parry:Stop() end
	end
end)

local CombatSystem = {}

CombatSystem.IsAttacking = function() return isAttacking end
CombatSystem.IsBlocking = function() return isBlocking end
CombatSystem.IsParrying = function() return isParrying end
CombatSystem.GetComboCount = function() return comboCount end
CombatSystem.GetLockedTarget = function() return lockedTarget end
CombatSystem.CheckParry = checkParry
CombatSystem.GetCombatEvent = function() return combatEvent end
CombatSystem.HasWeaponInHand = hasWeaponInHand
CombatSystem.GetActiveWeaponData = getActiveWeaponData

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
