local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local RunConfig = require(game.ReplicatedStorage.RunConfig)
local LedgeGrabConfig = require(game.ReplicatedStorage.LedgeGrabConfig)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)

-- === НАСТРОЙКИ ===
local LOCK_KEY = Enum.KeyCode.LeftControl 
local DEFAULT_OFFSET = Vector3.new(1.7, 0.5, 0) 

local playerGui = player:WaitForChild("PlayerGui")

-- Ищем существующий GUI или создаём новый
local screenGui = playerGui:FindFirstChild("CustomCrosshairGui")
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CustomCrosshairGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
end

-- Ищем существующий crosshair или создаём новый
local crosshair = screenGui:FindFirstChild("Crosshair")
if not crosshair then
	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
	crosshair.Size = UDim2.new(0, 2, 0, 2)
	crosshair.Visible = false
	crosshair.Parent = screenGui

	local uicorner = Instance.new("UICorner")
	uicorner.CornerRadius = UDim.new(1, 0)
	uicorner.Parent = crosshair
end

-- === СОХРАНЕНИЕ СОСТОЯНИЯ ШИФТЛОКА В PLAYER ===
local isLockedValue = player:FindFirstChild("IsShiftLocked")
if not isLockedValue then
	isLockedValue = Instance.new("BoolValue")
	isLockedValue.Name = "IsShiftLocked"
	isLockedValue.Value = false
	isLockedValue.Parent = player
end

-- Восстанавливаем состояние из сохранённого значения
local isLocked = isLockedValue.Value

local function isFirstPerson()
	return (camera.Focus.Position - camera.CFrame.Position).Magnitude <= 1
end

-- === ПОЛУЧЕНИЕ ТРЯСКИ КАМЕРЫ ===
local function getCameraShakeOffset()
	local character = player.Character
	if not character then return Vector3.new(0, 0, 0) end
	
	local shakeValue = character:FindFirstChild("CameraShakeOffset")
	if shakeValue then
		return shakeValue.Value
	end
	return Vector3.new(0, 0, 0)
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end
	
	-- Пропускаем обработку если меню открыто или в диалоге
	local settingsOpen = player:FindFirstChild("SettingsMenuOpen")
	local inventoryOpen = player:FindFirstChild("InventoryMenuOpen")
	local inDialogue = player:FindFirstChild("InDialogue")
	if (settingsOpen and settingsOpen.Value) or (inventoryOpen and inventoryOpen.Value) or (inDialogue and inDialogue.Value) then
		-- Скрываем прицел когда меню/диалог открыт
		crosshair.Visible = false
		return
	end

	local firstPerson = isFirstPerson()

	if firstPerson then
		UserInputService.MouseIconEnabled = false
		crosshair.Visible = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		
		-- Добавляем тряску камеры в первом лице
		local shakeOffset = getCameraShakeOffset()
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(shakeOffset, 0.5)
	elseif isLocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		crosshair.Visible = true

		-- ВЫЧИСЛЯЕМ СМЕЩЕНИЕ С УЧЕТОМ ПОЛЗАНИЯ
		local currentOffset = DEFAULT_OFFSET
		if RunConfig.isProne then
			-- Если ползем, сдвигаем смещение ShiftLock вниз на 2.5 студа
			currentOffset = Vector3.new(DEFAULT_OFFSET.X, DEFAULT_OFFSET.Y - 3, DEFAULT_OFFSET.Z)
		elseif player.IsCrouching.Value then
			-- Если сидим, сдвигаем вниз на 0.5
			currentOffset = Vector3.new(DEFAULT_OFFSET.X, DEFAULT_OFFSET.Y - 0.5, DEFAULT_OFFSET.Z)
		end

		-- Добавляем тряску камеры к смещению
		local shakeOffset = getCameraShakeOffset()
		local targetOffset = currentOffset + shakeOffset

		-- Плавный переход к нужному смещению
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetOffset, 0.2)

		-- Не поворачиваем игрока если он висит на краю ИЛИ если активен lock-on
		if not LedgeGrabConfig.IsHanging and not CombatConfig.IsLockedOn then
			humanoid.AutoRotate = false
			local lookVector = camera.CFrame.LookVector
			local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
			rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.lookAt(rootPart.Position, rootPart.Position + flatLookVector), 0.2)
		elseif CombatConfig.IsLockedOn then
			-- Lock-on активен - не мешаем боевой системе поворачивать персонажа
			humanoid.AutoRotate = false
		end
	else
		-- ОБЫЧНЫЙ РЕЖИМ (НЕ ШИФТЛОК)
		humanoid.AutoRotate = true
		-- Смещение в обычном режиме управляется скриптом Bobble, здесь просто не мешаем
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		UserInputService.MouseIconEnabled = true
		crosshair.Visible = false
		
		-- Добавляем тряску камеры в обычном режиме
		local shakeOffset = getCameraShakeOffset()
		if shakeOffset.Magnitude > 0.01 then
			humanoid.CameraOffset = humanoid.CameraOffset + shakeOffset
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	-- Блокируем если меню открыто
	local settingsOpen = player:FindFirstChild("SettingsMenuOpen")
	local inventoryOpen = player:FindFirstChild("InventoryMenuOpen")
	if (settingsOpen and settingsOpen.Value) or (inventoryOpen and inventoryOpen.Value) then return end
	
	if input.KeyCode == LOCK_KEY then
		if not isFirstPerson() then
			isLocked = not isLocked
			isLockedValue.Value = isLocked  -- Сохраняем состояние
		end
	end
end)