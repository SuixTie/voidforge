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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

-- === REMOTE FUNCTIONS ===
local remoteFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
local getInventoryFunc = remoteFolder and remoteFolder:WaitForChild("GetInventory", 5)
local moveItemEvent = remoteFolder and remoteFolder:WaitForChild("MoveItem", 5)
local equipItemEvent = remoteFolder and remoteFolder:WaitForChild("EquipItem", 5)
local getEquippedFunc = remoteFolder and remoteFolder:WaitForChild("GetEquipped", 5)

-- === ЦВЕТА НЕОН-АНИМЕ ===
local COLORS = {
	Panel = Color3.fromRGB(15, 15, 35),
	PanelDark = Color3.fromRGB(10, 10, 26),
	Border = Color3.fromRGB(0, 255, 255),           -- Циан
	BorderDim = Color3.fromRGB(0, 180, 180),
	BorderDark = Color3.fromRGB(0, 100, 100),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(140, 140, 160),
	SlotBg = Color3.fromRGB(25, 25, 50),
	SlotEmpty = Color3.fromRGB(35, 35, 60),
	Highlight = Color3.fromRGB(0, 255, 255),        -- Циан
	Magenta = Color3.fromRGB(255, 0, 255),          -- Розовый
}

-- === ИНДИВИДУАЛЬНЫЕ ОРИЕНТАЦИИ ПРЕДМЕТОВ В СЛОТАХ ===
local ITEM_ORIENTATIONS = {
	-- По умолчанию: position = (0, -0.7, -0.5), rotation = (45, 0, -135)
	["Stick"] = {
		position = Vector3.new(0, -0.7, -0.5),
		rotation = Vector3.new(45, 0, -135),
	},
	["Sword"] = {
		position = Vector3.new(0, 0, 0),
		rotation = Vector3.new(0, 0, -45),
	},
	["Axe"] = {
		position = Vector3.new(0, 0, 0),
		rotation = Vector3.new(0, 90, -45),
	},
}

local DEFAULT_ITEM_ORIENTATION = {
	position = Vector3.new(0, -0.7, -0.5),
	rotation = Vector3.new(45, 0, -135),
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
local currentSelectedSlot = nil -- Выбранный слот (по клику)
local currentHoveredItemData = nil -- Данные предмета в текущем слоте
local itemDescPanel = nil -- Панель описания предмета
local inventorySlotData = {} -- Данные предметов по слотам
local equippedSlotData = {} -- Данные экипированных предметов {PRIMARY = itemData, SECONDARY = itemData}

-- Drag & Drop
local isDragging = false
local dragStartSlot = nil
local dragStartSlotIndex = nil
local dragStartEquipSlot = nil -- Для drag из слота экипировки (PRIMARY/SECONDARY)
local dragGhostFrame = nil -- Визуальный элемент перетаскиваемого предмета

-- Forward declarations
local updateInventoryDisplay
local setSlotItem
local findInventorySlot
local updateItemDescPanel
local updateEquippedDisplay
local findEquipSlot
local startDragFromEquip

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

	-- ViewportFrame для 3D модели предмета (на весь слот)
	local itemViewport = Instance.new("ViewportFrame")
	itemViewport.Name = "ItemViewport"
	itemViewport.Size = UDim2.new(1, 0, 1, 0)
	itemViewport.Position = UDim2.new(0, 0, 0, 0)
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

	-- Не меняем стиль если это выбранный слот
	if slot == currentSelectedSlot then return end

	if hovered then
		hoverSound:Play()
		slotStroke.Color = COLORS.Highlight
		slot.BackgroundTransparency = 0.1
	else
		slotStroke.Color = COLORS.BorderDim
		slot.BackgroundTransparency = 0.3
	end
end

-- === ФУНКЦИЯ ВЫБОРА СЛОТА ===
local function setSlotSelected(slot, selected)
	local slotStroke = slot:FindFirstChild("SlotStroke")
	if not slotStroke then return end

	if selected then
		slotStroke.Color = COLORS.Magenta
		slotStroke.Thickness = 2
		slot.BackgroundTransparency = 0.1
	else
		slotStroke.Color = COLORS.BorderDim
		slotStroke.Thickness = 1
		slot.BackgroundTransparency = 0.3
	end
end

-- === ФУНКЦИИ DRAG & DROP ===
local function createDragGhost(itemData)
	-- Создаём ScreenGui для ghost элемента
	local screenGui = playerGui:FindFirstChild("DragGhostGui")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "DragGhostGui"
		screenGui.DisplayOrder = 100
		screenGui.Parent = playerGui
	end

	-- Создаём frame для ghost
	local ghost = Instance.new("Frame")
	ghost.Name = "DragGhost"
	ghost.Size = UDim2.new(0, 50, 0, 50)
	ghost.BackgroundColor3 = COLORS.SlotBg
	ghost.BackgroundTransparency = 0.3
	ghost.BorderSizePixel = 0
	ghost.Parent = screenGui

	local ghostStroke = Instance.new("UIStroke")
	ghostStroke.Color = COLORS.Highlight
	ghostStroke.Thickness = 2
	ghostStroke.Parent = ghost

	-- ViewportFrame для 3D модели
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "GhostViewport"
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
	viewport.Parent = ghost

	local viewportCamera = Instance.new("Camera")
	viewportCamera.Parent = viewport
	viewport.CurrentCamera = viewportCamera

	-- Ищем модель предмета
	local modelName = itemData.modelName or itemData.itemId
	local itemModel = nil

	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if itemsFolder then
		itemModel = itemsFolder:FindFirstChild(modelName)
	end

	if not itemModel then
		itemModel = workspace:FindFirstChild(modelName)
	end

	if itemModel then
		local worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewport

		local clone = itemModel:Clone()

		-- Получаем индивидуальную ориентацию для предмета
		local orientation = ITEM_ORIENTATIONS[modelName] or DEFAULT_ITEM_ORIENTATION
		local pos = orientation.position
		local rot = orientation.rotation
		local itemCFrame = CFrame.new(pos.X, pos.Y, pos.Z) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))

		local modelCF, modelSize
		if clone:IsA("Model") then
			modelCF, modelSize = clone:GetBoundingBox()
			if clone.PrimaryPart then
				clone:PivotTo(itemCFrame)
			else
				local primaryPart = clone:FindFirstChildWhichIsA("BasePart")
				if primaryPart then
					clone.PrimaryPart = primaryPart
					clone:PivotTo(itemCFrame)
				end
			end
		else
			modelSize = clone.Size
			clone.CFrame = itemCFrame
		end

		clone.Parent = worldModel

		local maxSize = math.max(modelSize.X, modelSize.Y, modelSize.Z)
		local cameraDistance = maxSize * 1.5

		viewportCamera.CFrame = CFrame.lookAt(
			Vector3.new(cameraDistance, 0, 0),
			Vector3.new(0, 0, 0)
		)
		viewportCamera.FieldOfView = 50
	end

	-- Название предмета
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.Position = UDim2.new(0, 0, 1, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.displayName or itemData.itemId or "Item"
	nameLabel.TextColor3 = COLORS.Highlight
	nameLabel.TextSize = 10
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = ghost

	return ghost
end

local function updateDragGhostPosition()
	if dragGhostFrame then
		dragGhostFrame.Position = UDim2.new(0, mouse.X - 25, 0, mouse.Y - 25)
	end
end

local function startDrag(slot, slotIndex)
	local itemData = inventorySlotData[slotIndex]
	if not itemData then return end

	isDragging = true
	dragStartSlot = slot
	dragStartSlotIndex = slotIndex
	dragStartEquipSlot = nil -- Сбрасываем

	-- Создаём ghost
	dragGhostFrame = createDragGhost(itemData)
	updateDragGhostPosition()

	-- Делаем исходный слот полупрозрачным
	slot.BackgroundTransparency = 0.7
	local viewport = slot:FindFirstChild("ItemViewport")
	if viewport then
		viewport.ImageTransparency = 0.5
	end
end

-- Функция начала drag из слота экипировки
startDragFromEquip = function(slot, equipSlotType)
	local itemData = equippedSlotData[equipSlotType]
	if not itemData then return end

	isDragging = true
	dragStartSlot = slot
	dragStartSlotIndex = nil -- Не из инвентаря
	dragStartEquipSlot = equipSlotType

	-- Создаём ghost
	dragGhostFrame = createDragGhost(itemData)
	updateDragGhostPosition()

	-- Делаем исходный слот полупрозрачным
	slot.BackgroundTransparency = 0.7
	local viewport = slot:FindFirstChild("ItemViewport")
	if viewport then
		viewport.ImageTransparency = 0.5
	end
end

local function endDrag(targetSlot)
	if not isDragging then return end

	local targetSlotIndex = nil
	local targetEquipSlot = nil

	if targetSlot then
		local slotName = targetSlot.Name
		targetSlotIndex = tonumber(slotName:match("InventorySlot_(%d+)"))

		-- Проверяем слоты экипировки
		if slotName == "EquipSlot_PRIMARY" then
			targetEquipSlot = "PRIMARY"
		elseif slotName == "EquipSlot_SECONDARY" then
			targetEquipSlot = "SECONDARY"
		end
	end

	-- Восстанавливаем исходный слот
	if dragStartSlot then
		dragStartSlot.BackgroundTransparency = 0.3
		local viewport = dragStartSlot:FindFirstChild("ItemViewport")
		if viewport then
			viewport.ImageTransparency = 0
		end
	end

	-- Удаляем ghost
	if dragGhostFrame then
		dragGhostFrame:Destroy()
		dragGhostFrame = nil
	end

	-- Если перетаскиваем ИЗ слота экипировки В другой слот экипировки
	if dragStartEquipSlot and targetEquipSlot and dragStartEquipSlot ~= targetEquipSlot then
		local sourceData = equippedSlotData[dragStartEquipSlot]
		local targetData = equippedSlotData[targetEquipSlot]

		if sourceData then
			-- Отправляем запрос на сервер
			if equipItemEvent then
				equipItemEvent:FireServer(dragStartEquipSlot, targetEquipSlot)
			end

			-- Локально меняем местами
			equippedSlotData[dragStartEquipSlot] = targetData
			equippedSlotData[targetEquipSlot] = sourceData

			if dragStartSlot then
				setSlotItem(dragStartSlot, targetData)
			end
			if targetSlot then
				setSlotItem(targetSlot, sourceData)
			end
		end

		isDragging = false
		dragStartSlot = nil
		dragStartSlotIndex = nil
		dragStartEquipSlot = nil
		return
	end

	-- Если перетаскиваем ИЗ слота экипировки В инвентарь
	if dragStartEquipSlot and targetSlotIndex then
		local sourceData = equippedSlotData[dragStartEquipSlot]

		if sourceData then
			-- Отправляем запрос на сервер (снять экипировку)
			if equipItemEvent then
				equipItemEvent:FireServer(dragStartEquipSlot, targetSlotIndex)
			end

			-- Локально обновляем
			equippedSlotData[dragStartEquipSlot] = nil
			if dragStartSlot then
				setSlotItem(dragStartSlot, nil)
			end

			-- Показываем в слоте инвентаря
			inventorySlotData[targetSlotIndex] = sourceData
			if targetSlot then
				setSlotItem(targetSlot, sourceData)
			end
		end

		isDragging = false
		dragStartSlot = nil
		dragStartSlotIndex = nil
		dragStartEquipSlot = nil
		return
	end

	-- Если перетаскиваем в слот экипировки ИЗ инвентаря
	if targetEquipSlot and dragStartSlotIndex then
		local sourceData = inventorySlotData[dragStartSlotIndex]

		-- Проверяем что это оружие
		if sourceData and sourceData.itemType == "Weapon" then
			-- Отправляем запрос на сервер
			if equipItemEvent then
				equipItemEvent:FireServer(dragStartSlotIndex, targetEquipSlot)
			end

			-- Локально обновляем (убираем из инвентаря)
			inventorySlotData[dragStartSlotIndex] = nil
			if dragStartSlot then
				setSlotItem(dragStartSlot, nil)
			end

			-- Показываем в слоте экипировки
			equippedSlotData[targetEquipSlot] = sourceData
			if targetSlot then
				setSlotItem(targetSlot, sourceData)
			end
		end

		isDragging = false
		dragStartSlot = nil
		dragStartSlotIndex = nil
		dragStartEquipSlot = nil
		return
	end

	-- Если есть целевой слот инвентаря и он отличается от исходного (перемещение внутри инвентаря)
	if targetSlotIndex and dragStartSlotIndex and targetSlotIndex ~= dragStartSlotIndex then
		-- Глубокое копирование данных для локального обновления
		local sourceData = inventorySlotData[dragStartSlotIndex]
		local targetData = inventorySlotData[targetSlotIndex]

		local newSourceData = nil
		local newTargetData = nil

		if targetData then
			newSourceData = {
				itemId = targetData.itemId,
				count = targetData.count,
				modelName = targetData.modelName,
				displayName = targetData.displayName,
				itemType = targetData.itemType,
				description = targetData.description,
				weight = targetData.weight,
				value = targetData.value,
				damage = targetData.damage,
				defense = targetData.defense,
			}
		end

		if sourceData then
			newTargetData = {
				itemId = sourceData.itemId,
				count = sourceData.count,
				modelName = sourceData.modelName,
				displayName = sourceData.displayName,
				itemType = sourceData.itemType,
				description = sourceData.description,
				weight = sourceData.weight,
				value = sourceData.value,
				damage = sourceData.damage,
				defense = sourceData.defense,
			}
		end

		-- Обновляем локальные данные
		inventorySlotData[dragStartSlotIndex] = newSourceData
		inventorySlotData[targetSlotIndex] = newTargetData

		-- Обновляем отображение
		if dragStartSlot then
			setSlotItem(dragStartSlot, newSourceData)
		end
		if targetSlot then
			setSlotItem(targetSlot, newTargetData)
		end

		-- Обновляем панель описания для выбранного слота
		if currentSelectedSlot then
			local selectedSlotName = currentSelectedSlot.Name
			local selectedSlotIndex = tonumber(selectedSlotName:match("InventorySlot_(%d+)"))
			if selectedSlotIndex then
				updateItemDescPanel(inventorySlotData[selectedSlotIndex])
			end
		end

		-- Отправляем запрос на сервер (после локального обновления)
		if moveItemEvent then
			moveItemEvent:FireServer(dragStartSlotIndex, targetSlotIndex)
		end
	end

	isDragging = false
	dragStartSlot = nil
	dragStartSlotIndex = nil
	dragStartEquipSlot = nil
end

local function cancelDrag()
	if not isDragging then return end

	-- Восстанавливаем исходный слот
	if dragStartSlot then
		dragStartSlot.BackgroundTransparency = 0.3
		local viewport = dragStartSlot:FindFirstChild("ItemViewport")
		if viewport then
			viewport.ImageTransparency = 0
		end
	end

	-- Удаляем ghost
	if dragGhostFrame then
		dragGhostFrame:Destroy()
		dragGhostFrame = nil
	end

	isDragging = false
	dragStartSlot = nil
	dragStartSlotIndex = nil
	dragStartEquipSlot = nil
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

	-- Позиционируем перед персонажем (ближе к игроку)
	local charCF = humanoidRootPart.CFrame
	part.CFrame = charCF * CFrame.new(4, 2, -2) * CFrame.Angles(0, math.rad(-15), 0)

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
	local inventoryPanel = createPanel(mainFrame, "InventoryPanel", UDim2.new(0, 320, 0, 380), UDim2.new(0, 310, 0, 30), "INVENTORY")

	-- Сетка слотов инвентаря 6x6
	local inventoryGrid = Instance.new("Frame")
	inventoryGrid.Name = "InventoryGrid"
	inventoryGrid.Size = UDim2.new(1, -20, 1, -50)
	inventoryGrid.Position = UDim2.new(0, 10, 0, 40)
	inventoryGrid.BackgroundTransparency = 1
	inventoryGrid.Parent = inventoryPanel

	local slotSize = 45
	local slotPadding = 6
	for row = 0, 5 do
		for col = 0, 5 do
			local slotX = col * (slotSize + slotPadding)
			local slotY = row * (slotSize + slotPadding)
			createSlot(inventoryGrid, UDim2.new(0, slotSize, 0, slotSize), UDim2.new(0, slotX, 0, slotY), "InventorySlot_" .. (row * 6 + col + 1))
		end
	end

	-- === ПАНЕЛЬ ОПИСАНИЯ ПРЕДМЕТА ===
	local descPanel = createPanel(mainFrame, "ItemDescPanel", UDim2.new(0, 180, 0, 380), UDim2.new(0, 640, 0, 30), "ITEM INFO")
	itemDescPanel = descPanel

	-- Название предмета
	local itemNameLabel = Instance.new("TextLabel")
	itemNameLabel.Name = "ItemName"
	itemNameLabel.Size = UDim2.new(1, -20, 0, 24)
	itemNameLabel.Position = UDim2.new(0, 10, 0, 35)
	itemNameLabel.BackgroundTransparency = 1
	itemNameLabel.Text = ""
	itemNameLabel.TextColor3 = COLORS.Highlight
	itemNameLabel.TextSize = 14
	itemNameLabel.Font = Enum.Font.GothamBold
	itemNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemNameLabel.TextWrapped = true
	itemNameLabel.Parent = descPanel

	-- Разделитель
	local separator = Instance.new("Frame")
	separator.Name = "Separator"
	separator.Size = UDim2.new(1, -20, 0, 1)
	separator.Position = UDim2.new(0, 10, 0, 65)
	separator.BackgroundColor3 = COLORS.BorderDim
	separator.BorderSizePixel = 0
	separator.Parent = descPanel

	-- Тип предмета
	local itemTypeLabel = Instance.new("TextLabel")
	itemTypeLabel.Name = "ItemType"
	itemTypeLabel.Size = UDim2.new(1, -20, 0, 16)
	itemTypeLabel.Position = UDim2.new(0, 10, 0, 75)
	itemTypeLabel.BackgroundTransparency = 1
	itemTypeLabel.Text = ""
	itemTypeLabel.TextColor3 = COLORS.Magenta
	itemTypeLabel.TextSize = 11
	itemTypeLabel.Font = Enum.Font.Gotham
	itemTypeLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemTypeLabel.Parent = descPanel

	-- Описание предмета
	local itemDescLabel = Instance.new("TextLabel")
	itemDescLabel.Name = "ItemDesc"
	itemDescLabel.Size = UDim2.new(1, -20, 0, 120)
	itemDescLabel.Position = UDim2.new(0, 10, 0, 100)
	itemDescLabel.BackgroundTransparency = 1
	itemDescLabel.Text = ""
	itemDescLabel.TextColor3 = COLORS.TextDim
	itemDescLabel.TextSize = 11
	itemDescLabel.Font = Enum.Font.Gotham
	itemDescLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemDescLabel.TextYAlignment = Enum.TextYAlignment.Top
	itemDescLabel.TextWrapped = true
	itemDescLabel.Parent = descPanel

	-- Статы предмета
	local itemStatsLabel = Instance.new("TextLabel")
	itemStatsLabel.Name = "ItemStats"
	itemStatsLabel.Size = UDim2.new(1, -20, 0, 100)
	itemStatsLabel.Position = UDim2.new(0, 10, 0, 230)
	itemStatsLabel.BackgroundTransparency = 1
	itemStatsLabel.Text = ""
	itemStatsLabel.TextColor3 = COLORS.Text
	itemStatsLabel.TextSize = 11
	itemStatsLabel.Font = Enum.Font.Gotham
	itemStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemStatsLabel.TextYAlignment = Enum.TextYAlignment.Top
	itemStatsLabel.TextWrapped = true
	itemStatsLabel.Parent = descPanel

	-- Подсказка "Hover over item"
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.Size = UDim2.new(1, -20, 1, -70)
	hintLabel.Position = UDim2.new(0, 10, 0, 40)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "Click over an item\nto see details"
	hintLabel.TextColor3 = COLORS.TextDim
	hintLabel.TextSize = 12
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextXAlignment = Enum.TextXAlignment.Center
	hintLabel.TextYAlignment = Enum.TextYAlignment.Center
	hintLabel.Parent = descPanel

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

	-- Запрашиваем текущий инвентарь с сервера
	task.spawn(function()
		if getInventoryFunc then
			local success, slots = pcall(function()
				return getInventoryFunc:InvokeServer()
			end)
			if success and slots then
				updateInventoryDisplay(slots)
			end
		end

		-- Запрашиваем экипировку
		if getEquippedFunc then
			local success, equipped = pcall(function()
				return getEquippedFunc:InvokeServer()
			end)
			if success and equipped then
				updateEquippedDisplay(equipped)
			end
		end
	end)

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
				-- Обновляем Part (ближе к игроку)
				if inventoryPart and inventoryPart.Parent then
					local targetCF = root.CFrame * CFrame.new(4, 2, -2) * CFrame.Angles(0, math.rad(-15), 0)
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

					-- Обновляем позицию drag ghost
					if isDragging then
						updateDragGhostPosition()
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

	-- Очищаем hover и drag
	cancelDrag()
	if currentHoveredSlot then
		setSlotHovered(currentHoveredSlot, false)
		currentHoveredSlot = nil
	end
	if currentSelectedSlot then
		currentSelectedSlot = nil
	end
	allSlots = {}
	inventorySlotData = {}
	itemDescPanel = nil

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

	-- Восстанавливаем камеру - просто переключаем тип на Custom
	-- Roblox сам вернёт камеру в правильную позицию
	local camera = workspace.CurrentCamera

	if savedCameraType then
		camera.CameraType = savedCameraType
		savedCameraType = nil
	else
		camera.CameraType = Enum.CameraType.Custom
	end

	savedCameraCFrame = nil
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

	-- Клик по слоту (начало drag или выбор)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and inventoryOpen then
		if currentHoveredSlot then
			clickSound:Play()

			local slotName = currentHoveredSlot.Name
			local slotIndex = tonumber(slotName:match("InventorySlot_(%d+)"))

			-- Проверяем слоты экипировки
			local equipSlotType = nil
			if slotName == "EquipSlot_PRIMARY" then
				equipSlotType = "PRIMARY"
			elseif slotName == "EquipSlot_SECONDARY" then
				equipSlotType = "SECONDARY"
			end

			-- Если в слоте инвентаря есть предмет - начинаем drag
			if slotIndex and inventorySlotData[slotIndex] then
				startDrag(currentHoveredSlot, slotIndex)
				-- Если в слоте экипировки есть предмет - начинаем drag
			elseif equipSlotType and equippedSlotData[equipSlotType] then
				startDragFromEquip(currentHoveredSlot, equipSlotType)
			end

			-- Снимаем выделение с предыдущего слота
			if currentSelectedSlot then
				setSlotSelected(currentSelectedSlot, false)
			end

			-- Выделяем новый слот
			currentSelectedSlot = currentHoveredSlot
			setSlotSelected(currentSelectedSlot, true)

			-- Обновляем панель описания
			if slotIndex and inventorySlotData[slotIndex] then
				updateItemDescPanel(inventorySlotData[slotIndex])
			elseif equipSlotType and equippedSlotData[equipSlotType] then
				updateItemDescPanel(equippedSlotData[equipSlotType])
			else
				updateItemDescPanel(nil)
			end
		end
	end

	-- ` (Backquote) для открытия/закрытия
	if input.KeyCode == Enum.KeyCode.Backquote then
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
		cancelDrag()
		closeInventory()
	end
end)

-- Отпускание кнопки мыши (конец drag)
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and inventoryOpen and isDragging then
		endDrag(currentHoveredSlot)
	end
end)

-- === ФУНКЦИЯ ОБНОВЛЕНИЯ ПАНЕЛИ ОПИСАНИЯ ===
updateItemDescPanel = function(itemData)
	if not itemDescPanel then return end

	local itemNameLabel = itemDescPanel:FindFirstChild("ItemName")
	local itemTypeLabel = itemDescPanel:FindFirstChild("ItemType")
	local itemDescLabel = itemDescPanel:FindFirstChild("ItemDesc")
	local itemStatsLabel = itemDescPanel:FindFirstChild("ItemStats")
	local hintLabel = itemDescPanel:FindFirstChild("HintLabel")
	local separator = itemDescPanel:FindFirstChild("Separator")

	if not itemData then
		-- Показываем подсказку, скрываем остальное
		if hintLabel then hintLabel.Visible = true end
		if itemNameLabel then itemNameLabel.Text = "" end
		if itemTypeLabel then itemTypeLabel.Text = "" end
		if itemDescLabel then itemDescLabel.Text = "" end
		if itemStatsLabel then itemStatsLabel.Text = "" end
		if separator then separator.Visible = false end
		return
	end

	-- Скрываем подсказку, показываем информацию
	if hintLabel then hintLabel.Visible = false end
	if separator then separator.Visible = true end

	-- Название
	if itemNameLabel then
		itemNameLabel.Text = itemData.displayName or itemData.itemId or "Unknown Item"
	end

	-- Тип
	if itemTypeLabel then
		itemTypeLabel.Text = itemData.itemType or "Misc"
	end

	-- Описание
	if itemDescLabel then
		itemDescLabel.Text = itemData.description or "No description available."
	end

	-- Статы
	if itemStatsLabel then
		local statsText = ""
		if itemData.damage then
			statsText = statsText .. "Damage: " .. itemData.damage .. "\n"
		end
		if itemData.defense then
			statsText = statsText .. "Defense: " .. itemData.defense .. "\n"
		end
		if itemData.weight then
			statsText = statsText .. "Weight: " .. itemData.weight .. "\n"
		end
		if itemData.value then
			statsText = statsText .. "Value: " .. itemData.value .. " gold\n"
		end
		if itemData.count and itemData.count > 1 then
			statsText = statsText .. "Count: " .. itemData.count .. "\n"
		end
		itemStatsLabel.Text = statsText
	end
end

-- === ФУНКЦИЯ ОТОБРАЖЕНИЯ 3D МОДЕЛИ В СЛОТЕ ===
setSlotItem = function(slot, itemData)
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

	-- Получаем индивидуальную ориентацию для предмета
	local orientation = ITEM_ORIENTATIONS[modelName] or DEFAULT_ITEM_ORIENTATION
	local pos = orientation.position
	local rot = orientation.rotation
	local itemCFrame = CFrame.new(pos.X, pos.Y, pos.Z) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))

	-- Определяем размер модели для правильного позиционирования камеры
	local modelCF, modelSize
	if clone:IsA("Model") then
		modelCF, modelSize = clone:GetBoundingBox()
		-- Центрируем модель с индивидуальной ориентацией
		if clone.PrimaryPart then
			clone:PivotTo(itemCFrame)
		else
			local primaryPart = clone:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				clone.PrimaryPart = primaryPart
				clone:PivotTo(itemCFrame)
			end
		end
	else
		-- Если это BasePart
		modelSize = clone.Size
		clone.CFrame = itemCFrame
	end

	clone.Parent = worldModel

	-- Настраиваем камеру для бокового отображения модели
	local maxSize = math.max(modelSize.X, modelSize.Y, modelSize.Z)
	local cameraDistance = maxSize * 1.5

	if viewportCamera then
		-- Камера смотрит на модель сбоку (по оси X)
		viewportCamera.CFrame = CFrame.lookAt(
			Vector3.new(cameraDistance, 0, 0),
			Vector3.new(0, 0, 0)
		)
		viewportCamera.FieldOfView = 50
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
findInventorySlot = function(index)
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
updateInventoryDisplay = function(slots)
	if not inventoryOpen or not surfaceGui then return end

	-- Сохраняем данные слотов с числовыми ключами
	inventorySlotData = {}
	if slots then
		for slotIndex, itemData in pairs(slots) do
			local numIndex = tonumber(slotIndex)
			if numIndex and itemData then
				-- Глубокое копирование данных предмета
				inventorySlotData[numIndex] = {
					itemId = itemData.itemId,
					count = itemData.count,
					modelName = itemData.modelName,
					displayName = itemData.displayName,
					itemType = itemData.itemType,
					description = itemData.description,
					weight = itemData.weight,
					value = itemData.value,
					damage = itemData.damage,
					defense = itemData.defense,
				}
			end
		end
	end

	-- Очищаем все слоты (6x6 = 36)
	for i = 1, 36 do
		local slot = findInventorySlot(i)
		if slot then
			setSlotItem(slot, nil)
		end
	end

	-- Заполняем слоты с предметами
	for slotIndex, itemData in pairs(inventorySlotData) do
		local slot = findInventorySlot(slotIndex)
		if slot then
			setSlotItem(slot, itemData)
		end
	end

	-- Обновляем панель описания для выбранного слота
	if currentSelectedSlot then
		local selectedSlotName = currentSelectedSlot.Name
		local selectedSlotIndex = tonumber(selectedSlotName:match("InventorySlot_(%d+)"))
		if selectedSlotIndex then
			updateItemDescPanel(inventorySlotData[selectedSlotIndex])
		end
	end
end

-- === ФУНКЦИЯ ПОИСКА СЛОТА ЭКИПИРОВКИ ===
findEquipSlot = function(slotType)
	if not surfaceGui then return nil end

	local mainFrame = surfaceGui:FindFirstChild("MainFrame")
	if not mainFrame then return nil end

	local characterPanel = mainFrame:FindFirstChild("CharacterPanel")
	if not characterPanel then return nil end

	return characterPanel:FindFirstChild("EquipSlot_" .. slotType)
end

-- === ОБНОВЛЕНИЕ ЭКИПИРОВКИ ИЗ ДАННЫХ ===
updateEquippedDisplay = function(equipped)
	if not inventoryOpen or not surfaceGui then return end

	-- Сохраняем данные экипировки
	equippedSlotData = {}
	if equipped then
		for slotType, itemData in pairs(equipped) do
			if itemData then
				equippedSlotData[slotType] = {
					itemId = itemData.itemId,
					count = itemData.count,
					modelName = itemData.modelName,
					displayName = itemData.displayName,
					itemType = itemData.itemType,
					description = itemData.description,
					weight = itemData.weight,
					value = itemData.value,
					damage = itemData.damage,
					defense = itemData.defense,
				}
			end
		end
	end

	-- Очищаем слоты экипировки
	local equipSlots = {"PRIMARY", "SECONDARY"}
	for _, slotType in ipairs(equipSlots) do
		local slot = findEquipSlot(slotType)
		if slot then
			setSlotItem(slot, nil)
		end
	end

	-- Заполняем слоты экипировки
	for slotType, itemData in pairs(equippedSlotData) do
		local slot = findEquipSlot(slotType)
		if slot then
			setSlotItem(slot, itemData)
		end
	end
end

-- === СЛУШАТЕЛЬ ОБНОВЛЕНИЙ ИНВЕНТАРЯ ===
local function setupInventoryListener()
	-- Слушаем локальные обновления через BindableEvent
	local inventoryChangedEvent = player:FindFirstChild("InventoryChanged")
	if not inventoryChangedEvent then
		inventoryChangedEvent = Instance.new("BindableEvent")
		inventoryChangedEvent.Name = "InventoryChanged"
		inventoryChangedEvent.Parent = player
	end

	inventoryChangedEvent.Event:Connect(function(slots)
		updateInventoryDisplay(slots)
	end)

	-- Слушаем обновления с сервера через RemoteEvent
	local inventoryUpdateEvent = remoteFolder and remoteFolder:FindFirstChild("InventoryUpdate")
	if inventoryUpdateEvent then
		inventoryUpdateEvent.OnClientEvent:Connect(function(slots)
			updateInventoryDisplay(slots)
		end)
	end

	-- Слушаем обновления экипировки с сервера
	if equipItemEvent then
		equipItemEvent.OnClientEvent:Connect(function(equipped)
			updateEquippedDisplay(equipped)
		end)
	end
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
