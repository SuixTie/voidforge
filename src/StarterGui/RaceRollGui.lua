--[[
	RaceRollGui - Меню выбора расы с системой ролла
	Стиль: Cyberpunk - неоновые цвета, тёмный фон
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RacesConfig = require(ReplicatedStorage:WaitForChild("RacesConfig"))

-- === ЗВУКИ ===
local function playSound(soundId, volume, pitch)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	return sound
end

-- === СОСТОЯНИЕ ===
local currentRace = nil
local spinsLeft = 6767
local isRolling = false

-- === ЦВЕТА CYBERPUNK ===
local COLORS = {
	Background = Color3.fromRGB(8, 10, 15),
	Panel = Color3.fromRGB(20, 22, 30),
	PanelBorder = Color3.fromRGB(0, 255, 200),      -- Cyan neon
	Accent = Color3.fromRGB(255, 0, 100),           -- Pink neon
	AccentAlt = Color3.fromRGB(0, 200, 255),        -- Blue neon
	Text = Color3.fromRGB(255, 255, 255),           -- Белый текст
	TextDim = Color3.fromRGB(200, 210, 230),        -- Светло-серый (читаемый!)
	Button = Color3.fromRGB(25, 30, 40),
	ButtonHover = Color3.fromRGB(35, 45, 60),
	ButtonAccent = Color3.fromRGB(255, 0, 100),
	Close = Color3.fromRGB(255, 50, 80),
	Glow = Color3.fromRGB(0, 255, 200),
}

-- === СОЗДАНИЕ GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RaceRollGui"
screenGui.ResetOnSpawn = true  -- Пересоздаём при респавне
screenGui.Enabled = false
screenGui.Parent = playerGui
screenGui.IgnoreGuiInset = true

-- Затемнение фона
local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = COLORS.Background
background.BackgroundTransparency = 0.15
background.BorderSizePixel = 0
background.Parent = screenGui

-- Сканлайны эффект
local scanlines = Instance.new("Frame")
scanlines.Name = "Scanlines"
scanlines.Size = UDim2.new(1, 0, 1, 0)
scanlines.BackgroundTransparency = 0.97
scanlines.BackgroundColor3 = Color3.new(1, 1, 1)
scanlines.BorderSizePixel = 0
scanlines.Parent = screenGui

-- === ЗАГОЛОВОК ===
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(0, 400, 0, 25)
titleLabel.Position = UDim2.new(0.5, -200, 0, 35)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Current Race:"
titleLabel.TextColor3 = COLORS.PanelBorder
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextStrokeTransparency = 0.7
titleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
titleLabel.Parent = screenGui

local raceNameLabel = Instance.new("TextLabel")
raceNameLabel.Name = "RaceName"
raceNameLabel.Size = UDim2.new(0, 500, 0, 55)
raceNameLabel.Position = UDim2.new(0.5, -250, 0, 55)
raceNameLabel.BackgroundTransparency = 1
raceNameLabel.Text = "SURVIVOR"
raceNameLabel.TextColor3 = COLORS.Accent
raceNameLabel.TextSize = 48
raceNameLabel.Font = Enum.Font.GothamBlack
raceNameLabel.TextStrokeTransparency = 0.5
raceNameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
raceNameLabel.Parent = screenGui

-- Glow эффект для названия расы
local raceNameGlow = Instance.new("TextLabel")
raceNameGlow.Name = "RaceNameGlow"
raceNameGlow.Size = UDim2.new(0, 500, 0, 55)
raceNameGlow.Position = UDim2.new(0.5, -250, 0, 55)
raceNameGlow.BackgroundTransparency = 1
raceNameGlow.Text = "SURVIVOR"
raceNameGlow.TextColor3 = COLORS.Accent
raceNameGlow.TextTransparency = 0.6
raceNameGlow.TextSize = 52
raceNameGlow.Font = Enum.Font.GothamBlack
raceNameGlow.ZIndex = 0
raceNameGlow.Parent = screenGui


-- === КНОПКА ЗАКРЫТЬ ===
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 100, 0, 35)
closeButton.Position = UDim2.new(1, -120, 0, 20)
closeButton.BackgroundColor3 = COLORS.Button
closeButton.Text = "[ CLOSE ]"
closeButton.TextColor3 = COLORS.Close
closeButton.TextSize = 14
closeButton.Font = Enum.Font.Code
closeButton.Parent = screenGui

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = COLORS.Close
closeStroke.Thickness = 1
closeStroke.Parent = closeButton

-- === ЛЕВАЯ ПАНЕЛЬ (Race Stats) ===
local leftPanel = Instance.new("Frame")
leftPanel.Name = "LeftPanel"
leftPanel.Size = UDim2.new(0, 280, 0, 360)
leftPanel.Position = UDim2.new(0, 25, 0.5, -180)
leftPanel.BackgroundColor3 = COLORS.Panel
leftPanel.BackgroundTransparency = 0.1
leftPanel.BorderSizePixel = 0
leftPanel.Parent = screenGui

local leftStroke = Instance.new("UIStroke")
leftStroke.Color = COLORS.PanelBorder
leftStroke.Thickness = 1
leftStroke.Transparency = 0.3
leftStroke.Parent = leftPanel

-- Декоративные углы
local leftCornerTL = Instance.new("Frame")
leftCornerTL.Size = UDim2.new(0, 15, 0, 2)
leftCornerTL.Position = UDim2.new(0, 0, 0, 0)
leftCornerTL.BackgroundColor3 = COLORS.PanelBorder
leftCornerTL.BorderSizePixel = 0
leftCornerTL.Parent = leftPanel

local leftCornerTL2 = Instance.new("Frame")
leftCornerTL2.Size = UDim2.new(0, 2, 0, 15)
leftCornerTL2.Position = UDim2.new(0, 0, 0, 0)
leftCornerTL2.BackgroundColor3 = COLORS.PanelBorder
leftCornerTL2.BorderSizePixel = 0
leftCornerTL2.Parent = leftPanel

local leftTitle = Instance.new("TextLabel")
leftTitle.Size = UDim2.new(1, 0, 0, 35)
leftTitle.Position = UDim2.new(0, 0, 0, 0)
leftTitle.BackgroundColor3 = COLORS.PanelBorder
leftTitle.BackgroundTransparency = 0.85
leftTitle.Text = "  >> RACE STATS"
leftTitle.TextColor3 = COLORS.PanelBorder
leftTitle.TextSize = 16
leftTitle.Font = Enum.Font.GothamBold
leftTitle.TextXAlignment = Enum.TextXAlignment.Left
leftTitle.TextStrokeTransparency = 0.8
leftTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
leftTitle.Parent = leftPanel

-- Контейнер для перков
local perksContainer = Instance.new("ScrollingFrame")
perksContainer.Name = "PerksContainer"
perksContainer.Size = UDim2.new(1, -16, 1, -50)
perksContainer.Position = UDim2.new(0, 8, 0, 42)
perksContainer.BackgroundTransparency = 1
perksContainer.ScrollBarThickness = 3
perksContainer.ScrollBarImageColor3 = COLORS.PanelBorder
perksContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
perksContainer.Parent = leftPanel

local perksLayout = Instance.new("UIListLayout")
perksLayout.SortOrder = Enum.SortOrder.LayoutOrder
perksLayout.Padding = UDim.new(0, 6)
perksLayout.Parent = perksContainer


-- === ЦЕНТРАЛЬНАЯ ОБЛАСТЬ (Viewport с персонажем) ===
local centerFrame = Instance.new("Frame")
centerFrame.Name = "CenterFrame"
centerFrame.Size = UDim2.new(0, 380, 0, 420)
centerFrame.Position = UDim2.new(0.5, -190, 0.5, -230)
centerFrame.BackgroundColor3 = COLORS.Panel
centerFrame.BackgroundTransparency = 0.5
centerFrame.BorderSizePixel = 0
centerFrame.Parent = screenGui

local centerStroke = Instance.new("UIStroke")
centerStroke.Color = COLORS.Accent
centerStroke.Thickness = 1
centerStroke.Transparency = 0.5
centerStroke.Parent = centerFrame

-- Hexagon pattern overlay (декоративный)
local hexOverlay = Instance.new("Frame")
hexOverlay.Size = UDim2.new(1, 0, 0, 3)
hexOverlay.Position = UDim2.new(0, 0, 1, -3)
hexOverlay.BackgroundColor3 = COLORS.Accent
hexOverlay.BackgroundTransparency = 0.3
hexOverlay.BorderSizePixel = 0
hexOverlay.Parent = centerFrame

local viewportFrame = Instance.new("ViewportFrame")
viewportFrame.Name = "CharacterViewport"
viewportFrame.Size = UDim2.new(1, 0, 1, 0)
viewportFrame.Position = UDim2.new(0, 0, 0, 0)
viewportFrame.BackgroundTransparency = 1
viewportFrame.Parent = centerFrame

-- Камера для viewport
local viewportCamera = Instance.new("Camera")
viewportCamera.Parent = viewportFrame
viewportFrame.CurrentCamera = viewportCamera

-- WorldModel для клонирования персонажа
local worldModel = Instance.new("WorldModel")
worldModel.Parent = viewportFrame

-- Освещение для viewport
local viewportLight = Instance.new("PointLight")
viewportLight.Brightness = 2
viewportLight.Range = 20
viewportLight.Color = Color3.new(1, 1, 1)

local viewportLight2 = Instance.new("PointLight")
viewportLight2.Brightness = 1
viewportLight2.Range = 15
viewportLight2.Color = COLORS.PanelBorder

-- Переменные для вращения
local characterClone = nil
local rotationAngle = 0
local isDragging = false
local lastMouseX = 0

-- Функция клонирования персонажа
local function cloneCharacter()
	for _, child in ipairs(worldModel:GetChildren()) do
		child:Destroy()
	end
	characterClone = nil

	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local success, clone = pcall(function()
		return character:Clone()
	end)

	if not success or not clone then return end

	characterClone = clone

	for _, descendant in ipairs(characterClone:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end

	local humanoid = characterClone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	characterClone.Parent = worldModel

	local rootPart = characterClone:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.Anchored = true
		rootPart.CFrame = CFrame.new(0, 0, 0)
		viewportCamera.CFrame = CFrame.new(0, 2, 8) * CFrame.Angles(math.rad(-5), 0, 0)

		-- Добавляем освещение к персонажу
		local light1 = viewportLight:Clone()
		light1.Parent = rootPart

		local light2 = viewportLight2:Clone()
		light2.Parent = rootPart
	end

	-- Добавляем пол для теней (опционально)
	local floor = Instance.new("Part")
	floor.Size = Vector3.new(10, 0.1, 10)
	floor.Position = Vector3.new(0, -3, 0)
	floor.Anchored = true
	floor.Transparency = 1
	floor.Parent = worldModel
end

-- Вращение персонажа мышью
centerFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = true
		lastMouseX = input.Position.X
	end
end)

centerFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = false
	end
end)

centerFrame.InputChanged:Connect(function(input)
	if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local deltaX = input.Position.X - lastMouseX
		rotationAngle = rotationAngle + deltaX * 0.5
		lastMouseX = input.Position.X

		if characterClone then
			local rootPart = characterClone:FindFirstChild("HumanoidRootPart")
			if rootPart then
				rootPart.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(rotationAngle), 0)
			end
		end
	end
end)


-- === ПРАВАЯ ПАНЕЛЬ (Race Chances) ===
local rightPanel = Instance.new("Frame")
rightPanel.Name = "RightPanel"
rightPanel.Size = UDim2.new(0, 220, 0, 360)
rightPanel.Position = UDim2.new(1, -245, 0.5, -180)
rightPanel.BackgroundColor3 = COLORS.Panel
rightPanel.BackgroundTransparency = 0.1
rightPanel.BorderSizePixel = 0
rightPanel.Parent = screenGui

local rightStroke = Instance.new("UIStroke")
rightStroke.Color = COLORS.AccentAlt
rightStroke.Thickness = 1
rightStroke.Transparency = 0.3
rightStroke.Parent = rightPanel

-- Декоративные углы
local rightCornerTR = Instance.new("Frame")
rightCornerTR.Size = UDim2.new(0, 15, 0, 2)
rightCornerTR.Position = UDim2.new(1, -15, 0, 0)
rightCornerTR.BackgroundColor3 = COLORS.AccentAlt
rightCornerTR.BorderSizePixel = 0
rightCornerTR.Parent = rightPanel

local rightCornerTR2 = Instance.new("Frame")
rightCornerTR2.Size = UDim2.new(0, 2, 0, 15)
rightCornerTR2.Position = UDim2.new(1, -2, 0, 0)
rightCornerTR2.BackgroundColor3 = COLORS.AccentAlt
rightCornerTR2.BorderSizePixel = 0
rightCornerTR2.Parent = rightPanel

local rightTitle = Instance.new("TextLabel")
rightTitle.Size = UDim2.new(1, 0, 0, 35)
rightTitle.Position = UDim2.new(0, 0, 0, 0)
rightTitle.BackgroundColor3 = COLORS.AccentAlt
rightTitle.BackgroundTransparency = 0.85
rightTitle.Text = "  >> RACE CHANCES"
rightTitle.TextColor3 = COLORS.AccentAlt
rightTitle.TextSize = 14
rightTitle.Font = Enum.Font.GothamBold
rightTitle.TextXAlignment = Enum.TextXAlignment.Left
rightTitle.TextStrokeTransparency = 0.8
rightTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
rightTitle.Parent = rightPanel

-- Список шансов
local chancesContainer = Instance.new("ScrollingFrame")
chancesContainer.Name = "ChancesContainer"
chancesContainer.Size = UDim2.new(1, -16, 1, -45)
chancesContainer.Position = UDim2.new(0, 8, 0, 40)
chancesContainer.BackgroundTransparency = 1
chancesContainer.ScrollBarThickness = 3
chancesContainer.ScrollBarImageColor3 = COLORS.AccentAlt
chancesContainer.Parent = rightPanel

local chancesLayout = Instance.new("UIListLayout")
chancesLayout.SortOrder = Enum.SortOrder.LayoutOrder
chancesLayout.Padding = UDim.new(0, 2)
chancesLayout.Parent = chancesContainer

-- Заполняем список шансов
for i, race in ipairs(RacesConfig.Races) do
	local chanceLabel = Instance.new("TextLabel")
	chanceLabel.Name = "Chance_" .. race.Name
	chanceLabel.Size = UDim2.new(1, 0, 0, 22)
	chanceLabel.BackgroundTransparency = 1
	chanceLabel.Text = "• " .. race.Name .. " (" .. race.Chance .. "%)"
	chanceLabel.TextColor3 = RacesConfig.RarityColors[race.Rarity]
	chanceLabel.TextSize = 14
	chanceLabel.Font = Enum.Font.GothamMedium
	chanceLabel.TextXAlignment = Enum.TextXAlignment.Left
	chanceLabel.TextStrokeTransparency = 0.5
	chanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	chanceLabel.LayoutOrder = i
	chanceLabel.Parent = chancesContainer
end

chancesContainer.CanvasSize = UDim2.new(0, 0, 0, #RacesConfig.Races * 24)


-- === НИЖНЯЯ ПАНЕЛЬ (Кнопки) ===
local spinsLabel = Instance.new("TextLabel")
spinsLabel.Name = "SpinsLabel"
spinsLabel.Size = UDim2.new(0, 200, 0, 25)
spinsLabel.Position = UDim2.new(0.5, -100, 1, -125)
spinsLabel.BackgroundTransparency = 1
spinsLabel.Text = "Spins: " .. spinsLeft
spinsLabel.TextColor3 = COLORS.PanelBorder
spinsLabel.TextSize = 18
spinsLabel.Font = Enum.Font.GothamBold
spinsLabel.TextStrokeTransparency = 0.7
spinsLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
spinsLabel.Parent = screenGui

-- Контейнер для кнопок
local buttonsContainer = Instance.new("Frame")
buttonsContainer.Name = "ButtonsContainer"
buttonsContainer.Size = UDim2.new(0, 480, 0, 55)
buttonsContainer.Position = UDim2.new(0.5, -240, 1, -95)
buttonsContainer.BackgroundTransparency = 1
buttonsContainer.Parent = screenGui

-- Кнопка Reroll
local rerollButton = Instance.new("TextButton")
rerollButton.Name = "RerollButton"
rerollButton.Size = UDim2.new(0, 220, 0, 55)
rerollButton.Position = UDim2.new(0, 0, 0, 0)
rerollButton.BackgroundColor3 = COLORS.Button
rerollButton.Text = "REROLL"
rerollButton.TextColor3 = COLORS.Accent
rerollButton.TextSize = 22
rerollButton.Font = Enum.Font.GothamBold
rerollButton.Parent = buttonsContainer

local rerollStroke = Instance.new("UIStroke")
rerollStroke.Color = COLORS.Accent
rerollStroke.Thickness = 1
rerollStroke.Parent = rerollButton

-- Кнопка Buy Rerolls
local buyButton = Instance.new("TextButton")
buyButton.Name = "BuyButton"
buyButton.Size = UDim2.new(0, 140, 0, 55)
buyButton.Position = UDim2.new(0, 230, 0, 0)
buyButton.BackgroundColor3 = COLORS.Button
buyButton.Text = "Buy Spins"
buyButton.TextColor3 = COLORS.AccentAlt
buyButton.TextSize = 15
buyButton.Font = Enum.Font.GothamMedium
buyButton.Parent = buttonsContainer

local buyStroke = Instance.new("UIStroke")
buyStroke.Color = COLORS.AccentAlt
buyStroke.Thickness = 1
buyStroke.Parent = buyButton

-- Кнопка Quick Roll
local quickRollButton = Instance.new("TextButton")
quickRollButton.Name = "QuickRollButton"
quickRollButton.Size = UDim2.new(0, 100, 0, 55)
quickRollButton.Position = UDim2.new(0, 380, 0, 0)
quickRollButton.BackgroundColor3 = COLORS.Button
quickRollButton.Text = "Quick"
quickRollButton.TextColor3 = COLORS.PanelBorder
quickRollButton.TextSize = 15
quickRollButton.Font = Enum.Font.GothamMedium
quickRollButton.Parent = buttonsContainer

local quickStroke = Instance.new("UIStroke")
quickStroke.Color = COLORS.PanelBorder
quickStroke.Thickness = 1
quickStroke.Parent = quickRollButton


-- === ФУНКЦИИ ===
local function updatePerks(race)
	for _, child in ipairs(perksContainer:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for i, perk in ipairs(race.Perks) do
		local perkFrame = Instance.new("Frame")
		perkFrame.Name = "Perk_" .. i
		perkFrame.Size = UDim2.new(1, 0, 0, 60)
		perkFrame.BackgroundColor3 = COLORS.Panel
		perkFrame.BackgroundTransparency = 0.2
		perkFrame.LayoutOrder = i
		perkFrame.Parent = perksContainer

		local perkStroke = Instance.new("UIStroke")
		perkStroke.Color = RacesConfig.RarityColors[race.Rarity]
		perkStroke.Thickness = 1
		perkStroke.Transparency = 0.5
		perkStroke.Parent = perkFrame

		local perkName = Instance.new("TextLabel")
		perkName.Size = UDim2.new(1, -10, 0, 24)
		perkName.Position = UDim2.new(0, 5, 0, 4)
		perkName.BackgroundTransparency = 1
		perkName.Text = perk.Name
		perkName.TextColor3 = Color3.new(1, 1, 1)  -- Белый
		perkName.TextSize = 16
		perkName.Font = Enum.Font.GothamBold
		perkName.TextXAlignment = Enum.TextXAlignment.Left
		perkName.TextStrokeTransparency = 0.5
		perkName.TextStrokeColor3 = Color3.new(0, 0, 0)
		perkName.Parent = perkFrame

		local perkDesc = Instance.new("TextLabel")
		perkDesc.Size = UDim2.new(1, -10, 0, 30)
		perkDesc.Position = UDim2.new(0, 5, 0, 28)
		perkDesc.BackgroundTransparency = 1
		perkDesc.Text = perk.Description
		perkDesc.TextColor3 = COLORS.TextDim
		perkDesc.TextSize = 14
		perkDesc.Font = Enum.Font.Gotham
		perkDesc.TextXAlignment = Enum.TextXAlignment.Left
		perkDesc.TextWrapped = true
		perkDesc.TextStrokeTransparency = 0.6
		perkDesc.TextStrokeColor3 = Color3.new(0, 0, 0)
		perkDesc.Parent = perkFrame
	end

	perksContainer.CanvasSize = UDim2.new(0, 0, 0, #race.Perks * 66)
end

local function setRace(race)
	currentRace = race
	raceNameLabel.Text = string.upper(race.Name)
	raceNameLabel.TextColor3 = RacesConfig.RarityColors[race.Rarity]
	raceNameGlow.Text = string.upper(race.Name)
	raceNameGlow.TextColor3 = RacesConfig.RarityColors[race.Rarity]
	updatePerks(race)
end

-- Анимация ролла с глитч-эффектом
local function rollAnimation()
	if isRolling or spinsLeft <= 0 then return end
	isRolling = true

	-- Звук начала ролла
	playSound(RacesConfig.Sounds.RollStart, 0.4, 1)

	local rollCount = 25 + math.random(5, 15)
	local delay = 0.04

	for i = 1, rollCount do
		local randomRace = RacesConfig.Races[math.random(1, #RacesConfig.Races)]
		raceNameLabel.Text = string.upper(randomRace.Name)
		raceNameLabel.TextColor3 = RacesConfig.RarityColors[randomRace.Rarity]
		raceNameGlow.Text = string.upper(randomRace.Name)
		raceNameGlow.TextColor3 = RacesConfig.RarityColors[randomRace.Rarity]

		-- Звук тика при прокрутке
		local pitch = 0.8 + (i / rollCount) * 0.4  -- Повышается к концу
		playSound(RacesConfig.Sounds.Tick, 0.15, pitch)

		-- Глитч эффект
		if math.random() > 0.7 then
			raceNameLabel.Position = UDim2.new(0.5, -250 + math.random(-3, 3), 0, 55 + math.random(-2, 2))
		else
			raceNameLabel.Position = UDim2.new(0.5, -250, 0, 55)
		end

		if i > rollCount - 10 then
			delay = delay + 0.025
		end
		if i > rollCount - 5 then
			delay = delay + 0.04
		end

		task.wait(delay)
	end

	raceNameLabel.Position = UDim2.new(0.5, -250, 0, 55)

	-- Финальный результат
	local finalRace = RacesConfig.Roll()
	setRace(finalRace)

	-- Звук выпадения в зависимости от редкости
	local dropSound = RacesConfig.Sounds[finalRace.Rarity] or RacesConfig.Sounds.Common
	local dropVolume = 0.5
	local dropPitch = 1

	-- Более эпичные звуки для редких рас
	if finalRace.Rarity == "Legendary" or finalRace.Rarity == "Mythic" or finalRace.Rarity == "Divine" then
		dropVolume = 0.8
		dropPitch = 0.9
	elseif finalRace.Rarity == "Epic" then
		dropVolume = 0.7
		dropPitch = 0.95
	elseif finalRace.Rarity == "Rare" then
		dropVolume = 0.6
	end

	playSound(dropSound, dropVolume, dropPitch)

	-- Эффект вспышки
	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = RacesConfig.RarityColors[finalRace.Rarity]
	flash.BackgroundTransparency = 0.8
	flash.Parent = screenGui

	TweenService:Create(flash, TweenInfo.new(0.5), {
		BackgroundTransparency = 1
	}):Play()

	task.delay(0.5, function()
		flash:Destroy()
	end)

	spinsLeft = spinsLeft - 1
	spinsLabel.Text = "Spins: " .. spinsLeft

	isRolling = false
end

-- Быстрый ролл
local function quickRoll()
	if isRolling or spinsLeft <= 0 then return end
	isRolling = true

	local finalRace = RacesConfig.Roll()
	setRace(finalRace)

	-- Звук выпадения
	local dropSound = RacesConfig.Sounds[finalRace.Rarity] or RacesConfig.Sounds.Common
	playSound(dropSound, 0.5, 1)

	raceNameLabel.TextTransparency = 1
	raceNameGlow.TextTransparency = 1
	TweenService:Create(raceNameLabel, TweenInfo.new(0.2), {
		TextTransparency = 0
	}):Play()
	TweenService:Create(raceNameGlow, TweenInfo.new(0.2), {
		TextTransparency = 0.6
	}):Play()

	spinsLeft = spinsLeft - 1
	spinsLabel.Text = "Spins: " .. spinsLeft

	isRolling = false
end


-- === СОБЫТИЯ ===
rerollButton.MouseButton1Click:Connect(rollAnimation)
quickRollButton.MouseButton1Click:Connect(quickRoll)

closeButton.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

-- Hover эффекты с неоновым свечением
rerollButton.MouseEnter:Connect(function()
	TweenService:Create(rerollButton, TweenInfo.new(0.1), {
		BackgroundColor3 = Color3.fromRGB(40, 20, 30)
	}):Play()
	TweenService:Create(rerollStroke, TweenInfo.new(0.1), {
		Thickness = 3
	}):Play()
end)

rerollButton.MouseLeave:Connect(function()
	TweenService:Create(rerollButton, TweenInfo.new(0.1), {
		BackgroundColor3 = COLORS.Button
	}):Play()
	TweenService:Create(rerollStroke, TweenInfo.new(0.1), {
		Thickness = 1
	}):Play()
end)

buyButton.MouseEnter:Connect(function()
	TweenService:Create(buyButton, TweenInfo.new(0.1), {
		BackgroundColor3 = Color3.fromRGB(20, 35, 45)
	}):Play()
end)

buyButton.MouseLeave:Connect(function()
	TweenService:Create(buyButton, TweenInfo.new(0.1), {
		BackgroundColor3 = COLORS.Button
	}):Play()
end)

quickRollButton.MouseEnter:Connect(function()
	TweenService:Create(quickRollButton, TweenInfo.new(0.1), {
		BackgroundColor3 = Color3.fromRGB(20, 40, 35)
	}):Play()
end)

quickRollButton.MouseLeave:Connect(function()
	TweenService:Create(quickRollButton, TweenInfo.new(0.1), {
		BackgroundColor3 = COLORS.Button
	}):Play()
end)

closeButton.MouseEnter:Connect(function()
	TweenService:Create(closeStroke, TweenInfo.new(0.1), {
		Thickness = 2
	}):Play()
end)

closeButton.MouseLeave:Connect(function()
	TweenService:Create(closeStroke, TweenInfo.new(0.1), {
		Thickness = 1
	}):Play()
end)

-- Автоматическое обновление клона
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	if screenGui.Enabled then
		cloneCharacter()
	end
end)

-- Инициализация
setRace(RacesConfig.Races[1])

-- Открытие меню по клавише R
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.R then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			cloneCharacter()
		end
	end
end)

-- Автовращение персонажа + пульсация glow
local glowPulse = 0
RunService.RenderStepped:Connect(function(dt)
	if screenGui.Enabled then
		-- Вращение персонажа
		if characterClone and not isDragging then
			rotationAngle = rotationAngle + dt * 15
			local rootPart = characterClone:FindFirstChild("HumanoidRootPart")
			if rootPart then
				rootPart.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(rotationAngle), 0)
			end
		end

		-- Пульсация glow эффекта
		glowPulse = glowPulse + dt * 2
		local pulse = 0.6 + math.sin(glowPulse) * 0.15
		raceNameGlow.TextTransparency = pulse
	end
end)

print("--- RaceRollGui [CYBERPUNK] loaded (Press R to open) ---")
