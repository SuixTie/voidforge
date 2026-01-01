--[[
	DummyManager - Управление тренировочными манекенами
	Voidforge: Eclipse Legacy
	
	Особенности:
	- Дамми стоит на месте и может получать урон
	- При смерти включается рагдолл
	- Респавн на том же месте через несколько секунды
	
	Использование:
	- Создайте R6 модель в Workspace
	- Назовите её "TrainingDummy" или добавьте тег "Dummy"
	- Скрипт автоматически найдёт и настроит всех дамми
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("=== DummyManager: Script started ===")

-- === НАСТРОЙКИ ===
local CONFIG = {
	RespawnTime = 5,           -- Время до респавна (секунды)
	MaxHealth = 1000,           -- Максимальное здоровье
	DeathSoundId = "rbxassetid://148590801",
	DeathSoundVolume = 0.05,
	RagdollDuration = 4,       -- Время рагдолла перед исчезновением
	DummyNames = {"TrainingDummy", "Dummy", "CombatDummy"}, -- Имена для поиска
	IdleAnimationId = "rbxassetid://118776133928639", -- Idle анимация для R6
}

-- === ХРАНИЛИЩЕ ДАММИ ===
local dummySpawnPoints = {} -- [dummy] = CFrame

-- === ФУНКЦИЯ ВОСПРОИЗВЕДЕНИЯ IDLE АНИМАЦИИ ===
local function playIdleAnimation(dummy)
	local humanoid = dummy:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Ждём Animator или создаём его
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Создаём и загружаем анимацию
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = CONFIG.IdleAnimationId

	local success, idleTrack = pcall(function()
		return animator:LoadAnimation(idleAnim)
	end)

	if success and idleTrack then
		idleTrack.Priority = Enum.AnimationPriority.Idle
		idleTrack.Looped = true
		idleTrack:Play()
		print("DummyManager: Idle animation started for", dummy.Name)
		return idleTrack
	else
		warn("DummyManager: Failed to load idle animation for", dummy.Name)
	end
end

-- === ФУНКЦИЯ РАГДОЛЛА ===
local function applyRagdoll(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		-- Импульс для падения
		local pushDirection = rootPart.CFrame.LookVector * -30 + Vector3.new(0, 20, 0)
		rootPart:ApplyImpulse(pushDirection)
	end

	-- Заменяем Motor6D на BallSocketConstraint
	for _, joint in pairs(character:GetDescendants()) do
		if joint:IsA("Motor6D") then
			local socket = Instance.new("BallSocketConstraint")
			local a1 = Instance.new("Attachment")
			local a2 = Instance.new("Attachment")
			a1.Parent = joint.Part0
			a2.Parent = joint.Part1
			socket.Parent = joint.Parent
			socket.Attachment0 = a1
			socket.Attachment1 = a2
			a1.CFrame = joint.C0
			a2.CFrame = joint.C1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			joint:Destroy()
		end
	end
end

-- === ФУНКЦИЯ СОЗДАНИЯ ЗВУКА СМЕРТИ ===
local function playDeathSound(character)
	local head = character:FindFirstChild("Head")
	if head then
		local sound = Instance.new("Sound")
		sound.SoundId = CONFIG.DeathSoundId
		sound.Volume = CONFIG.DeathSoundVolume
		sound.RollOffMinDistance = 5
		sound.RollOffMaxDistance = 30
		sound.Parent = head
		sound:Play()
	end
end

-- === ФУНКЦИЯ КЛОНИРОВАНИЯ ДАММИ ===
local function cloneDummy(originalDummy, spawnCFrame)
	local newDummy = originalDummy:Clone()

	-- Сбрасываем позицию
	local rootPart = newDummy:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = spawnCFrame
		rootPart.Anchored = false
	end

	-- Сбрасываем здоровье
	local humanoid = newDummy:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Health = CONFIG.MaxHealth
		humanoid.MaxHealth = CONFIG.MaxHealth
	end

	newDummy.Parent = workspace
	return newDummy
end

-- === ФУНКЦИЯ НАСТРОЙКИ ДАММИ ===
local function setupDummy(dummy, originalTemplate)
	local humanoid = dummy:FindFirstChild("Humanoid")
	local rootPart = dummy:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		warn("DummyManager: Invalid dummy model -", dummy.Name)
		return
	end

	-- Сохраняем точку спавна
	local spawnCFrame = rootPart.CFrame
	dummySpawnPoints[dummy] = spawnCFrame

	-- Настраиваем Humanoid
	humanoid.MaxHealth = CONFIG.MaxHealth
	humanoid.Health = CONFIG.MaxHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = 0 -- Дамми не двигается
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	-- Отключаем автоматическое удаление
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)

	-- Запускаем idle анимацию
	local idleTrack = playIdleAnimation(dummy)

	-- Обработка смерти
	humanoid.Died:Connect(function()
		-- Останавливаем idle анимацию
		if idleTrack then
			idleTrack:Stop()
		end

		-- Звук смерти
		playDeathSound(dummy)

		-- Рагдолл
		applyRagdoll(dummy)

		-- Удаляем через время
		task.delay(CONFIG.RagdollDuration, function()
			if dummy and dummy.Parent then
				dummy:Destroy()
			end
		end)

		-- Респавн нового дамми
		task.delay(CONFIG.RespawnTime, function()
			local newDummy = cloneDummy(originalTemplate, spawnCFrame)
			setupDummy(newDummy, originalTemplate)
		end)
	end)

	print("DummyManager: Setup complete for", dummy.Name)
end

-- === ПОИСК И НАСТРОЙКА ВСЕХ ДАММИ ===
local function findAndSetupDummies()
	print("DummyManager: Searching for dummies...")
	local foundCount = 0

	-- Ищем по именам
	for _, name in ipairs(CONFIG.DummyNames) do
		for _, dummy in ipairs(workspace:GetDescendants()) do
			if dummy:IsA("Model") and dummy.Name == name then
				print("DummyManager: Found dummy by name:", dummy.Name, "at", dummy:GetFullName())
				local template = dummy:Clone() -- Сохраняем шаблон для респавна
				setupDummy(dummy, template)
				foundCount = foundCount + 1
			end
		end
	end

	-- Ищем по тегу
	for _, dummy in ipairs(CollectionService:GetTagged("Dummy")) do
		if dummy:IsA("Model") and not dummySpawnPoints[dummy] then
			print("DummyManager: Found dummy by tag:", dummy.Name)
			local template = dummy:Clone()
			setupDummy(dummy, template)
			foundCount = foundCount + 1
		end
	end

	print("DummyManager: Total dummies found:", foundCount)
end

-- === СОЗДАНИЕ ДАММИ ПРОГРАММНО ===
local function createDummy(position, name)
	-- Создаём R6 модель
	local dummy = Instance.new("Model")
	dummy.Name = name or "TrainingDummy"

	-- Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.CFrame = CFrame.new(position)
	torso.Anchored = false
	torso.Parent = dummy

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Shape = Enum.PartType.Ball
	head.CFrame = torso.CFrame * CFrame.new(0, 1.5, 0)
	head.Anchored = false
	head.Parent = dummy

	local headJoint = Instance.new("Motor6D")
	headJoint.Name = "Neck"
	headJoint.Part0 = torso
	headJoint.Part1 = head
	headJoint.C0 = CFrame.new(0, 1, 0)
	headJoint.C1 = CFrame.new(0, -0.5, 0)
	headJoint.Parent = torso

	-- HumanoidRootPart
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.CFrame = torso.CFrame
	rootPart.Transparency = 1
	rootPart.Anchored = false
	rootPart.Parent = dummy

	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "RootJoint"
	rootJoint.Part0 = rootPart
	rootJoint.Part1 = torso
	rootJoint.Parent = rootPart

	-- Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.CFrame = torso.CFrame * CFrame.new(-1.5, 0, 0)
	leftArm.Anchored = false
	leftArm.Parent = dummy

	local leftShoulder = Instance.new("Motor6D")
	leftShoulder.Name = "Left Shoulder"
	leftShoulder.Part0 = torso
	leftShoulder.Part1 = leftArm
	leftShoulder.C0 = CFrame.new(-1, 0.5, 0)
	leftShoulder.C1 = CFrame.new(0.5, 0.5, 0)
	leftShoulder.Parent = torso

	-- Right Arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.CFrame = torso.CFrame * CFrame.new(1.5, 0, 0)
	rightArm.Anchored = false
	rightArm.Parent = dummy

	local rightShoulder = Instance.new("Motor6D")
	rightShoulder.Name = "Right Shoulder"
	rightShoulder.Part0 = torso
	rightShoulder.Part1 = rightArm
	rightShoulder.C0 = CFrame.new(1, 0.5, 0)
	rightShoulder.C1 = CFrame.new(-0.5, 0.5, 0)
	rightShoulder.Parent = torso

	-- Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.CFrame = torso.CFrame * CFrame.new(-0.5, -2, 0)
	leftLeg.Anchored = false
	leftLeg.Parent = dummy

	local leftHip = Instance.new("Motor6D")
	leftHip.Name = "Left Hip"
	leftHip.Part0 = torso
	leftHip.Part1 = leftLeg
	leftHip.C0 = CFrame.new(-0.5, -1, 0)
	leftHip.C1 = CFrame.new(0, 1, 0)
	leftHip.Parent = torso

	-- Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.CFrame = torso.CFrame * CFrame.new(0.5, -2, 0)
	rightLeg.Anchored = false
	rightLeg.Parent = dummy

	local rightHip = Instance.new("Motor6D")
	rightHip.Name = "Right Hip"
	rightHip.Part0 = torso
	rightHip.Part1 = rightLeg
	rightHip.C0 = CFrame.new(0.5, -1, 0)
	rightHip.C1 = CFrame.new(0, 1, 0)
	rightHip.Parent = torso

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = dummy

	-- Face
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- Цвет (серый для дамми)
	for _, part in ipairs(dummy:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.BrickColor = BrickColor.new("Medium stone grey")
			part.Material = Enum.Material.SmoothPlastic
		end
	end

	dummy.PrimaryPart = rootPart
	dummy.Parent = workspace

	return dummy
end

-- === ИНИЦИАЛИЗАЦИЯ ===
task.spawn(function()
	print("DummyManager: Waiting for world to load...")
	task.wait(2) -- Ждём загрузки мира
	findAndSetupDummies()
	print("=== DummyManager: Initialized ===")
end)

-- Также ищем при добавлении новых объектов в workspace
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") then
		for _, name in ipairs(CONFIG.DummyNames) do
			if descendant.Name == name and not dummySpawnPoints[descendant] then
				print("DummyManager: New dummy added:", descendant.Name)
				task.wait(0.1)
				local template = descendant:Clone()
				setupDummy(descendant, template)
			end
		end
	end
end)

-- Слушаем добавление новых дамми с тегом
CollectionService:GetInstanceAddedSignal("Dummy"):Connect(function(dummy)
	if dummy:IsA("Model") and not dummySpawnPoints[dummy] then
		task.wait(0.1)
		local template = dummy:Clone()
		setupDummy(dummy, template)
	end
end)

-- === ЭКСПОРТ ДЛЯ ДРУГИХ СКРИПТОВ ===
local DummyManager = {}
DummyManager.CreateDummy = createDummy
DummyManager.Config = CONFIG

return DummyManager
