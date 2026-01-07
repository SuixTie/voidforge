--[[
	SettingsMenu - Меню настроек
	Стиль: Cyberpunk
	Закрытие на TAB
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

-- === ЦВЕТА НЕОН-АНИМЕ ===
local COLORS = {
	Background = Color3.fromRGB(10, 10, 26),
	Panel = Color3.fromRGB(15, 15, 35),
	Border = Color3.fromRGB(0, 255, 255),           -- Циан
	BorderDim = Color3.fromRGB(0, 180, 180),
	Header = Color3.fromRGB(0, 255, 255),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(140, 140, 160),
	Active = Color3.fromRGB(0, 255, 255),
	Inactive = Color3.fromRGB(80, 80, 100),
	SliderBg = Color3.fromRGB(25, 25, 50),
	SliderFill = Color3.fromRGB(0, 255, 255),
	ItemLine = Color3.fromRGB(0, 120, 120),
	Accent = Color3.fromRGB(255, 0, 255),           -- Розовый акцент
}

-- === ЦВЕТА СЕКЦИЙ (единый неон-аниме стиль) ===
local SECTION_COLORS = {
	VIDEO = {
		accent = Color3.fromRGB(0, 255, 255),      -- Циан
		accentDim = Color3.fromRGB(0, 180, 180),
		accentDark = Color3.fromRGB(0, 100, 100),
	},
	AUDIO = {
		accent = Color3.fromRGB(255, 0, 255),      -- Розовый
		accentDim = Color3.fromRGB(180, 0, 180),
		accentDark = Color3.fromRGB(100, 0, 100),
	},
	GAMEPLAY = {
		accent = Color3.fromRGB(255, 215, 0),      -- Золотой
		accentDim = Color3.fromRGB(180, 150, 0),
		accentDark = Color3.fromRGB(100, 85, 0),
	},
	CONTROLS = {
		accent = Color3.fromRGB(0, 200, 255),      -- Голубой
		accentDim = Color3.fromRGB(0, 140, 180),
		accentDark = Color3.fromRGB(0, 80, 100),
	},
	CODES = {
		accent = Color3.fromRGB(100, 255, 150),    -- Зелёный
		accentDim = Color3.fromRGB(70, 180, 105),
		accentDark = Color3.fromRGB(40, 100, 60),
	},
}

-- Текущая секция для передачи цветов элементам
local currentSectionColors = SECTION_COLORS.VIDEO

-- === ЗВУКИ ===
local hoverSound = Instance.new("Sound")
hoverSound.SoundId = "rbxassetid://6895079853"
hoverSound.Volume = 0.3
hoverSound.Parent = playerGui

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6895079853"
clickSound.Volume = 0.4
clickSound.Parent = playerGui

-- === СОСТОЯНИЕ ===
local settingsOpen = false

-- === ГЛОБАЛЬНЫЙ ФЛАГ ДЛЯ ДРУГИХ СКРИПТОВ ===
local settingsOpenValue = player:FindFirstChild("SettingsMenuOpen")
if not settingsOpenValue then
	settingsOpenValue = Instance.new("BoolValue")
	settingsOpenValue.Name = "SettingsMenuOpen"
	settingsOpenValue.Value = false
	settingsOpenValue.Parent = player
end

-- === БЛЮР ===
local settingsBlur = Lighting:FindFirstChild("SettingsBlur")
if not settingsBlur then
	settingsBlur = Instance.new("BlurEffect")
	settingsBlur.Name = "SettingsBlur"
	settingsBlur.Size = 0
	settingsBlur.Enabled = false
	settingsBlur.Parent = Lighting
end

-- === GUI ===
local settingsGui = Instance.new("ScreenGui")
settingsGui.Name = "SettingsMenuGui"
settingsGui.ResetOnSpawn = false
settingsGui.IgnoreGuiInset = true
settingsGui.DisplayOrder = 200
settingsGui.Enabled = false
settingsGui.Parent = playerGui

-- Затемнение (кликабельное для закрытия меню)
local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = settingsGui

-- === ГЛАВНАЯ ПАНЕЛЬ ===
local mainPanel = Instance.new("Frame")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 450, 0, 550)
mainPanel.Position = UDim2.new(0.5, -225, 0.5, -275)
mainPanel.BackgroundColor3 = COLORS.Panel
mainPanel.BackgroundTransparency = 0.05
mainPanel.BorderSizePixel = 0
mainPanel.Parent = settingsGui

-- Внешняя рамка
local outerBorder = Instance.new("UIStroke")
outerBorder.Color = COLORS.Border
outerBorder.Thickness = 2
outerBorder.Parent = mainPanel

-- Угловые изображения главной панели (нижние углы)
local panelCornerBottomLeft = Instance.new("ImageLabel")
panelCornerBottomLeft.Size = UDim2.new(0, 18, 0, 18)
panelCornerBottomLeft.Position = UDim2.new(0, 0, 1, -18)
panelCornerBottomLeft.BackgroundTransparency = 1
panelCornerBottomLeft.Image = "rbxassetid://132921287217893"
panelCornerBottomLeft.ImageColor3 = Color3.fromRGB(0, 255, 255)
panelCornerBottomLeft.Rotation = -90
panelCornerBottomLeft.Parent = mainPanel

local panelCornerBottomRight = Instance.new("ImageLabel")
panelCornerBottomRight.Size = UDim2.new(0, 18, 0, 18)
panelCornerBottomRight.Position = UDim2.new(1, -18, 1, -18)
panelCornerBottomRight.BackgroundTransparency = 1
panelCornerBottomRight.Image = "rbxassetid://132921287217893"
panelCornerBottomRight.ImageColor3 = Color3.fromRGB(0, 255, 255)
panelCornerBottomRight.Rotation = 180
panelCornerBottomRight.Parent = mainPanel

-- === ЗАГОЛОВОК ===
local headerBar = Instance.new("Frame")
headerBar.Name = "HeaderBar"
headerBar.Size = UDim2.new(1, -4, 0, 45)
headerBar.Position = UDim2.new(0, 2, 0, 2)
headerBar.BackgroundColor3 = Color3.fromRGB(10, 3, 25)
headerBar.BackgroundTransparency = 0.1
headerBar.BorderSizePixel = 0
headerBar.Parent = mainPanel

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, 0, 1, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "SETTINGS"
headerTitle.TextColor3 = COLORS.Header
headerTitle.TextSize = 22
headerTitle.Font = Enum.Font.GothamBold
headerTitle.Parent = headerBar

-- Угловые изображения
local cornerTopLeft = Instance.new("ImageLabel")
cornerTopLeft.Size = UDim2.new(0, 12, 0, 12)
cornerTopLeft.Position = UDim2.new(0, 0, 0, 0)
cornerTopLeft.BackgroundTransparency = 1
cornerTopLeft.Image = "rbxassetid://132921287217893"
cornerTopLeft.ImageColor3 = Color3.fromRGB(0, 255, 255)
cornerTopLeft.Parent = headerBar

local cornerTopRight = Instance.new("ImageLabel")
cornerTopRight.Size = UDim2.new(0, 12, 0, 12)
cornerTopRight.Position = UDim2.new(1, -12, 0, 0)
cornerTopRight.BackgroundTransparency = 1
cornerTopRight.Image = "rbxassetid://132921287217893"
cornerTopRight.ImageColor3 = Color3.fromRGB(0, 255, 255)
cornerTopRight.Rotation = 90
cornerTopRight.Parent = headerBar

local cornerBottomLeft = Instance.new("ImageLabel")
cornerBottomLeft.Size = UDim2.new(0, 12, 0, 12)
cornerBottomLeft.Position = UDim2.new(0, 0, 1, -12)
cornerBottomLeft.BackgroundTransparency = 1
cornerBottomLeft.Image = "rbxassetid://132921287217893"
cornerBottomLeft.ImageColor3 = Color3.fromRGB(0, 255, 255)
cornerBottomLeft.Rotation = -90
cornerBottomLeft.Parent = headerBar

local cornerBottomRight = Instance.new("ImageLabel")
cornerBottomRight.Size = UDim2.new(0, 12, 0, 12)
cornerBottomRight.Position = UDim2.new(1, -12, 1, -12)
cornerBottomRight.BackgroundTransparency = 1
cornerBottomRight.Image = "rbxassetid://132921287217893"
cornerBottomRight.ImageColor3 = Color3.fromRGB(0, 255, 255)
cornerBottomRight.Rotation = 180
cornerBottomRight.Parent = headerBar

-- Линия под заголовком
local headerLine = Instance.new("Frame")
headerLine.Size = UDim2.new(1, 4, 0, 2)
headerLine.Position = UDim2.new(0, -2, 1, 0)
headerLine.BackgroundColor3 = Color3.fromRGB(15, 5, 30)
headerLine.BorderSizePixel = 0
headerLine.Parent = headerBar

-- Вторая линия под заголовком (циановая)
local headerLine2 = Instance.new("Frame")
headerLine2.Size = UDim2.new(1, 4, 0, 2)
headerLine2.Position = UDim2.new(0, -2, 1, 2)
headerLine2.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
headerLine2.BorderSizePixel = 0
headerLine2.Parent = headerBar

-- === КОНТЕНТ ===
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -30, 1, -61)
contentFrame.Position = UDim2.new(0, 10, 0, 51)
contentFrame.BackgroundTransparency = 1
contentFrame.ScrollBarThickness = 0 -- Скрываем стандартный скроллбар
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.BorderSizePixel = 0
contentFrame.Parent = mainPanel

local contentLayout = Instance.new("UIListLayout")
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 5)
contentLayout.Parent = contentFrame

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingLeft = UDim.new(0, 2)
contentPadding.PaddingRight = UDim.new(0, 2)
contentPadding.Parent = contentFrame

-- === КАСТОМНЫЙ СКРОЛЛБАР ===
local scrollbarTrack = Instance.new("Frame")
scrollbarTrack.Name = "ScrollbarTrack"
scrollbarTrack.Size = UDim2.new(0, 3, 1, -130)
scrollbarTrack.Position = UDim2.new(1, -14, 0, 115)
scrollbarTrack.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
scrollbarTrack.BackgroundTransparency = 0.5
scrollbarTrack.BorderSizePixel = 0
scrollbarTrack.Parent = mainPanel

-- Обводка на треке
local trackStroke = Instance.new("UIStroke")
trackStroke.Color = Color3.fromRGB(150, 0, 75)
trackStroke.Thickness = 1
trackStroke.Parent = scrollbarTrack

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 2)
trackCorner.Parent = scrollbarTrack

local scrollbarThumb = Instance.new("Frame")
scrollbarThumb.Name = "ScrollbarThumb"
scrollbarThumb.Size = UDim2.new(1, -2, 0.3, 0)
scrollbarThumb.Position = UDim2.new(0, 1, 0, 0)
scrollbarThumb.BackgroundColor3 = Color3.fromRGB(255, 0, 128)
scrollbarThumb.BorderSizePixel = 0
scrollbarThumb.Parent = scrollbarTrack

local scrollbarCorner = Instance.new("UICorner")
scrollbarCorner.CornerRadius = UDim.new(0, 2)
scrollbarCorner.Parent = scrollbarThumb

-- Обновление скроллбара
local function updateScrollbar()
	local canvasSize = contentFrame.AbsoluteCanvasSize.Y
	local frameSize = contentFrame.AbsoluteSize.Y

	if canvasSize <= frameSize then
		scrollbarTrack.Visible = false
		return
	end

	scrollbarTrack.Visible = true

	local thumbRatio = math.clamp(frameSize / canvasSize, 0.1, 1)
	local scrollRatio = contentFrame.CanvasPosition.Y / (canvasSize - frameSize)

	scrollbarThumb.Size = UDim2.new(1, 0, thumbRatio, 0)
	scrollbarThumb.Position = UDim2.new(0, 0, scrollRatio * (1 - thumbRatio), 0)
end

contentFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(updateScrollbar)
contentFrame:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateScrollbar)
contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScrollbar)

-- Перетаскивание скроллбара
local scrollDragging = false

scrollbarThumb.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		scrollDragging = true
	end
end)

scrollbarThumb.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		scrollDragging = false
	end
end)

scrollbarTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local trackPos = scrollbarTrack.AbsolutePosition.Y
		local trackSize = scrollbarTrack.AbsoluteSize.Y
		local clickY = input.Position.Y - trackPos
		local ratio = clickY / trackSize

		local canvasSize = contentFrame.AbsoluteCanvasSize.Y
		local frameSize = contentFrame.AbsoluteSize.Y
		local maxScroll = canvasSize - frameSize

		contentFrame.CanvasPosition = Vector2.new(0, ratio * maxScroll)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if scrollDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local trackPos = scrollbarTrack.AbsolutePosition.Y
		local trackSize = scrollbarTrack.AbsoluteSize.Y
		local mouseY = input.Position.Y - trackPos
		local ratio = math.clamp(mouseY / trackSize, 0, 1)

		local canvasSize = contentFrame.AbsoluteCanvasSize.Y
		local frameSize = contentFrame.AbsoluteSize.Y
		local maxScroll = canvasSize - frameSize

		contentFrame.CanvasPosition = Vector2.new(0, ratio * maxScroll)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		scrollDragging = false
	end
end)

task.defer(updateScrollbar)

-- === ДАННЫЕ НАСТРОЕК ===
local settingsData = {
	{section = "VIDEO"},
	{name = "Low Graphics Mode", type = "toggle", value = false, desc = "Disable the seo mesh and lower particle count."},
	{name = "Shadows", type = "toggle", value = true, desc = "Enable dynamic shadows for better visuals."},
	{name = "Motion Blur", type = "toggle", value = true, desc = "Enable motion blur effect during movement."},
	{name = "Texture Quality", type = "select", value = "MEDIUM", options = {"LOW", "MEDIUM", "HIGH"}, desc = "Adjust texture resolution quality."},
	{name = "Render Distance", type = "select", value = "MEDIUM", options = {"LOW", "MEDIUM", "HIGH"}, desc = "Control how far objects are rendered."},
	{section = "AUDIO"},
	{name = "Master Volume", type = "slider", value = 0.8, desc = "Fine tune your overall sound volume, all sound is affected."},
	{name = "Music Volume", type = "slider", value = 0.6, desc = "Fine tune your music volume, only music is affected."},
	{name = "SFX Volume", type = "slider", value = 0.8, desc = "Adjust sound effects volume for combat and environment."},
	{name = "Ambient Volume", type = "slider", value = 0.5, desc = "Control ambient and environmental sounds."},
	{section = "GAMEPLAY"},
	{name = "Camera Shake", type = "toggle", value = true, desc = "Enable camera shake effects during combat."},
	{name = "Screen Effects", type = "toggle", value = true, desc = "Enable visual effects like vignette and damage flash."},
	{name = "Show Damage Numbers", type = "toggle", value = true, desc = "Display damage numbers during combat."},
	{name = "Auto Lock-On", type = "toggle", value = false, desc = "Automatically lock onto nearby enemies."},
	{section = "CONTROLS"},
	{name = "Invert Y-Axis", type = "toggle", value = false, desc = "Invert vertical camera movement."},
	{name = "Camera Sensitivity", type = "slider", value = 0.5, desc = "Adjust camera rotation speed.", btnText = "RESET"},
	{name = "Aim Sensitivity", type = "slider", value = 0.5, desc = "Adjust aiming sensitivity when locked on.", btnText = "RESET"},
	{section = "CODES"},
	{name = "Enter Code", type = "textinput", value = "", desc = "Enter a promotional code to receive rewards."},
}

-- === СОЗДАНИЕ СЕКЦИИ ===
local function createSection(text, order)
	-- Устанавливаем цвета текущей секции
	currentSectionColors = SECTION_COLORS[text] or SECTION_COLORS.VIDEO
	
	local section = Instance.new("Frame")
	section.Name = "Section_" .. text
	-- Для секций кроме VIDEO меньшая высота
	local sectionHeight = (text == "VIDEO") and 55 or 45
	section.Size = UDim2.new(1, 0, 0, sectionHeight)
	section.BackgroundTransparency = 1
	section.LayoutOrder = order
	section.Parent = contentFrame

	-- Для секций кроме VIDEO меньший верхний отступ текста
	local topPadding = (text == "VIDEO") and 12 or 2
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 30)
	label.Position = UDim2.new(0, 0, 0, topPadding)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = currentSectionColors.accent
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.Parent = section

	-- Линия под секцией
	local sectionLine = Instance.new("Frame")
	sectionLine.Size = UDim2.new(1, 20, 0, 2)
	sectionLine.Position = UDim2.new(0, -10, 1, -8)
	sectionLine.BackgroundColor3 = currentSectionColors.accent
	sectionLine.BorderSizePixel = 0
	sectionLine.Parent = section

	-- Градиент прозрачности
	local lineGradient = Instance.new("UIGradient")
	lineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.9)
	})
	lineGradient.Parent = sectionLine

	return section
end

-- === СОЗДАНИЕ TOGGLE ===
local function createToggle(data, order)
	local sectionColors = currentSectionColors
	
	-- Внешний фрейм с обводкой
	local outerFrame = Instance.new("Frame")
	outerFrame.Name = "Toggle_" .. data.name
	outerFrame.Size = UDim2.new(1, -4, 0, 85)
	outerFrame.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
	outerFrame.BorderSizePixel = 0
	outerFrame.LayoutOrder = order
	outerFrame.Parent = contentFrame

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = sectionColors.accentDim
	outerStroke.Thickness = 1
	outerStroke.Parent = outerFrame

	-- Внутренний фрейм с обводкой
	local innerFrame = Instance.new("Frame")
	innerFrame.Size = UDim2.new(1, -6, 1, -6)
	innerFrame.Position = UDim2.new(0, 3, 0, 3)
	innerFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 30)
	innerFrame.BorderSizePixel = 0
	innerFrame.Parent = outerFrame

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = sectionColors.accentDark
	innerStroke.Thickness = 1
	innerStroke.Parent = innerFrame

	-- Название параметра
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.6, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 12, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.name
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = innerFrame

	-- ON OFF кнопки (без разделителя)
	local onBtn = Instance.new("TextButton")
	onBtn.Size = UDim2.new(0, 30, 0, 24)
	onBtn.Position = UDim2.new(1, -75, 0, 8)
	onBtn.BackgroundTransparency = 1
	onBtn.Text = "ON"
	onBtn.TextColor3 = data.value and sectionColors.accent or COLORS.Inactive
	onBtn.TextSize = 14
	onBtn.Font = Enum.Font.GothamMedium
	onBtn.Parent = innerFrame

	local offBtn = Instance.new("TextButton")
	offBtn.Size = UDim2.new(0, 35, 0, 24)
	offBtn.Position = UDim2.new(1, -40, 0, 8)
	offBtn.BackgroundTransparency = 1
	offBtn.Text = "OFF"
	offBtn.TextColor3 = data.value and COLORS.Inactive or sectionColors.accent
	offBtn.TextSize = 14
	offBtn.Font = Enum.Font.GothamMedium
	offBtn.Parent = innerFrame

	-- Линия с градиентом
	local dividerLine = Instance.new("Frame")
	dividerLine.Size = UDim2.new(1, -20, 0, 1)
	dividerLine.Position = UDim2.new(0, 10, 0, 38)
	dividerLine.BackgroundColor3 = sectionColors.accentDim
	dividerLine.BorderSizePixel = 0
	dividerLine.Parent = innerFrame

	local lineGradient = Instance.new("UIGradient")
	lineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.8)
	})
	lineGradient.Parent = dividerLine

	-- Описание параметра
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -24, 0, 20)
	descLabel.Position = UDim2.new(0, 12, 0, 45)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = data.desc
	descLabel.TextColor3 = COLORS.TextDim
	descLabel.TextSize = 13
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = innerFrame

	local function updateToggle()
		onBtn.TextColor3 = data.value and sectionColors.accent or COLORS.Inactive
		offBtn.TextColor3 = data.value and COLORS.Inactive or sectionColors.accent
	end

	onBtn.MouseButton1Click:Connect(function()
		clickSound:Play()
		data.value = true
		updateToggle()
	end)

	offBtn.MouseButton1Click:Connect(function()
		clickSound:Play()
		data.value = false
		updateToggle()
	end)

	onBtn.MouseEnter:Connect(function()
		hoverSound:Play()
		if not data.value then
			TweenService:Create(onBtn, TweenInfo.new(0.1), {TextColor3 = COLORS.Text}):Play()
		end
	end)
	onBtn.MouseLeave:Connect(function()
		if not data.value then
			TweenService:Create(onBtn, TweenInfo.new(0.1), {TextColor3 = COLORS.Inactive}):Play()
		end
	end)
	
	offBtn.MouseEnter:Connect(function()
		hoverSound:Play()
		if data.value then
			TweenService:Create(offBtn, TweenInfo.new(0.1), {TextColor3 = COLORS.Text}):Play()
		end
	end)
	offBtn.MouseLeave:Connect(function()
		if data.value then
			TweenService:Create(offBtn, TweenInfo.new(0.1), {TextColor3 = COLORS.Inactive}):Play()
		end
	end)

	return outerFrame
end

-- === СОЗДАНИЕ SELECT ===
local function createSelect(data, order)
	local sectionColors = currentSectionColors
	
	-- Внешний фрейм с обводкой
	local outerFrame = Instance.new("Frame")
	outerFrame.Name = "Select_" .. data.name
	outerFrame.Size = UDim2.new(1, -4, 0, 85)
	outerFrame.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
	outerFrame.BorderSizePixel = 0
	outerFrame.LayoutOrder = order
	outerFrame.Parent = contentFrame

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = sectionColors.accentDim
	outerStroke.Thickness = 1
	outerStroke.Parent = outerFrame

	-- Внутренний фрейм с обводкой
	local innerFrame = Instance.new("Frame")
	innerFrame.Size = UDim2.new(1, -6, 1, -6)
	innerFrame.Position = UDim2.new(0, 3, 0, 3)
	innerFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 30)
	innerFrame.BorderSizePixel = 0
	innerFrame.Parent = outerFrame

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = sectionColors.accentDark
	innerStroke.Thickness = 1
	innerStroke.Parent = innerFrame

	-- Название параметра
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.5, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 12, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.name
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = innerFrame

	-- Опции (без разделителей)
	local optionButtons = {}
	local btnWidth = 55
	local spacing = 10
	local totalWidth = #data.options * btnWidth + (#data.options - 1) * spacing
	local startX = -totalWidth - 10

	for i, opt in ipairs(data.options) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, btnWidth, 0, 24)
		btn.Position = UDim2.new(1, startX + (i - 1) * (btnWidth + spacing), 0, 8)
		btn.BackgroundTransparency = 1
		btn.Text = opt
		btn.TextColor3 = data.value == opt and sectionColors.accent or COLORS.Inactive
		btn.TextSize = 14
		btn.Font = Enum.Font.GothamMedium
		btn.Parent = innerFrame

		optionButtons[opt] = btn

		btn.MouseButton1Click:Connect(function()
			clickSound:Play()
			data.value = opt
			for o, b in pairs(optionButtons) do
				b.TextColor3 = o == opt and sectionColors.accent or COLORS.Inactive
			end
		end)

		btn.MouseEnter:Connect(function()
			hoverSound:Play()
			if data.value ~= opt then
				TweenService:Create(btn, TweenInfo.new(0.1), {TextColor3 = COLORS.Text}):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			if data.value ~= opt then
				TweenService:Create(btn, TweenInfo.new(0.1), {TextColor3 = COLORS.Inactive}):Play()
			end
		end)
	end

	-- Линия с градиентом
	local dividerLine = Instance.new("Frame")
	dividerLine.Size = UDim2.new(1, -20, 0, 1)
	dividerLine.Position = UDim2.new(0, 10, 0, 38)
	dividerLine.BackgroundColor3 = sectionColors.accentDim
	dividerLine.BorderSizePixel = 0
	dividerLine.Parent = innerFrame

	local lineGradient = Instance.new("UIGradient")
	lineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.8)
	})
	lineGradient.Parent = dividerLine

	-- Описание параметра
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -24, 0, 20)
	descLabel.Position = UDim2.new(0, 12, 0, 45)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = data.desc
	descLabel.TextColor3 = COLORS.TextDim
	descLabel.TextSize = 13
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = innerFrame

	return outerFrame
end

-- === СОЗДАНИЕ SLIDER ===
local function createSlider(data, order)
	local sectionColors = currentSectionColors
	
	-- Внешний фрейм с обводкой
	local outerFrame = Instance.new("Frame")
	outerFrame.Name = "Slider_" .. data.name
	outerFrame.Size = UDim2.new(1, -4, 0, 85)
	outerFrame.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
	outerFrame.BorderSizePixel = 0
	outerFrame.LayoutOrder = order
	outerFrame.Parent = contentFrame

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = sectionColors.accentDim
	outerStroke.Thickness = 1
	outerStroke.Parent = outerFrame

	-- Внутренний фрейм с обводкой
	local innerFrame = Instance.new("Frame")
	innerFrame.Size = UDim2.new(1, -6, 1, -6)
	innerFrame.Position = UDim2.new(0, 3, 0, 3)
	innerFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 30)
	innerFrame.BorderSizePixel = 0
	innerFrame.Parent = outerFrame

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = sectionColors.accentDark
	innerStroke.Thickness = 1
	innerStroke.Parent = innerFrame

	-- Название параметра
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.35, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 12, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.name
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = innerFrame

	-- Слайдер с сегментами
	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(0, 180, 0, 14)
	sliderBg.Position = UDim2.new(1, -240, 0, 12)
	sliderBg.BackgroundTransparency = 1
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = innerFrame

	-- Создаем сегменты
	local segmentCount = 30
	local segmentWidth = 180 / segmentCount
	local segments = {}

	for i = 1, segmentCount do
		local segment = Instance.new("Frame")
		segment.Size = UDim2.new(0, segmentWidth - 1, 1, 0)
		segment.Position = UDim2.new(0, (i - 1) * segmentWidth, 0, 0)
		segment.BackgroundColor3 = (i / segmentCount) <= data.value and sectionColors.accent or COLORS.SliderBg
		segment.BorderSizePixel = 0
		segment.Parent = sliderBg
		segments[i] = segment
	end

	-- Кнопка справа (MUTE для звука, RESET для других)
	local btnText = data.btnText or "MUTE"
	local defaultValue = data.btnText and 0.5 or 0
	
	local actionBtn = Instance.new("TextButton")
	actionBtn.Size = UDim2.new(0, 50, 0, 24)
	actionBtn.Position = UDim2.new(1, -55, 0, 6)
	actionBtn.BackgroundTransparency = 1
	actionBtn.Text = btnText
	actionBtn.TextColor3 = data.value == defaultValue and sectionColors.accent or COLORS.Inactive
	actionBtn.TextSize = 14
	actionBtn.Font = Enum.Font.GothamMedium
	actionBtn.Parent = innerFrame

	-- Линия с градиентом
	local dividerLine = Instance.new("Frame")
	dividerLine.Size = UDim2.new(1, -20, 0, 1)
	dividerLine.Position = UDim2.new(0, 10, 0, 38)
	dividerLine.BackgroundColor3 = sectionColors.accentDim
	dividerLine.BorderSizePixel = 0
	dividerLine.Parent = innerFrame

	local lineGradient = Instance.new("UIGradient")
	lineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.8)
	})
	lineGradient.Parent = dividerLine

	-- Описание параметра
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -24, 0, 20)
	descLabel.Position = UDim2.new(0, 12, 0, 45)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = data.desc
	descLabel.TextColor3 = COLORS.TextDim
	descLabel.TextSize = 13
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = innerFrame

	local dragging = false

	local function updateSlider(val)
		data.value = math.clamp(val, 0, 1)
		for i, segment in ipairs(segments) do
			segment.BackgroundColor3 = (i / segmentCount) <= data.value and sectionColors.accent or COLORS.SliderBg
		end
		actionBtn.TextColor3 = data.value == defaultValue and sectionColors.accent or COLORS.Inactive
	end

	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			local rel = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
			updateSlider(rel)
		end
	end)

	sliderBg.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local rel = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
			updateSlider(rel)
		end
	end)

	actionBtn.MouseButton1Click:Connect(function()
		clickSound:Play()
		updateSlider(defaultValue)
	end)

	actionBtn.MouseEnter:Connect(function()
		hoverSound:Play()
		if data.value ~= defaultValue then
			TweenService:Create(actionBtn, TweenInfo.new(0.1), {TextColor3 = COLORS.Text}):Play()
		end
	end)
	actionBtn.MouseLeave:Connect(function()
		if data.value ~= defaultValue then
			TweenService:Create(actionBtn, TweenInfo.new(0.1), {TextColor3 = COLORS.Inactive}):Play()
		end
	end)

	return outerFrame
end

-- === СОЗДАНИЕ TEXT INPUT (для кодов) ===
local function createTextInput(data, order)
	local sectionColors = currentSectionColors
	
	-- Внешний фрейм с обводкой
	local outerFrame = Instance.new("Frame")
	outerFrame.Name = "TextInput_" .. data.name
	outerFrame.Size = UDim2.new(1, -4, 0, 85)
	outerFrame.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
	outerFrame.BorderSizePixel = 0
	outerFrame.LayoutOrder = order
	outerFrame.Parent = contentFrame

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = sectionColors.accentDim
	outerStroke.Thickness = 1
	outerStroke.Parent = outerFrame

	-- Внутренний фрейм с обводкой
	local innerFrame = Instance.new("Frame")
	innerFrame.Size = UDim2.new(1, -6, 1, -6)
	innerFrame.Position = UDim2.new(0, 3, 0, 3)
	innerFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 30)
	innerFrame.BorderSizePixel = 0
	innerFrame.Parent = outerFrame

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = sectionColors.accentDark
	innerStroke.Thickness = 1
	innerStroke.Parent = innerFrame

	-- Название параметра
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.35, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 12, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.name
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = innerFrame

	-- Поле ввода
	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0, 140, 0, 24)
	inputBox.Position = UDim2.new(1, -210, 0, 8)
	inputBox.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
	inputBox.BorderSizePixel = 0
	inputBox.Text = ""
	inputBox.PlaceholderText = "Enter code..."
	inputBox.PlaceholderColor3 = sectionColors.accentDark
	inputBox.TextColor3 = COLORS.Text
	inputBox.TextSize = 14
	inputBox.Font = Enum.Font.Gotham
	inputBox.ClearTextOnFocus = false
	inputBox.TextTruncate = Enum.TextTruncate.AtEnd
	inputBox.ClipsDescendants = true
	inputBox.Parent = innerFrame

	local inputPadding = Instance.new("UIPadding")
	inputPadding.PaddingLeft = UDim.new(0, 6)
	inputPadding.PaddingRight = UDim.new(0, 6)
	inputPadding.Parent = inputBox

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = sectionColors.accentDim
	inputStroke.Thickness = 1
	inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inputStroke.Parent = inputBox

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 3)
	inputCorner.Parent = inputBox

	-- Кнопка REDEEM
	local redeemBtn = Instance.new("TextButton")
	redeemBtn.Size = UDim2.new(0, 60, 0, 24)
	redeemBtn.Position = UDim2.new(1, -65, 0, 8)
	redeemBtn.BackgroundTransparency = 1
	redeemBtn.Text = "REDEEM"
	redeemBtn.TextColor3 = COLORS.Inactive
	redeemBtn.TextSize = 14
	redeemBtn.Font = Enum.Font.GothamMedium
	redeemBtn.Parent = innerFrame

	-- Линия с градиентом
	local dividerLine = Instance.new("Frame")
	dividerLine.Size = UDim2.new(1, -20, 0, 1)
	dividerLine.Position = UDim2.new(0, 10, 0, 38)
	dividerLine.BackgroundColor3 = sectionColors.accentDim
	dividerLine.BorderSizePixel = 0
	dividerLine.Parent = innerFrame

	local lineGradient = Instance.new("UIGradient")
	lineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.8)
	})
	lineGradient.Parent = dividerLine

	-- Статус код (изначально скрыт)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0, 100, 0, 20)
	statusLabel.Position = UDim2.new(0, 12, 0, 45)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = sectionColors.accent -- зелёный по умолчанию
	statusLabel.TextSize = 13
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Visible = false
	statusLabel.Parent = innerFrame

	-- Описание параметра
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -24, 0, 20)
	descLabel.Position = UDim2.new(0, 12, 0, 45)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = data.desc
	descLabel.TextColor3 = COLORS.TextDim
	descLabel.TextSize = 13
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = innerFrame

	local function showStatus(message, color)
		statusLabel.Text = message
		statusLabel.TextColor3 = color
		statusLabel.Visible = true
		descLabel.Visible = false
		
		task.delay(2, function()
			statusLabel.Visible = false
			descLabel.Visible = true
		end)
	end

	-- Таблицы кодов (вынесены из функции клика)
	local validCodes = {
		["VOIDFORGE"] = true,
		["ECLIPSE"] = true,
		["LEGACY"] = true,
	}
	local expiredCodes = {
		["BETA2024"] = true,
	}
	local usedCodes = {} -- использованные коды игрока

	redeemBtn.MouseButton1Click:Connect(function()
		clickSound:Play()
		local code = inputBox.Text
		
		-- Подсветка кнопки при клике
		redeemBtn.TextColor3 = sectionColors.accent
		task.delay(0.2, function()
			redeemBtn.TextColor3 = COLORS.Inactive
		end)
		
		if code == "" then
			return
		end
		
		local upperCode = code:upper()
		
		if usedCodes[upperCode] then
			showStatus("Already redeemed!", Color3.fromRGB(200, 180, 100))
		elseif expiredCodes[upperCode] then
			showStatus("Code expired!", Color3.fromRGB(200, 100, 100))
		elseif validCodes[upperCode] then
			usedCodes[upperCode] = true -- помечаем код как использованный
			showStatus("Code redeemed!", sectionColors.accent)
			inputBox.Text = ""
		else
			showStatus("Code doesn't exist!", Color3.fromRGB(200, 100, 100))
		end
	end)

	redeemBtn.MouseEnter:Connect(function()
		hoverSound:Play()
		TweenService:Create(redeemBtn, TweenInfo.new(0.1), {TextColor3 = COLORS.Text}):Play()
	end)
	redeemBtn.MouseLeave:Connect(function()
		TweenService:Create(redeemBtn, TweenInfo.new(0.1), {TextColor3 = COLORS.Inactive}):Play()
	end)

	inputBox.Focused:Connect(function()
		TweenService:Create(inputStroke, TweenInfo.new(0.1), {Color = sectionColors.accent}):Play()
	end)

	inputBox.FocusLost:Connect(function()
		TweenService:Create(inputStroke, TweenInfo.new(0.1), {Color = sectionColors.accentDim}):Play()
	end)

	return outerFrame
end

-- === СОЗДАНИЕ ЭЛЕМЕНТОВ ===
local order = 0
for _, data in ipairs(settingsData) do
	order = order + 1
	if data.section then
		createSection(data.section, order)
	elseif data.type == "toggle" then
		createToggle(data, order)
	elseif data.type == "select" then
		createSelect(data, order)
	elseif data.type == "slider" then
		createSlider(data, order)
	elseif data.type == "textinput" then
		createTextInput(data, order)
	end
end

-- === КНОПКА SAVE ===
-- Внешний контейнер
local saveBtnOuter = Instance.new("Frame")
saveBtnOuter.Name = "SaveButtonOuter"
saveBtnOuter.Size = UDim2.new(0, 180, 0, 44)
saveBtnOuter.Position = UDim2.new(0.5, -90, 0.5, 288)
saveBtnOuter.BackgroundTransparency = 1
saveBtnOuter.BorderSizePixel = 0
saveBtnOuter.Parent = settingsGui

local saveOuterStroke = Instance.new("UIStroke")
saveOuterStroke.Color = Color3.fromRGB(0, 255, 255)
saveOuterStroke.Thickness = 2
saveOuterStroke.Parent = saveBtnOuter

-- Кнопка
local saveBtn = Instance.new("TextButton")
saveBtn.Name = "SaveButton"
saveBtn.Size = UDim2.new(1, -4, 1, -4)
saveBtn.Position = UDim2.new(0, 2, 0, 2)
saveBtn.BackgroundColor3 = Color3.fromRGB(15, 5, 30)
saveBtn.BorderSizePixel = 0
saveBtn.Text = "SAVE"
saveBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
saveBtn.TextSize = 18
saveBtn.Font = Enum.Font.GothamBold
saveBtn.Parent = saveBtnOuter

local saveBtnStroke = Instance.new("UIStroke")
saveBtnStroke.Color = Color3.fromRGB(0, 150, 150)
saveBtnStroke.Thickness = 2
saveBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
saveBtnStroke.Parent = saveBtn

-- Угловые изображения для кнопки SAVE (внутри границ)
local saveCornerTL = Instance.new("ImageLabel")
saveCornerTL.Size = UDim2.new(0, 14, 0, 14)
saveCornerTL.Position = UDim2.new(0, 2, 0, 2)
saveCornerTL.BackgroundTransparency = 1
saveCornerTL.Image = "rbxassetid://132921287217893"
saveCornerTL.ImageColor3 = Color3.fromRGB(0, 255, 255)
saveCornerTL.Parent = saveBtn

local saveCornerTR = Instance.new("ImageLabel")
saveCornerTR.Size = UDim2.new(0, 14, 0, 14)
saveCornerTR.Position = UDim2.new(1, -16, 0, 2)
saveCornerTR.BackgroundTransparency = 1
saveCornerTR.Image = "rbxassetid://132921287217893"
saveCornerTR.ImageColor3 = Color3.fromRGB(0, 255, 255)
saveCornerTR.Rotation = 90
saveCornerTR.Parent = saveBtn

local saveCornerBL = Instance.new("ImageLabel")
saveCornerBL.Size = UDim2.new(0, 14, 0, 14)
saveCornerBL.Position = UDim2.new(0, 2, 1, -16)
saveCornerBL.BackgroundTransparency = 1
saveCornerBL.ImageColor3 = Color3.fromRGB(0, 255, 255)
saveCornerBL.Image = "rbxassetid://132921287217893"
saveCornerBL.Rotation = -90
saveCornerBL.Parent = saveBtn

local saveCornerBR = Instance.new("ImageLabel")
saveCornerBR.Size = UDim2.new(0, 14, 0, 14)
saveCornerBR.Position = UDim2.new(1, -16, 1, -16)
saveCornerBR.BackgroundTransparency = 1
saveCornerBR.Image = "rbxassetid://132921287217893"
saveCornerBR.ImageColor3 = Color3.fromRGB(0, 255, 255)
saveCornerBR.Rotation = 180
saveCornerBR.Parent = saveBtn

saveBtn.MouseEnter:Connect(function()
	hoverSound:Play()
	TweenService:Create(saveBtnStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(0, 255, 255)}):Play()
	TweenService:Create(saveBtn, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
end)

saveBtn.MouseLeave:Connect(function()
	TweenService:Create(saveBtnStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(0, 150, 150)}):Play()
	TweenService:Create(saveBtn, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(0, 255, 255)}):Play()
end)

saveBtn.MouseButton1Click:Connect(function()
	clickSound:Play()
end)

-- === БЛОКИРОВКА УПРАВЛЕНИЯ ===
local ContextActionService = game:GetService("ContextActionService")

local controlsDisabled = false
local savedMouseBehavior = nil

local function disableControls()
	if controlsDisabled then return end
	controlsDisabled = true
	
	-- Сохраняем текущие настройки
	savedMouseBehavior = UserInputService.MouseBehavior
	
	-- Блокируем движение
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpHeight = 0
			humanoid.JumpPower = 0
		end
	end
	
	-- Разблокируем мышь для UI (камера остаётся Custom, следует за игроком)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	
	-- Отключаем стандартные контролы движения
	ContextActionService:BindAction(
		"DisableMovement",
		function() return Enum.ContextActionResult.Sink end,
		false,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
	
	-- Блокируем вращение камеры мышью
	ContextActionService:BindAction(
		"DisableCameraRotation",
		function() return Enum.ContextActionResult.Sink end,
		false,
		Enum.UserInputType.MouseMovement,
		Enum.UserInputType.MouseWheel
	)
end

local function enableControls()
	if not controlsDisabled then return end
	controlsDisabled = false
	
	-- Восстанавливаем движение
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			local RunConfig = ReplicatedStorage:FindFirstChild("RunConfig")
			if RunConfig then
				local config = require(RunConfig)
				humanoid.WalkSpeed = config.WalkSpeed or 16
				humanoid.JumpHeight = config.JumpHeight or 7.2
				humanoid.JumpPower = 50
			else
				humanoid.WalkSpeed = 16
				humanoid.JumpHeight = 7.2
				humanoid.JumpPower = 50
			end
		end
	end
	
	-- Восстанавливаем мышь (зависит от шифтлока)
	local isShiftLocked = player:FindFirstChild("IsShiftLocked")
	if isShiftLocked and isShiftLocked.Value then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = savedMouseBehavior or Enum.MouseBehavior.Default
	end
	
	-- Включаем контролы обратно
	ContextActionService:UnbindAction("DisableMovement")
	ContextActionService:UnbindAction("DisableCameraRotation")
end

-- === АНИМАЦИИ ===
local function openSettings()
	if settingsOpen then return end
	settingsOpen = true
	settingsOpenValue.Value = true
	settingsGui.Enabled = true
	
	-- Блокируем управление
	disableControls()

	settingsBlur.Enabled = true
	TweenService:Create(settingsBlur, TweenInfo.new(0.4), {Size = 15}):Play()
	TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.5}):Play()

	mainPanel.Position = UDim2.new(0.5, -225, 0, -600)
	saveBtnOuter.Position = UDim2.new(0.5, -85, 0, -600 + 550 + 15)
	
	TweenService:Create(mainPanel, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -225, 0.5, -275)
	}):Play()
	TweenService:Create(saveBtnOuter, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -85, 0.5, 290)
	}):Play()
end

local function closeSettings()
	if not settingsOpen then return end
	settingsOpen = false
	settingsOpenValue.Value = false
	
	-- Восстанавливаем управление
	enableControls()

	TweenService:Create(settingsBlur, TweenInfo.new(0.3), {Size = 0}):Play()
	task.delay(0.3, function()
		if not settingsOpen then settingsBlur.Enabled = false end
	end)

	TweenService:Create(overlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()

	TweenService:Create(mainPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5, -225, 1, 100)
	}):Play()
	TweenService:Create(saveBtnOuter, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5, -85, 1, 100 + 550 + 15)
	}):Play()

	task.delay(0.35, function()
		if not settingsOpen then
			settingsGui.Enabled = false
			mouse.Icon = ""
		end
	end)
end

-- === ЗАКРЫТИЕ НА TAB ===
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Tab and settingsOpen then
		closeSettings()
	end
end)

-- === ЗАКРЫТИЕ ПО КЛИКУ НА OVERLAY ===
overlay.MouseButton1Click:Connect(function()
	if settingsOpen then
		closeSettings()
	end
end)

-- === МОДУЛЬ ===
local SettingsMenu = {}
function SettingsMenu.Open() openSettings() end
function SettingsMenu.Close() closeSettings() end
function SettingsMenu.Toggle()
	if settingsOpen then closeSettings() else openSettings() end
end
function SettingsMenu.IsOpen() return settingsOpen end

return SettingsMenu
