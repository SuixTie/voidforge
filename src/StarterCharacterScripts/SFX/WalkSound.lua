local RunService = game:GetService("RunService")
local char = script.Parent.Parent 
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

-- === НАСТРОЙКИ ===
local DEFAULT_WALK_SPEED = 12 
local BASE_VOLUME = 0.05       
local BASE_PITCH = 0.95        
local PITCH_VARIATION = 0.05

-- Настройки дистанции слышимости (чтобы не было слышно далеко)
local SOUND_MAX_DISTANCE = 18 -- Макс. расстояние слышимости
local SOUND_MIN_DISTANCE = 3  

-- Ссылки на состояния (созданные в других скриптах)
local player = game.Players.LocalPlayer
local isCrouchingValue = player:WaitForChild("IsCrouching")
local isSlidingValue = player:WaitForChild("IsSliding") -- Флаг слайда/переката

-- Шаблон звука
local soundTemplate = Instance.new("Sound")
soundTemplate.Name = "StepTemplate"
soundTemplate.SoundId = "rbxassetid://112240321395589"
soundTemplate.Volume = BASE_VOLUME

-- 3D Настройки
soundTemplate.RollOffMode = Enum.RollOffMode.Linear
soundTemplate.RollOffMinDistance = SOUND_MIN_DISTANCE
soundTemplate.RollOffMaxDistance = SOUND_MAX_DISTANCE
soundTemplate.Parent = rootPart

local distanceTraveled = 0
local lastPosition = rootPart.Position

-- Блокировка стандартных звуков Roblox
local function muteDefaultSounds()
	local soundContainers = {char:WaitForChild("Head"), rootPart}
	local function silence(sound)
		local defaultNames = {["Running"]=true, ["Walking"]=true, ["Climbing"]=true, ["Swimming"]=true, ["Jumping"]=true, ["Landing"]=true}
		if sound:IsA("Sound") and defaultNames[sound.Name] then
			sound.Volume = 0
			sound.SoundId = ""
			sound:Stop()
			sound:GetPropertyChangedSignal("Volume"):Connect(function() sound.Volume = 0 end)
			sound:GetPropertyChangedSignal("SoundId"):Connect(function() sound.SoundId = "" end)
		end
	end
	for _, container in pairs(soundContainers) do
		for _, obj in ipairs(container:GetChildren()) do silence(obj) end
		container.ChildAdded:Connect(silence)
	end
end

muteDefaultSounds()

-- Функция проигрывания шага
local function playStep(speed, isCrouching)
	local newSound = soundTemplate:Clone()
	newSound.Name = "Step"

	local speedFactor = speed / DEFAULT_WALK_SPEED
	local pitchModifier = isCrouching and 1.05 or 1.0 

	newSound.PlaybackSpeed = (BASE_PITCH * pitchModifier) * math.clamp(speedFactor, 0.8, 1.2) + (math.random(-PITCH_VARIATION * 100, PITCH_VARIATION * 100) / 100)

	newSound.Parent = rootPart
	newSound:Play()

	task.delay(1, function() 
		if newSound then newSound:Destroy() end 
	end)
end

-- Основной цикл
RunService.Heartbeat:Connect(function()
	local currentPosition = rootPart.Position
	local velocity = rootPart.Velocity * Vector3.new(1, 0, 1)
	local currentSpeed = velocity.Magnitude

	-- Проверяем состояния
	local isCrouching = isCrouchingValue.Value
	local isSliding = isSlidingValue.Value -- Идет ли сейчас слайд?

	-- УСЛОВИЕ: Игрок движется, на земле И НЕ СЛАЙДИТ
	if currentSpeed > 1.5 and humanoid.FloorMaterial ~= Enum.Material.Air and not isSliding then
		local delta = (currentPosition - lastPosition).Magnitude

		-- Темп дистанции
		local dynamicStepDistance = 6.5 

		if isCrouching then
			dynamicStepDistance = 2.5 
		elseif currentSpeed > 20 then
			dynamicStepDistance = 11.0 
		end

		local speedMultiplier = math.clamp(currentSpeed / DEFAULT_WALK_SPEED, 0.5, 1.5)
		distanceTraveled = distanceTraveled + (delta * speedMultiplier)

		lastPosition = currentPosition

		if distanceTraveled >= dynamicStepDistance then
			distanceTraveled = 0
			playStep(currentSpeed, isCrouching)
		end
	else
		-- Если игрок стоит, в воздухе или СЛАЙДИТ — сбрасываем счетчик шагов
		distanceTraveled = 0
		lastPosition = currentPosition
	end
end)