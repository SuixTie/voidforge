--[[
	PlayerDataManager - Сохранение данных игрока (персонаж, спины)
	Anime Wars
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- DataStore
local playerDataStore = DataStoreService:GetDataStore("AnimeWars_PlayerData_v1")

-- === СОЗДАНИЕ REMOTE EVENTS ===
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- Remote Functions
local getPlayerDataFunc = Instance.new("RemoteFunction")
getPlayerDataFunc.Name = "GetPlayerData"
getPlayerDataFunc.Parent = remotesFolder

local saveCharacterEvent = Instance.new("RemoteEvent")
saveCharacterEvent.Name = "SaveCharacter"
saveCharacterEvent.Parent = remotesFolder

local saveSpinsEvent = Instance.new("RemoteEvent")
saveSpinsEvent.Name = "SaveSpins"
saveSpinsEvent.Parent = remotesFolder

local rollCharacterFunc = Instance.new("RemoteFunction")
rollCharacterFunc.Name = "RollCharacter"
rollCharacterFunc.Parent = remotesFolder

-- === КЭШИРОВАНИЕ ДАННЫХ ===
local playerDataCache = {}

-- === ДЕФОЛТНЫЕ ДАННЫЕ ===
local DEFAULT_DATA = {
	currentCharacter = "Sakura Haruno",
	spins = 10,
	unlockedCharacters = {"Sakura Haruno"},
}

-- === ФУНКЦИИ ===

-- Загрузка данных игрока
local function loadPlayerData(player)
	local userId = player.UserId
	local key = "Player_" .. userId
	
	local success, data = pcall(function()
		return playerDataStore:GetAsync(key)
	end)
	
	if success and data then
		-- Мержим с дефолтными данными на случай новых полей
		for k, v in pairs(DEFAULT_DATA) do
			if data[k] == nil then
				data[k] = v
			end
		end
		playerDataCache[userId] = data
		print("PlayerDataManager: Loaded data for", player.Name)
	else
		-- Новый игрок - даём дефолтные данные
		playerDataCache[userId] = {
			currentCharacter = DEFAULT_DATA.currentCharacter,
			spins = DEFAULT_DATA.spins,
			unlockedCharacters = {DEFAULT_DATA.currentCharacter},
		}
		print("PlayerDataManager: Created new data for", player.Name)
	end
	
	return playerDataCache[userId]
end

-- Сохранение данных игрока
local function savePlayerData(player)
	local userId = player.UserId
	local key = "Player_" .. userId
	local data = playerDataCache[userId]
	
	if not data then return false end
	
	local success, err = pcall(function()
		playerDataStore:SetAsync(key, data)
	end)
	
	if success then
		print("PlayerDataManager: Saved data for", player.Name)
	else
		warn("PlayerDataManager: Failed to save data for", player.Name, err)
	end
	
	return success
end

-- === REMOTE HANDLERS ===

-- Получить данные игрока
getPlayerDataFunc.OnServerInvoke = function(player)
	local data = playerDataCache[player.UserId]
	if not data then
		data = loadPlayerData(player)
	end
	return data
end

-- Сохранить текущего персонажа
saveCharacterEvent.OnServerEvent:Connect(function(player, characterName)
	local data = playerDataCache[player.UserId]
	if not data then return end
	
	-- Проверяем что персонаж разблокирован
	local isUnlocked = false
	for _, name in ipairs(data.unlockedCharacters) do
		if name == characterName then
			isUnlocked = true
			break
		end
	end
	
	if isUnlocked then
		data.currentCharacter = characterName
		savePlayerData(player)
	end
end)

-- Сохранить количество спинов
saveSpinsEvent.OnServerEvent:Connect(function(player, spins)
	local data = playerDataCache[player.UserId]
	if not data then return end
	
	-- Защита от читов - спины могут только уменьшаться (или увеличиваться через покупку)
	if spins >= 0 then
		data.spins = spins
		savePlayerData(player)
	end
end)

-- Ролл персонажа (серверная валидация)
rollCharacterFunc.OnServerInvoke = function(player)
	local data = playerDataCache[player.UserId]
	if not data then return nil end
	
	-- Проверяем есть ли спины
	if data.spins <= 0 then
		return nil
	end
	
	-- Загружаем конфиг персонажей
	local CharactersConfig = require(ReplicatedStorage:WaitForChild("CharactersConfig"))
	
	-- Роллим персонажа на сервере
	local rolledChar = CharactersConfig.Roll()
	
	-- Уменьшаем спины
	data.spins = data.spins - 1
	
	-- Добавляем персонажа в разблокированные (если ещё нет)
	local alreadyUnlocked = false
	for _, name in ipairs(data.unlockedCharacters) do
		if name == rolledChar.Name then
			alreadyUnlocked = true
			break
		end
	end
	
	if not alreadyUnlocked then
		table.insert(data.unlockedCharacters, rolledChar.Name)
	end
	
	-- Устанавливаем как текущего
	data.currentCharacter = rolledChar.Name
	
	-- Сохраняем
	savePlayerData(player)
	
	return {
		character = rolledChar,
		spins = data.spins,
	}
end

-- === СОБЫТИЯ ИГРОКОВ ===

-- RemoteEvent для синхронизации блока
local blockSyncEvent = Instance.new("RemoteEvent")
blockSyncEvent.Name = "BlockSyncEvent"
blockSyncEvent.Parent = remotesFolder

-- Обработка синхронизации блока от клиента
blockSyncEvent.OnServerEvent:Connect(function(player, isBlocking)
	local character = player.Character
	if not character then return end
	
	local blockingValue = character:FindFirstChild("IsBlocking")
	if blockingValue then
		blockingValue.Value = isBlocking
		print("PlayerDataManager: Block sync for", player.Name, "- IsBlocking:", isBlocking)
	end
end)

Players.PlayerAdded:Connect(function(player)
	loadPlayerData(player)
	
	-- Создаём IsBlocking на персонаже (для серверной проверки блока)
	player.CharacterAdded:Connect(function(character)
		local isBlockingValue = Instance.new("BoolValue")
		isBlockingValue.Name = "IsBlocking"
		isBlockingValue.Value = false
		isBlockingValue.Parent = character
		
		-- Также создаём BlockDurability
		local blockDurabilityValue = Instance.new("NumberValue")
		blockDurabilityValue.Name = "BlockDurability"
		blockDurabilityValue.Value = 100
		blockDurabilityValue.Parent = character
	end)
	
	-- Если персонаж уже есть
	if player.Character then
		local character = player.Character
		if not character:FindFirstChild("IsBlocking") then
			local isBlockingValue = Instance.new("BoolValue")
			isBlockingValue.Name = "IsBlocking"
			isBlockingValue.Value = false
			isBlockingValue.Parent = character
		end
		if not character:FindFirstChild("BlockDurability") then
			local blockDurabilityValue = Instance.new("NumberValue")
			blockDurabilityValue.Name = "BlockDurability"
			blockDurabilityValue.Value = 100
			blockDurabilityValue.Parent = character
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	playerDataCache[player.UserId] = nil
end)

-- Автосохранение каждые 5 минут
task.spawn(function()
	while true do
		task.wait(300) -- 5 минут
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayerData(player)
		end
		print("PlayerDataManager: Auto-saved all player data")
	end
end)

-- Сохранение при закрытии сервера
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

print("--- PlayerDataManager loaded ---")
