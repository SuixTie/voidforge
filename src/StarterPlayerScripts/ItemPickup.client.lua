--[[
	ItemPickup - Клиентская обработка подбора предметов
	Voidforge: Eclipse Legacy
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- === ЗВУК ПОДБОРА ===
local pickupSound = Instance.new("Sound")
pickupSound.Name = "PickupSound"
pickupSound.SoundId = "rbxassetid://9119713951" -- Звук подбора предмета
pickupSound.Volume = 0.4
pickupSound.Parent = SoundService

-- === REMOTE EVENTS ===
local remoteFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local pickupItemEvent = remoteFolder and remoteFolder:WaitForChild("PickupItem", 10)
local inventoryUpdateEvent = remoteFolder and remoteFolder:WaitForChild("InventoryUpdate", 10)

-- === ЛОКАЛЬНЫЙ ИНВЕНТАРЬ ===
local localInventory = {}

-- === ОБРАБОТКА PROXIMITYPROMPT ===
ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then return end
	if prompt.Name ~= "PickupPrompt" then return end
	
	local item = prompt.Parent and prompt.Parent.Parent
	if not item then
		item = prompt.Parent -- Если промпт на самой модели
	end
	
	if item and pickupItemEvent then
		-- Проигрываем звук
		pickupSound:Play()
		
		-- Отправляем запрос на сервер
		pickupItemEvent:FireServer(item)
	end
end)

-- === ПОЛУЧЕНИЕ ОБНОВЛЕНИЙ ИНВЕНТАРЯ ===
if inventoryUpdateEvent then
	inventoryUpdateEvent.OnClientEvent:Connect(function(slots)
		localInventory = slots
		
		-- Считаем количество предметов
		local itemCount = 0
		for _ in pairs(slots) do
			itemCount = itemCount + 1
		end
		print("ItemPickup: Inventory updated, slots with items:", itemCount)
		
		-- Отправляем событие для обновления UI инвентаря
		local inventoryChangedEvent = player:FindFirstChild("InventoryChanged")
		if not inventoryChangedEvent then
			inventoryChangedEvent = Instance.new("BindableEvent")
			inventoryChangedEvent.Name = "InventoryChanged"
			inventoryChangedEvent.Parent = player
		end
		inventoryChangedEvent:Fire(localInventory)
	end)
end

-- === ЭКСПОРТ ДЛЯ ДРУГИХ СКРИПТОВ ===
local ItemPickup = {}

function ItemPickup.GetInventory()
	return localInventory
end

function ItemPickup.GetSlot(index)
	return localInventory[index]
end

-- Сохраняем модуль в ReplicatedStorage для доступа из других скриптов
local moduleValue = player:FindFirstChild("ItemPickupModule")
if not moduleValue then
	moduleValue = Instance.new("ObjectValue")
	moduleValue.Name = "ItemPickupModule"
	moduleValue.Parent = player
end

print("ItemPickup: Initialized")

return ItemPickup
