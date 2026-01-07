--[[
	ItemManager - Управление предметами в мире
	Voidforge: Eclipse Legacy
	
	Особенности:
	- Создаёт ProximityPrompt для подбираемых предметов
	- Управляет инвентарём игроков
	- Синхронизирует данные между клиентом и сервером
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

print("=== ItemManager: Script started ===")

-- === НАСТРОЙКИ ===
local CONFIG = {
	PickupDistance = 5, -- Дистанция подбора
	InventorySize = 36, -- 6x6 слотов
}

-- === ДАННЫЕ ПРЕДМЕТОВ ===
local ITEM_DATA = {
	["Stick"] = {
		name = "Stick",
		displayName = "Wooden Stick",
		itemType = "Material",
		description = "A simple wooden stick found in the forest. Can be used for crafting basic tools and weapons.",
		stackable = true,
		maxStack = 10,
		weight = 0.5,
		value = 2,
	},
	["Sword"] = {
		name = "Sword",
		displayName = "Iron Sword",
		itemType = "Weapon",
		description = "A sturdy iron sword forged by skilled blacksmiths. Its balanced weight makes it ideal for both offense and defense.",
		stackable = false,
		maxStack = 1,
		weight = 3.5,
		value = 150,
		damage = 25,
	},
	["Axe"] = {
		name = "Axe",
		displayName = "Battle Axe",
		itemType = "Weapon",
		description = "A heavy battle axe with devastating power. Slower than a sword but deals significantly more damage per hit.",
		stackable = false,
		maxStack = 1,
		weight = 5.0,
		value = 200,
		damage = 35,
	},
}

-- === ИНВЕНТАРИ ИГРОКОВ ===
local playerInventories = {} -- [player] = {slots = {}, equipped = {}}
local playerEquipped = {} -- [player] = {PRIMARY = itemData, SECONDARY = itemData}

-- === REMOTE EVENTS ===
local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "Remotes"
	remoteFolder.Parent = ReplicatedStorage
end

local pickupItemEvent = remoteFolder:FindFirstChild("PickupItem")
if not pickupItemEvent then
	pickupItemEvent = Instance.new("RemoteEvent")
	pickupItemEvent.Name = "PickupItem"
	pickupItemEvent.Parent = remoteFolder
end

local inventoryUpdateEvent = remoteFolder:FindFirstChild("InventoryUpdate")
if not inventoryUpdateEvent then
	inventoryUpdateEvent = Instance.new("RemoteEvent")
	inventoryUpdateEvent.Name = "InventoryUpdate"
	inventoryUpdateEvent.Parent = remoteFolder
end

local moveItemEvent = remoteFolder:FindFirstChild("MoveItem")
if not moveItemEvent then
	moveItemEvent = Instance.new("RemoteEvent")
	moveItemEvent.Name = "MoveItem"
	moveItemEvent.Parent = remoteFolder
end

local equipItemEvent = remoteFolder:FindFirstChild("EquipItem")
if not equipItemEvent then
	equipItemEvent = Instance.new("RemoteEvent")
	equipItemEvent.Name = "EquipItem"
	equipItemEvent.Parent = remoteFolder
end

local getInventoryFunc = remoteFolder:FindFirstChild("GetInventory")
if not getInventoryFunc then
	getInventoryFunc = Instance.new("RemoteFunction")
	getInventoryFunc.Name = "GetInventory"
	getInventoryFunc.Parent = remoteFolder
end

local getEquippedFunc = remoteFolder:FindFirstChild("GetEquipped")
if not getEquippedFunc then
	getEquippedFunc = Instance.new("RemoteFunction")
	getEquippedFunc.Name = "GetEquipped"
	getEquippedFunc.Parent = remoteFolder
end

local getActiveWeaponFunc = remoteFolder:FindFirstChild("GetActiveWeapon")
if not getActiveWeaponFunc then
	getActiveWeaponFunc = Instance.new("RemoteFunction")
	getActiveWeaponFunc.Name = "GetActiveWeapon"
	getActiveWeaponFunc.Parent = remoteFolder
end

-- === ФУНКЦИИ ИНВЕНТАРЯ ===
local function initPlayerInventory(player)
	playerInventories[player] = {
		slots = {}, -- {[slotIndex] = {itemId = "Stick", count = 1, modelName = "Stick"}}
	}
	print("ItemManager: Initialized inventory for", player.Name)
end

local function findEmptySlot(player)
	local inventory = playerInventories[player]
	if not inventory then return nil end

	for i = 1, CONFIG.InventorySize do
		if not inventory.slots[i] then
			return i
		end
	end
	return nil -- Инвентарь полон
end

local function findStackableSlot(player, itemId)
	local inventory = playerInventories[player]
	if not inventory then return nil end

	local itemInfo = ITEM_DATA[itemId]
	if not itemInfo or not itemInfo.stackable then return nil end

	for i = 1, CONFIG.InventorySize do
		local slot = inventory.slots[i]
		if slot and slot.itemId == itemId and slot.count < itemInfo.maxStack then
			return i
		end
	end
	return nil
end

local function addItemToInventory(player, itemId, modelName)
	local inventory = playerInventories[player]
	if not inventory then return false end

	local itemInfo = ITEM_DATA[itemId]
	if not itemInfo then
		warn("ItemManager: Unknown item:", itemId)
		return false
	end

	-- Пробуем добавить в существующий стак
	local stackSlot = findStackableSlot(player, itemId)
	if stackSlot then
		inventory.slots[stackSlot].count = inventory.slots[stackSlot].count + 1
		-- Обновляем данные на случай если они изменились
		inventory.slots[stackSlot].displayName = itemInfo.displayName
		inventory.slots[stackSlot].itemType = itemInfo.itemType or "Misc"
		inventory.slots[stackSlot].description = itemInfo.description
		inventory.slots[stackSlot].weight = itemInfo.weight
		inventory.slots[stackSlot].value = itemInfo.value
		print("ItemManager: Added", itemId, "to stack in slot", stackSlot)
		return true, stackSlot
	end

	-- Ищем пустой слот
	local emptySlot = findEmptySlot(player)
	if not emptySlot then
		warn("ItemManager: Inventory full for", player.Name)
		return false
	end

	inventory.slots[emptySlot] = {
		itemId = itemId,
		count = 1,
		modelName = modelName or itemId,
		displayName = itemInfo.displayName,
		itemType = itemInfo.itemType or "Misc",
		description = itemInfo.description,
		weight = itemInfo.weight,
		value = itemInfo.value,
		damage = itemInfo.damage,
		defense = itemInfo.defense,
	}

	print("ItemManager: Added", itemId, "to slot", emptySlot)
	return true, emptySlot
end

local function sendInventoryUpdate(player)
	local inventory = playerInventories[player]
	if not inventory then return end

	inventoryUpdateEvent:FireClient(player, inventory.slots)
end

-- === НАСТРОЙКА ПРЕДМЕТОВ В МИРЕ ===
local function setupPickupItem(item)
	if item:FindFirstChild("PickupPrompt") then return end -- Уже настроен

	local itemId = item.Name
	local itemInfo = ITEM_DATA[itemId]

	if not itemInfo then
		-- Неизвестный предмет - всё равно делаем подбираемым
		itemInfo = {
			name = itemId,
			displayName = itemId,
			description = "An item.",
			stackable = true,
			maxStack = 10,
		}
		ITEM_DATA[itemId] = itemInfo
	end

	-- Находим основную часть предмета
	local primaryPart
	if item:IsA("BasePart") then
		primaryPart = item
	else
		primaryPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
	end

	if not primaryPart then
		warn("ItemManager: No BasePart found in", item.Name)
		return
	end

	-- Сохраняем копию модели в ReplicatedStorage/Items для отображения в инвентаре
	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if not itemsFolder then
		itemsFolder = Instance.new("Folder")
		itemsFolder.Name = "Items"
		itemsFolder.Parent = ReplicatedStorage
	end

	if not itemsFolder:FindFirstChild(itemId) then
		local modelCopy = item:Clone()
		-- Удаляем ProximityPrompt из копии если есть
		local promptCopy = modelCopy:FindFirstChild("PickupPrompt", true)
		if promptCopy then
			promptCopy:Destroy()
		end
		modelCopy.Parent = itemsFolder
		print("ItemManager: Saved model copy for", itemId)
	end

	-- Создаём ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = itemInfo.displayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = CONFIG.PickupDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = primaryPart

	-- Добавляем тег
	CollectionService:AddTag(item, "PickupItem")

	print("ItemManager: Setup pickup for", item.Name)
end

-- === ОБРАБОТКА ПОДБОРА ===
local function onPickupItem(player, item)
	if not item or not item.Parent then return end
	if not CollectionService:HasTag(item, "PickupItem") then return end

	-- Проверяем дистанцию
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local itemPart
	if item:IsA("BasePart") then
		itemPart = item
	else
		itemPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
	end

	if not rootPart or not itemPart then return end

	local distance = (rootPart.Position - itemPart.Position).Magnitude
	if distance > CONFIG.PickupDistance + 2 then
		warn("ItemManager: Player too far from item")
		return
	end

	-- Добавляем в инвентарь
	local success, slot = addItemToInventory(player, item.Name, item.Name)

	if success then
		-- Удаляем предмет из мира
		item:Destroy()

		-- Отправляем обновление инвентаря
		sendInventoryUpdate(player)

		print("ItemManager:", player.Name, "picked up", item.Name)
	end
end

-- === СОБЫТИЯ ===
pickupItemEvent.OnServerEvent:Connect(onPickupItem)

-- Перемещение предметов между слотами
moveItemEvent.OnServerEvent:Connect(function(player, fromSlot, toSlot)
	local inventory = playerInventories[player]
	if not inventory then return end

	-- Проверяем валидность слотов
	if fromSlot < 1 or fromSlot > CONFIG.InventorySize then return end
	if toSlot < 1 or toSlot > CONFIG.InventorySize then return end
	if fromSlot == toSlot then return end

	-- Меняем местами
	local fromData = inventory.slots[fromSlot]
	local toData = inventory.slots[toSlot]

	inventory.slots[toSlot] = fromData
	inventory.slots[fromSlot] = toData

	print("ItemManager:", player.Name, "moved item from slot", fromSlot, "to slot", toSlot)

	-- Отправляем обновление
	sendInventoryUpdate(player)
end)

-- Получение инвентаря по запросу
getInventoryFunc.OnServerInvoke = function(requestingPlayer)
	local inventory = playerInventories[requestingPlayer]
	if inventory then
		return inventory.slots
	end
	return {}
end

-- Получение экипировки по запросу
getEquippedFunc.OnServerInvoke = function(requestingPlayer)
	local equipped = playerEquipped[requestingPlayer]
	if equipped then
		return equipped
	end
	return {}
end

-- Инициализируем для уже подключённых игроков
for _, player in ipairs(Players:GetPlayers()) do
	initPlayerInventory(player)
	playerEquipped[player] = {}
end

-- === ПОИСК ПРЕДМЕТОВ В МИРЕ ===
local function findPickupItems()
	-- Ищем по тегу
	for _, item in ipairs(CollectionService:GetTagged("PickupItem")) do
		setupPickupItem(item)
	end

	-- Ищем по известным именам (Model и BasePart)
	for itemName, _ in pairs(ITEM_DATA) do
		for _, obj in ipairs(workspace:GetDescendants()) do
			if (obj:IsA("Model") or obj:IsA("BasePart")) and obj.Name == itemName then
				setupPickupItem(obj)
			end
		end
	end
end

-- Слушаем добавление новых предметов
workspace.DescendantAdded:Connect(function(descendant)
	if (descendant:IsA("Model") or descendant:IsA("BasePart")) and ITEM_DATA[descendant.Name] then
		task.wait(0.1)
		setupPickupItem(descendant)
	end
end)

CollectionService:GetInstanceAddedSignal("PickupItem"):Connect(function(item)
	if item:IsA("Model") or item:IsA("BasePart") then
		setupPickupItem(item)
	end
end)

-- Инициализация
task.spawn(function()
	task.wait(2)
	findPickupItems()
	print("=== ItemManager: Initialized ===")
end)

-- === СИСТЕМА ЭКИПИРОВКИ ===

-- Позиции крепления оружия (для R6)
local EQUIP_OFFSETS = {
	-- Активное оружие в руке
	IN_HAND = {
		part = "Right Arm",
		offset = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0),
	},
	-- Оружие на спине (PRIMARY неактивное)
	ON_BACK_PRIMARY = {
		part = "Torso",
		offset = CFrame.new(0, 0.4, 0.5) * CFrame.Angles(math.rad(-90), math.rad(225), 0),
	},
	-- Оружие на спине (SECONDARY неактивное)
	ON_BACK_SECONDARY = {
		part = "Torso",
		offset = CFrame.new(0, 0.4, 0.5) * CFrame.Angles(math.rad(-90), math.rad(225), 0),
	},
}

-- Индивидуальные смещения для конкретных предметов
local ITEM_EQUIP_OFFSETS = {
	["Sword"] = {
		IN_HAND = CFrame.new(0, -1, -1.4) * CFrame.Angles(math.rad(0), math.rad(180), math.rad(90)),
		ON_BACK_PRIMARY = CFrame.new(0, 0.4, 0.5) * CFrame.Angles(math.rad(-90), math.rad(225), 0),
		ON_BACK_SECONDARY = CFrame.new(0, 0.4, 0.5) * CFrame.Angles(math.rad(-90), math.rad(225), 0),
	},
	["Axe"] = {
		IN_HAND = CFrame.new(0, -1, -1.4) * CFrame.Angles(math.rad(0), math.rad(180), math.rad(90)),
		ON_BACK_PRIMARY = CFrame.new(0.3, 0.4, 0.5) * CFrame.Angles(math.rad(-90), math.rad(225), 0),
		ON_BACK_SECONDARY = CFrame.new(-0.3, 0.4, 0.5) * CFrame.Angles(math.rad(-90), math.rad(225), 0),
	},
}

-- Активное оружие игрока (какой слот сейчас в руке: "PRIMARY", "SECONDARY" или nil)
local playerActiveWeapon = {}

-- Получение активного оружия по запросу
getActiveWeaponFunc.OnServerInvoke = function(requestingPlayer)
	return playerActiveWeapon[requestingPlayer]
end

-- Функция крепления оружия к персонажу (с указанием позиции: IN_HAND, ON_BACK_PRIMARY, ON_BACK_SECONDARY)
local function attachWeaponToCharacter(player, itemData, positionType, weaponName)
	local character = player.Character
	if not character then return end

	local equipConfig = EQUIP_OFFSETS[positionType]
	if not equipConfig then return end

	local attachPart = character:FindFirstChild(equipConfig.part)
	if not attachPart then return end

	-- Ищем модель оружия
	local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
	if not itemsFolder then return end

	local modelName = itemData.modelName or itemData.itemId
	local itemModel = itemsFolder:FindFirstChild(modelName)
	if not itemModel then return end

	-- Удаляем старое оружие с этим именем
	local oldWeapon = character:FindFirstChild(weaponName)
	if oldWeapon then
		oldWeapon:Destroy()
	end

	-- Определяем offset - сначала проверяем индивидуальный, потом дефолтный
	local offset = equipConfig.offset
	if ITEM_EQUIP_OFFSETS[modelName] and ITEM_EQUIP_OFFSETS[modelName][positionType] then
		offset = ITEM_EQUIP_OFFSETS[modelName][positionType]
	end

	-- Клонируем и крепим
	local weaponClone = itemModel:Clone()
	weaponClone.Name = weaponName

	-- Если это BasePart
	if weaponClone:IsA("BasePart") then
		weaponClone.CanCollide = false
		weaponClone.Anchored = false
		weaponClone.Massless = true

		local weld = Instance.new("Weld")
		weld.Part0 = attachPart
		weld.Part1 = weaponClone
		weld.C0 = offset
		weld.Parent = weaponClone

		weaponClone.Parent = character
	else
		-- Если это Model
		local primaryPart = weaponClone.PrimaryPart or weaponClone:FindFirstChildWhichIsA("BasePart")
		if primaryPart then
			weaponClone.PrimaryPart = primaryPart

			for _, part in ipairs(weaponClone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.Anchored = false
					part.Massless = true
				end
			end

			local weld = Instance.new("Weld")
			weld.Part0 = attachPart
			weld.Part1 = primaryPart
			weld.C0 = offset
			weld.Parent = primaryPart

			weaponClone.Parent = character
		end
	end

	print("ItemManager: Attached", modelName, "to", positionType, "for", player.Name)
end

-- Функция снятия оружия с персонажа
local function detachWeaponFromCharacter(player, weaponName)
	local character = player.Character
	if not character then return end

	local weapon = character:FindFirstChild(weaponName)
	if weapon then
		weapon:Destroy()
		print("ItemManager: Detached", weaponName, "for", player.Name)
	end
end

-- Функция обновления позиций всего оружия на персонаже
local function updateWeaponPositions(player)
	local character = player.Character
	if not character then return end

	local equipped = playerEquipped[player]
	if not equipped then return end

	local activeSlot = playerActiveWeapon[player] -- "PRIMARY", "SECONDARY" или nil

	-- Удаляем все оружия
	detachWeaponFromCharacter(player, "Equipped_PRIMARY")
	detachWeaponFromCharacter(player, "Equipped_SECONDARY")

	-- PRIMARY оружие
	if equipped.PRIMARY then
		if activeSlot == "PRIMARY" then
			-- PRIMARY в руке
			attachWeaponToCharacter(player, equipped.PRIMARY, "IN_HAND", "Equipped_PRIMARY")
		else
			-- PRIMARY на спине
			attachWeaponToCharacter(player, equipped.PRIMARY, "ON_BACK_PRIMARY", "Equipped_PRIMARY")
		end
	end

	-- SECONDARY оружие
	if equipped.SECONDARY then
		if activeSlot == "SECONDARY" then
			-- SECONDARY в руке
			attachWeaponToCharacter(player, equipped.SECONDARY, "IN_HAND", "Equipped_SECONDARY")
		else
			-- SECONDARY на спине
			attachWeaponToCharacter(player, equipped.SECONDARY, "ON_BACK_SECONDARY", "Equipped_SECONDARY")
		end
	end
end

-- RemoteEvent для смены активного оружия
local switchWeaponEvent = remoteFolder:FindFirstChild("SwitchWeapon") or Instance.new("RemoteEvent")
switchWeaponEvent.Name = "SwitchWeapon"
switchWeaponEvent.Parent = remoteFolder

-- Обработка смены активного оружия (клавиши 1 и 2)
switchWeaponEvent.OnServerEvent:Connect(function(player, slotToActivate)
	-- slotToActivate: "PRIMARY" или "SECONDARY"
	if slotToActivate ~= "PRIMARY" and slotToActivate ~= "SECONDARY" then return end

	local equipped = playerEquipped[player]
	if not equipped then return end

	-- Проверяем есть ли оружие в этом слоте
	if not equipped[slotToActivate] then return end

	local currentActive = playerActiveWeapon[player]
	local otherSlot = (slotToActivate == "PRIMARY") and "SECONDARY" or "PRIMARY"

	-- Если это оружие уже активно - переключаемся на другое (если есть)
	if currentActive == slotToActivate then
		-- Если есть другое оружие - активируем его
		if equipped[otherSlot] then
			playerActiveWeapon[player] = otherSlot
		else
			-- Нет другого оружия - оставляем текущее в руке
			-- (не убираем на спину если это единственное оружие)
		end
	else
		-- Активируем запрошенное оружие
		playerActiveWeapon[player] = slotToActivate
	end

	-- Обновляем позиции
	updateWeaponPositions(player)

	-- Отправляем клиенту информацию об активном оружии
	switchWeaponEvent:FireClient(player, playerActiveWeapon[player])
end)

-- Обработка экипировки
equipItemEvent.OnServerEvent:Connect(function(player, fromSlot, toSlot)
	local inventory = playerInventories[player]
	if not inventory then return end

	-- Инициализируем экипировку если нужно
	if not playerEquipped[player] then
		playerEquipped[player] = {}
	end

	-- Если fromSlot - строка и toSlot - строка (между слотами экипировки)
	if type(fromSlot) == "string" and type(toSlot) == "string" then
		-- Проверяем валидность слотов экипировки
		if fromSlot ~= "PRIMARY" and fromSlot ~= "SECONDARY" then return end
		if toSlot ~= "PRIMARY" and toSlot ~= "SECONDARY" then return end
		if fromSlot == toSlot then return end

		local sourceItem = playerEquipped[player][fromSlot]
		local targetItem = playerEquipped[player][toSlot]

		if not sourceItem then return end

		-- Меняем местами
		playerEquipped[player][fromSlot] = targetItem
		playerEquipped[player][toSlot] = sourceItem

		-- Обновляем визуал на персонаже
		updateWeaponPositions(player)

		print("ItemManager:", player.Name, "swapped equip from", fromSlot, "to", toSlot)

		-- Если fromSlot - число (из инвентаря) и toSlot - строка (в экипировку)
	elseif type(fromSlot) == "number" and type(toSlot) == "string" then
		-- Проверяем валидность слота инвентаря
		if fromSlot < 1 or fromSlot > CONFIG.InventorySize then return end

		-- Проверяем валидность слота экипировки
		if toSlot ~= "PRIMARY" and toSlot ~= "SECONDARY" then return end

		local itemData = inventory.slots[fromSlot]

		-- Проверяем что это оружие
		if not itemData or itemData.itemType ~= "Weapon" then
			warn("ItemManager: Item is not a weapon")
			return
		end

		-- Если в слоте экипировки уже есть предмет - меняем местами
		local currentEquipped = playerEquipped[player][toSlot]
		if currentEquipped then
			-- Возвращаем текущий предмет в инвентарь
			inventory.slots[fromSlot] = currentEquipped
		else
			-- Просто убираем из инвентаря
			inventory.slots[fromSlot] = nil
		end

		-- Экипируем новый предмет
		playerEquipped[player][toSlot] = itemData
		
		-- При экипировке в PRIMARY - оружие берётся в руку
		-- При экипировке в SECONDARY - оружие остаётся на спине
		if toSlot == "PRIMARY" then
			playerActiveWeapon[player] = "PRIMARY"
		end
		-- Для SECONDARY не меняем activeWeapon - оружие идёт на спину
		
		updateWeaponPositions(player)

		print("ItemManager:", player.Name, "equipped item to", toSlot)

		-- Если fromSlot - строка (из экипировки) и toSlot - число (в инвентарь)
	elseif type(fromSlot) == "string" and type(toSlot) == "number" then
		-- Проверяем валидность слота экипировки
		if fromSlot ~= "PRIMARY" and fromSlot ~= "SECONDARY" then return end

		-- Проверяем валидность слота инвентаря
		if toSlot < 1 or toSlot > CONFIG.InventorySize then return end

		local equippedItem = playerEquipped[player][fromSlot]
		if not equippedItem then return end

		-- Если в целевом слоте инвентаря есть предмет - меняем местами (если это оружие)
		local targetItem = inventory.slots[toSlot]
		if targetItem then
			if targetItem.itemType == "Weapon" then
				-- Меняем местами
				inventory.slots[toSlot] = equippedItem
				playerEquipped[player][fromSlot] = targetItem
				updateWeaponPositions(player)
			else
				-- Не можем поменять - целевой предмет не оружие
				warn("ItemManager: Cannot swap - target item is not a weapon")
				return
			end
		else
			-- Просто перемещаем в пустой слот
			inventory.slots[toSlot] = equippedItem
			playerEquipped[player][fromSlot] = nil
			
			-- Если это было активное оружие - переключаемся на другое
			if playerActiveWeapon[player] == fromSlot then
				local otherSlot = (fromSlot == "PRIMARY") and "SECONDARY" or "PRIMARY"
				if playerEquipped[player][otherSlot] then
					playerActiveWeapon[player] = otherSlot
				else
					playerActiveWeapon[player] = nil
				end
			end
			updateWeaponPositions(player)
		end

		print("ItemManager:", player.Name, "unequipped item from", fromSlot, "to slot", toSlot)
	end

	-- Отправляем обновление
	sendInventoryUpdate(player)
	equipItemEvent:FireClient(player, playerEquipped[player])
	-- Также отправляем информацию об активном оружии
	switchWeaponEvent:FireClient(player, playerActiveWeapon[player])
end)

-- Обновляем инициализацию игрока
Players.PlayerAdded:Connect(function(player)
	initPlayerInventory(player)
	playerEquipped[player] = {}
	playerActiveWeapon[player] = nil

	-- При респавне восстанавливаем экипировку
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5) -- Ждём загрузки персонажа
		updateWeaponPositions(player)
		-- Отправляем клиенту информацию об экипировке и активном оружии
		equipItemEvent:FireClient(player, playerEquipped[player])
		switchWeaponEvent:FireClient(player, playerActiveWeapon[player])
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerInventories[player] = nil
	playerEquipped[player] = nil
	playerActiveWeapon[player] = nil
end)
