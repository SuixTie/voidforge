local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local char = script.Parent.Parent 
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")
local rootJoint = rootPart:WaitForChild("RootJoint")
local RunConfig = require(game.ReplicatedStorage.RunConfig)
local LedgeGrabConfig = require(game.ReplicatedStorage.LedgeGrabConfig)

local player = game.Players.LocalPlayer
local isCrouchingValue = player:WaitForChild("IsCrouching")
local isSlidingValue = player:WaitForChild("IsSliding")

-- Флаг для предотвращения звука подъёма после переката
local wasSlidingValue = player:FindFirstChild("WasSliding") or Instance.new("BoolValue")
wasSlidingValue.Name = "WasSliding"
wasSlidingValue.Parent = player

-- === STAMINA INTEGRATION ===
local isBreathing = false
local currentSpeedMultiplier = 1.0
local currentStamina = 100
local ROLL_COST = 10
local DASH_COST = 15

-- Ждём события от StaminaSystem
task.spawn(function()
	local breathingEvent = char:WaitForChild("BreathingEvent", 10)
	if breathingEvent then
		breathingEvent.Event:Connect(function(breathing)
			isBreathing = breathing
		end)
	end
end)

task.spawn(function()
	local speedUpdateEvent = char:WaitForChild("SpeedUpdateEvent", 10)
	if speedUpdateEvent then
		speedUpdateEvent.Event:Connect(function(multiplier)
			currentSpeedMultiplier = multiplier
		end)
	end
end)

-- Слушаем обновления стамины из HUD события
task.spawn(function()
	local staminaEvent = player:WaitForChild("StaminaUpdateEvent", 10)
	if staminaEvent then
		staminaEvent.Event:Connect(function(stamina, maxStamina)
			currentStamina = stamina
		end)
	end
end)

-- Функция для траты стамины через DashEvent
local dashStaminaEvent = char:FindFirstChild("DashEvent")
if not dashStaminaEvent then
	dashStaminaEvent = Instance.new("BindableEvent")
	dashStaminaEvent.Name = "DashEvent"
	dashStaminaEvent.Parent = char
end

local normalSlideAnim = Instance.new("Animation")
normalSlideAnim.AnimationId = "rbxassetid://103470705707880"

local crouchSlideAnim = Instance.new("Animation")
crouchSlideAnim.AnimationId = "rbxassetid://115304249930882"

local keybind = Enum.KeyCode.Q
local canslide = true
local animator = humanoid:WaitForChild("Animator")

local DEFAULT_HIP_HEIGHT = humanoid.HipHeight
local originalC0 = rootJoint.C0

local function setVisualOffset(offset, speed)
	local targetC0 = originalC0 * CFrame.new(0, offset, 0) 
	TweenService:Create(rootJoint, TweenInfo.new(speed), {C0 = targetC0}):Play()
end

UIS.InputBegan:Connect(function(input, gameprocessed)
	if gameprocessed or not canslide or input.KeyCode ~= keybind then return end
	
	-- Не даём делать дэш во время виса на краю
	if LedgeGrabConfig.IsHanging then return end
	
	-- Не даём делать дэш во время ползания
	if RunConfig.isProne then return end
	
	-- Не даём делать дэш во время отдышки
	if isBreathing then return end
	
	local isCrouching = isCrouchingValue.Value
	local requiredStamina = isCrouching and ROLL_COST or DASH_COST
	
	-- Проверяем: стамина должна быть СТРОГО БОЛЬШЕ стоимости
	if currentStamina <= requiredStamina then
		return -- Недостаточно стамины
	end

	canslide = false
	local currentAnim = isCrouching and crouchSlideAnim or normalSlideAnim
	local slideTrack = animator:LoadAnimation(currentAnim)

	isSlidingValue.Value = true
	
	-- Тратим стамину через событие
	local dashType = isCrouching and "roll" or "dash"
	dashStaminaEvent:Fire(dashType)

	if isCrouching then
		humanoid.HipHeight = -2.0
		setVisualOffset(-2.5, 0.5)
		slideTrack.Priority = Enum.AnimationPriority.Action4
		for _, playingTrack in animator:GetPlayingAnimationTracks() do
			if playingTrack.Priority.Value <= Enum.AnimationPriority.Action.Value then
				playingTrack:Stop(0.1)
			end
		end
	else
		humanoid.HipHeight = -1.2 
		setVisualOffset(-0.5, 0.2)
		slideTrack.Priority = Enum.AnimationPriority.Action2
	end

	slideTrack:Play()

	-- Базовая скорость переката/дэша
	local baseSpeed = 40
	local runSpeed = RunConfig.Running and 70 or baseSpeed
	
	-- Применяем множитель скорости от стамины
	local finalSpeed = runSpeed * currentSpeedMultiplier

	local slide = Instance.new("BodyVelocity")
	slide.MaxForce = Vector3.new(1, 0, 1) * 30000
	slide.Velocity = rootPart.CFrame.LookVector * finalSpeed
	slide.Parent = rootPart

	local steps = isCrouching and 8 or 6
	for count = 1, steps do
		task.wait(0.1)
		slide.Velocity = slide.Velocity * 0.7
	end

	slide:Destroy()
	slideTrack:Stop(0.2)

	setVisualOffset(0, 0.3)

	if isCrouchingValue.Value then
		humanoid.HipHeight = -0.5
	else
		humanoid.HipHeight = DEFAULT_HIP_HEIGHT
	end

	-- Устанавливаем флаг "был перекат" ПЕРЕД сбросом IsSliding
	wasSlidingValue.Value = true
	isSlidingValue.Value = false
	
	task.delay(0.5, function()
		wasSlidingValue.Value = false
	end)

	task.wait(1.5)
	canslide = true
end)
