--[[
	CharacterPanel - Панель персонажа с 3D превью
	Voidforge: Eclipse Legacy
	
	При открытии:
	- Камера перемещается к копии модели игрока
	- HUD и компас плавно уходят за экран
	При закрытии:
	- Всё возвращается обратно
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CharacterPanel = {}
CharacterPanel.IsOpen = false

-- === НАСТРОЙКИ ===
local MODEL_POSITION = Vector3.new(9999, 100, 9999) -- Далеко от карты, но не под ней
local TWEEN_TIME = 0.5

-- === СОСТОЯНИЕ ===
local characterClone = nil
local platformPart = nil
local savedCameraType = nil
local savedCameraCFrame = nil
local savedWalkSpeed = nil
local savedJumpPower = nil
local cameraConnection = nil
local isAnimating = false

-- GUI элементы для скрытия
local hudScreenGui = nil
local compassScreenGui = nil
local hudOriginalPosition = nil
local compassOriginalPosition = nil

-- === ПОЗИЦИИ ДЛЯ СКРЫТИЯ GUI ===
local HUD_HIDDEN_POSITION = UDim2.new(0, -500, 1, -120)
local COMPASS_HIDDEN_POSITION = UDim2.new(0.5, -160, 0, -100)

-- === СОЗДАНИЕ ПЛАТФОРМЫ ===
local function createPlatform()
	if platformPart then
		platformPart:Destroy()
	end
	
	platformPart = Instance.new("Part")
	platformPart.Name = "CharacterPanelPlatform"
	platformPart.Size = Vector3.new(10, 1, 10)
	platformPart.Position = MODEL_POSITION - Vector3.new(0, 3, 0)
	platformPart.Anchored = true
	platformPart.CanCollide = false
	platformPart.Transparency = 1
	platformPart.Parent = workspace
	
	return platformPart
end

-- === СОЗДАНИЕ КОПИИ ПЕРСОНАЖА ===
local function createCharacterClone()
	if characterClone then
		characterClone:Destroy()
		characterClone = nil
	end
	
	local character = player.Character
	if not character then return nil end
	
	-- Временно включаем Archivable для клонирования
	local wasArchivable = character.Archivable
	character.Archivable = true
	
	-- Клонируем персонажа
	characterClone = character:Clone()
	
	-- Возвращаем Archivable обратно
	character.Archivable = wasArchivable
	
	if not characterClone then return nil end
	
	characterClone.Name = "CharacterPreview"
	
	-- Удаляем скрипты и ненужные объекты
	for _, child in ipairs(characterClone:GetDescendants()) do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
			child:Destroy()
		end
	end
	
	-- Отключаем физику у Humanoid
	local humanoid = characterClone:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
	end
	
	-- Делаем все части anchored
	for _, part in ipairs(characterClone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	
	-- Позиционируем модель (R6 использует Torso как PrimaryPart)
	local rootPart = characterClone:FindFirstChild("HumanoidRootPart") or characterClone:FindFirstChild("Torso")
	if rootPart then
		characterClone.PrimaryPart = rootPart
		characterClone:SetPrimaryPartCFrame(CFrame.new(MODEL_POSITION))
	end
	
	characterClone.Parent = workspace
	return characterClone
end

-- === УДАЛЕНИЕ КОПИИ ===
local function destroyCharacterClone()
	if characterClone then
		characterClone:Destroy()
		characterClone = nil
	end
	if platformPart then
		platformPart:Destroy()
		platformPart = nil
	end
end

-- === ПОЛУЧЕНИЕ GUI ЭЛЕМЕНТОВ ===
local function getGUIElements()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	
	-- PlayerHUD
	local playerHUD = playerGui:FindFirstChild("PlayerHUD")
	if playerHUD then
		hudScreenGui = playerHUD
		local hudContainer = playerHUD:FindFirstChild("HUDContainer")
		if hudContainer and not hudOriginalPosition then
			hudOriginalPosition = hudContainer.Position
		end
	end
	
	-- CompassGui3D
	local compass = playerGui:FindFirstChild("CompassGui3D")
	if compass then
		compassScreenGui = compass
		local compassFrame = compass:FindFirstChild("CompassFrame")
		if compassFrame and not compassOriginalPosition then
			compassOriginalPosition = compassFrame.Position
		end
	end
end

-- === СКРЫТИЕ GUI ===
local function hideGUI()
	getGUIElements()
	
	-- Скрываем HUD
	if hudScreenGui then
		local hudContainer = hudScreenGui:FindFirstChild("HUDContainer")
		if hudContainer then
			local tween = TweenService:Create(
				hudContainer,
				TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Position = HUD_HIDDEN_POSITION}
			)
			tween:Play()
		end
	end
	
	-- Скрываем компас
	if compassScreenGui then
		local compassFrame = compassScreenGui:FindFirstChild("CompassFrame")
		if compassFrame then
			local tween = TweenService:Create(
				compassFrame,
				TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Position = COMPASS_HIDDEN_POSITION}
			)
			tween:Play()
		end
	end
end

-- === ПОКАЗ GUI ===
local function showGUI()
	-- Показываем HUD
	if hudScreenGui and hudOriginalPosition then
		local hudContainer = hudScreenGui:FindFirstChild("HUDContainer")
		if hudContainer then
			local tween = TweenService:Create(
				hudContainer,
				TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Position = hudOriginalPosition}
			)
			tween:Play()
		end
	end
	
	-- Показываем компас
	if compassScreenGui and compassOriginalPosition then
		local compassFrame = compassScreenGui:FindFirstChild("CompassFrame")
		if compassFrame then
			local tween = TweenService:Create(
				compassFrame,
				TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Position = compassOriginalPosition}
			)
			tween:Play()
		end
	end
end

-- === БЛОКИРОВКА ДВИЖЕНИЯ ===
local function disableMovement()
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		savedWalkSpeed = humanoid.WalkSpeed
		savedJumpPower = humanoid.JumpPower
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

local function enableMovement()
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = savedWalkSpeed or 16
		humanoid.JumpPower = savedJumpPower or 50
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

-- === АНИМАЦИЯ ВРАЩЕНИЯ МОДЕЛИ ===
local rotationAngle = 0
local function startModelRotation()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	
	cameraConnection = RunService.RenderStepped:Connect(function(dt)
		if not CharacterPanel.IsOpen or not characterClone then return end
		
		-- Медленное вращение модели
		rotationAngle = rotationAngle + dt * 20 -- 20 градусов в секунду
		
		local rootPart = characterClone:FindFirstChild("HumanoidRootPart") or characterClone:FindFirstChild("Torso")
		if rootPart and characterClone.PrimaryPart then
			characterClone:SetPrimaryPartCFrame(
				CFrame.new(MODEL_POSITION) * CFrame.Angles(0, math.rad(rotationAngle), 0)
			)
		end
	end)
end

local function stopModelRotation()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
end

-- === ОТКРЫТИЕ ПАНЕЛИ ===
function CharacterPanel.Open()
	if CharacterPanel.IsOpen or isAnimating then return end
	isAnimating = true
	
	-- Создаём платформу и копию персонажа
	createPlatform()
	createCharacterClone()
	
	if not characterClone then 
		isAnimating = false
		return 
	end
	
	-- Сохраняем состояние камеры
	savedCameraType = camera.CameraType
	savedCameraCFrame = camera.CFrame
	
	-- Переключаем камеру в Scriptable
	camera.CameraType = Enum.CameraType.Scriptable
	
	-- Позиция камеры перед моделью
	local targetCFrame = CFrame.new(MODEL_POSITION + Vector3.new(0, 2, 6)) * CFrame.Angles(0, math.rad(180), 0)
	
	-- Анимируем камеру
	local cameraTween = TweenService:Create(
		camera,
		TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{CFrame = targetCFrame}
	)
	cameraTween:Play()
	
	-- Скрываем GUI
	hideGUI()
	
	-- Блокируем движение
	disableMovement()
	
	-- Запускаем вращение модели
	rotationAngle = 0
	startModelRotation()
	
	-- Создаём флаг для других скриптов
	local menuOpenFlag = player:FindFirstChild("CharacterPanelOpen")
	if not menuOpenFlag then
		menuOpenFlag = Instance.new("BoolValue")
		menuOpenFlag.Name = "CharacterPanelOpen"
		menuOpenFlag.Parent = player
	end
	menuOpenFlag.Value = true
	
	CharacterPanel.IsOpen = true
	isAnimating = false
	
	print("CharacterPanel: Opened")
end

-- === ЗАКРЫТИЕ ПАНЕЛИ ===
function CharacterPanel.Close()
	if not CharacterPanel.IsOpen or isAnimating then return end
	isAnimating = true
	
	-- Останавливаем вращение
	stopModelRotation()
	
	-- Возвращаем камеру
	if savedCameraCFrame then
		local cameraTween = TweenService:Create(
			camera,
			TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CFrame = savedCameraCFrame}
		)
		cameraTween:Play()
		cameraTween.Completed:Wait()
	end
	
	-- Восстанавливаем тип камеры
	if savedCameraType then
		camera.CameraType = savedCameraType
	end
	
	-- Показываем GUI
	showGUI()
	
	-- Разблокируем движение
	enableMovement()
	
	-- Удаляем копию персонажа и платформу
	destroyCharacterClone()
	
	-- Убираем флаг
	local menuOpenFlag = player:FindFirstChild("CharacterPanelOpen")
	if menuOpenFlag then
		menuOpenFlag.Value = false
	end
	
	CharacterPanel.IsOpen = false
	isAnimating = false
	
	print("CharacterPanel: Closed")
end

-- === ПЕРЕКЛЮЧЕНИЕ ===
function CharacterPanel.Toggle()
	if CharacterPanel.IsOpen then
		CharacterPanel.Close()
	else
		CharacterPanel.Open()
	end
end

-- === ОЧИСТКА ПРИ РЕСПАВНЕ ===
player.CharacterAdded:Connect(function()
	if CharacterPanel.IsOpen then
		CharacterPanel.Close()
	end
end)

return CharacterPanel
