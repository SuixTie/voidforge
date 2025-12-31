--[[
	MotionBlur - Эффект размытия при повороте камеры
	
	Особенности:
	- Размытие зависит от угловой скорости камеры
	- Работает при поворотах мышью
	- Плавные переходы
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- === НАСТРОЙКИ ===
local CONFIG = {
	-- Чувствительность к повороту (градусы/сек)
	MinRotationSpeed = 50,       -- Минимальная скорость поворота для размытия
	MaxRotationSpeed = 400,      -- Скорость для максимального размытия
	
	-- Интенсивность размытия
	MaxBlur = 8,                 -- Максимальное размытие
	
	-- Плавность
	BlurAttackSpeed = 15,        -- Скорость появления размытия
	BlurDecaySpeed = 8,          -- Скорость затухания размытия
}

-- === СОЗДАНИЕ ЭФФЕКТА ===
local blurEffect = Lighting:FindFirstChild("MotionBlur")
if not blurEffect then
	blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "MotionBlur"
	blurEffect.Size = 0
	blurEffect.Parent = Lighting
end

-- === СОСТОЯНИЕ ===
local currentBlur = 0
local lastCameraLookVector = camera.CFrame.LookVector
local lastCameraUpVector = camera.CFrame.UpVector

-- === ГЛАВНЫЙ ЦИКЛ ===
RunService.RenderStepped:Connect(function(dt)
	local currentLookVector = camera.CFrame.LookVector
	local currentUpVector = camera.CFrame.UpVector
	
	-- Рассчитываем угловое изменение (в радианах)
	local lookDot = math.clamp(lastCameraLookVector:Dot(currentLookVector), -1, 1)
	local upDot = math.clamp(lastCameraUpVector:Dot(currentUpVector), -1, 1)
	
	local lookAngle = math.acos(lookDot)
	local upAngle = math.acos(upDot)
	
	-- Общий угол поворота
	local totalAngle = math.sqrt(lookAngle * lookAngle + upAngle * upAngle)
	
	-- Угловая скорость (градусы в секунду)
	local rotationSpeed = math.deg(totalAngle) / dt
	
	-- Рассчитываем целевое размытие
	local targetBlur = 0
	if rotationSpeed > CONFIG.MinRotationSpeed then
		local speedPercent = math.clamp(
			(rotationSpeed - CONFIG.MinRotationSpeed) / (CONFIG.MaxRotationSpeed - CONFIG.MinRotationSpeed),
			0, 1
		)
		targetBlur = speedPercent * CONFIG.MaxBlur
	end
	
	-- Плавная интерполяция (быстрее появляется, медленнее исчезает)
	local lerpSpeed = targetBlur > currentBlur and CONFIG.BlurAttackSpeed or CONFIG.BlurDecaySpeed
	currentBlur = currentBlur + (targetBlur - currentBlur) * math.min(1, dt * lerpSpeed)
	
	-- Применяем размытие
	blurEffect.Size = currentBlur
	
	-- Сохраняем текущие векторы
	lastCameraLookVector = currentLookVector
	lastCameraUpVector = currentUpVector
end)

print("--- MotionBlur loaded ---")
