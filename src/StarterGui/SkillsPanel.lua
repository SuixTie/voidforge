--[[
	SkillsPanel - 3D Панель скиллов справа снизу
	Показывает список доступных действий и их клавиши
	Voidforge: Eclipse Legacy
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Screen3D = require(ReplicatedStorage.Screen3D)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Удаляем старую панель если есть (предотвращает дублирование)
local existingGui = playerGui:FindFirstChild("SkillsPanelGui")
if existingGui then
	existingGui:Destroy()
end

-- === ЦВЕТА (Cyberpunk стиль) ===
local COLORS = {
	panelBg = Color3.fromRGB(15, 5, 30),
	keyBg = Color3.fromRGB(25, 15, 45),
	keyText = Color3.fromRGB(0, 255, 255), -- Cyan
	skillText = Color3.fromRGB(220, 220, 220),
	border = Color3.fromRGB(60, 40, 80),
	highlight = Color3.fromRGB(255, 0, 128), -- Magenta
}

-- === СПИСОК СКИЛЛОВ ===
local SKILLS = {
	-- Combat
	{key = "LMB", name = "Light Attack", category = "combat"},
	{key = "RMB", name = "Heavy Attack", category = "combat"},
	{key = "F", name = "Block", category = "combat"},
	{key = "R", name = "Parry", category = "combat"},
	{key = "G", name = "Lock-on", category = "combat"},
	-- Movement
	{key = "Q", name = "Dash", category = "movement"},
	{key = "C", name = "Crouch", category = "movement"},
	{key = "SHIFT", name = "Run", category = "movement"},
	-- Equipment
	{key = "1", name = "Primary", category = "equipment"},
	{key = "2", name = "Secondary", category = "equipment"},
	{key = "`", name = "Inventory", category = "equipment"},
}

-- === СОЗДАНИЕ GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkillsPanelGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Главный контейнер (справа снизу)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 150, 0, 0)
mainFrame.Position = UDim2.new(1, -220, 1, -10)
mainFrame.AnchorPoint = Vector2.new(0, 1)
mainFrame.BackgroundColor3 = COLORS.panelBg
mainFrame.BackgroundTransparency = 0.3
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Скругление
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = mainFrame

-- Обводка
local stroke = Instance.new("UIStroke")
stroke.Color = COLORS.border
stroke.Thickness = 1
stroke.Transparency = 0.5
stroke.Parent = mainFrame

-- Список скиллов
local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 2)
listLayout.Parent = mainFrame

-- Padding
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.PaddingLeft = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 6)
padding.Parent = mainFrame

-- === ФУНКЦИЯ СОЗДАНИЯ СТРОКИ СКИЛЛА ===
local function createSkillRow(skillData, order)
	local row = Instance.new("Frame")
	row.Name = "Skill_" .. skillData.key
	row.Size = UDim2.new(1, 0, 0, 24)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = mainFrame
	
	-- Контейнер для клавиши
	local keyFrame = Instance.new("Frame")
	keyFrame.Name = "KeyFrame"
	keyFrame.Size = UDim2.new(0, 36, 0, 20)
	keyFrame.Position = UDim2.new(0, 0, 0.5, 0)
	keyFrame.AnchorPoint = Vector2.new(0, 0.5)
	keyFrame.BackgroundColor3 = COLORS.keyBg
	keyFrame.BorderSizePixel = 0
	keyFrame.Parent = row
	
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 4)
	keyCorner.Parent = keyFrame
	
	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = COLORS.border
	keyStroke.Thickness = 1
	keyStroke.Parent = keyFrame
	
	-- Текст клавиши
	local keyText = Instance.new("TextLabel")
	keyText.Name = "KeyText"
	keyText.Size = UDim2.new(1, 0, 1, 0)
	keyText.BackgroundTransparency = 1
	keyText.Text = skillData.key
	keyText.TextColor3 = COLORS.keyText
	keyText.TextSize = 12
	keyText.Font = Enum.Font.GothamBold
	keyText.Parent = keyFrame
	
	-- Название скилла
	local skillName = Instance.new("TextLabel")
	skillName.Name = "SkillName"
	skillName.Size = UDim2.new(1, -44, 1, 0)
	skillName.Position = UDim2.new(0, 42, 0, 0)
	skillName.BackgroundTransparency = 1
	skillName.Text = skillData.name
	skillName.TextColor3 = COLORS.skillText
	skillName.TextSize = 13
	skillName.Font = Enum.Font.Gotham
	skillName.TextXAlignment = Enum.TextXAlignment.Left
	skillName.Parent = row
	
	return row
end

-- === СОЗДАНИЕ ВСЕХ СКИЛЛОВ ===
local totalHeight = 12

for i, skill in ipairs(SKILLS) do
	createSkillRow(skill, i)
	totalHeight = totalHeight + 26
end

mainFrame.Size = UDim2.new(0, 150, 0, totalHeight)

-- === 3D ЭФФЕКТ ===
local GUI3D = Screen3D.new(screenGui, 5)
local Frame3D = GUI3D:GetComponent3D(mainFrame)
Frame3D:Enable()
Frame3D.offset = CFrame.Angles(0, math.rad(-10), 0) -- Наклон влево для правой панели

-- === АНИМАЦИЯ ПОЯВЛЕНИЯ ===
mainFrame.Position = UDim2.new(1, 0, 1, -10)
task.delay(1, function()
	local tween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -220, 1, -10)
	})
	tween:Play()
end)

-- === ПОДСВЕТКА ПРИ НАЖАТИИ ===
local keyCodeMap = {
	["LMB"] = Enum.UserInputType.MouseButton1,
	["RMB"] = Enum.UserInputType.MouseButton2,
	["F"] = Enum.KeyCode.F,
	["R"] = Enum.KeyCode.R,
	["G"] = Enum.KeyCode.G,
	["Q"] = Enum.KeyCode.Q,
	["C"] = Enum.KeyCode.C,
	["SHIFT"] = Enum.KeyCode.LeftShift,
	["1"] = Enum.KeyCode.One,
	["2"] = Enum.KeyCode.Two,
	["`"] = Enum.KeyCode.Backquote,
}

local function highlightSkill(skillKey, highlight)
	local row = mainFrame:FindFirstChild("Skill_" .. skillKey)
	if row then
		local keyFrame = row:FindFirstChild("KeyFrame")
		if keyFrame then
			local targetColor = highlight and COLORS.highlight or COLORS.keyBg
			TweenService:Create(keyFrame, TweenInfo.new(0.1), {BackgroundColor3 = targetColor}):Play()
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	for skillKey, inputType in pairs(keyCodeMap) do
		if input.KeyCode == inputType or input.UserInputType == inputType then
			highlightSkill(skillKey, true)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	for skillKey, inputType in pairs(keyCodeMap) do
		if input.KeyCode == inputType or input.UserInputType == inputType then
			highlightSkill(skillKey, false)
		end
	end
end)

-- === ОБРАБОТКА СМЕРТИ ===
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	
	humanoid.Died:Connect(function()
		-- Отключаем 3D эффект при смерти
		if Frame3D then
			Frame3D:Disable()
		end
		-- Скрываем панель
		if screenGui then
			screenGui.Enabled = false
		end
	end)
end

-- Подключаемся к текущему персонажу
if player.Character then
	onCharacterAdded(player.Character)
end

-- Подключаемся к будущим персонажам
player.CharacterAdded:Connect(function(character)
	-- Включаем панель обратно при респавне
	if screenGui then
		screenGui.Enabled = true
	end
	-- Включаем 3D эффект обратно
	if Frame3D then
		task.delay(0.5, function()
			Frame3D:Enable()
		end)
	end
	onCharacterAdded(character)
end)

return {}
