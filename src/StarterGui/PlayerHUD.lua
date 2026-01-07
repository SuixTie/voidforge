--[[
	PlayerHUD - Health Bar, Stamina Bar, Level Box, UI Buttons
	Всё в одном 3D GUI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- === СКРЫВАЕМ СТАНДАРТНЫЙ UI ROBLOX ===
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- Отключаем стандартный инвентарь

-- Подключаем Screen3D
local Screen3D = require(ReplicatedStorage:WaitForChild("Screen3D"))

-- === СОСТОЯНИЕ ===
local maxHealth = 100
local currentHealth = 100
local maxStamina = 100
local currentStamina = 100
local playerLevel = 1

-- === ЦВЕТА (Неон-Аниме Style) ===
-- Референсы: Persona 5, Genshin Impact, SAO
local COLORS = {
	HealthBar = Color3.fromRGB(255, 50, 100),       -- Розовый неон
	HealthBarLow = Color3.fromRGB(150, 30, 60),     -- Тёмно-розовый
	StaminaBar = Color3.fromRGB(0, 255, 255),       -- Циан неон
	BarBg = Color3.fromRGB(30, 30, 50),             -- Тёмно-синий фон
	LevelBox = Color3.fromRGB(15, 15, 35),          -- Тёмный фон
	Text = Color3.fromRGB(255, 255, 255),           -- Белый текст
	Accent = Color3.fromRGB(0, 255, 255),           -- Циан акцент
	AccentPink = Color3.fromRGB(255, 0, 255),       -- Розовый акцент
	Gold = Color3.fromRGB(255, 215, 0),             -- Золотой
}

-- === СОЗДАНИЕ GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerHUD"
screenGui.ResetOnSpawn = true
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- === ГЛАВНЫЙ КОНТЕЙНЕР ===
local hudContainer = Instance.new("Frame")
hudContainer.Name = "HUDContainer"
hudContainer.Size = UDim2.new(0, 400, 0, 100)
hudContainer.Position = UDim2.new(0, 20, 1, -120)
hudContainer.BackgroundTransparency = 1
hudContainer.Parent = screenGui

-- === LEVEL BOX ===
local levelBoxContainer = Instance.new("Frame")
levelBoxContainer.Name = "LevelBoxContainer"
levelBoxContainer.Size = UDim2.new(0, 60, 0, 60)
levelBoxContainer.Position = UDim2.new(0, 0, 0, 20)
levelBoxContainer.BackgroundTransparency = 1
levelBoxContainer.Parent = hudContainer

local levelBox = Instance.new("Frame")
levelBox.Name = "LevelBox"
levelBox.Size = UDim2.new(0, 45, 0, 45)
levelBox.Position = UDim2.new(0.5, -22, 0.5, -22)
levelBox.BackgroundColor3 = COLORS.LevelBox
levelBox.BorderSizePixel = 0
levelBox.Rotation = 45
levelBox.Parent = levelBoxContainer

local levelBoxStroke = Instance.new("UIStroke")
levelBoxStroke.Color = COLORS.Accent
levelBoxStroke.Thickness = 2
levelBoxStroke.Parent = levelBox

local strokeGradient = Instance.new("UIGradient")
strokeGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.8),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0.8)
})
strokeGradient.Rotation = -45
strokeGradient.Parent = levelBoxStroke

local levelBoxText = Instance.new("TextLabel")
levelBoxText.Name = "LevelBoxText"
levelBoxText.Size = UDim2.new(1, 0, 1, 0)
levelBoxText.BackgroundTransparency = 1
levelBoxText.Text = tostring(playerLevel)
levelBoxText.TextColor3 = COLORS.Text
levelBoxText.TextSize = 22
levelBoxText.Font = Enum.Font.GothamBold
levelBoxText.Parent = levelBoxContainer

-- === ФУНКЦИЯ СОЗДАНИЯ БАРА ===
local function createBar(name, yPos, height, width, barColor, xPos)
	local cutSize = height
	local canvas = Instance.new("Frame")
	canvas.Name = name .. "Canvas"
	canvas.Size = UDim2.new(0, width, 0, height)
	canvas.Position = UDim2.new(0, xPos, 0, yPos)
	canvas.BackgroundTransparency = 1
	canvas.ClipsDescendants = true
	canvas.Parent = hudContainer

	local barBg = Instance.new("Frame")
	barBg.Name = name .. "Bg"
	barBg.Size = UDim2.new(1, -cutSize, 1, 0)
	barBg.Position = UDim2.new(0, cutSize, 0, 0)
	barBg.BackgroundColor3 = COLORS.BarBg
	barBg.BorderSizePixel = 0
	barBg.Parent = canvas

	local bgCut = Instance.new("Frame")
	bgCut.Name = name .. "BgCut"
	bgCut.Size = UDim2.new(0, cutSize, 0, height)
	bgCut.Position = UDim2.new(0, 0, 0, 0)
	bgCut.BackgroundColor3 = COLORS.BarBg
	bgCut.BorderSizePixel = 0
	bgCut.Parent = canvas

	local bgCutGradient = Instance.new("UIGradient")
	bgCutGradient.Rotation = 45
	bgCutGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0)
	})
	bgCutGradient.Parent = bgCut

	local barMask = Instance.new("Frame")
	barMask.Name = name .. "Mask"
	barMask.Size = UDim2.new(1, 0, 1, 0)
	barMask.Position = UDim2.new(0, 0, 0, 0)
	barMask.BackgroundTransparency = 1
	barMask.ClipsDescendants = true
	barMask.ZIndex = 2
	barMask.Parent = canvas

	local bar = Instance.new("Frame")
	bar.Name = name .. "Bar"
	bar.Size = UDim2.new(0, width - cutSize, 0, height)
	bar.Position = UDim2.new(0, cutSize, 0, 0)
	bar.BackgroundColor3 = barColor
	bar.BorderSizePixel = 0
	bar.Parent = barMask

	local barCut = Instance.new("Frame")
	barCut.Name = name .. "BarCut"
	barCut.Size = UDim2.new(0, cutSize, 0, height)
	barCut.Position = UDim2.new(0, 0, 0, 0)
	barCut.BackgroundColor3 = barColor
	barCut.BorderSizePixel = 0
	barCut.Parent = barMask

	local barCutGradient = Instance.new("UIGradient")
	barCutGradient.Rotation = 45
	barCutGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0)
	})
	barCutGradient.Parent = barCut

	local valueText = Instance.new("TextLabel")
	valueText.Name = name .. "Text"
	valueText.Size = UDim2.new(0, 50, 0, height)
	valueText.Position = UDim2.new(0, xPos + width + 8, 0, yPos)
	valueText.BackgroundTransparency = 1
	valueText.Text = "100"
	valueText.TextColor3 = COLORS.Text
	valueText.TextSize = 12
	valueText.Font = Enum.Font.GothamBold
	valueText.TextXAlignment = Enum.TextXAlignment.Left
	valueText.Parent = hudContainer

	return barMask, valueText, width, height
end

local healthMask, healthText, HEALTH_WIDTH, HEALTH_HEIGHT = createBar("Health", 40, 16, 280, COLORS.HealthBar, 70)
local staminaMask, staminaText, STAMINA_WIDTH, STAMINA_HEIGHT = createBar("Stamina", 62, 12, 220, COLORS.StaminaBar, 55)

local healthBar = healthMask:FindFirstChild("HealthBar")
local healthBarCut = healthMask:FindFirstChild("HealthBarCut")

-- === UI BUTTONS ===
local buttonsContainer = Instance.new("Frame")
buttonsContainer.Name = "ButtonsContainer"
buttonsContainer.Size = UDim2.new(0, 84, 0, 24)
buttonsContainer.Position = UDim2.new(0, 310, 0, 15)
buttonsContainer.BackgroundTransparency = 1
buttonsContainer.Parent = hudContainer

local shopButton = Instance.new("ImageButton")
shopButton.Name = "ShopButton"
shopButton.Size = UDim2.new(0, 18, 0, 18)
shopButton.Position = UDim2.new(0, 0, 0, 0)
shopButton.BackgroundTransparency = 1
shopButton.Image = "rbxassetid://11385395241"
shopButton.ScaleType = Enum.ScaleType.Fit
shopButton.Parent = buttonsContainer

local settingsButton = Instance.new("ImageButton")
settingsButton.Name = "SettingsButton"
settingsButton.Size = UDim2.new(0, 18, 0, 18)
settingsButton.Position = UDim2.new(0, 24, 0, 0)
settingsButton.BackgroundTransparency = 1
settingsButton.Image = "rbxassetid://105466965551651"
settingsButton.ScaleType = Enum.ScaleType.Fit
settingsButton.Parent = buttonsContainer

-- === 3D GUI ===
local GUI3D = Screen3D.new(screenGui, 5)
local HUD3D = GUI3D:GetComponent3D(hudContainer)

local function setup3DHUD()
	if HUD3D then
		HUD3D:Enable()
		HUD3D.offset = CFrame.Angles(0, math.rad(10), 0)
	end
end
setup3DHUD()

-- === ЭФФЕКТ НИЗКОЙ СТАМИНЫ ===
local blurEffect = Lighting:FindFirstChild("StaminaBlur")
if not blurEffect then
	blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "StaminaBlur"
	blurEffect.Size = 0
	blurEffect.Parent = Lighting
end

local vignetteGui = Instance.new("ScreenGui")
vignetteGui.Name = "StaminaVignette"
vignetteGui.ResetOnSpawn = true
vignetteGui.IgnoreGuiInset = true
vignetteGui.DisplayOrder = 100
vignetteGui.Parent = playerGui

local vignetteFrame = Instance.new("Frame")
vignetteFrame.Name = "Vignette"
vignetteFrame.Size = UDim2.new(1, 0, 1, 0)
vignetteFrame.Position = UDim2.new(0, 0, 0, 0)
vignetteFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
vignetteFrame.BackgroundTransparency = 1
vignetteFrame.BorderSizePixel = 0
vignetteFrame.Parent = vignetteGui

local vignetteGradient = Instance.new("UIGradient")
vignetteGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(0.8, 0.8),
	NumberSequenceKeypoint.new(1, 0.3)
})
vignetteGradient.Parent = vignetteFrame

local isLowStaminaActive = false
local LOW_STAMINA_THRESHOLD = 0.20

local function updateLowStaminaEffect(staminaPercent)
	if staminaPercent <= LOW_STAMINA_THRESHOLD and staminaPercent > 0 then
		local intensity = 1 - (staminaPercent / LOW_STAMINA_THRESHOLD)
		local targetBlur = intensity * 8
		TweenService:Create(blurEffect, TweenInfo.new(0.3), {Size = targetBlur}):Play()
		local targetVignette = 1 - (intensity * 0.4)
		TweenService:Create(vignetteFrame, TweenInfo.new(0.3), {BackgroundTransparency = targetVignette}):Play()
		isLowStaminaActive = true
	else
		if isLowStaminaActive or staminaPercent > LOW_STAMINA_THRESHOLD then
			TweenService:Create(blurEffect, TweenInfo.new(0.5), {Size = 0}):Play()
			TweenService:Create(vignetteFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
			isLowStaminaActive = false
		end
	end
end


-- === ФУНКЦИИ ОБНОВЛЕНИЯ ===
local function updateHealthBar(newHealth)
	currentHealth = math.clamp(newHealth, 0, maxHealth)
	local percent = currentHealth / maxHealth
	healthText.Text = tostring(math.floor(currentHealth))
	healthMask.Size = UDim2.new(percent, 0, 1, 0)
	local healthColor = COLORS.HealthBar:Lerp(COLORS.HealthBarLow, 1 - percent)
	if healthBar then healthBar.BackgroundColor3 = healthColor end
	if healthBarCut then healthBarCut.BackgroundColor3 = healthColor end
end

local function updateStaminaBar(newStamina)
	currentStamina = math.clamp(newStamina, 0, maxStamina)
	local percent = currentStamina / maxStamina
	staminaText.Text = tostring(math.floor(currentStamina))
	staminaMask.Size = UDim2.new(percent, 0, 1, 0)
	updateLowStaminaEffect(percent)
end

local function updateLevel(newLevel)
	playerLevel = newLevel
	levelBoxText.Text = tostring(playerLevel)
end

-- === ЗВУКИ ===
local HOVER_SOUND_ID = "rbxassetid://6895079853"
local CLICK_SOUND_ID = "rbxassetid://87437544236708"

local hoverSound = Instance.new("Sound")
hoverSound.Name = "HoverSound"
hoverSound.SoundId = HOVER_SOUND_ID
hoverSound.Volume = 0.3
hoverSound.Parent = playerGui

local clickSound = Instance.new("Sound")
clickSound.Name = "ClickSound"
clickSound.SoundId = CLICK_SOUND_ID
clickSound.Volume = 0.4
clickSound.Parent = playerGui

-- === КУРСОР ===
local HOVER_CURSOR = "rbxassetid://7033235466"
local mouse = player:GetMouse()

-- === HOVER ЭФФЕКТЫ ДЛЯ КНОПОК HUD ===
shopButton.MouseEnter:Connect(function()
	TweenService:Create(shopButton, TweenInfo.new(0.1), {ImageTransparency = 0.3}):Play()
	hoverSound:Play()
	mouse.Icon = HOVER_CURSOR
end)
shopButton.MouseLeave:Connect(function()
	TweenService:Create(shopButton, TweenInfo.new(0.1), {ImageTransparency = 0}):Play()
	mouse.Icon = ""
end)

settingsButton.MouseEnter:Connect(function()
	TweenService:Create(settingsButton, TweenInfo.new(0.1), {ImageTransparency = 0.3}):Play()
	hoverSound:Play()
	mouse.Icon = HOVER_CURSOR
end)
settingsButton.MouseLeave:Connect(function()
	TweenService:Create(settingsButton, TweenInfo.new(0.1), {ImageTransparency = 0}):Play()
	mouse.Icon = ""
end)

-- === ПОДКЛЮЧЕНИЕ МЕНЮ НАСТРОЕК ===
local SettingsMenu = require(ReplicatedStorage:WaitForChild("SettingsMenu"))


-- === ПОДКЛЮЧЕНИЕ МЕНЮ ИНВЕНТАРЯ ===
local InventoryMenu = require(ReplicatedStorage:WaitForChild("InventoryMenu"))

-- === ПОДКЛЮЧЕНИЕ ПАНЕЛИ ПЕРСОНАЖА ===
local CharacterPanel = require(ReplicatedStorage:WaitForChild("CharacterPanel"))

-- === CLICK ЭФФЕКТЫ ДЛЯ КНОПОК HUD ===
shopButton.MouseButton1Click:Connect(function()
	clickSound:Play()
	CharacterPanel.OpenWithTab("STORE")
end)

settingsButton.MouseButton1Click:Connect(function()
	clickSound:Play()
	CharacterPanel.OpenWithTab("SETTINGS")
end)

-- === СОБЫТИЯ ===
local function createOrGetEvent(name)
	local existing = player:FindFirstChild(name)
	if existing then existing:Destroy() end
	local event = Instance.new("BindableEvent")
	event.Name = name
	event.Parent = player
	return event
end

local staminaEvent = createOrGetEvent("StaminaUpdateEvent")
local healthEvent = createOrGetEvent("HealthUpdateEvent")
local levelEvent = createOrGetEvent("LevelUpdateEvent")

staminaEvent.Event:Connect(function(newStamina, newMaxStamina)
	if newMaxStamina then maxStamina = newMaxStamina end
	updateStaminaBar(newStamina)
end)

healthEvent.Event:Connect(function(newHealth, newMaxHealth)
	if newMaxHealth then maxHealth = newMaxHealth end
	updateHealthBar(newHealth)
end)

levelEvent.Event:Connect(function(newLevel)
	updateLevel(newLevel)
end)

print("PlayerHUD: Events created")

-- === ПОДКЛЮЧЕНИЕ К ПЕРСОНАЖУ ===
local function connectToCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	maxHealth = humanoid.MaxHealth
	currentHealth = humanoid.Health
	updateHealthBar(currentHealth)

	currentStamina = maxStamina
	updateStaminaBar(currentStamina)

	humanoid.HealthChanged:Connect(function(health)
		updateHealthBar(health)
	end)

	staminaEvent = createOrGetEvent("StaminaUpdateEvent")
	staminaEvent.Event:Connect(function(newStamina, newMaxStamina)
		if newMaxStamina then maxStamina = newMaxStamina end
		updateStaminaBar(newStamina)
	end)

	print("PlayerHUD: Connected to new character")
end

if player.Character then
	connectToCharacter(player.Character)
end
player.CharacterAdded:Connect(connectToCharacter)

-- Инициализация
updateHealthBar(currentHealth)
updateStaminaBar(currentStamina)

-- === ФУНКЦИИ СКРЫТИЯ/ПОКАЗА HUD ===
local isHUDHidden = false

local function resetButtonHovers()
	-- Сбрасываем hover эффекты всех кнопок
	shopButton.ImageTransparency = 0
	settingsButton.ImageTransparency = 0
	mouse.Icon = ""
end

local function hideHUD()
	if isHUDHidden then return end
	isHUDHidden = true

	-- Сбрасываем hover эффекты кнопок
	resetButtonHovers()

	-- Отключаем 3D компонент (это удалит Part из CurrentCamera)
	if HUD3D then
		HUD3D:Disable()
	end

	-- Скрываем 2D контейнер
	hudContainer.Visible = false
end

local function showHUD()
	if not isHUDHidden then return end
	isHUDHidden = false

	-- Показываем 2D контейнер
	hudContainer.Visible = true

	-- Включаем 3D компонент обратно
	if HUD3D then
		HUD3D:Enable()
	end
end

-- === СОБЫТИЯ ДЛЯ СКРЫТИЯ/ПОКАЗА GUI ===
local function setupGUIEvents()
	-- Событие скрытия
	local hideEvent = player:FindFirstChild("HideGUIEvent")
	if not hideEvent then
		hideEvent = Instance.new("BindableEvent")
		hideEvent.Name = "HideGUIEvent"
		hideEvent.Parent = player
	end
	hideEvent.Event:Connect(hideHUD)

	-- Событие показа
	local showEvent = player:FindFirstChild("ShowGUIEvent")
	if not showEvent then
		showEvent = Instance.new("BindableEvent")
		showEvent.Name = "ShowGUIEvent"
		showEvent.Parent = player
	end
	showEvent.Event:Connect(showHUD)
end
setupGUIEvents()

-- === ЭКСПОРТ ===
local HUD = {}
HUD.UpdateHealth = updateHealthBar
HUD.UpdateStamina = updateStaminaBar
HUD.UpdateLevel = updateLevel
HUD.GUI3D = GUI3D
HUD.HUD3D = HUD3D
HUD.HideHUD = hideHUD
HUD.ShowHUD = showHUD
HUD.OpenSettings = SettingsMenu.Open
HUD.CloseSettings = SettingsMenu.Close
HUD.ToggleSettings = SettingsMenu.Toggle
HUD.OpenInventory = InventoryMenu.Open
HUD.CloseInventory = InventoryMenu.Close
HUD.ToggleInventory = InventoryMenu.Toggle
HUD.OpenCharacterPanel = CharacterPanel.Open
HUD.CloseCharacterPanel = CharacterPanel.Close
HUD.ToggleCharacterPanel = CharacterPanel.Toggle

print("--- PlayerHUD 3D loaded ---")
return HUD
