local RunService = game:GetService("RunService")
local char = script.Parent.Parent
local rootPart = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local player = game.Players.LocalPlayer

-- === НАСТРОЙКИ ===
local SLIDE_SOUND_ID = "rbxassetid://104298925753512" 
local ROLL_SOUND_ID = "rbxassetid://17727520771"    

local MAX_DISTANCE = 20
local MAX_SLIDE_VOLUME = 0.1 -- Максимальная громкость слайда при высокой скорости
local MAX_ROLL_VOLUME = 0.1  -- Громкость переката

local isSlidingValue = player:WaitForChild("IsSliding")
local isCrouchingValue = player:WaitForChild("IsCrouching")

local slideSound = Instance.new("Sound")
slideSound.Name = "SlideSound"
slideSound.SoundId = SLIDE_SOUND_ID
slideSound.Looped = true
slideSound.Volume = 0
slideSound.RollOffMaxDistance = MAX_DISTANCE
slideSound.Parent = rootPart

local rollSound = Instance.new("Sound")
rollSound.Name = "RollSound"
rollSound.SoundId = ROLL_SOUND_ID
rollSound.Volume = 0
rollSound.RollOffMaxDistance = MAX_DISTANCE
rollSound.Parent = rootPart

local wasSliding = false

-- Функция для проверки анимации по числу ID
local function getActiveSlideType()
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		-- Сначала проверяем самые свежие запущенные треки
		local tracks = animator:GetPlayingAnimationTracks()
		for i = #tracks, 1, -1 do -- Проверяем с конца (самые новые)
			local track = tracks[i]
			local id = tostring(track.Animation.AnimationId)
			if id:find("103470705707880") then
				return "Roll"
			elseif id:find("115304249930882") then
				return "Slide"
			end
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local isSliding = isSlidingValue.Value

	if isSliding then
		if not wasSliding then
			wasSliding = true

			-- Небольшая пауза, чтобы аниматор успел зарегистрировать трек
			task.wait() 

			for _, s in ipairs(rootPart:GetChildren()) do
				if s.Name == "Step" then s:Destroy() end
			end

			local slideType = getActiveSlideType()

			if slideType == "Roll" then
				rollSound:Play()
			elseif slideType == "Slide" then
				slideSound:Play()
			else
				-- Если аниматор всё еще не выдал ID, используем флаг приседа
				if isCrouchingValue.Value then
					slideSound:Play()
				else
					rollSound:Play()
				end
			end
		end

		if slideSound.IsPlaying then
			local currentSpeed = rootPart.Velocity.Magnitude
			-- Умножаем коэффициент скорости на нашу настроенную громкость
			local speedFactor = math.clamp(currentSpeed / 50, 0, 1) 
			slideSound.Volume = speedFactor * MAX_SLIDE_VOLUME

			slideSound.PlaybackSpeed = math.clamp(currentSpeed / 40, 0.8, 1.1)
		elseif rollSound.IsPlaying then
			local currentSpeed = rootPart.Velocity.Magnitude
			-- Умножаем коэффициент скорости на нашу настроенную громкость
			local speedFactor = math.clamp(currentSpeed / 50, 0, 1) 
			rollSound.Volume = speedFactor * MAX_ROLL_VOLUME

			rollSound.PlaybackSpeed = math.clamp(currentSpeed / 40, 0.8, 1.1)
		end
	else
		if wasSliding then
			wasSliding = false
			slideSound:Stop()
		end
	end
end)