--[[
	NPCManager - Управление NPC персонажами
	Voidforge: Eclipse Legacy
	
	Особенности:
	- NPC стоит на месте с idle анимацией
	- Нельзя двигать и наносить урон
	- Неуязвимый
	
	Использование:
	- Создайте R6 модель в Workspace
	- Назовите её именем NPC (например "Ymstvennootstal")
	- Или добавьте тег "NPC"
]]

local CollectionService = game:GetService("CollectionService")

print("=== NPCManager: Script started ===")

-- === НАСТРОЙКИ ===
local CONFIG = {
	NPCNames = {"Ymstvennootstal"}, -- Имена NPC для поиска
	IdleAnimationId = "rbxassetid://82153277493530", -- Idle анимация для R6
	InteractDistance = 8, -- Дистанция для взаимодействия
}

-- === ХРАНИЛИЩЕ NPC ===
local setupNPCs = {} -- Уже настроенные NPC

-- === ФУНКЦИЯ ВОСПРОИЗВЕДЕНИЯ IDLE АНИМАЦИИ ===
local function playIdleAnimation(npc)
	local humanoid = npc:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Ждём Animator или создаём его
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Создаём и загружаем анимацию
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = CONFIG.IdleAnimationId

	local success, idleTrack = pcall(function()
		return animator:LoadAnimation(idleAnim)
	end)

	if success and idleTrack then
		idleTrack.Priority = Enum.AnimationPriority.Idle
		idleTrack.Looped = true
		idleTrack:Play()
		print("NPCManager: Idle animation started for", npc.Name)
		return idleTrack
	else
		warn("NPCManager: Failed to load idle animation for", npc.Name)
	end
end

-- === ФУНКЦИЯ НАСТРОЙКИ NPC ===
local function setupNPC(npc)
	if setupNPCs[npc] then return end -- Уже настроен

	local humanoid = npc:FindFirstChild("Humanoid")
	local rootPart = npc:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		warn("NPCManager: Invalid NPC model -", npc.Name)
		return
	end

	setupNPCs[npc] = true

	-- === ДЕЛАЕМ НЕУЯЗВИМЫМ ===
	-- Устанавливаем огромное здоровье
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge

	-- Отключаем смерть
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	-- === ДЕЛАЕМ НЕПОДВИЖНЫМ ===
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	-- Якорим HumanoidRootPart чтобы нельзя было сдвинуть
	rootPart.Anchored = true

	-- Добавляем тег для идентификации как неуязвимого NPC
	CollectionService:AddTag(npc, "InvulnerableNPC")

	-- === ЗАПУСКАЕМ IDLE АНИМАЦИЮ ===
	playIdleAnimation(npc)

	-- === ДОБАВЛЯЕМ PROXIMITYPROMPT ===
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Поговорить"
	prompt.ObjectText = npc.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = CONFIG.InteractDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = rootPart

	-- Восстанавливаем здоровье если каким-то образом получил урон
	humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth < math.huge then
			humanoid.Health = math.huge
		end
	end)

	print("NPCManager: Setup complete for", npc.Name, "(invulnerable, immovable)")
end

-- === ПОИСК И НАСТРОЙКА ВСЕХ NPC ===
local function findAndSetupNPCs()
	print("NPCManager: Searching for NPCs...")
	local foundCount = 0

	-- Ищем по именам
	for _, name in ipairs(CONFIG.NPCNames) do
		for _, npc in ipairs(workspace:GetDescendants()) do
			if npc:IsA("Model") and npc.Name == name then
				print("NPCManager: Found NPC by name:", npc.Name)
				setupNPC(npc)
				foundCount = foundCount + 1
			end
		end
	end

	-- Ищем по тегу "NPC"
	for _, npc in ipairs(CollectionService:GetTagged("NPC")) do
		if npc:IsA("Model") and not setupNPCs[npc] then
			print("NPCManager: Found NPC by tag:", npc.Name)
			setupNPC(npc)
			foundCount = foundCount + 1
		end
	end

	print("NPCManager: Total NPCs found:", foundCount)
end

-- === ИНИЦИАЛИЗАЦИЯ ===
task.spawn(function()
	print("NPCManager: Waiting for world to load...")
	task.wait(2)
	findAndSetupNPCs()
	print("=== NPCManager: Initialized ===")
end)

-- Слушаем добавление новых NPC
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") then
		for _, name in ipairs(CONFIG.NPCNames) do
			if descendant.Name == name and not setupNPCs[descendant] then
				print("NPCManager: New NPC added:", descendant.Name)
				task.wait(0.1)
				setupNPC(descendant)
			end
		end
	end
end)

-- Слушаем добавление NPC с тегом
CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(npc)
	if npc:IsA("Model") and not setupNPCs[npc] then
		task.wait(0.1)
		setupNPC(npc)
	end
end)

print("=== NPCManager: Ready ===")
