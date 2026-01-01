--[[
	NPCInteraction - Система взаимодействия с NPC
	Voidforge: Eclipse Legacy
	
	Особенности:
	- Использует ProximityPrompt (стандартная система Roblox)
	- Запускает диалог при нажатии E
	- Cyberpunk стиль диалогового окна
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterPlayer = game:GetService("StarterPlayer")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- === ЗВУКИ ДИАЛОГА ===
local dialogueSound = Instance.new("Sound")
dialogueSound.Name = "DialogueTypeSound"
dialogueSound.SoundId = "rbxassetid://101572333845544" -- Звук печати текста
dialogueSound.Volume = 0.1
dialogueSound.PlaybackSpeed = 1.2
dialogueSound.Parent = SoundService

-- Звук наведения на кнопку
local hoverSound = Instance.new("Sound")
hoverSound.Name = "ButtonHoverSound"
hoverSound.SoundId = "rbxassetid://92876108656319" -- Мягкий hover звук
hoverSound.Volume = 0.3
hoverSound.PlaybackSpeed = 1.0
hoverSound.Parent = SoundService

-- Звук клика по кнопке
local clickSound = Instance.new("Sound")
clickSound.Name = "ButtonClickSound"
clickSound.SoundId = "rbxassetid://6895079853" -- Звук клика
clickSound.Volume = 0.4
clickSound.PlaybackSpeed = 1.0
clickSound.Parent = SoundService

-- Получаем PlayerModule для отключения управления
local PlayerModule = nil
task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts", 10)
	if playerScripts then
		local success, result = pcall(function()
			return require(playerScripts:WaitForChild("PlayerModule", 10))
		end)
		if success then
			PlayerModule = result
		end
	end
end)

-- === НАСТРОЙКИ ===
local CONFIG = {
	-- Cyberpunk цвета
	PanelColor = Color3.fromRGB(15, 5, 30),
	CyanColor = Color3.fromRGB(0, 255, 255),
	MagentaColor = Color3.fromRGB(255, 0, 128),
	TextColor = Color3.fromRGB(255, 255, 255),
}

-- === ДИАЛОГИ NPC ===
local NPC_DIALOGUES = {
	["Ymstvennootstal"] = {
		name = "The Wanderer",
		-- Альтернативное приветствие для повторного разговора
		returningGreeting = {
			text = "Ah, you've returned. The void hasn't claimed you yet... impressive. What brings you back to me?",
			responses = {
				{text = "I have more questions.", next = 16}, -- Ведёт на меню вопросов без приветствия
				{text = "Tell me about yourself again.", next = 2},
				{text = "What should I do next?", next = 15},
				{text = "Just passing by. Farewell.", next = nil},
			}
		},
		dialogues = {
			-- 1: Начало (первое приветствие)
			{
				text = "Greetings, traveler. I see you're new to these lands... The void has a way of drawing in lost souls.",
				responses = {
					{text = "Who are you?", next = 2},
					{text = "What is this place?", next = 5},
					{text = "I'm looking for something.", next = 9},
					{text = "Farewell.", next = nil},
				}
			},
			-- 2: Кто ты?
			{
				text = "They call me The Wanderer. Once, I had a name... but time has stripped it away, like flesh from bone.",
				responses = {
					{text = "Were you always a wanderer?", next = 3},
					{text = "That sounds lonely.", next = 4},
					{text = "Back.", next = 16},
				}
			},
			-- 3: Был ли ты всегда странником?
			{
				text = "No. I was a knight of the Eclipse Order. We swore to protect the realm from the encroaching darkness. But the darkness... it consumed us all.",
				responses = {
					{text = "What happened to the Order?", next = 13},
					{text = "I'm sorry.", next = 14},
				}
			},
			-- 4: Звучит одиноко
			{
				text = "Loneliness is a luxury here. The void whispers to those who listen too long. I've learned to embrace the silence.",
			},
			-- 5: Что это за место?
			{
				text = "This is Voidforge - the edge of reality itself. Here, the boundary between worlds grows thin. Legends are born here... and heroes meet their end.",
				responses = {
					{text = "Why is it called Voidforge?", next = 6},
					{text = "Is it dangerous?", next = 7},
					{text = "Back.", next = 16},
				}
			},
			-- 6: Почему Voidforge?
			{
				text = "Long ago, the ancients forged weapons of immense power here, using the raw essence of the void. Those weapons... they still exist, scattered across these lands.",
				responses = {
					{text = "Where can I find these weapons?", next = 8},
					{text = "Interesting...", next = 16},
				}
			},
			-- 7: Опасно ли здесь?
			{
				text = "Dangerous? Hah... Every shadow hides a threat. Every step could be your last. But danger is merely an opportunity to grow stronger. Remember that.",
			},
			-- 8: Где найти оружие?
			{
				text = "Seek the Shattered Sanctum to the north. But be warned - the guardians there do not take kindly to intruders. Many have tried. None have returned.",
			},
			-- 9: Я ищу кое-что
			{
				text = "Aren't we all? This place attracts seekers - of power, of truth, of redemption. What is it you seek, traveler?",
				responses = {
					{text = "Power.", next = 10},
					{text = "Answers.", next = 11},
					{text = "A way out.", next = 12},
				}
			},
			-- 10: Силу
			{
				text = "Power comes at a price here. The void grants strength to those who sacrifice. But be careful what you offer... it may take more than you're willing to give.",
			},
			-- 11: Ответы
			{
				text = "Answers are scarce in Voidforge. The truth shifts like sand. But if you seek knowledge, find the Keeper in the Ashen Library. She knows things... things best left forgotten.",
			},
			-- 12: Выход
			{
				text = "A way out? There is no escape from Voidforge, traveler. The void chose you. It brought you here for a reason. Your only path... is forward.",
			},
			-- 13: Что случилось с Орденом?
			{
				text = "The Eclipse came. A darkness so complete it swallowed the sun. We fought... but you cannot fight the night itself. I alone survived. Sometimes I wonder if that was mercy... or punishment.",
			},
			-- 14: Мне жаль
			{
				text = "Save your pity, traveler. The past is ash. Focus on surviving the present. That is all any of us can do now.",
			},
			-- 15: Что делать дальше? (для повторного разговора)
			{
				text = "The path forward is treacherous, but clear. Seek the Shattered Sanctum if you desire power. The Ashen Library if you seek knowledge. Or simply explore... Voidforge reveals its secrets to those who persist.",
			},
			-- 16: Меню вопросов (без приветствия)
			{
				text = "What would you like to know?",
				responses = {
					{text = "Who are you?", next = 2},
					{text = "What is this place?", next = 5},
					{text = "I'm looking for something.", next = 9},
					{text = "That's all. Farewell.", next = nil},
				}
			},
		}
	},
}

-- === СОСТОЯНИЕ ===
local currentNPC = nil
local isInDialogue = false
local talkedToNPCs = {} -- Запоминаем с какими NPC уже говорили
local currentDialogueIndex = 1
local isTyping = false -- Флаг анимации текста
local skipTyping = false -- Флаг для пропуска анимации

-- Сохранённые значения для восстановления
local savedWalkSpeed = 16
local savedJumpPower = 50
local savedCameraType = nil
local dialogueCameraConnection = nil

-- Настройки typewriter эффекта
local TYPEWRITER_SPEED = 0.03 -- Секунд на символ

-- === GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NPCInteractionGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- === ЦВЕТА ===
local PANEL_COLOR = Color3.fromRGB(30, 30, 35)
local PANEL_DARK = Color3.fromRGB(20, 20, 25)
local BORDER_COLOR = Color3.fromRGB(60, 60, 65)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local HINT_COLOR = Color3.fromRGB(150, 150, 150)

-- === ДИАЛОГОВОЕ ОКНО (новый стиль) ===
local dialogueFrame = Instance.new("Frame")
dialogueFrame.Name = "DialogueFrame"
dialogueFrame.Size = UDim2.new(0, 700, 0, 200)
dialogueFrame.Position = UDim2.new(0.5, -350, 1, -220)
dialogueFrame.BackgroundColor3 = PANEL_COLOR
dialogueFrame.BackgroundTransparency = 0.1
dialogueFrame.BorderSizePixel = 0
dialogueFrame.Visible = false
dialogueFrame.Parent = screenGui

local dialogueCorner = Instance.new("UICorner")
dialogueCorner.CornerRadius = UDim.new(0, 8)
dialogueCorner.Parent = dialogueFrame

local dialogueStroke = Instance.new("UIStroke")
dialogueStroke.Color = BORDER_COLOR
dialogueStroke.Thickness = 2
dialogueStroke.Parent = dialogueFrame

-- === ИМЯ NPC (сверху над всем) ===
local npcNameLabel = Instance.new("TextLabel")
npcNameLabel.Name = "NPCName"
npcNameLabel.Size = UDim2.new(1, -20, 0, 30)
npcNameLabel.Position = UDim2.new(0, 10, 0, -35)
npcNameLabel.BackgroundTransparency = 1
npcNameLabel.Text = "NPC"
npcNameLabel.TextColor3 = TEXT_COLOR
npcNameLabel.TextSize = 22
npcNameLabel.Font = Enum.Font.GothamBold
npcNameLabel.TextXAlignment = Enum.TextXAlignment.Left
npcNameLabel.Parent = dialogueFrame

-- === ПОРТРЕТ NPC (слева) ===
local portraitFrame = Instance.new("Frame")
portraitFrame.Name = "PortraitFrame"
portraitFrame.Size = UDim2.new(0, 180, 0, 180)
portraitFrame.Position = UDim2.new(0, 10, 0, 10)
portraitFrame.BackgroundColor3 = PANEL_DARK
portraitFrame.BorderSizePixel = 0
portraitFrame.Parent = dialogueFrame

local portraitCorner = Instance.new("UICorner")
portraitCorner.CornerRadius = UDim.new(0, 6)
portraitCorner.Parent = portraitFrame

local portraitStroke = Instance.new("UIStroke")
portraitStroke.Color = BORDER_COLOR
portraitStroke.Thickness = 2
portraitStroke.Parent = portraitFrame

-- ViewportFrame для 3D портрета NPC
local portraitViewport = Instance.new("ViewportFrame")
portraitViewport.Name = "PortraitViewport"
portraitViewport.Size = UDim2.new(1, 0, 1, 0)
portraitViewport.BackgroundTransparency = 1
portraitViewport.Parent = portraitFrame

local portraitCamera = Instance.new("Camera")
portraitCamera.Parent = portraitViewport
portraitViewport.CurrentCamera = portraitCamera

-- === ПАНЕЛЬ ТЕКСТА (справа) ===
local textPanel = Instance.new("Frame")
textPanel.Name = "TextPanel"
textPanel.Size = UDim2.new(0, 480, 0, 180)
textPanel.Position = UDim2.new(0, 200, 0, 10)
textPanel.BackgroundColor3 = PANEL_DARK
textPanel.BorderSizePixel = 0
textPanel.Parent = dialogueFrame

local textPanelCorner = Instance.new("UICorner")
textPanelCorner.CornerRadius = UDim.new(0, 6)
textPanelCorner.Parent = textPanel

local textPanelStroke = Instance.new("UIStroke")
textPanelStroke.Color = BORDER_COLOR
textPanelStroke.Thickness = 2
textPanelStroke.Parent = textPanel

-- Текст диалога
local dialogueText = Instance.new("TextLabel")
dialogueText.Name = "DialogueText"
dialogueText.Size = UDim2.new(1, -20, 1, -40)
dialogueText.Position = UDim2.new(0, 10, 0, 10)
dialogueText.BackgroundTransparency = 1
dialogueText.Text = ""
dialogueText.TextColor3 = TEXT_COLOR
dialogueText.TextSize = 18
dialogueText.Font = Enum.Font.Gotham
dialogueText.TextXAlignment = Enum.TextXAlignment.Left
dialogueText.TextYAlignment = Enum.TextYAlignment.Top
dialogueText.TextWrapped = true
dialogueText.RichText = true
dialogueText.Parent = textPanel

-- Подсказка "Click to continue"
local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.new(1, -20, 0, 20)
hintLabel.Position = UDim2.new(0, 10, 1, -25)
hintLabel.BackgroundTransparency = 1
hintLabel.Text = "Click to continue"
hintLabel.TextColor3 = HINT_COLOR
hintLabel.TextSize = 14
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextXAlignment = Enum.TextXAlignment.Right
hintLabel.Parent = textPanel

-- Контейнер для ответов (появляется когда есть выбор)
local responsesFrame = Instance.new("Frame")
responsesFrame.Name = "Responses"
responsesFrame.Size = UDim2.new(1, -16, 0, 100)
responsesFrame.Position = UDim2.new(0, 8, 0, 75)
responsesFrame.BackgroundTransparency = 1
responsesFrame.Visible = false
responsesFrame.ClipsDescendants = true -- Обрезаем контент который выходит за рамки
responsesFrame.Parent = textPanel

local responsesLayout = Instance.new("UIListLayout")
responsesLayout.SortOrder = Enum.SortOrder.LayoutOrder
responsesLayout.Padding = UDim.new(0, 3)
responsesLayout.Parent = responsesFrame

-- === БЛОКИРОВКА ДВИЖЕНИЯ ===
local movementConnection = nil

local function lockPlayerMovement()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	-- Создаём значение для других скриптов СРАЗУ (до всех остальных действий)
	local dialogueValue = player:FindFirstChild("InDialogue")
	if not dialogueValue then
		dialogueValue = Instance.new("BoolValue")
		dialogueValue.Name = "InDialogue"
		dialogueValue.Parent = player
	end
	dialogueValue.Value = true

	-- Якорим персонажа СРАЗУ чтобы остановить движение
	if rootPart then
		rootPart.Anchored = true
	end

	if humanoid then
		-- Сохраняем текущие значения
		savedWalkSpeed = humanoid.WalkSpeed
		savedJumpPower = humanoid.JumpPower

		-- Блокируем движение
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0

		-- Останавливаем ВСЕ анимации движения на Animator
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0.1)
			end
		end

		-- Отключаем состояния движения
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
	end

	-- Отключаем управление через PlayerModule
	if PlayerModule then
		local controls = PlayerModule:GetControls()
		if controls then
			controls:Disable()
		end
	end

	-- Постоянно сбрасываем скорость (на случай если другие скрипты её меняют)
	movementConnection = RunService.Heartbeat:Connect(function()
		if humanoid and isInDialogue then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		end
	end)
end

local function unlockPlayerMovement()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	-- Отключаем постоянное обновление
	if movementConnection then
		movementConnection:Disconnect()
		movementConnection = nil
	end

	-- Разякориваем персонажа
	if rootPart then
		rootPart.Anchored = false
	end

	-- Включаем управление через PlayerModule
	if PlayerModule then
		local controls = PlayerModule:GetControls()
		if controls then
			controls:Enable()
		end
	end

	if humanoid then
		-- Восстанавливаем состояния движения
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)

		-- Восстанавливаем движение
		humanoid.WalkSpeed = savedWalkSpeed
		humanoid.JumpPower = savedJumpPower
		humanoid.JumpHeight = 7.2
	end

	-- Убираем значение диалога
	local dialogueValue = player:FindFirstChild("InDialogue")
	if dialogueValue then
		dialogueValue.Value = false
	end
end

-- === КАМЕРА ДИАЛОГА ===
local camera = workspace.CurrentCamera

local function setupDialogueCamera(npc)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local npcRoot = npc:FindFirstChild("HumanoidRootPart")
	if not rootPart or not npcRoot then return end

	-- Сохраняем тип камеры
	savedCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	-- Поворачиваем игрока к NPC
	local directionToNPC = (npcRoot.Position - rootPart.Position)
	directionToNPC = Vector3.new(directionToNPC.X, 0, directionToNPC.Z).Unit
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + directionToNPC)

	-- Позиция камеры: справа за спиной игрока, смотрит на NPC
	local npcLookPoint = npcRoot.Position + Vector3.new(0, 2, 0) -- Смотрим на NPC (на уровне головы)
	local rightOffset = rootPart.CFrame.RightVector * 4 -- Правее
	local backOffset = -directionToNPC * 1 -- Ближе к игроку
	local cameraPosition = rootPart.Position + rightOffset + backOffset + Vector3.new(0, 2, 0)

	-- Плавно перемещаем камеру
	local targetCFrame = CFrame.lookAt(cameraPosition, npcLookPoint)

	-- Анимация камеры
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {CFrame = targetCFrame})
	tween:Play()

	-- Поддерживаем позицию камеры
	dialogueCameraConnection = RunService.RenderStepped:Connect(function()
		if not isInDialogue then return end
		-- Камера остаётся на месте (уже установлена твином)
	end)
end

local function restoreCamera()
	-- Отключаем обновление камеры диалога
	if dialogueCameraConnection then
		dialogueCameraConnection:Disconnect()
		dialogueCameraConnection = nil
	end

	-- Восстанавливаем тип камеры
	if savedCameraType then
		camera.CameraType = savedCameraType
		savedCameraType = nil
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- === ФУНКЦИИ ===
local function clearResponses()
	for _, child in ipairs(responsesFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function createResponseButton(index, text, nextDialogue)
	local button = Instance.new("TextButton")
	button.Name = "Response" .. index
	button.Size = UDim2.new(1, 0, 0, 22)
	button.BackgroundColor3 = PANEL_COLOR
	button.BackgroundTransparency = 0.3
	button.Text = index .. ". " .. text
	button.TextColor3 = TEXT_COLOR
	button.TextSize = 13
	button.Font = Enum.Font.Gotham
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.AutoButtonColor = false
	button.LayoutOrder = index
	button.Parent = responsesFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 4)
	btnCorner.Parent = button

	local btnPadding = Instance.new("UIPadding")
	btnPadding.PaddingLeft = UDim.new(0, 10)
	btnPadding.Parent = button

	-- Hover эффект
	button.MouseEnter:Connect(function()
		hoverSound:Play()
		TweenService:Create(button, TweenInfo.new(0.1), {
			BackgroundTransparency = 0
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {
			BackgroundTransparency = 0.3
		}):Play()
	end)

	-- Клик
	button.MouseButton1Click:Connect(function()
		clickSound:Play()
		if nextDialogue then
			showDialogue(nextDialogue)
		else
			closeDialogue()
		end
	end)

	return button
end

-- === ФУНКЦИЯ СОЗДАНИЯ 3D ПОРТРЕТА ===
local IDLE_ANIMATION_ID = "rbxassetid://82153277493530" -- Та же анимация что в NPCManager

local function setupNPCPortrait(npc)
	-- Очищаем старый портрет
	for _, child in ipairs(portraitViewport:GetChildren()) do
		if child:IsA("Model") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end

	-- Создаём WorldModel для портрета
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = portraitViewport

	-- Клонируем NPC для портрета
	local npcClone = npc:Clone()

	-- Устанавливаем PrimaryPart если нет
	if not npcClone.PrimaryPart then
		local root = npcClone:FindFirstChild("HumanoidRootPart")
		if root then
			npcClone.PrimaryPart = root
		end
	end

	-- Перемещаем модель в центр, лицом к камере
	npcClone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0))

	npcClone.Parent = worldModel

	-- Настраиваем Humanoid
	local cloneHumanoid = npcClone:FindFirstChild("Humanoid")
	if cloneHumanoid then
		cloneHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		-- Создаём Animator если нет
		local animator = cloneHumanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = cloneHumanoid
		end

		-- Получаем текущую позицию анимации у оригинального NPC
		local originalHumanoid = npc:FindFirstChild("Humanoid")
		local originalAnimator = originalHumanoid and originalHumanoid:FindFirstChildOfClass("Animator")
		local originalTimePosition = 0

		if originalAnimator then
			local playingTracks = originalAnimator:GetPlayingAnimationTracks()
			for _, track in ipairs(playingTracks) do
				if track.Animation and track.Animation.AnimationId == IDLE_ANIMATION_ID then
					originalTimePosition = track.TimePosition
					break
				end
			end
		end

		-- Загружаем и запускаем Idle анимацию с той же позиции
		local idleAnim = Instance.new("Animation")
		idleAnim.AnimationId = IDLE_ANIMATION_ID

		local success, idleTrack = pcall(function()
			return animator:LoadAnimation(idleAnim)
		end)

		if success and idleTrack then
			idleTrack.Priority = Enum.AnimationPriority.Idle
			idleTrack.Looped = true
			idleTrack:Play()
			idleTrack.TimePosition = originalTimePosition -- Синхронизируем позицию
		end
	end

	-- Якорим только HumanoidRootPart (чтобы анимация работала, но модель не падала)
	local cloneRoot = npcClone:FindFirstChild("HumanoidRootPart")
	if cloneRoot then
		cloneRoot.Anchored = true
	end

	-- Камера смотрит на лицо NPC
	portraitCamera.CFrame = CFrame.lookAt(
		Vector3.new(0, 1.5, 3),   -- Позиция камеры (перед NPC)
		Vector3.new(0, 1.3, 0)    -- Смотрим на голову
	)
end

-- === ФУНКЦИЯ TYPEWRITER ЭФФЕКТА ===
local function typewriterEffect(text, onComplete)
	isTyping = true
	skipTyping = false
	dialogueText.Text = ""

	-- Скрываем ответы и подсказку пока печатается текст
	responsesFrame.Visible = false
	hintLabel.Visible = false

	local fullText = text
	local currentText = ""
	local soundCounter = 0

	task.spawn(function()
		for i = 1, #fullText do
			if not isInDialogue then break end

			-- Проверяем пропуск
			if skipTyping then
				dialogueText.Text = fullText
				break
			end

			currentText = string.sub(fullText, 1, i)
			dialogueText.Text = currentText

			-- Воспроизводим звук каждые 2-3 символа (не на каждый, чтобы не было слишком много)
			local char = string.sub(fullText, i, i)
			if char ~= " " and char ~= "." and char ~= "," and char ~= "!" and char ~= "?" then
				soundCounter = soundCounter + 1
				if soundCounter % 2 == 0 then
					dialogueSound.PlaybackSpeed = 1.0 + math.random() * 0.4 -- Небольшая вариация
					dialogueSound:Play()
				end
			end

			-- Пауза между символами (дольше для знаков препинания)
			if char == "." or char == "!" or char == "?" then
				task.wait(TYPEWRITER_SPEED * 5)
			elseif char == "," or char == ";" or char == ":" then
				task.wait(TYPEWRITER_SPEED * 3)
			elseif char == "-" then
				task.wait(TYPEWRITER_SPEED * 2)
			else
				task.wait(TYPEWRITER_SPEED)
			end
		end

		isTyping = false
		skipTyping = false

		-- Вызываем callback после завершения
		if onComplete and isInDialogue then
			onComplete()
		end
	end)
end

function showDialogue(dialogueIndex)
	if not currentNPC then return end

	local npcData = NPC_DIALOGUES[currentNPC.Name]
	if not npcData then return end

	local dialogue = npcData.dialogues[dialogueIndex]
	if not dialogue then return end

	currentDialogueIndex = dialogueIndex

	-- Обновляем имя NPC
	npcNameLabel.Text = npcData.name

	-- Очищаем старые ответы
	clearResponses()

	-- Проверяем есть ли ответы (конец ветки или нет)
	local hasResponses = dialogue.responses and #dialogue.responses > 0

	-- Настраиваем размер текста в зависимости от наличия ответов
	if hasResponses then
		dialogueText.Size = UDim2.new(1, -16, 0, 68) -- Больше места для текста
	else
		dialogueText.Size = UDim2.new(1, -16, 1, -30)
	end

	-- Запускаем typewriter эффект
	typewriterEffect(dialogue.text, function()
		-- После завершения анимации
		if hasResponses then
			-- Есть варианты - показываем кнопки
			responsesFrame.Visible = true
			hintLabel.Visible = false

			for i, response in ipairs(dialogue.responses) do
				createResponseButton(i, response.text, response.next)
			end
		else
			-- Нет вариантов - это конец ветки, показываем подсказку для закрытия
			responsesFrame.Visible = false
			hintLabel.Visible = true
		end
	end)
end

-- === ФУНКЦИЯ ПОКАЗА АЛЬТЕРНАТИВНОГО ПРИВЕТСТВИЯ ===
function showReturningGreeting(npcName)
	local npcData = NPC_DIALOGUES[npcName]
	if not npcData or not npcData.returningGreeting then return end

	local greeting = npcData.returningGreeting
	currentDialogueIndex = 0 -- Специальный индекс для приветствия

	-- Обновляем имя NPC
	npcNameLabel.Text = npcData.name

	-- Очищаем старые ответы
	clearResponses()

	-- Проверяем есть ли ответы
	local hasResponses = greeting.responses and #greeting.responses > 0

	-- Настраиваем размер текста
	if hasResponses then
		dialogueText.Size = UDim2.new(1, -16, 0, 68) -- Больше места для текста
	else
		dialogueText.Size = UDim2.new(1, -16, 1, -30)
	end

	-- Запускаем typewriter эффект
	typewriterEffect(greeting.text, function()
		if hasResponses then
			responsesFrame.Visible = true
			hintLabel.Visible = false

			for i, response in ipairs(greeting.responses) do
				createResponseButton(i, response.text, response.next)
			end
		else
			responsesFrame.Visible = false
			hintLabel.Visible = true
		end
	end)
end

function openDialogue(npc)
	currentNPC = npc
	isInDialogue = true
	currentDialogueIndex = 1

	-- Скрываем ProximityPrompt текущего NPC (находится в HumanoidRootPart)
	local npcRoot = npc:FindFirstChild("HumanoidRootPart")
	if npcRoot then
		local prompt = npcRoot:FindFirstChild("TalkPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end

	-- Блокируем движение игрока
	lockPlayerMovement()

	-- Устанавливаем камеру диалога
	setupDialogueCamera(npc)

	-- Создаём 3D портрет NPC
	setupNPCPortrait(npc)

	-- Показываем диалог
	dialogueFrame.Visible = true

	-- Проверяем говорили ли мы уже с этим NPC
	local npcData = NPC_DIALOGUES[npc.Name]
	if talkedToNPCs[npc.Name] and npcData and npcData.returningGreeting then
		-- Показываем альтернативное приветствие
		showReturningGreeting(npc.Name)
	else
		-- Первый разговор - показываем обычный диалог
		showDialogue(1)
		-- Запоминаем что говорили с этим NPC
		talkedToNPCs[npc.Name] = true
	end

	-- Разблокируем мышь
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

function closeDialogue()
	-- Показываем ProximityPrompt обратно
	if currentNPC then
		local npcRoot = currentNPC:FindFirstChild("HumanoidRootPart")
		if npcRoot then
			local prompt = npcRoot:FindFirstChild("TalkPrompt")
			if prompt then
				prompt.Enabled = true
			end
		end
	end

	isInDialogue = false
	currentNPC = nil
	dialogueFrame.Visible = false
	clearResponses()

	-- Разблокируем движение
	unlockPlayerMovement()

	-- Восстанавливаем камеру
	restoreCamera()
end

-- === ОБРАБОТКА PROXIMITYPROMPT ===
ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then return end
	if prompt.Name ~= "TalkPrompt" then return end
	if isInDialogue then return end

	-- Находим NPC
	local npc = prompt.Parent and prompt.Parent.Parent
	if npc and NPC_DIALOGUES[npc.Name] then
		openDialogue(npc)
	end
end)

-- === ВВОД ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Цифры 1-9 для быстрого выбора ответа (работают даже когда GUI активен)
	if isInDialogue and currentNPC and input.KeyCode then
		local keyNumber = nil

		-- Проверяем цифры на основной клавиатуре
		if input.KeyCode == Enum.KeyCode.One then keyNumber = 1
		elseif input.KeyCode == Enum.KeyCode.Two then keyNumber = 2
		elseif input.KeyCode == Enum.KeyCode.Three then keyNumber = 3
		elseif input.KeyCode == Enum.KeyCode.Four then keyNumber = 4
		elseif input.KeyCode == Enum.KeyCode.Five then keyNumber = 5
		elseif input.KeyCode == Enum.KeyCode.Six then keyNumber = 6
		elseif input.KeyCode == Enum.KeyCode.Seven then keyNumber = 7
		elseif input.KeyCode == Enum.KeyCode.Eight then keyNumber = 8
		elseif input.KeyCode == Enum.KeyCode.Nine then keyNumber = 9
		end

		-- Цифры работают только когда текст уже напечатан и ответы видны
		if keyNumber and not isTyping and responsesFrame.Visible then
			local npcData = NPC_DIALOGUES[currentNPC.Name]
			if npcData then
				local dialogue = nil

				-- Проверяем: это returningGreeting (index = 0) или обычный диалог
				if currentDialogueIndex == 0 and npcData.returningGreeting then
					dialogue = npcData.returningGreeting
				else
					dialogue = npcData.dialogues[currentDialogueIndex]
				end

				if dialogue and dialogue.responses and dialogue.responses[keyNumber] then
					local nextDialogue = dialogue.responses[keyNumber].next
					if nextDialogue then
						showDialogue(nextDialogue)
					else
						closeDialogue()
					end
					return
				end
			end
		end
	end

	if gameProcessed then return end

	-- TAB - закрыть диалог
	if input.KeyCode == Enum.KeyCode.Tab then
		if isInDialogue then
			closeDialogue()
		end
	end

	-- Клик мышью или пробел
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space) and isInDialogue then
		if isTyping then
			-- Пропускаем анимацию текста
			skipTyping = true
		elseif not responsesFrame.Visible then
			-- Нет вариантов ответа - закрываем диалог
			closeDialogue()
		end
	end
end)

print("NPCInteraction: Initialized")
