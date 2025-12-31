local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local RunConfig = require(game.ReplicatedStorage.RunConfig)
local LedgeGrabConfig = require(game.ReplicatedStorage.LedgeGrabConfig)

local humanoidConnection = nil
local humanoid = nil
local character = nil

-- === STAMINA STATE ===
local isBreathing = false

local function setupCameraBobble(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")

	-- Подключаемся к событию отдышки
	task.spawn(function()
		local breathingEvent = character:WaitForChild("BreathingEvent", 10)
		if breathingEvent then
			breathingEvent.Event:Connect(function(breathing)
				isBreathing = breathing
			end)
		end
	end)

	if humanoidConnection then
		humanoidConnection:Disconnect()
	end

	humanoidConnection = RunService.RenderStepped:Connect(function()
		local currentTime = tick()
		local targetOffset

		-- ОПРЕДЕЛЯЕМ БАЗОВУЮ ВЫСОТУ
		local baseHeight = 0
		local isCrouching = player:WaitForChild("IsCrouching").Value
		local isHanging = LedgeGrabConfig.IsHanging

		if RunConfig.isProne then
			baseHeight = -3 -- Высота для ползания
		elseif isCrouching then
			baseHeight = -0.5 -- Высота для приседа
		end

		-- При отдышке - сильная тряска камеры (тяжёлое дыхание)
		if isBreathing then
			local breathingModifier = 0.15 -- Сильная тряска
			local breathingSpeed = 3 -- Медленнее, как дыхание
			local breathingX = math.cos(currentTime * breathingSpeed) * breathingModifier * 0.3
			local breathingY = math.abs(math.sin(currentTime * breathingSpeed)) * breathingModifier
			targetOffset = Vector3.new(breathingX, baseHeight + breathingY, -0.45)
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetOffset, 0.15)
			return
		end

		-- При висе bobble только для A/D (боковое движение)
		if isHanging then
			-- Проверяем нажаты ли A или D (боковые клавиши)
			local isMovingSideways = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.D)
			
			if isMovingSideways then
				local modifier = 0.05 -- Очень маленький bobble при висе
				local speed = 2 -- Медленнее
				local bobbleX = math.cos(currentTime * speed) * modifier
				local bobbleY = math.abs(math.sin(currentTime * speed)) * modifier
				targetOffset = Vector3.new(bobbleX, baseHeight + bobbleY, -0.45)
			else
				-- W/S или ничего не нажато - без bobble
				targetOffset = Vector3.new(0, baseHeight, -0.45)
			end
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetOffset, 0.1) -- Более плавно
		elseif humanoid.MoveDirection.Magnitude > 0 then
			-- Интенсивность тряски меньше, если ползем
			local modifier = RunConfig.isProne and 0.2 or 0.5
			local speed = RunConfig.isProne and 4 or 5.6

			local bobbleX = math.cos(currentTime * speed) * modifier
			local bobbleY = math.abs(math.sin(currentTime * speed)) * modifier
			targetOffset = Vector3.new(bobbleX, baseHeight + bobbleY, -0.45)
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetOffset, 0.25)
		else
			targetOffset = Vector3.new(0, baseHeight, -0.45)
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetOffset, 0.25)
		end
	end)
end

player.CharacterAdded:Connect(setupCameraBobble)
if player.Character then
	setupCameraBobble(player.Character)
end