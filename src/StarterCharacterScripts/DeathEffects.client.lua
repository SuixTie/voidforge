--[[
	DeathEffects - Визуальные эффекты смерти (LocalScript)
	
	- Блюр
	- Затемнение (виньетка)
	- Туннельное зрение
	- Обесцвечивание
	- Мерцание перед полным затемнением
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

-- === НАСТРОЙКИ ЭФФЕКТОВ СМЕРТИ ===
local CONFIG = {
	-- Блюр
	BlurSize = 56,
	BlurFadeTime = 2.5,
	
	-- Цветокоррекция
	DesaturationTime = 2.0,
	MaxDesaturation = -0.8,
	
	-- Туннельное зрение
	TunnelVisionTime = 2.5,
	
	-- Мерцание
	FlickerCount = 3,
	FlickerDuration = 0.15,
}

-- === УДАЛЯЕМ СТАРЫЕ ЭФФЕКТЫ ОТ ПРЕДЫДУЩЕЙ СМЕРТИ ===
local oldBlur = Lighting:FindFirstChild("DeathBlur")
if oldBlur then oldBlur:Destroy() end

local oldColorCorrection = Lighting:FindFirstChild("DeathColorCorrection")
if oldColorCorrection then oldColorCorrection:Destroy() end

local oldGui = player.PlayerGui:FindFirstChild("DeathEffectsGui")
if oldGui then oldGui:Destroy() end

-- === СОЗДАНИЕ ЭФФЕКТОВ ===

-- Блюр
local deathBlur = Instance.new("BlurEffect")
deathBlur.Name = "DeathBlur"
deathBlur.Size = 0
deathBlur.Enabled = false
deathBlur.Parent = Lighting

-- Цветокоррекция
local deathColorCorrection = Instance.new("ColorCorrectionEffect")
deathColorCorrection.Name = "DeathColorCorrection"
deathColorCorrection.Saturation = 0
deathColorCorrection.Brightness = 0
deathColorCorrection.TintColor = Color3.new(1, 1, 1)
deathColorCorrection.Enabled = false
deathColorCorrection.Parent = Lighting

-- GUI для виньетки
local deathGui = Instance.new("ScreenGui")
deathGui.Name = "DeathEffectsGui"
deathGui.ResetOnSpawn = true
deathGui.IgnoreGuiInset = true
deathGui.DisplayOrder = 999
deathGui.Parent = player:WaitForChild("PlayerGui")

-- Виньетка (через ImageLabel с радиальным градиентом)
local vignetteImage = Instance.new("ImageLabel")
vignetteImage.Name = "Vignette"
vignetteImage.Size = UDim2.new(1, 0, 1, 0)
vignetteImage.BackgroundTransparency = 1
vignetteImage.Image = "rbxassetid://2778230947"  -- Радиальная виньетка
vignetteImage.ImageColor3 = Color3.new(0, 0, 0)
vignetteImage.ImageTransparency = 1
vignetteImage.ScaleType = Enum.ScaleType.Stretch
vignetteImage.Parent = deathGui

-- Полное затемнение
local blackoutFrame = Instance.new("Frame")
blackoutFrame.Name = "Blackout"
blackoutFrame.Size = UDim2.new(1, 0, 1, 0)
blackoutFrame.BackgroundColor3 = Color3.new(0, 0, 0)
blackoutFrame.BackgroundTransparency = 1
blackoutFrame.BorderSizePixel = 0
blackoutFrame.ZIndex = 2
blackoutFrame.Parent = deathGui

-- === ФУНКЦИЯ ЭФФЕКТА СМЕРТИ ===
local function playDeathEffects()
	-- Включаем эффекты
	deathBlur.Enabled = true
	deathColorCorrection.Enabled = true
	
	-- 1. Блюр нарастает
	TweenService:Create(deathBlur, TweenInfo.new(
		CONFIG.BlurFadeTime,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	), {Size = CONFIG.BlurSize}):Play()
	
	-- 2. Обесцвечивание
	TweenService:Create(deathColorCorrection, TweenInfo.new(
		CONFIG.DesaturationTime,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	), {
		Saturation = CONFIG.MaxDesaturation,
		Brightness = -0.3,
		TintColor = Color3.new(0.7, 0.7, 0.8)
	}):Play()
	
	-- 3. Туннельное зрение (виньетка появляется и усиливается)
	TweenService:Create(vignetteImage, TweenInfo.new(
		CONFIG.TunnelVisionTime,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	), {ImageTransparency = 0}):Play()
	
	-- 4. Мерцание перед затемнением
	task.delay(CONFIG.TunnelVisionTime * 0.7, function()
		for i = 1, CONFIG.FlickerCount do
			blackoutFrame.BackgroundTransparency = 0.3
			task.wait(CONFIG.FlickerDuration)
			blackoutFrame.BackgroundTransparency = 0.7
			task.wait(CONFIG.FlickerDuration * 0.5)
		end
		
		-- 5. Полное затемнение
		TweenService:Create(blackoutFrame, TweenInfo.new(
			1.0,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		), {BackgroundTransparency = 0}):Play()
	end)
end

-- === ОЧИСТКА ===
local function cleanup()
	if deathBlur then deathBlur:Destroy() end
	if deathColorCorrection then deathColorCorrection:Destroy() end
	if deathGui then deathGui:Destroy() end
end

-- === ПОДКЛЮЧЕНИЕ ===
humanoid.Died:Connect(playDeathEffects)

-- Очистка при уничтожении персонажа
character.AncestryChanged:Connect(function(_, parent)
	if not parent then
		cleanup()
	end
end)

-- Очистка при респавне (новый персонаж)
player.CharacterAdded:Connect(function()
	cleanup()
end)

print("--- DeathEffects (Client) loaded ---")
