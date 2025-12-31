--[[
	NPCInteraction - Система взаимодействия с NPC
	Voidforge: Eclipse Legacy
	
	Особенности:
	- Показывает кнопку E при приближении к NPC
	- Запускает диалог при нажатии E
	- Cyberpunk стиль UI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- === НАСТРОЙКИ ===
local CONFIG = {
	InteractDistance = 8, -- Дистанция для взаимодействия
	InteractKey = Enum.KeyCode.E,
	
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

-- === GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NPCInteractionGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Кнопка взаимодействия (E)
local interactPrompt = Instance.new("Frame")
interactPrompt.Name = "InteractPrompt"
interactPrompt.Size = UDim2.new(0, 200, 0, 60)
interactPrompt.Position = UDim2.new(0.5, -100, 0.7, 0)
interactPrompt.BackgroundColor3 = CONFIG.PanelColor
interactPrompt.BackgroundTransparency = 0.2
interactPrompt.BorderSizePixel = 0
interactPrompt.Visible = false
interactPrompt.Parent = screenGui

local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 8)
promptCorner.Parent = interactPrompt

local promptStroke = Instance.new("UIStroke")
promptStroke.Color = CONFIG.CyanColor
promptStroke.Thickness = 2
promptStroke.Parent = interactPrompt

local promptKey = Instance.new("TextLabel")
promptKey.Name = "Key"
promptKey.Size = UDim2.new(0, 40, 0, 40)
promptKey.Position = UDim2.new(0, 10, 0.5, -20)
promptKey.BackgroundColor3 = CONFIG.CyanColor
promptKey.BackgroundTransparency = 0.3
promptKey.Text = "E"
promptKey.TextColor3 = CONFIG.TextColor
promptKey.TextSize = 24
promptKey.Font = Enum.Font.GothamBold
promptKey.Parent = interactPrompt

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 6)
keyCorner.Parent = promptKey

local promptText = Instance.new("TextLabel")
promptText.Name = "Text"
promptText.Size = UDim2.new(1, -60, 1, 0)
promptText.Position = UDim2.new(0, 55, 0, 0)
promptText.BackgroundTransparency = 1
promptText.Text = "Поговорить"
promptText.TextColor3 = CONFIG.TextColor
promptText.TextSize = 18
promptText.Font = Enum.Font.Gotham
promptText.TextXAlignment = Enum.TextXAlignment.Left
promptText.Parent = interactPrompt

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
	
	-- Скрываем prompt, показываем диалог
	interactPrompt.Visible = false
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
end

-- === ПОИСК БЛИЖАЙШЕГО NPC ===
local function findNearestNPC()
	local character = player.Character
	if not character then return nil end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	
	local nearestNPC = nil
	local nearestDistance = CONFIG.InteractDistance
	
	-- Ищем NPC с тегом InvulnerableNPC
	for _, npc in ipairs(CollectionService:GetTagged("InvulnerableNPC")) do
		if npc:IsA("Model") then
			local npcRoot = npc:FindFirstChild("HumanoidRootPart")
			if npcRoot then
				local distance = (npcRoot.Position - rootPart.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestNPC = npc
				end
			end
		end
	end
	
	return nearestNPC
end

-- === ОБНОВЛЕНИЕ ===
RunService.RenderStepped:Connect(function()
	if isInDialogue then return end
	
	local nearestNPC = findNearestNPC()
	
	if nearestNPC and NPC_DIALOGUES[nearestNPC.Name] then
		interactPrompt.Visible = true
		currentNPC = nearestNPC
	else
		interactPrompt.Visible = false
		currentNPC = nil
	end
end)

-- === ВВОД ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- E - взаимодействие
	if input.KeyCode == CONFIG.InteractKey then
		if isInDialogue then
			-- Можно добавить быстрый выбор по номерам
		elseif currentNPC then
			openDialogue(currentNPC)
		end
	end
	
	-- TAB или Escape - закрыть диалог
	if input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.Escape then
		if isInDialogue then
			closeDialogue()
		end
	end
	
	-- Цифры 1-9 для быстрого выбора ответа
	if isInDialogue then
		local keyNumber = tonumber(input.KeyCode.Name:match("(%d)"))
		if keyNumber then
			local responseButton = responsesFrame:FindFirstChild("Response" .. keyNumber)
			if responseButton then
				-- Симулируем клик
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
	end
end)

print("NPCInteraction: Initialized")
