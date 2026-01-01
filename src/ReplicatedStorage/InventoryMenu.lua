--[[
	InventoryMenu - Меню инвентаря (3D Part перед игроком)
	Стиль: Cyberpunk
	Открытие на T, закрытие на T или TAB
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

-- === ЦВЕТА CYBERPUNK ===
local COLORS = {
	Panel = Color3.fromRGB(15, 5, 30),
	PanelDark = Color3.fromRGB(10, 3, 20),
	Border = Color3.fromRGB(0, 255, 255),
	BorderDim = Color3.fromRGB(0, 150, 150),
	BorderDark = Color3.fromRGB(0, 80, 80),
	Text = Color3.fromRGB(220, 240, 255),
	TextDim = Color3.fromRGB(100, 140, 160),
	SlotBg = Color3.fromRGB(20, 10, 40),
	SlotEmpty = Color3.fromRGB(30, 15, 50),
	Highlight = Color3.fromRGB(0, 255, 255),
	Magenta = Color3.fromRGB(255, 0, 128),
}

-- === ЗВУКИ ===
local hoverSound = Instance.new("Sound")
hoverSound.SoundId = "rbxassetid://6895079853"
hoverSound.Volume = 0.3
hoverSound.Parent = playerGui

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6895079853"
clickSound.Volume = 0.4
clickSound.Parent = playerGui

local openSound = Instance.new("Sound")
openSound.SoundId = "rbxassetid://70452176150315"
openSound.Volume = 0.5
openSound.Parent = playerGui

local closeSound = Instance.new("Sound")
closeSound.SoundId = "rbxassetid://8968249849"
closeSound.Volume = 0.4
closeSound.Parent = playerGui

-- === СОСТОЯНИЕ ===
local inventoryOpen = false
local inventoryPart = nil
local surfaceGui = nil
local updateConnection = nil
local savedCameraType = nil
local savedCameraCFrame = nil -- Сохраняем оригинальную позицию камеры
local fixedCameraCFrame = nil
local cameraTransitionAlpha = 0 -- Для плавного перехода камеры
local savedShiftLockState = false -- Сохраняем состояние шифтлока
local allSlots = {} -- Все слоты для hover системы
local currentHoveredSlot = nil -- Текущий слот под курсором

-- === ГЛОБАЛЬНЫЙ ФЛАГ ===
local inventoryOpenValue = player:FindFirstChild("InventoryMenuOpen")
if not inventoryOpenValue then
	inventoryOpenValue = Instance.new("BoolValue")
	inventoryOpenValue.Name = "InventoryMenuOpen"
	inventoryOpenValue.Value = false
	inventoryOpenValue.Parent = player
end



-- === ФУНКЦИЯ СОЗДАНИЯ СЛОТА ===
local function createSlot(parent, size, position, name, labelText)
	local slot = Instance.new("Frame")
	slot.Name = name or "Slot"
	slot.Size = size
	slot.Position = position
	slot.BackgroundColor3 = COLORS.SlotEmpty
	slot.BackgroundTransparency = 0.3
	slot.BorderSizePixel = 0
	slot.Parent = parent

	local slotStroke = Instance.new("UIStroke")
	slotStroke.Name = "SlotStroke"
	slotStroke.Color = COLORS.BorderDim
	slotStroke.Thickness = 1
	slotStroke.Parent = slot

	-- ViewportFrame для 3D модели предмета
	local itemViewport = Instance.new("ViewportFrame")
	itemViewport.Name = "ItemViewport"
	itemViewport.Size = UDim2.new(0.85, 0, 0.85, 0)
	itemViewport.Position = UDim2.new(0.075, 0, 0.075, 0)
	itemViewport.BackgroundTransparency = 1
	itemViewport.Parent = slot
	
	local viewportCamera = Instance.new("Camera")
	viewportCamera.Name = "ViewportCamera"
	viewportCamera.Parent = itemViewport
	itemViewport.CurrentCamera = viewportCamera

	-- Количество
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.new(0, 20, 0, 16)
	countLabel.Position = UDim2.new(1, -22, 1, -18)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = ""
	countLabel.TextColor3 = COLORS.Text
	countLabel.TextSize = 12
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 2
	countLabel.Parent = slot

	-- Подпись слота (если есть)
	if labelText then
		local slotLabel = Instance.new("TextLabel")
		slotLabel.Name = "SlotLabel"
		slotLabel.Size = UDim2.new(1, 0, 0, 14)
		slotLabel.Position = UDim2.new(0, 0, 1, 2)
		slotLabel.BackgroundTransparency = 1
		slotLabel.Text = labelText
		slotLabel.TextColor3 = COLORS.TextDim
		slotLabel.TextSize = 10
		slotLabel.Font = Enum.Font.Gotham
		slotLabel.Parent = slot
	end

	-- Сохраняем слот для hover системы
	table.insert(allSlots, slot)

	return slot
end

-- === ФУНКЦИИ HOVER ===
local function setSlotHovered(slot, hovered)
	local slotStroke = slot:FindFirstChild("SlotStroke")
	if not slotStroke then return end
	
	if hovered then
		hoverSound:Play()
		TweenService:Create(slotStroke, TweenInfo.new(0.1), {Color = COLORS.Highlight}):Play()
		TweenService:Create(slot, TweenInfo.new(0.1), {BackgroundTransparency = 0.1}):Play()
	else
		TweenService:Create(slotStroke, TweenInfo.new(0.1), {Color = COLORS.BorderDim}):Play()
		TweenService:Create(slot, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
	end
end

-- === ФУНКЦИЯ СОЗДАНИЯ ПАНЕЛИ ===
local function createPanel(parent, name, size, position, title)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = COLORS.PanelDark
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.Parent = parent

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = COLORS.BorderDim
	panelStroke.Thickness = 1
	panelStroke.Parent = panel

	-- Заголовок
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 25)
	titleLabel.Position = UDim2.new(0, 0, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = COLORS.Border
	titleLabel.TextSize = 14
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = panel

	return panel
end


-- === СОЗДАНИЕ 3D PART С ИНВЕНТАРЕМ ===
local function createInventoryPart()
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	-- Создаем Part
	local part = Instance.new("Part")
	part.Name = "InventoryPart"
	part.Size = Vector3.new(7.5, 4.5, 0.1) -- Расширен для 8x6 инвентаря
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1 -- Невидимый Part
	part.CastShadow = false
	part.Parent = workspace

	-- Позиционируем перед персонажем (ближе, выше и правее, с поворотом)
	local charCF = humanoidRootPart.CFrame
	part.CFrame = charCF * CFrame.new(5, 2, -1) * CFrame.Angles(0, math.rad(-15), 0)

	-- SurfaceGui в PlayerGui с Adornee для работы mouse events
	local gui = Instance.new("SurfaceGui")
	gui.Name = "InventorySurfaceGui"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.Adornee = part
	gui.MaxDistance = 20 -- Дистанция взаимодействия
	gui.Active = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui -- В PlayerGui для работы mouse events

	-- Главный контейнер
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundTransparency = 1
	mainFrame.Active = false -- Не блокирует клики
	mainFrame.Parent = gui

	-- === ЛЕВАЯ ПАНЕЛЬ - CHARACTER ===
	local characterPanel = createPanel(mainFrame, "CharacterPanel", UDim2.new(0, 280, 0, 380), UDim2.new(0, 20, 0, 30), "CHARACTER")

	-- Слоты экипировки
	local equipSlots = {
		{name = "HEADWEAR", x = 0.5, y = 0.08},
		{name = "BACKPACK", x = 0.15, y = 0.25},
		{name = "VEST", x = 0.85, y = 0.25},
		{name = "CLOTHES", x = 0.5, y = 0.45},
		{name = "PRIMARY", x = 0.2, y = 0.75},
		{name = "SECONDARY", x = 0.8, y = 0.75},
	}

	local equipSlotSize = 55
	for _, slotData in ipairs(equipSlots) do
		local xPos = slotData.x - (equipSlotSize / 280 / 2)
		local yPos = slotData.y
		createSlot(
			characterPanel, 
			UDim2.new(0, equipSlotSize, 0, equipSlotSize), 
			UDim2.new(xPos, 0, yPos, 0), 
			"EquipSlot_" .. slotData.name,
			slotData.name
		)
	end

	-- === ПРАВАЯ ПАНЕЛЬ - INVENTORY ===
	local inventoryPanel = createPanel(mainFrame, "InventoryPanel", UDim2.new(0, 420, 0, 380), UDim2.new(1, -440, 0, 30), "INVENTORY")

	-- Сетка слотов инвентаря 8x6
	local inventoryGrid = Instance.new("Frame")
	inventoryGrid.Name = "InventoryGrid"
	inventoryGrid.Size = UDim2.new(1, -20, 1, -50)
	inventoryGrid.Position = UDim2.new(0, 10, 0, 40)
	inventoryGrid.BackgroundTransparency = 1
	inventoryGrid.Parent = inventoryPanel

	local slotSize = 45
	local slotPadding = 6
	for row = 0, 5 do
		for col = 0, 7 do
			local slotX = col * (slotSize + slotPadding)
			local slotY = row * (slotSize + slotPadding)
			createSlot(inventoryGrid, UDim2.new(0, slotSize, 0, slotSize), UDim2.new(0, slotX, 0, slotY), "InventorySlot_" .. (row * 8 + col + 1))
		end
	end

	return part, gui
end

-- === БЛОКИРОВКА УПРАВЛЕНИЯ ===
local function blockControls()
	ContextActionService:BindAction("BlockMovement", function() return Enum.ContextActionResult.Sink end, false,
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right
	)
	-- Зум камеры разрешен
	UserInputService.MouseIconEnabled = true
end

local function unblockControls()
	ContextActionService:UnbindAction("BlockMovement")
end

-- === ОТКРЫТИЕ МЕНЮ ===
local function openInventory()
	if inventoryOpen then return end
	
	-- Проверяем, не в диалоге ли игрок
	local inDialogue = player:FindFirstChild("InDialogue")
	if inDialogue and inDialogue.Value then
		return
	end
	
	inventoryOpen = true
	inventoryOpenValue.Value = true

	-- Звук открытия
	openSound:Play()

	-- Сохраняем и отключаем шифтлок
	local shiftLockValue = player:FindFirstChild("IsShiftLocked")
	if shiftLockValue then
		savedShiftLockState = shiftLockValue.Value
		shiftLockValue.Value = false
	end

	-- Разблокируем мышь
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	local camera = workspace.CurrentCamera
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")

	-- Сохраняем тип камеры и её позицию
	savedCameraType = camera.CameraType
	savedCameraCFrame = camera.CFrame

	-- Создаем Part сначала
	inventoryPart, surfaceGui = createInventoryPart()

	-- Вычисляем позицию камеры относительно панели (по центру, под углом)
	if inventoryPart then
		local panelCF = inventoryPart.CFrame
		-- Камера по центру панели, чуть ниже и перед ней
		local cameraPos = panelCF * CFrame.new(0, -0.5, 5) -- По центру, чуть ниже
		fixedCameraCFrame = CFrame.lookAt(cameraPos.Position, panelCF.Position)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	cameraTransitionAlpha = 0 -- Начинаем плавный переход

	-- Блокируем управление
	blockControls()

	-- Обновляем позицию Part и камеры каждый кадр
	updateConnection = RunService.RenderStepped:Connect(function()
		local char = player.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				-- Обновляем Part (ближе, выше и правее, с поворотом)
				if inventoryPart and inventoryPart.Parent then
					local targetCF = root.CFrame * CFrame.new(5, 2, -1) * CFrame.Angles(0, math.rad(-15), 0)
					inventoryPart.CFrame = inventoryPart.CFrame:Lerp(targetCF, 0.15)

					-- Плавный переход камеры
					cameraTransitionAlpha = math.min(cameraTransitionAlpha + 0.02, 1) -- Медленно увеличиваем до 1

					-- Обновляем камеру относительно панели (по центру, под углом)
					local panelCF = inventoryPart.CFrame
					local cameraPos = panelCF * CFrame.new(0, -0.5, 5)
					local targetCameraCF = CFrame.lookAt(cameraPos.Position, panelCF.Position)

					local cam = workspace.CurrentCamera
					-- Используем плавный easing для перехода
					local smoothAlpha = 1 - math.pow(1 - cameraTransitionAlpha, 3) -- Ease out cubic
					cam.CFrame = cam.CFrame:Lerp(targetCameraCF, smoothAlpha * 0.15)
				end
				
				-- Проверяем hover через SurfaceGui
				if surfaceGui then
					local guiObjects = playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
					local foundSlot = nil
					
					for _, guiObj in ipairs(guiObjects) do
						-- Проверяем, является ли это слотом
						if guiObj.Parent and string.find(guiObj.Parent.Name, "Slot") then
							foundSlot = guiObj.Parent
							break
						elseif string.find(guiObj.Name, "Slot") then
							foundSlot = guiObj
							break
						end
					end
					
					-- Обновляем hover состояние
					if foundSlot ~= currentHoveredSlot then
						if currentHoveredSlot then
							setSlotHovered(currentHoveredSlot, false)
						end
						if foundSlot then
							setSlotHovered(foundSlot, true)
						end
						currentHoveredSlot = foundSlot
					end
				end
			end
		end
	end)

	-- Анимация появления (масштаб)
	if inventoryPart then
		inventoryPart.Size = Vector3.new(0.1, 0.1, 0.1)
		TweenService:Create(inventoryPart, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.new(7.5, 4.5, 0.1)
		}):Play()
	end
end

-- === ЗАКРЫТИЕ МЕНЮ ===
local function closeInventory()
	if not inventoryOpen then return end
	inventoryOpen = false
	inventoryOpenValue.Value = false

	-- Звук закрытия
	closeSound:Play()

	-- Очищаем hover
	if currentHoveredSlot then
		setSlotHovered(currentHoveredSlot, false)
		currentHoveredSlot = nil
	end
	allSlots = {}

	-- Восстанавливаем шифтлок
	local shiftLockValue = player:FindFirstChild("IsShiftLocked")
	if shiftLockValue and savedShiftLockState then
		shiftLockValue.Value = true
	end

	-- Разблокируем управление
	unblockControls()

	-- Отключаем обновление позиции
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	-- Плавно возвращаем камеру к персонажу перед переключением типа
	local camera = workspace.CurrentCamera
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	
	if hrp then
		-- Вычисляем позицию камеры за персонажем (стандартная позиция third-person)
		local targetCameraPos = hrp.CFrame * CFrame.new(0, 2, 8) -- За спиной, выше
		local targetCameraCFrame = CFrame.lookAt(targetCameraPos.Position, hrp.Position + Vector3.new(0, 1.5, 0))
		
		-- Плавная анимация возврата камеры
		local cameraTween = TweenService:Create(camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = targetCameraCFrame
		})
		cameraTween:Play()
		
		-- После анимации восстанавливаем тип камеры
		cameraTween.Completed:Connect(function()
			if savedCameraType then
				camera.CameraType = savedCameraType
				savedCameraType = nil
			end
			savedCameraCFrame = nil
		end)
	else
		-- Если нет персонажа, просто восстанавливаем тип
		if savedCameraType then
			camera.CameraType = savedCameraType
			savedCameraType = nil
		end
		savedCameraCFrame = nil
	end
	
	fixedCameraCFrame = nil

	-- Анимация исчезновения
	if inventoryPart then
		TweenService:Create(inventoryPart, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = Vector3.new(0.1, 0.1, 0.1)
		}):Play()

		task.delay(0.2, function()
			if inventoryPart then
				inventoryPart:Destroy()
				inventoryPart = nil
			end
			if surfaceGui then
				surfaceGui:Destroy()
				surfaceGui = nil
			end
		end)
	end
end

-- === TOGGLE ===
local function toggleInventory()
	if inventoryOpen then
		closeInventory()
	else
		openInventory()
	end
end

-- === ВВОД ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- Клик по слоту
	if input.UserInputType == Enum.UserInputType.MouseButton1 and inventoryOpen then
		if currentHoveredSlot then
			clickSound:Play()
			-- Здесь можно добавить логику выбора слота
		end
	end

	-- T для открытия/закрытия
	if input.KeyCode == Enum.KeyCode.T then
		-- Проверяем, не в диалоге ли игрок
		local inDialogue = player:FindFirstChild("InDialogue")
		if inDialogue and inDialogue.Value then
			return
		end
		
		-- Проверяем, не открыты ли другие меню
		local settingsOpen = player:FindFirstChild("SettingsMenuOpen")
		local shopOpen = player:FindFirstChild("ShopMenuOpen")

		if (settingsOpen and settingsOpen.Value) or (shopOpen and shopOpen.Value) then
			return
		end

		toggleInventory()
	end

	-- TAB для закрытия
	if input.KeyCode == Enum.KeyCode.Tab and inventoryOpen then
		closeInventory()
	end
end)

-- === ФУНКЦИЯ ОТОБРАЖЕНИЯ 3D МОДЕЛИ В СЛОТЕ ===
local function setSlotItem(slot, itemData)
	local viewport = slot:FindFirstChild("ItemViewport")
	if not viewport then return end
	
	local viewportCamera = viewport:FindFirstChild("ViewportCamera")
	local countLabel = slot:FindFirstChild("Count")
	
	-- Очищаем старую модель
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("Model") or child:IsA("WorldModel") or child:IsA("BasePart") then
			child:Destroy()
		end
	end
	
	-- Если нет предмета - очищаем слот
	if not itemData then
		if countLabel then
			countLabel.Text = ""
		end
		slot.BackgroundColor3 = COLORS.SlotEmpty
		return
	end
	
	-- Ищем модель предмета в workspace или ReplicatedStorage
	local modelName = itemData.modelName or itemData.itemId
	local itemModel = nil
	
	-- Сначала ищем в ReplicatedStorage/Items
	local itemsFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Items")
	if itemsFolder then
		itemModel = itemsFolder:FindFirstChild(modelName)
	end
	
	-- Если не нашли, ищем в workspace
	if not itemModel then
		itemModel = workspace:FindFirstChild(modelName)
	end
	
	if not itemModel then
		warn("InventoryMenu: Model not found:", modelName)
		return
	end
	
	-- Создаём WorldModel для viewport
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	
	-- Клонируем модель
	local clone = itemModel:Clone()
	
	-- Определяем размер модели для правильного позиционирования камеры
	local modelCF, modelSize
	if clone:IsA("Model") then
		modelCF, modelSize = clone:GetBoundingBox()
		-- Центрируем модель
		if clone.PrimaryPart then
			clone:PivotTo(CFrame.new(0, 0, 0))
		else
			local primaryPart = clone:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				clone.PrimaryPart = primaryPart
				clone:PivotTo(CFrame.new(0, 0, 0))
			end
		end
	else
		-- Если это BasePart
		modelSize = clone.Size
		clone.CFrame = CFrame.new(0, 0, 0)
	end
	
	clone.Parent = worldModel
	
	-- Настраиваем камеру чтобы модель была видна целиком
	local maxSize = math.max(modelSize.X, modelSize.Y, modelSize.Z)
	local cameraDistance = maxSize * 1.5
	
	if viewportCamera then
		viewportCamera.CFrame = CFrame.lookAt(
			Vector3.new(cameraDistance * 0.7, cameraDistance * 0.5, cameraDistance * 0.7),
			Vector3.new(0, 0, 0)
		)
	end
	
	-- Обновляем количество
	if countLabel then
		if itemData.count and itemData.count > 1 then
			countLabel.Text = tostring(itemData.count)
		else
			countLabel.Text = ""
		end
	end
	
	-- Меняем цвет слота на заполненный
	slot.BackgroundColor3 = COLORS.SlotBg
end

-- === ФУНКЦИЯ ПОИСКА СЛОТА ПО ИНДЕКСУ ===
local function findInventorySlot(index)
	if not surfaceGui then return nil end
	
	local mainFrame = surfaceGui:FindFirstChild("MainFrame")
	if not mainFrame then return nil end
	
	local inventoryPanel = mainFrame:FindFirstChild("InventoryPanel")
	if not inventoryPanel then return nil end
	
	local inventoryGrid = inventoryPanel:FindFirstChild("InventoryGrid")
	if not inventoryGrid then return nil end
	
	return inventoryGrid:FindFirstChild("InventorySlot_" .. index)
end

-- === ОБНОВЛЕНИЕ ИНВЕНТАРЯ ИЗ ДАННЫХ ===
local function updateInventoryDisplay(slots)
	if not inventoryOpen or not surfaceGui then return end
	
	-- Очищаем все слоты
	for i = 1, 48 do
		local slot = findInventorySlot(i)
		if slot then
			setSlotItem(slot, nil)
		end
	end
	
	-- Заполняем слоты с предметами
	for slotIndex, itemData in pairs(slots) do
		local slot = findInventorySlot(slotIndex)
		if slot then
			setSlotItem(slot, itemData)
		end
	end
end

-- === СЛУШАТЕЛЬ ОБНОВЛЕНИЙ ИНВЕНТАРЯ ===
local function setupInventoryListener()
	local inventoryChangedEvent = player:FindFirstChild("InventoryChanged")
	if not inventoryChangedEvent then
		inventoryChangedEvent = Instance.new("BindableEvent")
		inventoryChangedEvent.Name = "InventoryChanged"
		inventoryChangedEvent.Parent = player
	end
	
	inventoryChangedEvent.Event:Connect(function(slots)
		updateInventoryDisplay(slots)
	end)
end

-- Инициализируем слушатель
setupInventoryListener()

-- === ЭКСПОРТ ===
local InventoryMenu = {}
InventoryMenu.Open = openInventory
InventoryMenu.Close = closeInventory
InventoryMenu.Toggle = toggleInventory
InventoryMenu.UpdateDisplay = updateInventoryDisplay

print("--- InventoryMenu 3D Part loaded ---")
return InventoryMenu
