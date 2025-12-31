--[[
	LedgeGrabScript - Система цепляния за края
	Использует CollectionService с тегом "Ledge" для определения краёв
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local head = character:WaitForChild("Head")
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local RunConfig = require(game.ReplicatedStorage.RunConfig)
local LedgeGrabConfig = require(game.ReplicatedStorage.LedgeGrabConfig)

-- === ПРИНУДИТЕЛЬНЫЙ СБРОС ПРИ ЗАГРУЗКЕ СКРИПТА ===
-- Это гарантирует что при респавне флаги сброшены
LedgeGrabConfig.IsHanging = false
LedgeGrabConfig.IsClimbingUp = false
LedgeGrabConfig.IsShimmying = false
LedgeGrabConfig.CanGrab = true

-- Сбрасываем RunConfig флаги тоже
RunConfig.CanRun = true
RunConfig.Running = false
RunConfig.Sprinting = false
RunConfig.Walking = false

-- === STAMINA INTEGRATION ===
local isBreathing = false
-- Подключение к событию будет после определения функции fall()

-- === STATE ===
local holding = false
local ledgeavailable = true
local cd = false
local isTransitioning = false  -- Флаг для блокировки обновления gyro во время перехода

local gyro = nil
local ledgeVelocity = nil
local cross = nil

-- === RAYCAST PARAMS ===
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- === ANIMATIONS ===
local holdAnim = Instance.new("Animation")
holdAnim.AnimationId = LedgeGrabConfig.HangIdleAnimId
local holdTrack = nil

local climbAnim = Instance.new("Animation")
climbAnim.AnimationId = LedgeGrabConfig.ClimbUpAnimId
local climbTrack = nil

local leftAnim = Instance.new("Animation")
leftAnim.AnimationId = LedgeGrabConfig.ShimmyLeftAnimId
local leftTrack = nil

local rightAnim = Instance.new("Animation")
rightAnim.AnimationId = LedgeGrabConfig.ShimmyRightAnimId
local rightTrack = nil

local dropAnim = Instance.new("Animation")
dropAnim.AnimationId = LedgeGrabConfig.DropAnimId
local dropTrack = nil

-- === ЗВУКИ ===
local grabSound = nil    -- Звук захвата
local climbSound = nil   -- Звук забирания наверх
local dropSound = nil    -- Звук отпускания
local shimmySound = nil  -- Звук перемещения
local cornerSound = nil  -- Звук перехода Q/E

local function loadAnimations()
	if LedgeGrabConfig.HangIdleAnimId ~= "rbxassetid://0" then
		holdTrack = animator:LoadAnimation(holdAnim)
		holdTrack.Priority = Enum.AnimationPriority.Action3
		holdTrack.Looped = true
	end
	if LedgeGrabConfig.ClimbUpAnimId ~= "rbxassetid://0" then
		climbTrack = animator:LoadAnimation(climbAnim)
		climbTrack.Priority = Enum.AnimationPriority.Action4
	end
	if LedgeGrabConfig.ShimmyLeftAnimId ~= "rbxassetid://0" then
		leftTrack = animator:LoadAnimation(leftAnim)
		leftTrack.Priority = Enum.AnimationPriority.Action3
	end
	if LedgeGrabConfig.ShimmyRightAnimId ~= "rbxassetid://0" then
		rightTrack = animator:LoadAnimation(rightAnim)
		rightTrack.Priority = Enum.AnimationPriority.Action3
	end
	if LedgeGrabConfig.DropAnimId ~= "rbxassetid://0" then
		dropTrack = animator:LoadAnimation(dropAnim)
		dropTrack.Priority = Enum.AnimationPriority.Action4
	end

	-- Создаём звук захвата
	if LedgeGrabConfig.GrabSoundId ~= "rbxassetid://0" then
		grabSound = Instance.new("Sound")
		grabSound.Name = "GrabSound"
		grabSound.SoundId = LedgeGrabConfig.GrabSoundId
		grabSound.RollOffMinDistance = 5
		grabSound.RollOffMaxDistance = 20
		grabSound.Volume = 0.1
		grabSound.Parent = rootPart
	end

	-- Создаём звук забирания наверх
	if LedgeGrabConfig.ClimbSoundId ~= "rbxassetid://0" then
		climbSound = Instance.new("Sound")
		climbSound.Name = "ClimbSound"
		climbSound.SoundId = LedgeGrabConfig.ClimbSoundId
		climbSound.RollOffMinDistance = 5
		climbSound.RollOffMaxDistance = 20
		climbSound.Volume = 0.15
		climbSound.Parent = rootPart
	end

	-- Создаём звук отпускания
	if LedgeGrabConfig.DropSoundId ~= "rbxassetid://0" then
		dropSound = Instance.new("Sound")
		dropSound.Name = "DropSound"
		dropSound.SoundId = LedgeGrabConfig.DropSoundId
		dropSound.RollOffMinDistance = 5
		dropSound.RollOffMaxDistance = 20
		dropSound.Volume = 0.1
		dropSound.Parent = rootPart
	end

	-- Создаём звук перемещения (shimmy)
	if LedgeGrabConfig.ShimmySoundId ~= "rbxassetid://0" then
		shimmySound = Instance.new("Sound")
		shimmySound.Name = "ShimmySound"
		shimmySound.SoundId = LedgeGrabConfig.ShimmySoundId
		shimmySound.RollOffMinDistance = 5
		shimmySound.RollOffMaxDistance = 20
		shimmySound.Volume = 0.1
		shimmySound.Parent = rootPart
	end
	
	-- Создаём звук перехода Q/E (corner)
	if LedgeGrabConfig.CornerSoundId ~= "rbxassetid://0" then
		cornerSound = Instance.new("Sound")
		cornerSound.Name = "CornerSound"
		cornerSound.SoundId = LedgeGrabConfig.CornerSoundId
		cornerSound.RollOffMinDistance = 5
		cornerSound.RollOffMaxDistance = 20
		cornerSound.Volume = 0.15
		cornerSound.Parent = rootPart
	end
end

loadAnimations()


-- === SAVED STATE ===
local savedState = {}
local savedArmCollisions = {}  -- Сохраняем оригинальные настройки коллизий рук

-- === COLLISION FUNCTIONS ===
local armParts = {"LeftHand", "LeftLowerArm", "LeftUpperArm", "RightHand", "RightLowerArm", "RightUpperArm"}
-- ВСЕ части тела которые могут сталкиваться с блоками при переходе (включая ноги и торс)
local allBodyParts = {
	"LeftHand", "LeftLowerArm", "LeftUpperArm", 
	"RightHand", "RightLowerArm", "RightUpperArm", 
	"UpperTorso", "LowerTorso", "Head",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot"
}
local savedBodyCollisions = {}

local function enableArmCollisions()
	for _, partName in ipairs(armParts) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			-- Сохраняем оригинальное значение
			savedArmCollisions[partName] = part.CanCollide
			-- Включаем коллизии
			part.CanCollide = true
		end
	end
end

local function disableArmCollisions()
	for _, partName in ipairs(armParts) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			-- Восстанавливаем оригинальное значение
			part.CanCollide = savedArmCollisions[partName] or false
		end
	end
	savedArmCollisions = {}
end

-- Временно отключает коллизии рук (без сброса savedArmCollisions)
local function tempDisableArmCollisions()
	for _, partName in ipairs(armParts) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

-- Восстанавливает коллизии рук после временного отключения
local function tempEnableArmCollisions()
	for _, partName in ipairs(armParts) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.CanCollide = true
		end
	end
end

-- Временно отключает коллизии всего тела (для переходов в углах)
local function tempDisableAllBodyCollisions()
	for _, partName in ipairs(allBodyParts) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			savedBodyCollisions[partName] = part.CanCollide
			part.CanCollide = false
		end
	end
	-- Также отключаем HumanoidRootPart
	if rootPart then
		savedBodyCollisions["HumanoidRootPart"] = rootPart.CanCollide
		rootPart.CanCollide = false
	end
end

-- Восстанавливает коллизии всего тела
local function tempEnableAllBodyCollisions()
	for _, partName in ipairs(allBodyParts) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.CanCollide = savedBodyCollisions[partName] or false
		end
	end
	-- Восстанавливаем HumanoidRootPart
	if rootPart then
		rootPart.CanCollide = savedBodyCollisions["HumanoidRootPart"] or true
	end
	savedBodyCollisions = {}
end

-- === STOP ALL OTHER ANIMATIONS ===
local function stopAllOtherAnimations()
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		-- Не останавливаем наши ledge анимации
		if track ~= holdTrack and track ~= climbTrack and track ~= leftTrack and track ~= rightTrack then
			track:Stop(0.1)
		end
	end
end

-- === HELPER FUNCTIONS ===
local function disableMovement()
	-- Сохраняем текущее состояние
	savedState = {
		WalkSpeed = humanoid.WalkSpeed,
		JumpHeight = humanoid.JumpHeight,
		CanRun = RunConfig.CanRun,
		Running = RunConfig.Running,
		Sprinting = RunConfig.Sprinting,
	}

	-- Отключаем движение
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0

	-- Отключаем все флаги в RunConfig
	LedgeGrabConfig.IsHanging = true
	RunConfig.CanRun = false
	RunConfig.Running = false
	RunConfig.Sprinting = false
	RunConfig.Walking = false
	RunConfig.isProne = false

	-- Отключаем присед
	local crouchVal = player:FindFirstChild("IsCrouching")
	if crouchVal then crouchVal.Value = false end

	-- Отключаем слайд
	local slideVal = player:FindFirstChild("IsSliding")
	if slideVal then slideVal.Value = false end

	-- Включаем коллизии рук
	enableArmCollisions()

	-- Останавливаем все другие анимации
	stopAllOtherAnimations()
end

local function enableMovement()
	-- Восстанавливаем состояние
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = savedState.WalkSpeed or 12
	-- Всегда восстанавливаем дефолтный JumpHeight (не сохранённый, т.к. мог быть 0 при приседании)
	humanoid.JumpHeight = humanoid:GetAttribute("DefaultJumpHeight") or 7.2

	-- Восстанавливаем флаги
	LedgeGrabConfig.IsHanging = false
	RunConfig.CanRun = savedState.CanRun or true
	RunConfig.Running = false
	RunConfig.Sprinting = false
	RunConfig.Walking = false

	-- Отключаем коллизии рук (восстанавливаем оригинальные значения)
	disableArmCollisions()
end

local function cleanup()
	if ledgeVelocity then
		ledgeVelocity:Destroy()
		ledgeVelocity = nil
	end
	if gyro then
		gyro:Destroy()
		gyro = nil
	end
end

-- === CHECK CLIMB SPACE ===
local function canClimbUp()
	raycastParams.FilterDescendantsInstances = {character}

	-- Проверяем место над головой (вверх на ~5 studs)
	local upOrigin = head.Position
	local upDirection = Vector3.new(0, 5, 0)
	local upResult = workspace:Raycast(upOrigin, upDirection, raycastParams)

	if upResult then
		-- Что-то блокирует сверху
		return false
	end

	-- Проверяем место впереди на платформе (вперёд и вверх)
	local forwardOrigin = head.Position + Vector3.new(0, 3, 0)
	local forwardDirection = rootPart.CFrame.LookVector * 3
	local forwardResult = workspace:Raycast(forwardOrigin, forwardDirection, raycastParams)

	if forwardResult then
		-- Что-то блокирует впереди на платформе
		return false
	end

	return true
end

-- === CLIMB UP ===
local function climb()
	-- Проверяем есть ли место для подъёма
	if not canClimbUp() then
		return -- Нет места - ничего не делаем
	end

	-- Тратим стамину за забирание
	local dashStaminaEvent = character:FindFirstChild("DashEvent")
	if dashStaminaEvent then
		dashStaminaEvent:Fire("climb")
	end

	cleanup()
	holding = false

	-- Длительность анимации подъёма
	local climbDuration = 0.87

	-- Останавливаем анимацию виса и запускаем подъём
	if holdTrack then holdTrack:Stop() end
	if climbTrack then climbTrack:Play() end

	-- Проигрываем звук забирания
	if climbSound then climbSound:Play() end

	-- Фаза 1: Подтягивание вверх (первые 60% анимации)
	local pullUpDuration = climbDuration * 0.6
	local pullUpVelocity = Instance.new("BodyVelocity")
	pullUpVelocity.Parent = rootPart
	pullUpVelocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	pullUpVelocity.Velocity = Vector3.new(0, 8, 0) -- Уменьшено с 12 до 8

	task.wait(pullUpDuration)
	pullUpVelocity:Destroy()

	-- Фаза 2: Движение вперёд на платформу (оставшиеся 40% анимации)
	local moveForwardDuration = climbDuration * 0.4
	local forwardVelocity = Instance.new("BodyVelocity")
	forwardVelocity.Parent = rootPart
	forwardVelocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	forwardVelocity.Velocity = rootPart.CFrame.LookVector * 5 -- Уменьшено с 8 до 5

	task.wait(moveForwardDuration)
	forwardVelocity:Destroy()

	-- Небольшая пауза для завершения анимации
	task.wait(0.1)

	ledgeavailable = true
	enableMovement()
end

-- === DROP DOWN ===
local function fall()
	cleanup()

	local velocity = Instance.new("BodyVelocity")
	velocity.Parent = rootPart
	velocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	velocity.Velocity = rootPart.CFrame.LookVector * 0.5 + Vector3.new(0, -30, 0)

	if holdTrack then holdTrack:Stop() end

	-- Проигрываем анимацию отпускания
	if dropTrack then dropTrack:Play() end

	-- Проигрываем звук отпускания когда игрок касается земли
	if dropSound then
		task.spawn(function()
			-- Ждём пока игрок коснётся земли (максимум 3 секунды)
			local startTime = tick()
			while tick() - startTime < 3 do
				if humanoid.FloorMaterial ~= Enum.Material.Air then
					dropSound:Play()
					break
				end
				task.wait(0.05)
			end
		end)
	end

	game.Debris:AddItem(velocity, 0.15)
	holding = false

	task.wait(0.1)
	ledgeavailable = true
	enableMovement()
end

-- === STAMINA EVENT CONNECTION (после определения fall) ===
task.spawn(function()
	local breathingEvent = character:WaitForChild("BreathingEvent", 10)
	if breathingEvent then
		breathingEvent.Event:Connect(function(breathing)
			isBreathing = breathing
			print("LedgeGrab: Breathing state changed to", breathing)
			-- Если начинается отдышка во время виса - отпускаем
			if breathing and holding then
				fall()
			end
		end)
	else
		warn("LedgeGrab: BreathingEvent not found!")
	end
end)

-- === SHIMMY LEFT ===
local isShimmyingLeft = false

local function moveLeft()
	if isShimmyingLeft then return end
	isShimmyingLeft = true
	
	-- Меняем скорость существующего ledgeVelocity вместо создания нового
	if ledgeVelocity then
		ledgeVelocity.Velocity = cross * -3.5
	end

	if holdTrack then holdTrack:Stop() end
	if leftTrack then leftTrack:Play() end

	-- Проигрываем звук перемещения
	if shimmySound then shimmySound:Play() end

	task.delay(0.49, function()
		if leftTrack then leftTrack:Stop() end
		isShimmyingLeft = false
		-- Возвращаем скорость на ноль и анимацию виса
		if holding then
			if ledgeVelocity then
				ledgeVelocity.Velocity = Vector3.zero
			end
			if holdTrack then holdTrack:Play() end
		end
	end)
end

-- === SHIMMY RIGHT ===
local isShimmyingRight = false

local function moveRight()
	if isShimmyingRight then return end
	isShimmyingRight = true
	
	-- Меняем скорость существующего ledgeVelocity вместо создания нового
	if ledgeVelocity then
		ledgeVelocity.Velocity = cross * 3.5
	end

	if holdTrack then holdTrack:Stop() end
	if rightTrack then rightTrack:Play() end

	-- Проигрываем звук перемещения
	if shimmySound then shimmySound:Play() end

	task.delay(0.49, function()
		if rightTrack then rightTrack:Stop() end
		isShimmyingRight = false
		-- Возвращаем скорость на ноль и анимацию виса
		if holding then
			if ledgeVelocity then
				ledgeVelocity.Velocity = Vector3.zero
			end
			if holdTrack then holdTrack:Play() end
		end
	end)
end

-- === CORNER TRANSITION LEFT (Q) ===
local function cornerLeft(turnRayResult)
	isTransitioning = true  -- Блокируем обновление gyro в Heartbeat

	-- Полностью отключаем физику персонажа
	humanoid.PlatformStand = true
	
	-- Проигрываем звук перехода
	if cornerSound then cornerSound:Play() end

	-- Останавливаем все анимации (включая shimmy - они могут двигать персонажа)
	if holdTrack then holdTrack:Stop() end
	if leftTrack then leftTrack:Stop() end
	if rightTrack then rightTrack:Stop() end

	-- Получаем нормаль новой стены из turnRay
	local newNormal = turnRayResult.Normal
	-- Убираем вертикальную составляющую нормали
	newNormal = Vector3.new(newNormal.X, 0, newNormal.Z).Unit

	-- Сохраняем текущую Y позицию игрока
	local currentY = rootPart.Position.Y

	-- Позиция: точка удара + отступ от стены (увеличен до 1.5 чтобы не попадать в блоки)
	local hitPos = turnRayResult.Position
	local targetPos = Vector3.new(hitPos.X, currentY, hitPos.Z) + newNormal * 1.5

	-- Игрок смотрит на стену
	local lookDir = -newNormal
	local targetCFrame = CFrame.lookAt(targetPos, targetPos + lookDir)

	-- Вычисляем новый cross вектор для новой стены
	cross = Vector3.new(0, 1, 0):Cross(newNormal)

	-- Обновляем gyro для нового направления
	if gyro then
		gyro.CFrame = targetCFrame
	end

	-- Телепортируем игрока напрямую через CFrame (без velocity)
	rootPart.CFrame = targetCFrame

	-- Полностью обнуляем все скорости
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	if ledgeVelocity then
		ledgeVelocity.Velocity = Vector3.zero
	end

	task.delay(0.3, function()
		-- Ещё раз обнуляем скорости перед включением физики
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero

		isTransitioning = false  -- Разрешаем обновление gyro
		humanoid.PlatformStand = false  -- Включаем физику обратно
		if holding then
			if holdTrack then holdTrack:Play() end
		end
	end)
end

-- === CORNER TRANSITION RIGHT (E) ===
local function cornerRight(turnRayResult)
	isTransitioning = true  -- Блокируем обновление gyro в Heartbeat

	-- Полностью отключаем физику персонажа
	humanoid.PlatformStand = true
	
	-- Проигрываем звук перехода
	if cornerSound then cornerSound:Play() end

	-- Останавливаем все анимации (включая shimmy - они могут двигать персонажа)
	if holdTrack then holdTrack:Stop() end
	if leftTrack then leftTrack:Stop() end
	if rightTrack then rightTrack:Stop() end

	-- Получаем нормаль новой стены из turnRay
	local newNormal = turnRayResult.Normal
	-- Убираем вертикальную составляющую нормали
	newNormal = Vector3.new(newNormal.X, 0, newNormal.Z).Unit

	-- Сохраняем текущую Y позицию игрока
	local currentY = rootPart.Position.Y

	-- Позиция: точка удара + отступ от стены (увеличен до 1.5 чтобы не попадать в блоки)
	local hitPos = turnRayResult.Position
	local targetPos = Vector3.new(hitPos.X, currentY, hitPos.Z) + newNormal * 1.5

	-- Игрок смотрит на стену
	local lookDir = -newNormal
	local targetCFrame = CFrame.lookAt(targetPos, targetPos + lookDir)

	-- Вычисляем новый cross вектор для новой стены
	cross = Vector3.new(0, 1, 0):Cross(newNormal)

	-- Обновляем gyro для нового направления
	if gyro then
		gyro.CFrame = targetCFrame
	end

	-- Телепортируем игрока напрямую через CFrame (без velocity)
	rootPart.CFrame = targetCFrame

	-- Полностью обнуляем все скорости
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	if ledgeVelocity then
		ledgeVelocity.Velocity = Vector3.zero
	end

	task.delay(0.3, function()
		-- Ещё раз обнуляем скорости перед включением физики
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero

		isTransitioning = false  -- Разрешаем обновление gyro
		humanoid.PlatformStand = false  -- Включаем физику обратно
		if holding then
			if holdTrack then holdTrack:Play() end
		end
	end)
end

-- === SIDE WALL TRANSITION LEFT (Q) - переход на стену слева (блокирующую путь) ===
local function sideWallLeft(sideWallResult)
	isTransitioning = true  -- Блокируем обновление gyro в Heartbeat

	-- Полностью отключаем физику персонажа
	humanoid.PlatformStand = true
	
	-- Проигрываем звук перехода
	if cornerSound then cornerSound:Play() end

	-- Останавливаем все анимации (включая shimmy - они могут двигать персонажа)
	if holdTrack then holdTrack:Stop() end
	if leftTrack then leftTrack:Stop() end
	if rightTrack then rightTrack:Stop() end

	-- Получаем нормаль боковой стены (направлена ОТ стены)
	local newNormal = sideWallResult.Normal
	-- Убираем вертикальную составляющую нормали (только горизонтальное направление)
	newNormal = Vector3.new(newNormal.X, 0, newNormal.Z).Unit

	-- Игрок должен смотреть НА стену (в направлении противоположном нормали)
	local lookDir = -newNormal

	-- Сохраняем текущую Y позицию игрока
	local currentY = rootPart.Position.Y

	-- Позиция: точка удара + отступ от стены (увеличен до 1.5 чтобы не попадать в блоки)
	local hitPos = sideWallResult.Position
	local targetPos = Vector3.new(hitPos.X, currentY, hitPos.Z) + newNormal * 1.5

	-- CFrame.lookAt(позиция, куда_смотрим) - смотрим на стену
	local targetCFrame = CFrame.lookAt(targetPos, targetPos + lookDir)

	-- Вычисляем новый cross вектор для новой стены
	cross = Vector3.new(0, 1, 0):Cross(newNormal)

	-- Обновляем gyro для нового направления
	if gyro then
		gyro.CFrame = targetCFrame
	end

	-- Телепортируем игрока напрямую через CFrame (без velocity)
	rootPart.CFrame = targetCFrame

	-- Полностью обнуляем все скорости
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	if ledgeVelocity then
		ledgeVelocity.Velocity = Vector3.zero
	end

	task.delay(0.3, function()
		-- Ещё раз обнуляем скорости перед включением физики
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero

		isTransitioning = false  -- Разрешаем обновление gyro
		humanoid.PlatformStand = false  -- Включаем физику обратно
		if holding then
			if holdTrack then holdTrack:Play() end
		end
	end)
end

-- === SIDE WALL TRANSITION RIGHT (E) - переход на стену справа (блокирующую путь) ===
local function sideWallRight(sideWallResult)
	isTransitioning = true  -- Блокируем обновление gyro в Heartbeat

	-- Полностью отключаем физику персонажа
	humanoid.PlatformStand = true
	
	-- Проигрываем звук перехода
	if cornerSound then cornerSound:Play() end

	-- Останавливаем все анимации (включая shimmy - они могут двигать персонажа)
	if holdTrack then holdTrack:Stop() end
	if leftTrack then leftTrack:Stop() end
	if rightTrack then rightTrack:Stop() end

	-- Получаем нормаль боковой стены (направлена ОТ стены)
	local newNormal = sideWallResult.Normal
	-- Убираем вертикальную составляющую нормали (только горизонтальное направление)
	newNormal = Vector3.new(newNormal.X, 0, newNormal.Z).Unit

	-- Игрок должен смотреть НА стену (в направлении противоположном нормали)
	local lookDir = -newNormal

	-- Сохраняем текущую Y позицию игрока
	local currentY = rootPart.Position.Y

	-- Позиция: точка удара + отступ от стены (увеличен до 1.5 чтобы не попадать в блоки)
	local hitPos = sideWallResult.Position
	local targetPos = Vector3.new(hitPos.X, currentY, hitPos.Z) + newNormal * 1.5

	-- CFrame.lookAt(позиция, куда_смотрим) - смотрим на стену
	local targetCFrame = CFrame.lookAt(targetPos, targetPos + lookDir)

	-- Вычисляем новый cross вектор для новой стены
	cross = Vector3.new(0, 1, 0):Cross(newNormal)

	-- Обновляем gyro для нового направления
	if gyro then
		gyro.CFrame = targetCFrame
	end

	-- Телепортируем игрока напрямую через CFrame (без velocity)
	rootPart.CFrame = targetCFrame

	-- Полностью обнуляем все скорости
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	if ledgeVelocity then
		ledgeVelocity.Velocity = Vector3.zero
	end

	task.delay(0.3, function()
		-- Ещё раз обнуляем скорости перед включением физики
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero

		isTransitioning = false  -- Разрешаем обновление gyro
		humanoid.PlatformStand = false  -- Включаем физику обратно
		if holding then
			if holdTrack then holdTrack:Play() end
		end
	end)
end


-- === INPUT HANDLING ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not holding then return end
	if gameProcessed then return end

	-- Climb up (Space)
	if input.KeyCode == Enum.KeyCode.Space then
		climb()
	end

	-- Corner transition left (Q) - переход на левый угол блока или на стену слева
	if input.KeyCode == Enum.KeyCode.Q and not cd then
		raycastParams.FilterDescendantsInstances = {character}

		-- Проверяем нет ли блоков над головой игрока (текущая позиция)
		local aboveCheckOrigin = head.Position
		local aboveCheckDirection = Vector3.new(0, 3, 0)
		local aboveResult = workspace:Raycast(aboveCheckOrigin, aboveCheckDirection, raycastParams)
		if aboveResult then return end  -- Есть блок сверху - нельзя делать переход

		-- Сначала проверяем есть ли стена слева (блокирующая путь) - переход на неё
		local sideWallOrigin = rootPart.CFrame.Position
		local sideWallDirection = -cross * 3  -- Луч влево
		local sideWallResult = workspace:Raycast(sideWallOrigin, sideWallDirection, raycastParams)

		if sideWallResult and sideWallResult.Instance and CollectionService:HasTag(sideWallResult.Instance, "Ledge") then
			-- Проверяем нет ли блоков над целевой позицией
			local targetNormal = sideWallResult.Normal
			targetNormal = Vector3.new(targetNormal.X, 0, targetNormal.Z).Unit
			local targetPos = sideWallResult.Position + targetNormal * 1.5
			local targetAboveOrigin = Vector3.new(targetPos.X, head.Position.Y, targetPos.Z)
			local targetAboveResult = workspace:Raycast(targetAboveOrigin, Vector3.new(0, 3, 0), raycastParams)
			if targetAboveResult then return end  -- Есть блок над целевой позицией

			-- Есть стена слева - переходим на неё (используем специальную функцию)
			sideWallLeft(sideWallResult)
			cd = true
			task.wait(0.6)
			cd = false
			return
		end

		-- Иначе проверяем угол блока (старая логика)
		-- Шаг 1: Проверяем что слева нет продолжения стены (мы на краю)
		local moveCheckOrigin = head.Position - cross * 3
		local moveCheckDirection = rootPart.CFrame.LookVector * 2
		local moveResult = workspace:Raycast(moveCheckOrigin, moveCheckDirection, raycastParams)

		-- Если слева есть стена - это не угол, используй A для shimmy
		if moveResult then return end

		-- Шаг 2: turnRay - ищем боковую сторону блока
		local turnOrigin = head.Position + Vector3.new(0, -1, 0) - cross * 3 + rootPart.CFrame.LookVector * 2
		local turnDirection = cross * 4  -- Направлен вправо (обратно к блоку)
		local turnResult = workspace:Raycast(turnOrigin, turnDirection, raycastParams)

		if turnResult and turnResult.Instance and CollectionService:HasTag(turnResult.Instance, "Ledge") then
			-- Проверяем нет ли блоков над целевой позицией (угол блока)
			local targetNormal = turnResult.Normal
			targetNormal = Vector3.new(targetNormal.X, 0, targetNormal.Z).Unit
			local targetPos = turnResult.Position + targetNormal * 1.5
			local targetAboveOrigin = Vector3.new(targetPos.X, head.Position.Y, targetPos.Z)
			local targetAboveResult = workspace:Raycast(targetAboveOrigin, Vector3.new(0, 3, 0), raycastParams)
			if targetAboveResult then return end  -- Есть блок над целевой позицией

			cornerLeft(turnResult)
			cd = true
			task.wait(0.6)
			cd = false
		end
	end

	-- Corner transition right (E) - переход на правый угол блока или на стену справа
	if input.KeyCode == Enum.KeyCode.E and not cd then
		raycastParams.FilterDescendantsInstances = {character}

		-- Проверяем нет ли блоков над головой игрока (текущая позиция)
		local aboveCheckOrigin = head.Position
		local aboveCheckDirection = Vector3.new(0, 3, 0)
		local aboveResult = workspace:Raycast(aboveCheckOrigin, aboveCheckDirection, raycastParams)
		if aboveResult then return end  -- Есть блок сверху - нельзя делать переход

		-- Сначала проверяем есть ли стена справа (блокирующая путь) - переход на неё
		local sideWallOrigin = rootPart.CFrame.Position
		local sideWallDirection = cross * 3  -- Луч вправо
		local sideWallResult = workspace:Raycast(sideWallOrigin, sideWallDirection, raycastParams)

		if sideWallResult and sideWallResult.Instance and CollectionService:HasTag(sideWallResult.Instance, "Ledge") then
			-- Проверяем нет ли блоков над целевой позицией
			local targetNormal = sideWallResult.Normal
			targetNormal = Vector3.new(targetNormal.X, 0, targetNormal.Z).Unit
			local targetPos = sideWallResult.Position + targetNormal * 1.5
			local targetAboveOrigin = Vector3.new(targetPos.X, head.Position.Y, targetPos.Z)
			local targetAboveResult = workspace:Raycast(targetAboveOrigin, Vector3.new(0, 3, 0), raycastParams)
			if targetAboveResult then return end  -- Есть блок над целевой позицией

			-- Есть стена справа - переходим на неё (используем специальную функцию)
			sideWallRight(sideWallResult)
			cd = true
			task.wait(0.6)
			cd = false
			return
		end

		-- Иначе проверяем угол блока (старая логика)
		-- Шаг 1: Проверяем что справа нет продолжения стены (мы на краю)
		local moveCheckOrigin = head.Position + cross * 3
		local moveCheckDirection = rootPart.CFrame.LookVector * 2
		local moveResult = workspace:Raycast(moveCheckOrigin, moveCheckDirection, raycastParams)

		-- Если справа есть стена - это не угол, используй D для shimmy
		if moveResult then return end

		-- Шаг 2: turnRay - ищем боковую сторону блока
		local turnOrigin = head.Position + Vector3.new(0, -1, 0) + cross * 3 + rootPart.CFrame.LookVector * 2
		local turnDirection = -cross * 4  -- Направлен влево (обратно к блоку)
		local turnResult = workspace:Raycast(turnOrigin, turnDirection, raycastParams)

		if turnResult and turnResult.Instance and CollectionService:HasTag(turnResult.Instance, "Ledge") then
			-- Проверяем нет ли блоков над целевой позицией (угол блока)
			local targetNormal = turnResult.Normal
			targetNormal = Vector3.new(targetNormal.X, 0, targetNormal.Z).Unit
			local targetPos = turnResult.Position + targetNormal * 1.5
			local targetAboveOrigin = Vector3.new(targetPos.X, head.Position.Y, targetPos.Z)
			local targetAboveResult = workspace:Raycast(targetAboveOrigin, Vector3.new(0, 3, 0), raycastParams)
			if targetAboveResult then return end  -- Есть блок над целевой позицией

			cornerRight(turnResult)
			cd = true
			task.wait(0.6)
			cd = false
		end
	end

	-- Drop (S or C)
	if input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.C then
		fall()
	end
end)


-- === MAIN DETECTION LOOP ===
RunService.Heartbeat:Connect(function()
	-- === ПРОВЕРКА ЗАЖАТЫХ КЛАВИШ A/D ДЛЯ SHIMMY ===
	if holding and not cd and not isTransitioning then
		-- Проверяем зажата ли A
		if UserInputService:IsKeyDown(Enum.KeyCode.A) and not isShimmyingLeft then
			raycastParams.FilterDescendantsInstances = {character}
			-- Проверяем есть ли стена СЛЕВА от игрока
			local origin = rootPart.CFrame.Position - cross * 1.5
			local direction = rootPart.CFrame.LookVector * 2
			local result = workspace:Raycast(origin, direction, raycastParams)
			
			if result then
				-- Проверяем нет ли препятствия сбоку
				local sideBlockOrigin = rootPart.CFrame.Position
				local sideBlockDirection = -cross * 2
				local sideBlockResult = workspace:Raycast(sideBlockOrigin, sideBlockDirection, raycastParams)
				
				if not sideBlockResult then
					moveLeft()
				end
			end
		end
		
		-- Проверяем зажата ли D
		if UserInputService:IsKeyDown(Enum.KeyCode.D) and not isShimmyingRight then
			raycastParams.FilterDescendantsInstances = {character}
			-- Проверяем есть ли стена СПРАВА от игрока
			local origin = rootPart.CFrame.Position + cross * 1.5
			local direction = rootPart.CFrame.LookVector * 2
			local result = workspace:Raycast(origin, direction, raycastParams)
			
			if result then
				-- Проверяем нет ли препятствия сбоку
				local sideBlockOrigin = rootPart.CFrame.Position
				local sideBlockDirection = cross * 2
				local sideBlockResult = workspace:Raycast(sideBlockOrigin, sideBlockDirection, raycastParams)
				
				if not sideBlockResult then
					moveRight()
				end
			end
		end
	end
	
	-- Raycast forward and slightly up to find ledge
	raycastParams.FilterDescendantsInstances = {character}
	local origin = rootPart.CFrame.Position
	local direction = rootPart.CFrame.LookVector * 2 + Vector3.new(0, 1.5, 0)
	local result = workspace:Raycast(origin, direction, raycastParams)

	-- Если игрок уже висит - обновляем направление для следования за формой стены
	-- НО только если не в процессе перехода на другую стену
	if holding and gyro and not isTransitioning then
		-- Raycast вперёд чтобы найти текущую нормаль стены
		local wallCheckOrigin = rootPart.CFrame.Position
		local wallCheckDirection = rootPart.CFrame.LookVector * 3
		local wallResult = workspace:Raycast(wallCheckOrigin, wallCheckDirection, raycastParams)

		if wallResult and wallResult.Instance and CollectionService:HasTag(wallResult.Instance, "Ledge") then
			local wallPart = wallResult.Instance
			local newNormal = wallResult.Normal
			
			-- Получаем полную ориентацию стены
			local wallCFrame = wallPart.CFrame
			local wallUp = wallCFrame.UpVector
			
			-- Вычисляем горизонтальную нормаль для направления взгляда
			local horizontalNormal = Vector3.new(newNormal.X, 0, newNormal.Z)
			if horizontalNormal.Magnitude > 0.01 then
				horizontalNormal = horizontalNormal.Unit
			else
				horizontalNormal = newNormal
			end
			
			-- Cross вектор для shimmy (вдоль стены)
			local newCross = wallUp:Cross(horizontalNormal)
			if newCross.Magnitude > 0.01 then
				newCross = newCross.Unit
			else
				newCross = Vector3.new(0, 1, 0):Cross(horizontalNormal)
			end
			cross = newCross

			-- Игрок смотрит НА стену (в направлении стены, противоположно нормали)
			local playerLook = -horizontalNormal
			
			-- Вычисляем Right вектор игрока (перпендикулярно Look и Up стены)
			local playerRight = playerLook:Cross(wallUp).Unit
			
			-- Пересчитываем Up чтобы был ортогональным
			local playerUp = playerRight:Cross(playerLook).Unit
			
			-- Создаём CFrame: игрок смотрит на стену, наклонён как стена
			local targetCFrame = CFrame.fromMatrix(
				rootPart.Position,
				playerRight,   -- Right
				playerUp,      -- Up (наклон стены)
				-playerLook    -- -LookVector (CFrame использует -Z как forward)
			)
			
			gyro.CFrame = gyro.CFrame:Lerp(targetCFrame, 0.25)
			
			-- Корректируем высоту игрока постоянно на наклонной стене
			local wallTilt = math.abs(wallUp:Dot(Vector3.new(0, 1, 0)))
			if wallTilt < 0.99 then
				-- Находим верхнюю грань стены в текущей позиции
				local topCheckOrigin = rootPart.Position + Vector3.new(0, 8, 0) + rootPart.CFrame.LookVector * 2
				local topCheckDirection = Vector3.new(0, -15, 0)
				local topResult = workspace:Raycast(topCheckOrigin, topCheckDirection, raycastParams)
				
				if topResult and topResult.Instance == wallPart then
					-- Голова должна быть НИЖЕ верха стены (опускаем на 1.5 studs)
					local targetY = topResult.Position.Y - 1.5
					local currentY = rootPart.Position.Y
					local yDiff = targetY - currentY
					
					-- Корректировка высоты
					if math.abs(yDiff) > 0.05 then
						local correction = yDiff * 0.3
						if ledgeVelocity then
							local currentVel = ledgeVelocity.Velocity
							ledgeVelocity.Velocity = Vector3.new(currentVel.X, correction * 10, currentVel.Z)
						end
					end
				end
			end
		end
	end

	-- Check if we found a valid ledge
	if result and result.Instance and ledgeavailable and not holding and CollectionService:HasTag(result.Instance, "Ledge") then
		-- Блокируем захват во время отдышки
		if isBreathing then return end
		
		local part = result.Instance
		local normal = result.Normal
		-- Part must be tall enough
		if part.Size.Y >= 7 then
			local partTopY = part.Position.Y + (part.Size.Y / 2)
			local headY = head.Position.Y

			-- Head must be near the top of the part, player must be in air and falling
			if headY >= partTopY - 1 and headY <= partTopY and humanoid.FloorMaterial == Enum.Material.Air and rootPart.AssemblyLinearVelocity.Y <= 0 then

				-- Проверяем нет ли блоков над головой игрока
				local aboveCheckOrigin = head.Position
				local aboveCheckDirection = Vector3.new(0, 3, 0)  -- Проверяем 3 studs вверх
				local aboveResult = workspace:Raycast(aboveCheckOrigin, aboveCheckDirection, raycastParams)

				-- Если есть блок над головой - не цепляемся
				if aboveResult then
					return
				end

				holding = true
				ledgeavailable = false

				-- Сначала отключаем движение и останавливаем все анимации
				disableMovement()

				-- Проигрываем звук захвата
				if grabSound then
					grabSound:Play()
				end

				-- Потом запускаем нашу анимацию виса
				if holdTrack then holdTrack:Play() end

				if holding and not rootPart:FindFirstChild("Ledge") then
					-- Calculate orientation to face the wall
					local normalCFrame = part.CFrame:ToObjectSpace(CFrame.new(Vector3.zero, -normal))
					normalCFrame = normalCFrame - normalCFrame.Position
					local offsetCFrame = CFrame.new((part.CFrame:Inverse() * rootPart.CFrame).Position)
					local newCFrame = part.CFrame * offsetCFrame * normalCFrame

					-- Calculate cross vector for shimmy movement
					cross = Vector3.new(0, 1, 0):Cross(normal)

					-- Create BodyGyro to hold rotation
					gyro = Instance.new("BodyGyro")
					gyro.Name = "Ledge"
					gyro.Parent = rootPart
					gyro.MaxTorque = Vector3.new(1, 1, 1) * 200000
					gyro.CFrame = newCFrame
					gyro.P = 20000

					-- Create BodyVelocity to hold position
					ledgeVelocity = Instance.new("BodyVelocity")
					ledgeVelocity.Name = "LedgeVel"
					ledgeVelocity.Parent = rootPart
					ledgeVelocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
					ledgeVelocity.Velocity = Vector3.zero

					if leftTrack then leftTrack:Stop() end
					if rightTrack then rightTrack:Stop() end
				end
			end
		end
	end
end)

-- === CHARACTER RESPAWN ===
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	rootPart = newChar:WaitForChild("HumanoidRootPart")
	head = newChar:WaitForChild("Head")
	humanoid = newChar:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")

	holding = false
	ledgeavailable = true
	cd = false
	isTransitioning = false

	-- Сбрасываем флаги в конфигах
	LedgeGrabConfig.IsHanging = false
	LedgeGrabConfig.IsClimbingUp = false
	LedgeGrabConfig.IsShimmying = false
	LedgeGrabConfig.CanGrab = true

	cleanup()
	loadAnimations()
	
	-- Подключаем обработчик смерти для нового персонажа
	humanoid.Died:Connect(function()
		holding = false
		ledgeavailable = true
		LedgeGrabConfig.IsHanging = false
		LedgeGrabConfig.IsClimbingUp = false
		LedgeGrabConfig.IsShimmying = false
		
		-- Сбрасываем RunConfig флаги
		RunConfig.CanRun = true
		RunConfig.Running = false
		RunConfig.Sprinting = false
		RunConfig.Walking = false
		
		cleanup()
		
		-- Останавливаем все анимации ledge
		if holdTrack then holdTrack:Stop(0) end
		if climbTrack then climbTrack:Stop(0) end
		if leftTrack then leftTrack:Stop(0) end
		if rightTrack then rightTrack:Stop(0) end
		if dropTrack then dropTrack:Stop(0) end
	end)
end)

-- === ОБРАБОТКА СМЕРТИ (для первого персонажа) ===
humanoid.Died:Connect(function()
	holding = false
	ledgeavailable = true
	LedgeGrabConfig.IsHanging = false
	LedgeGrabConfig.IsClimbingUp = false
	LedgeGrabConfig.IsShimmying = false
	
	-- Сбрасываем RunConfig флаги
	RunConfig.CanRun = true
	RunConfig.Running = false
	RunConfig.Sprinting = false
	RunConfig.Walking = false
	
	cleanup()
	
	-- Останавливаем все анимации ledge
	if holdTrack then holdTrack:Stop(0) end
	if climbTrack then climbTrack:Stop(0) end
	if leftTrack then leftTrack:Stop(0) end
	if rightTrack then rightTrack:Stop(0) end
	if dropTrack then dropTrack:Stop(0) end
end)

print("--- LedgeGrabScript loaded (Tag-based) ---")
