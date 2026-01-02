--[[
	WeaponSwitch - Переключение активного оружия
	Клавиша 1: взять PRIMARY в руку
	Клавиша 2: взять SECONDARY в руку
	Повторное нажатие: убрать оружие на спину
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Ждём RemoteEvent
local remoteFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local switchWeaponEvent = remoteFolder and remoteFolder:WaitForChild("SwitchWeapon", 10)

if not switchWeaponEvent then
	warn("WeaponSwitch: SwitchWeapon event not found")
	return
end

-- Текущее активное оружие (синхронизируется с сервером)
local activeWeapon = nil

-- Обработка нажатий клавиш
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Проверяем не открыты ли меню
	local inventoryOpen = player:FindFirstChild("InventoryMenuOpen")
	local settingsOpen = player:FindFirstChild("SettingsMenuOpen")
	local shopOpen = player:FindFirstChild("ShopMenuOpen")
	local inDialogue = player:FindFirstChild("InDialogue")
	
	if (inventoryOpen and inventoryOpen.Value) or
	   (settingsOpen and settingsOpen.Value) or
	   (shopOpen and shopOpen.Value) or
	   (inDialogue and inDialogue.Value) then
		return
	end
	
	-- Клавиша 1 - PRIMARY
	if input.KeyCode == Enum.KeyCode.One then
		switchWeaponEvent:FireServer("PRIMARY")
	end
	
	-- Клавиша 2 - SECONDARY
	if input.KeyCode == Enum.KeyCode.Two then
		switchWeaponEvent:FireServer("SECONDARY")
	end
end)

-- Получаем обновления от сервера
switchWeaponEvent.OnClientEvent:Connect(function(newActiveWeapon)
	activeWeapon = newActiveWeapon
	print("WeaponSwitch: Active weapon is now", activeWeapon or "none")
end)

print("--- WeaponSwitch loaded ---")
