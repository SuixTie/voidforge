--[[
	CompassGui3D - 3D Компас в стиле Elden Ring + Cyberpunk
	Использует Screen3D для 3D эффекта
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Screen3D = require(ReplicatedStorage:WaitForChild("Screen3D"))

-- === ЦВЕТА CYBERPUNK ===
local COLORS = {
	Background = Color3.fromRGB(10, 12, 18),
	BackgroundStroke = Color3.fromRGB(0, 255, 200),
	MainLine = Color3.fromRGB(180, 170, 140),
	Cardinal = Color3.fromRGB(0, 255, 200),
	Intercardinal = Color3.fromRGB(255, 50, 100),
	Tick = Color3.fromRGB(100, 95, 80),
	CenterMarker = Color3.fromRGB(255, 200, 50),
}

-- === СОЗДАНИЕ 2D GUI (база для 3D) ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CompassGui3D"
screenGui.ResetOnSpawn = true  -- Пересоздаём при респавне чтобы 3D части не оставались
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Основной контейнер
local compassFrame = Instance.new("Frame")
compassFrame.Name = "CompassFrame"
compassFrame.Size = UDim2.new(0, 320, 0, 35)  -- Чуть шире
compassFrame.Position = UDim2.new(0.5, -160, 0, 12)
compassFrame.BackgroundColor3 = COLORS.Background
compassFrame.BackgroundTransparency = 0.7
compassFrame.BorderSizePixel = 0
compassFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = compassFrame

local stroke = Instance.new("UIStroke")
stroke.Color = COLORS.BackgroundStroke
stroke.Thickness = 1
stroke.Transparency = 0.6
stroke.Parent = compassFrame

-- Контейнер для направлений
local directionsContainer = Instance.new("Frame")
directionsContainer.Name = "DirectionsContainer"
directionsContainer.Size = UDim2.new(1, -20, 1, 0)
directionsContainer.Position = UDim2.new(0, 10, 0, 0)
directionsContainer.BackgroundTransparency = 1
directionsContainer.ClipsDescendants = true
directionsContainer.Parent = compassFrame

local directionsInner = Instance.new("Frame")
directionsInner.Name = "DirectionsInner"
directionsInner.Size = UDim2.new(3, 0, 1, 0)
directionsInner.Position = UDim2.new(0, 0, 0, 0)
directionsInner.BackgroundTransparency = 1
directionsInner.Parent = directionsContainer

-- Горизонтальная линия
local mainLine = Instance.new("Frame")
mainLine.Name = "MainLine"
mainLine.Size = UDim2.new(1, 0, 0, 2)
mainLine.Position = UDim2.new(0, 0, 0.7, 0)
mainLine.BackgroundColor3 = COLORS.MainLine
mainLine.BackgroundTransparency = 0.3
mainLine.BorderSizePixel = 0
mainLine.Parent = directionsInner

-- Центральный маркер
local centerMarker = Instance.new("Frame")
centerMarker.Name = "CenterMarker"
centerMarker.Size = UDim2.new(0, 6, 0, 6)
centerMarker.Position = UDim2.new(0.5, -3, 0.7, -3)
centerMarker.BackgroundColor3 = COLORS.CenterMarker
centerMarker.BackgroundTransparency = 0
centerMarker.BorderSizePixel = 0
centerMarker.Rotation = 45
centerMarker.ZIndex = 10
centerMarker.Parent = compassFrame

local markerCorner = Instance.new("UICorner")
markerCorner.CornerRadius = UDim.new(0, 1)
markerCorner.Parent = centerMarker

local markerGlow = Instance.new("UIStroke")
markerGlow.Color = COLORS.CenterMarker
markerGlow.Thickness = 1.5
markerGlow.Transparency = 0.5
markerGlow.Parent = centerMarker


-- === НАПРАВЛЕНИЯ ===
local directions = {
	{angle = 0, text = "N", cardinal = true},
	{angle = 45, text = "NE", cardinal = false},
	{angle = 90, text = "E", cardinal = true},
	{angle = 135, text = "SE", cardinal = false},
	{angle = 180, text = "S", cardinal = true},
	{angle = 225, text = "SW", cardinal = false},
	{angle = 270, text = "W", cardinal = true},
	{angle = 315, text = "NW", cardinal = false},
}

local directionLabels = {}

for _, dir in ipairs(directions) do
	local label = Instance.new("TextLabel")
	label.Name = "Dir_" .. dir.text
	label.Size = UDim2.new(0, 30, 0, 18)
	label.BackgroundTransparency = 1
	label.Text = dir.text
	label.TextColor3 = dir.cardinal and COLORS.Cardinal or COLORS.Intercardinal
	label.TextSize = dir.cardinal and 14 or 11
	label.Font = Enum.Font.GothamBold  -- Более чёткий шрифт
	label.TextStrokeTransparency = 0  -- Полностью видимый stroke для чёткости
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextYAlignment = Enum.TextYAlignment.Bottom
	label.RichText = false
	label.Parent = directionsInner
	
	directionLabels[dir.angle] = label
end

-- Деления
local ticks = {}
for i = 0, 359, 15 do
	local isDirection = false
	for _, dir in ipairs(directions) do
		if dir.angle == i then
			isDirection = true
			break
		end
	end
	
	if not isDirection then
		local tick = Instance.new("Frame")
		tick.Name = "Tick_" .. i
		tick.Size = UDim2.new(0, 1, 0, 8)
		tick.BackgroundColor3 = COLORS.Tick
		tick.BackgroundTransparency = 0.5
		tick.BorderSizePixel = 0
		tick.Parent = directionsInner
		
		ticks[i] = tick
	end
end

-- === ИНИЦИАЛИЗАЦИЯ 3D ===
local GUI3D = Screen3D.new(screenGui, 5)  -- 5 studs distance
local Frame3D = GUI3D:GetComponent3D(compassFrame)

if Frame3D then
	Frame3D:Enable()
	-- Наклон компаса вперёд для 3D эффекта
	Frame3D.offset = CFrame.Angles(math.rad(15), 0, 0)
end

-- === ОБНОВЛЕНИЕ КОМПАСА ===
local function updateCompass()
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	local camera = workspace.CurrentCamera
	local lookVector = camera.CFrame.LookVector
	local yaw = math.atan2(lookVector.X, lookVector.Z)
	local degrees = math.deg(yaw)
	if degrees < 0 then degrees = degrees + 360 end
	
	-- Обновляем позиции направлений
	for angle, label in pairs(directionLabels) do
		local diff = angle - degrees
		
		while diff > 180 do diff = diff - 360 end
		while diff < -180 do diff = diff + 360 end
		
		local screenPos = 0.5 + (diff / 180) * 0.5
		local distFromCenter = math.abs(screenPos - 0.5)
		local alpha = 1 - (distFromCenter * 1.5)
		alpha = math.clamp(alpha, 0, 1)
		
		label.Position = UDim2.new(screenPos, -15, 0.1, 0)
		label.TextTransparency = (1 - alpha) * 0.7
		label.Visible = alpha > 0.05
	end
	
	-- Обновляем позиции делений
	for angle, tick in pairs(ticks) do
		local diff = angle - degrees
		
		while diff > 180 do diff = diff - 360 end
		while diff < -180 do diff = diff + 360 end
		
		local screenPos = 0.5 + (diff / 180) * 0.5
		local distFromCenter = math.abs(screenPos - 0.5)
		local alpha = 1 - (distFromCenter * 2)
		alpha = math.clamp(alpha, 0, 1)
		
		tick.Position = UDim2.new(screenPos, 0, 0.7, -4)
		tick.BackgroundTransparency = 1 - (alpha * 0.5)
		tick.Visible = alpha > 0.1
	end
end

RunService.RenderStepped:Connect(updateCompass)

-- === ФУНКЦИИ СКРЫТИЯ/ПОКАЗА КОМПАСА ===
local isCompassHidden = false

local function hideCompass()
	if isCompassHidden then return end
	isCompassHidden = true
	
	-- Отключаем 3D компонент (это удалит Part из CurrentCamera)
	if Frame3D then
		Frame3D:Disable()
	end
	
	-- Скрываем 2D контейнер
	compassFrame.Visible = false
end

local function showCompass()
	if not isCompassHidden then return end
	isCompassHidden = false
	
	-- Показываем 2D контейнер
	compassFrame.Visible = true
	
	-- Включаем 3D компонент обратно
	if Frame3D then
		Frame3D:Enable()
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
	hideEvent.Event:Connect(hideCompass)
	
	-- Событие показа
	local showEvent = player:FindFirstChild("ShowGUIEvent")
	if not showEvent then
		showEvent = Instance.new("BindableEvent")
		showEvent.Name = "ShowGUIEvent"
		showEvent.Parent = player
	end
	showEvent.Event:Connect(showCompass)
end
setupGUIEvents()

-- === ЭКСПОРТ ===
local Compass = {}
Compass.GUI3D = GUI3D
Compass.Frame3D = Frame3D
Compass.HideCompass = hideCompass
Compass.ShowCompass = showCompass

print("--- CompassGui3D loaded (Screen3D) ---")

return Compass
