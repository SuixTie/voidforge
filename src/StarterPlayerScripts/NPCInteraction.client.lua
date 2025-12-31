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

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
		name = "Умственноотсталый",
		dialogues = {
			{
				text = "Привет, путник. Я вижу, ты новенький в этих краях...",
				responses = {
					{text = "Кто ты?", next = 2},
					{text = "Что это за место?", next = 3},
					{text = "До свидания", next = nil},
				}
			},
			{
				text = "Меня зовут Умственноотсталый. Я страж этого места уже много лет. Видел многое...",
				responses = {
					{text = "Расскажи больше", next = 4},
					{text = "Назад", next = 1},
					{text = "До свидания", next = nil},
				}
			},
			{
				text = "Это Voidforge - место, где тьма встречается со светом. Здесь рождаются легенды... и умирают герои.",
				responses = {
					{text = "Звучит опасно", next = 5},
					{text = "Назад", next = 1},
					{text = "До свидания", next = nil},
				}
			},
			{
				text = "Я был воином когда-то. Теперь я лишь наблюдаю. Время меняет всех нас...",
				responses = {
					{text = "Понятно", next = 1},
					{text = "До свидания", next = nil},
				}
			},
			{
				text = "Опасно? Хах... Опасность - это лишь возможность стать сильнее. Будь осторожен, путник.",
				responses = {
					{text = "Спасибо за совет", next = 1},
					{text = "До свидания", next = nil},
				}
			},
		}
	},
}

-- === СОСТОЯНИЕ ===
local currentNPC = nil
local isInDialogue = false
local currentDialogueIndex = 1

-- Сохранённые значения для восстановления
local savedWalkSpeed = 16
local savedJumpPower = 50
local savedCameraType = nil
local dialogueCameraConnection = nil

-- === GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NPCInteractionGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- === ДИАЛОГОВОЕ ОКНО ===
local dialogueFrame = Instance.new("Frame")
dialogueFrame.Name = "DialogueFrame"
dialogueFrame.Size = UDim2.new(0, 600, 0, 300)
dialogueFrame.Position = UDim2.new(0.5, -300, 0.7, -150)
dialogueFrame.BackgroundColor3 = CONFIG.PanelColor
dialogueFrame.BackgroundTransparency = 0.1
dialogueFrame.BorderSizePixel = 0
dialogueFrame.Visible = false
dialogueFrame.Parent = screenGui

local dialogueCorner = Instance.new("UICorner")
dialogueCorner.CornerRadius = UDim.new(0, 12)
dialogueCorner.Parent = dialogueFrame

local dialogueStroke = Instance.new("UIStroke")
dialogueStroke.Color = CONFIG.CyanColor
dialogueStroke.Thickness = 2
dialogueStroke.Parent = dialogueFrame

-- Имя NPC
local npcNameLabel = Instance.new("TextLabel")
npcNameLabel.Name = "NPCName"
npcNameLabel.Size = UDim2.new(1, -20, 0, 30)
npcNameLabel.Position = UDim2.new(0, 10, 0, 10)
npcNameLabel.BackgroundTransparency = 1
npcNameLabel.Text = "NPC"
npcNameLabel.TextColor3 = CONFIG.CyanColor
npcNameLabel.TextSize = 20
npcNameLabel.Font = Enum.Font.GothamBold
npcNameLabel.TextXAlignment = Enum.TextXAlignment.Left
npcNameLabel.Parent = dialogueFrame

-- Текст диалога
local dialogueText = Instance.new("TextLabel")
dialogueText.Name = "DialogueText"
dialogueText.Size = UDim2.new(1, -20, 0, 80)
dialogueText.Position = UDim2.new(0, 10, 0, 45)
dialogueText.BackgroundTransparency = 1
dialogueText.Text = ""
dialogueText.TextColor3 = CONFIG.TextColor
dialogueText.TextSize = 16
dialogueText.Font = Enum.Font.Gotham
dialogueText.TextXAlignment = Enum.TextXAlignment.Left
dialogueText.TextYAlignment = Enum.TextYAlignment.Top
dialogueText.TextWrapped = true
dialogueText.Parent = dialogueFrame

-- Контейнер для ответов
local responsesFrame = Instance.new("Frame")
responsesFrame.Name = "Responses"
responsesFrame.Size = UDim2.new(1, -20, 0, 150)
responsesFrame.Position = UDim2.new(0, 10, 0, 135)
responsesFrame.BackgroundTransparency = 1
responsesFrame.Parent = dialogueFrame

local responsesLayout = Instance.new("UIListLayout")
responsesLayout.SortOrder = Enum.SortOrder.LayoutOrder
responsesLayout.Padding = UDim.new(0, 8)
responsesLayout.Parent = responsesFrame

-- === БЛОКИРОВКА ДВИЖЕНИЯ ===
local function lockPlayerMovement()
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		-- Сохраняем текущие значения
		savedWalkSpeed = humanoid.WalkSpeed
		savedJumpPower = humanoid.JumpPower
		
		-- Блокируем движение
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
	
	-- Создаём значение для других скриптов
	local dialogueValue = player:FindFirstChild("InDialogue")
	if not dialogueValue then
		dialogueValue = Instance.new("BoolValue")
		dialogueValue.Name = "InDialogue"
		dialogueValue.Parent = player
	end
	dialogueValue.Value = true
end

local function unlockPlayerMovement()
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
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
	
	-- Позиция камеры: справа за спиной игрока, смотрит на обоих
	local midPoint = (rootPart.Position + npcRoot.Position) / 2 + Vector3.new(0, 2, 0)
	local rightOffset = rootPart.CFrame.RightVector * 4
	local backOffset = -directionToNPC * 3
	local cameraPosition = rootPart.Position + rightOffset + backOffset + Vector3.new(0, 2.5, 0)
	
	-- Плавно перемещаем камеру
	local targetCFrame = CFrame.lookAt(cameraPosition, midPoint)
	
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
	button.Size = UDim2.new(1, 0, 0, 35)
	button.BackgroundColor3 = CONFIG.PanelColor
	button.BackgroundTransparency = 0.5
	button.Text = index .. ". " .. text
	button.TextColor3 = CONFIG.TextColor
	button.TextSize = 14
	button.Font = Enum.Font.Gotham
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.AutoButtonColor = false
	button.LayoutOrder = index
	button.Parent = responsesFrame
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = button
	
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = CONFIG.MagentaColor
	btnStroke.Thickness = 1
	btnStroke.Transparency = 0.5
	btnStroke.Parent = button
	
	local btnPadding = Instance.new("UIPadding")
	btnPadding.PaddingLeft = UDim.new(0, 10)
	btnPadding.Parent = button
	
	-- Hover эффект
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), {
			BackgroundTransparency = 0.2
		}):Play()
		TweenService:Create(btnStroke, TweenInfo.new(0.15), {
			Transparency = 0,
			Color = CONFIG.CyanColor
		}):Play()
	end)
	
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), {
			BackgroundTransparency = 0.5
		}):Play()
		TweenService:Create(btnStroke, TweenInfo.new(0.15), {
			Transparency = 0.5,
			Color = CONFIG.MagentaColor
		}):Play()
	end)
	
	-- Клик
	button.MouseButton1Click:Connect(function()
		if nextDialogue then
			showDialogue(nextDialogue)
		else
			closeDialogue()
		end
	end)
	
	return button
end

function showDialogue(dialogueIndex)
	if not currentNPC then return end
	
	local npcData = NPC_DIALOGUES[currentNPC.Name]
	if not npcData then return end
	
	local dialogue = npcData.dialogues[dialogueIndex]
	if not dialogue then return end
	
	currentDialogueIndex = dialogueIndex
	
	-- Обновляем UI
	npcNameLabel.Text = npcData.name
	dialogueText.Text = dialogue.text
	
	-- Очищаем и создаём кнопки ответов
	clearResponses()
	for i, response in ipairs(dialogue.responses) do
		createResponseButton(i, response.text, response.next)
	end
end

function openDialogue(npc)
	currentNPC = npc
	isInDialogue = true
	currentDialogueIndex = 1
	
	-- Блокируем движение игрока
	lockPlayerMovement()
	
	-- Устанавливаем камеру диалога
	setupDialogueCamera(npc)
	
	-- Показываем диалог
	dialogueFrame.Visible = true
	
	-- Показываем первый диалог
	showDialogue(1)
	
	-- Разблокируем мышь
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

function closeDialogue()
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
	if gameProcessed then return end
	
	-- TAB - закрыть диалог
	if input.KeyCode == Enum.KeyCode.Tab then
		if isInDialogue then
			closeDialogue()
		end
	end
	
	-- Цифры 1-9 для быстрого выбора ответа
	if isInDialogue and currentNPC then
		local keyNumber = tonumber(input.KeyCode.Name:match("(%d)"))
		if keyNumber then
			local npcData = NPC_DIALOGUES[currentNPC.Name]
			if npcData then
				local dialogue = npcData.dialogues[currentDialogueIndex]
				if dialogue and dialogue.responses[keyNumber] then
					local nextDialogue = dialogue.responses[keyNumber].next
					if nextDialogue then
						showDialogue(nextDialogue)
					else
						closeDialogue()
					end
				end
			end
		end
	end
end)

print("NPCInteraction: Initialized")
