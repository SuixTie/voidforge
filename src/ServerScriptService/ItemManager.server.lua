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
	InventorySize = 48, -- 8x6 слотов
}

-- === ДАННЫЕ ПРЕДМЕТОВ ===
local ITEM_DATA = {
	["Stick"] = {
		name = "Stick",
		displayName = "Wooden Stick",
		description = "A simple wooden stick. Can be used for crafting.",
		stackable = true,
		maxStack = 10,
	},
	-- Добавляй другие предметы здесь
}

-- === ИНВЕНТАРИ ИГРОКОВ ===
local playerInventories = {} -- [player] = {slots = {}, equipped = {}}

-- === REMOTE EVENTS ===
local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "Remotes"
	remoteFolder.Parent = ReplicatedStorage
end

local pickupItemEvent = remoteFolder:FindFirstChild("PickupItem") or Instance.new("RemoteEvent")
pickupItemEvent.Name = "PickupItem"
pickupItemEvent.Parent = remoteFolder

local inventoryUpdateEvent = remoteFolder:FindFirstChild("InventoryUpdate") or Instance.new("RemoteEvent")
inventoryUpdateEvent.Name = "InventoryUpdate"
inventoryUpdateEvent.Parent = remoteFolder

local getInventoryFunc = remoteFolder:FindFirstChild("GetInventory") or Instance.new("RemoteFunction")
getInventoryFunc.Name = "GetInventory"
getInventoryFunc.Parent = remoteFolder

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
	local primaryPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
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
	local itemPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
	
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

-- Получение инвентаря по запросу
getInventoryFunc.OnServerInvoke = function(requestingPlayer)
	local inventory = playerInventories[requestingPlayer]
	if inventory then
		return inventory.slots
	end
	return {}
end

Players.PlayerAdded:Connect(function(player)
	initPlayerInventory(player)
end)

Players.PlayerRemoving:Connect(function(player)
	playerInventories[player] = nil
end)

-- Инициализируем для уже подключённых игроков
for _, player in ipairs(Players:GetPlayers()) do
	initPlayerInventory(player)
end

-- === ПОИСК ПРЕДМЕТОВ В МИРЕ ===
local function findPickupItems()
	-- Ищем по тегу
	for _, item in ipairs(CollectionService:GetTagged("PickupItem")) do
		setupPickupItem(item)
	end
	
	-- Ищем по известным именам
	for itemName, _ in pairs(ITEM_DATA) do
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") and obj.Name == itemName then
				setupPickupItem(obj)
			end
		end
	end
end

-- Слушаем добавление новых предметов
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") and ITEM_DATA[descendant.Name] then
		task.wait(0.1)
		setupPickupItem(descendant)
	end
end)

CollectionService:GetInstanceAddedSignal("PickupItem"):Connect(function(item)
	if item:IsA("Model") then
		setupPickupItem(item)
	end
end)

-- Инициализация
task.spawn(function()
	task.wait(2)
	findPickupItems()
	print("=== ItemManager: Initialized ===")
end)
