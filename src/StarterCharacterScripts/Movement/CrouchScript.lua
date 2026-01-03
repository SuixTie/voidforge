local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local crouchKey = Enum.KeyCode.C
local RunConfig = require(ReplicatedStorage:WaitForChild("RunConfig"))
local LedgeGrabConfig = require(ReplicatedStorage:WaitForChild("LedgeGrabConfig"))
local CombatConfig = require(ReplicatedStorage:WaitForChild("CombatConfig"))

-- === STAMINA INTEGRATION ===
local isBreathing = false

local crouchState = player:FindFirstChild("IsCrouching") or Instance.new("BoolValue")
crouchState.Name = "IsCrouching"
crouchState.Parent = player

local isSliding = player:FindFirstChild("IsSliding") or Instance.new("BoolValue")
isSliding.Name = "IsSliding"
isSliding.Parent = player

local crouchHipHeight = -0.5
local crouchWalkSpeed = 7
local crouchJumpHeight = 0

local crouchWalkAnim = script:WaitForChild("CrouchWalkAnim")
local crouchIdleAnim = script:WaitForChild("CrouchIdleAnim")
local toggle = script:FindFirstChild("Toggle")

-- === ЗВУК НАЧАЛА ПРИСЕДА ===
local crouchStartSound = nil  -- Создаётся при setupCharacter
local standUpSound = nil  -- Звук подъёма

local isKeyDown = false 
local crouching = false 
local character, humanoid, animator, crouchWalkTrack, crouchIdleTrack, renderConnection

local function needsCrouch()
	local head = character and character:FindFirstChild("Head")
	if not head then return false end

	local rayOrigin = head.Position
	local params = RaycastParams.new()
	
	-- Собираем все модели персонажей для исключения
	local excludeList = {character}
	
	-- Исключаем всех игроков
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(excludeList, plr.Character)
		end
	end
	
	-- Исключаем NPC (модели с Humanoid)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj ~= character then
			table.insert(excludeList, obj)
		end
	end
	
	params.FilterDescendantsInstances = excludeList
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- Длина 4 студа для уверенного обнаружения
	local standCheck = workspace:Spherecast(rayOrigin, 0.5, Vector3.new(0, 4, 0), params)

	if standCheck then
		-- Если над головой меньше 2.5 студов (когда мы сидим), значит встать нельзя
		return standCheck.Distance < 2.5
	end
	return false
end

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")
	
	-- Подключаем событие отдышки
	task.spawn(function()
		local breathingEvent = char:WaitForChild("BreathingEvent", 10)
		if breathingEvent then
			breathingEvent.Event:Connect(function(breathing)
				isBreathing = breathing
				print("CrouchScript: Breathing state changed to", breathing)
			end)
		else
			warn("CrouchScript: BreathingEvent not found!")
		end
	end)

	-- Создаём звук начала приседа
	local rootPart = char:WaitForChild("HumanoidRootPart")
	crouchStartSound = Instance.new("Sound")
	crouchStartSound.Name = "CrouchStartSound"
	crouchStartSound.SoundId = "rbxassetid://140071470572800"  -- Звук приседания (замени на свой ID)
	crouchStartSound.Volume = 0.1
	crouchStartSound.RollOffMinDistance = 5
	crouchStartSound.RollOffMaxDistance = 20
	crouchStartSound.PlaybackSpeed = 1.3
	crouchStartSound.Parent = rootPart
	
	-- Создаём звук подъёма
	standUpSound = Instance.new("Sound")
	standUpSound.Name = "StandUpSound"
	standUpSound.SoundId = "rbxassetid://101486761816396"  -- Звук подъёма
	standUpSound.Volume = 0.08
	standUpSound.RollOffMinDistance = 5
	standUpSound.RollOffMaxDistance = 20
	standUpSound.Parent = rootPart

	if not humanoid:GetAttribute("DefaultHipHeight") then
		humanoid:SetAttribute("DefaultHipHeight", humanoid.HipHeight)
		humanoid:SetAttribute("DefaultWalkSpeed", humanoid.WalkSpeed)
		humanoid:SetAttribute("DefaultJumpHeight", humanoid.JumpHeight)
	end

	crouchWalkTrack = animator:LoadAnimation(crouchWalkAnim)
	crouchIdleTrack = animator:LoadAnimation(crouchIdleAnim)
	crouchWalkTrack.Priority = Enum.AnimationPriority.Action
	crouchIdleTrack.Priority = Enum.AnimationPriority.Action

	if renderConnection then renderConnection:Disconnect() end
	renderConnection = RunService.RenderStepped:Connect(function()
		local isProne = RunConfig.isProne == true
		local isHanging = LedgeGrabConfig.IsHanging == true

		-- Если висим на краю - отключаем присед
		if isHanging then
			if crouchState.Value == true then
				crouchState.Value = false
				crouchWalkTrack:Stop(0.1)
				crouchIdleTrack:Stop(0.1)
			end
			return
		end

		if isProne then
			if crouchState.Value == true then
				crouchState.Value = false
				crouchWalkTrack:Stop(0.1)
				crouchIdleTrack:Stop(0.1)
			end
			-- ВАЖНО: сбросить HipHeight в дефолт, чтобы при выходе из Prone не было прыжка
			humanoid.HipHeight = humanoid:GetAttribute("DefaultHipHeight") 
			return 
		end

		-- 3. Дальше идет обычная логика приседания
		-- Проверяем находится ли игрок в воздухе
		local isInAir = humanoid.FloorMaterial == Enum.Material.Air

		-- lowCeiling проверяем только когда игрок на земле
		local lowCeiling = false
		if not isInAir then
			lowCeiling = needsCrouch()
		end

		-- Если игрок в воздухе - не садимся автоматически
		if isInAir then
			crouching = false
		elseif isKeyDown or isSliding.Value or lowCeiling then
			crouching = true
		else
			crouching = false
		end

		if not crouching then
			if crouchState.Value == true then
				crouchState.Value = false
				crouchWalkTrack:Stop(0.3)
				crouchIdleTrack:Stop(0.3)
				
				-- Проигрываем звук подъёма (не при перекате и не сразу после него)
				local wasSlidingValue = player:FindFirstChild("WasSliding")
				local wasSlidingNow = wasSlidingValue and wasSlidingValue.Value or false
				if standUpSound and not isSliding.Value and not wasSlidingNow then
					standUpSound:Play()
				end

				-- Возвращаем дефолтные параметры, только если мы не в слайде и не ползем
				if not isSliding.Value then
					humanoid.HipHeight = humanoid:GetAttribute("DefaultHipHeight")
					humanoid.WalkSpeed = humanoid:GetAttribute("DefaultWalkSpeed")
					humanoid.JumpHeight = humanoid:GetAttribute("DefaultJumpHeight")
				end
			end
			return
		end

		-- Логика активного приседа
		-- Проигрываем звук только при входе в присед (не при слайде/перекате)
		if crouchState.Value == false and crouchStartSound and not isSliding.Value then
			crouchStartSound:Play()
		end
		crouchState.Value = true
		if not isSliding.Value then
			humanoid.HipHeight = crouchHipHeight
			humanoid.JumpHeight = crouchJumpHeight

			if humanoid.MoveDirection.Magnitude > 0.1 then
				if not crouchWalkTrack.IsPlaying then crouchWalkTrack:Play(0.2) end
				crouchIdleTrack:Stop(0.2)
				humanoid.WalkSpeed = crouchWalkSpeed
			else
				if not crouchIdleTrack.IsPlaying then crouchIdleTrack:Play(0.2) end
				crouchWalkTrack:Stop(0.2)
				humanoid.WalkSpeed = crouchWalkSpeed
			end
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp or input.KeyCode ~= crouchKey then return end
	-- Блокируем если меню настроек открыто
	local settingsOpen = player:FindFirstChild("SettingsMenuOpen")
	if settingsOpen and settingsOpen.Value then return end
	-- Блокируем если панель персонажа открыта
	local characterPanelOpen = player:FindFirstChild("CharacterPanelOpen")
	if characterPanelOpen and characterPanelOpen.Value then return end
	-- Блокируем присед во время диалога
	local inDialogue = player:FindFirstChild("InDialogue")
	if inDialogue and inDialogue.Value then return end
	-- Блокируем присед во время отдышки
	if isBreathing then return end
	-- Блокируем присед во время блока
	if CombatConfig.IsBlocking then return end
	if toggle and toggle.Value then isKeyDown = not isKeyDown else isKeyDown = true end
end)
UserInputService.InputEnded:Connect(function(input, gp)
	if gp or input.KeyCode ~= crouchKey then return end
	if not (toggle and toggle.Value) then isKeyDown = false end
end)

player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end