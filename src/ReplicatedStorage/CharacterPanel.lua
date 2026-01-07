--[[
	CharacterPanel - Панель персонажа с 3D превью
	Voidforge: Eclipse Legacy
	
	При открытии:
	- Камера перемещается к копии модели игрока
	- HUD и компас плавно уходят за экран
	- Показывается UI меню в стиле Race Roll
	При закрытии:
	- Всё возвращается обратно
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Загружаем конфиг персонажей
local CharactersConfig = require(ReplicatedStorage:WaitForChild("CharactersConfig"))
local Screen3D = require(ReplicatedStorage:WaitForChild("Screen3D"))

-- === ФУНКЦИЯ ВОСПРОИЗВЕДЕНИЯ ЗВУКА ===
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

local CharacterPanel = {}
CharacterPanel.IsOpen = false

-- === НАСТРОЙКИ ===
local TWEEN_TIME = 0.5

-- === ЦВЕТА НЕОН-АНИМЕ ===
local COLORS = {
	Background = Color3.fromRGB(10, 10, 26),        -- #0a0a1a
	Panel = Color3.fromRGB(15, 15, 35),
	PanelBorder = Color3.fromRGB(0, 255, 255),      -- Циан
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(140, 140, 160),
	Accent = Color3.fromRGB(255, 215, 0),           -- Золотой
	ButtonBg = Color3.fromRGB(30, 30, 50),
	ButtonHover = Color3.fromRGB(45, 45, 70),
	Green = Color3.fromRGB(100, 255, 150),
}

-- === СОСТОЯНИЕ ===
local characterClone = nil
local originalPreviewModel = nil
local savedCameraType = nil
local savedCameraCFrame = nil
local savedWalkSpeed = nil
local savedJumpPower = nil
local cameraConnection = nil
local headTrackingConnection = nil
local isAnimating = false
local idleAnimation = nil
local idleTrack = nil
local modelPosition = nil
local menuGui = nil
local closeBtn3DGui = nil
local selectedTab = "HOME"
local mouse = player:GetMouse()

-- === ДАННЫЕ ИГРОКА (загружаются с сервера) ===
local playerData = {
	currentCharacter = CharactersConfig.Characters[1], -- Sakura по умолчанию
	spins = 10,
	unlockedCharacters = {},
}

-- === REMOTE EVENTS ===
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local getPlayerDataFunc = remotesFolder and remotesFolder:WaitForChild("GetPlayerData", 5)
local saveCharacterEvent = remotesFolder and remotesFolder:WaitForChild("SaveCharacter", 5)
local rollCharacterFunc = remotesFolder and remotesFolder:WaitForChild("RollCharacter", 5)

-- === ЗАГРУЗКА ДАННЫХ С СЕРВЕРА ===
local function loadPlayerData()
	if not getPlayerDataFunc then 
		warn("CharacterPanel: GetPlayerData remote not found")
		return 
	end
	
	local success, data = pcall(function()
		return getPlayerDataFunc:InvokeServer()
	end)
	
	if success and data then
		playerData.spins = data.spins or 10
		playerData.unlockedCharacters = data.unlockedCharacters or {}
		
		-- Находим персонажа по имени
		local charName = data.currentCharacter
		if charName then
			local foundChar = CharactersConfig.GetByName(charName)
			if foundChar then
				playerData.currentCharacter = foundChar
			end
		end
		
		print("CharacterPanel: Loaded player data - Character:", playerData.currentCharacter.Name, "Spins:", playerData.spins)
	else
		warn("CharacterPanel: Failed to load player data")
	end
end

-- Загружаем данные при старте
task.spawn(loadPlayerData)

-- === НАСТРОЙКИ СЛЕЖЕНИЯ ГОЛОВЫ ===
local HEAD_TRACK_SMOOTH_SPEED = 8
local currentHeadTargetRot = Vector3.new(0, 0, 0)

-- === СОЗДАНИЕ КОПИИ ПЕРСОНАЖА ===
local function createCharacterClone()
	originalPreviewModel = workspace:FindFirstChild("CharacterPreview")
	if not originalPreviewModel then
		warn("CharacterPanel: CharacterPreview model not found in workspace!")
		return nil
	end

	local existingRoot = originalPreviewModel:FindFirstChild("HumanoidRootPart") or originalPreviewModel:FindFirstChild("Torso") or originalPreviewModel.PrimaryPart
	if existingRoot then
		modelPosition = existingRoot.Position
	else
		for _, part in ipairs(originalPreviewModel:GetDescendants()) do
			if part:IsA("BasePart") then
				modelPosition = part.Position
				break
			end
		end
	end

	if not modelPosition then
		warn("CharacterPanel: Could not determine CharacterPreview position!")
		return nil
	end

	for _, part in ipairs(originalPreviewModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end

	if characterClone then
		characterClone:Destroy()
		characterClone = nil
	end

	local character = player.Character
	if not character then return nil end

	local wasArchivable = character.Archivable
	character.Archivable = true
	characterClone = character:Clone()
	character.Archivable = wasArchivable

	if not characterClone then return nil end

	characterClone.Name = "CharacterPreviewClone"

	for _, child in ipairs(characterClone:GetDescendants()) do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
			child:Destroy()
		end
	end

	local humanoid = characterClone:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false

		local oldAnimator = humanoid:FindFirstChildOfClass("Animator")
		if oldAnimator then oldAnimator:Destroy() end

		local animController = characterClone:FindFirstChildOfClass("AnimationController")
		if animController then animController:Destroy() end

		local animateScript = characterClone:FindFirstChild("Animate")
		if animateScript then animateScript:Destroy() end

		local headMovement = characterClone:FindFirstChild("RealisticHeadMovement", true)
		if headMovement then headMovement:Destroy() end

		local torso = characterClone:FindFirstChild("Torso")
		local head = characterClone:FindFirstChild("Head")
		local leftArm = characterClone:FindFirstChild("Left Arm")
		local rightArm = characterClone:FindFirstChild("Right Arm")
		local leftLeg = characterClone:FindFirstChild("Left Leg")
		local rightLeg = characterClone:FindFirstChild("Right Leg")
		local hrp = characterClone:FindFirstChild("HumanoidRootPart")

		if torso then
			for _, part in ipairs(characterClone:GetDescendants()) do
				if part:IsA("Motor6D") then part:Destroy() end
			end

			torso.CFrame = CFrame.new(modelPosition)
			if hrp then hrp.CFrame = torso.CFrame end
			if head then head.CFrame = torso.CFrame * CFrame.new(0, 1.5, 0) end
			if leftArm then leftArm.CFrame = torso.CFrame * CFrame.new(-1.5, 0, 0) end
			if rightArm then rightArm.CFrame = torso.CFrame * CFrame.new(1.5, 0, 0) end
			if leftLeg then leftLeg.CFrame = torso.CFrame * CFrame.new(-0.5, -2, 0) end
			if rightLeg then rightLeg.CFrame = torso.CFrame * CFrame.new(0.5, -2, 0) end

			if hrp then
				local rootJoint = Instance.new("Motor6D")
				rootJoint.Name = "RootJoint"
				rootJoint.Part0 = hrp
				rootJoint.Part1 = torso
				rootJoint.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
				rootJoint.C1 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
				rootJoint.Parent = hrp
			end

			if head then
				local neck = Instance.new("Motor6D")
				neck.Name = "Neck"
				neck.Part0 = torso
				neck.Part1 = head
				neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
				neck.C1 = CFrame.new(0, -0.5, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
				neck.Parent = torso
			end

			if leftArm then
				local leftShoulder = Instance.new("Motor6D")
				leftShoulder.Name = "Left Shoulder"
				leftShoulder.Part0 = torso
				leftShoulder.Part1 = leftArm
				leftShoulder.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0)
				leftShoulder.C1 = CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0)
				leftShoulder.Parent = torso
			end

			if rightArm then
				local rightShoulder = Instance.new("Motor6D")
				rightShoulder.Name = "Right Shoulder"
				rightShoulder.Part0 = torso
				rightShoulder.Part1 = rightArm
				rightShoulder.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi/2, 0)
				rightShoulder.C1 = CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi/2, 0)
				rightShoulder.Parent = torso
			end

			if leftLeg then
				local leftHip = Instance.new("Motor6D")
				leftHip.Name = "Left Hip"
				leftHip.Part0 = torso
				leftHip.Part1 = leftLeg
				leftHip.C0 = CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi/2, 0)
				leftHip.C1 = CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi/2, 0)
				leftHip.Parent = torso
			end

			if rightLeg then
				local rightHip = Instance.new("Motor6D")
				rightHip.Name = "Right Hip"
				rightHip.Part0 = torso
				rightHip.Part1 = rightLeg
				rightHip.C0 = CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi/2, 0)
				rightHip.C1 = CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.pi/2, 0)
				rightHip.Parent = torso
			end
		end

		task.wait()

		for _, accessory in ipairs(characterClone:GetChildren()) do
			if accessory:IsA("Accessory") then
				local handle = accessory:FindFirstChild("Handle")
				if handle then
					local oldWeld = handle:FindFirstChild("AccessoryWeld")
					if oldWeld then oldWeld:Destroy() end

					local attachment = handle:FindFirstChildOfClass("Attachment")
					if attachment then
						local attachmentName = attachment.Name
						for _, part in ipairs(characterClone:GetDescendants()) do
							if part:IsA("Attachment") and part.Name == attachmentName and part.Parent ~= handle then
								local newWeld = Instance.new("Weld")
								newWeld.Name = "AccessoryWeld"
								newWeld.Part0 = part.Parent
								newWeld.Part1 = handle
								newWeld.C0 = part.CFrame
								newWeld.C1 = attachment.CFrame
								newWeld.Parent = handle
								handle.CFrame = part.Parent.CFrame * part.CFrame * attachment.CFrame:Inverse()
								break
							end
						end
					end
				end
			end
		end

		local newAnimator = Instance.new("Animator")
		newAnimator.Parent = humanoid

		idleAnimation = Instance.new("Animation")
		idleAnimation.AnimationId = "rbxassetid://125068773366975"

		idleTrack = newAnimator:LoadAnimation(idleAnimation)
		idleTrack.Looped = true
		idleTrack.Priority = Enum.AnimationPriority.Action
		idleTrack:Play(0)
	end

	local hrpClone = characterClone:FindFirstChild("HumanoidRootPart")
	for _, part in ipairs(characterClone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			if part == hrpClone then
				part.Anchored = true
			else
				part.Anchored = false
			end
		end
	end

	local rootPart = characterClone:FindFirstChild("HumanoidRootPart") or characterClone:FindFirstChild("Torso")
	if rootPart then
		characterClone.PrimaryPart = rootPart
		rootPart.CFrame = CFrame.new(modelPosition)
	end

	characterClone.Parent = workspace
	return characterClone
end

-- === УДАЛЕНИЕ КОПИИ ===
local function destroyCharacterClone()
	if idleTrack then
		idleTrack:Stop()
		idleTrack = nil
	end
	if idleAnimation then
		idleAnimation:Destroy()
		idleAnimation = nil
	end

	if characterClone then
		characterClone:Destroy()
		characterClone = nil
	end

	if originalPreviewModel then
		for _, part in ipairs(originalPreviewModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0
			end
		end
		originalPreviewModel = nil
	end

	modelPosition = nil
end


-- === СОЗДАНИЕ UI МЕНЮ (HOME TAB - Race Roll Style) ===
local function createMenuUI()
	if menuGui then
		menuGui:Destroy()
	end

	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end

	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "CharacterPanelMenu"
	menuGui.ResetOnSpawn = false
	menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	menuGui.IgnoreGuiInset = true
	menuGui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.Parent = menuGui

	-- === ВЕРХНЯЯ НАВИГАЦИЯ ===
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 45)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(15, 12, 10)
	topBar.BackgroundTransparency = 0.3
	topBar.BorderSizePixel = 0
	topBar.Parent = background

	local bottomLine = Instance.new("Frame")
	bottomLine.Name = "BottomLine"
	bottomLine.Size = UDim2.new(1, 0, 0, 2)
	bottomLine.Position = UDim2.new(0, 0, 1, -2)
	bottomLine.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
	bottomLine.BorderSizePixel = 0
	bottomLine.Parent = topBar

	local lineGradient = Instance.new("UIGradient")
	lineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.3),
		NumberSequenceKeypoint.new(0.9, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	lineGradient.Parent = bottomLine

	local navButtons = {
		{name = "HOME", icon = "rbxassetid://7733960981"},
		{name = "CHARACTER", icon = "rbxassetid://81489458260315"}, -- Иконка персонажа
		{name = "SETTINGS", icon = "rbxassetid://7734053495"},
		{name = "STORE", icon = "rbxassetid://9405933217"}
	}

	local navContainer = Instance.new("Frame")
	navContainer.Name = "NavContainer"
	navContainer.Size = UDim2.new(0, 600, 1, 0)
	navContainer.Position = UDim2.new(0.5, -300, 0, 0)
	navContainer.BackgroundTransparency = 1
	navContainer.Parent = topBar

	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.Padding = UDim.new(0, 40)
	navLayout.Parent = navContainer

	for _, tabData in ipairs(navButtons) do
		local navBtn = Instance.new("TextButton")
		navBtn.Name = tabData.name
		navBtn.Size = UDim2.new(0, 120, 0, 40)
		navBtn.BackgroundTransparency = 1
		navBtn.Text = ""
		navBtn.Parent = navContainer

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(0, 16, 0, 16)
		icon.Position = UDim2.new(0, 0, 0.5, -11)
		icon.BackgroundTransparency = 1
		icon.Image = tabData.icon
		icon.ImageColor3 = selectedTab == tabData.name and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 110, 100)
		icon.Parent = navBtn

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, -24, 0, 16)
		label.Position = UDim2.new(0, 24, 0.5, -11)
		label.BackgroundTransparency = 1
		label.Text = tabData.name
		label.TextColor3 = selectedTab == tabData.name and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 110, 100)
		label.TextSize = 13
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = navBtn

		local indicator = Instance.new("Frame")
		indicator.Name = "Indicator"
		indicator.Size = UDim2.new(1, 0, 0, 2)
		indicator.Position = UDim2.new(0, 0, 1, 0)
		indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		indicator.BorderSizePixel = 0
		indicator.ZIndex = 10
		indicator.Visible = selectedTab == tabData.name
		indicator.Parent = navBtn

		local hoverColor = Color3.fromRGB(200, 190, 180)
		local activeColor = Color3.fromRGB(255, 255, 255)
		local inactiveColor = Color3.fromRGB(120, 110, 100)

		navBtn.MouseEnter:Connect(function()
			if selectedTab ~= tabData.name then
				icon.ImageColor3 = hoverColor
				label.TextColor3 = hoverColor
			end
		end)

		navBtn.MouseLeave:Connect(function()
			if selectedTab ~= tabData.name then
				icon.ImageColor3 = inactiveColor
				label.TextColor3 = inactiveColor
			end
		end)

		navBtn.MouseButton1Click:Connect(function()
			selectedTab = tabData.name
			for _, btn in ipairs(navContainer:GetChildren()) do
				if btn:IsA("TextButton") then
					local isSelected = btn.Name == selectedTab
					local btnIcon = btn:FindFirstChild("Icon")
					local btnLabel = btn:FindFirstChild("Label")
					local btnIndicator = btn:FindFirstChild("Indicator")

					if btnIcon then btnIcon.ImageColor3 = isSelected and activeColor or inactiveColor end
					if btnLabel then btnLabel.TextColor3 = isSelected and activeColor or inactiveColor end
					if btnIndicator then btnIndicator.Visible = isSelected end
				end
			end

			-- Переключаем видимость контейнеров вкладок
			local homeContent = background:FindFirstChild("HomeContent")
			local characterContent = background:FindFirstChild("CharacterContent")
			if homeContent then homeContent.Visible = (selectedTab == "HOME") end
			if characterContent then characterContent.Visible = (selectedTab == "CHARACTER") end
		end)
	end

	-- Профиль игрока справа
	local playerInfoContainer = Instance.new("Frame")
	playerInfoContainer.Name = "PlayerInfoContainer"
	playerInfoContainer.Size = UDim2.new(0, 180, 0, 40)
	playerInfoContainer.Position = UDim2.new(1, -190, 0.5, -20)
	playerInfoContainer.BackgroundTransparency = 1
	playerInfoContainer.Parent = topBar

	local playerAvatar = Instance.new("ImageLabel")
	playerAvatar.Name = "PlayerAvatar"
	playerAvatar.Size = UDim2.new(0, 36, 0, 36)
	playerAvatar.Position = UDim2.new(0, 0, 0.5, -18)
	playerAvatar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	playerAvatar.BorderSizePixel = 0
	playerAvatar.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	playerAvatar.Parent = playerInfoContainer

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0, 4)
	avatarCorner.Parent = playerAvatar

	local displayNameLabel = Instance.new("TextLabel")
	displayNameLabel.Name = "DisplayName"
	displayNameLabel.Size = UDim2.new(0, 130, 0, 18)
	displayNameLabel.Position = UDim2.new(0, 44, 0, 2)
	displayNameLabel.BackgroundTransparency = 1
	displayNameLabel.Text = player.DisplayName
	displayNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	displayNameLabel.TextSize = 13
	displayNameLabel.Font = Enum.Font.GothamMedium
	displayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	displayNameLabel.Parent = playerInfoContainer

	local usernameLabel = Instance.new("TextLabel")
	usernameLabel.Name = "Username"
	usernameLabel.Size = UDim2.new(0, 130, 0, 16)
	usernameLabel.Position = UDim2.new(0, 44, 0, 20)
	usernameLabel.BackgroundTransparency = 1
	usernameLabel.Text = "@" .. player.Name
	usernameLabel.TextColor3 = Color3.fromRGB(120, 110, 100)
	usernameLabel.TextSize = 11
	usernameLabel.Font = Enum.Font.Gotham
	usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
	usernameLabel.Parent = playerInfoContainer


	-- === КНОПКА CLOSE (справа вверху) - Cyberpunk Style ===
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 100, 0, 30)
	closeBtn.Position = UDim2.new(1, -140, 0, 55)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 30, 30) -- Красный
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = ""
	closeBtn.Parent = background

	-- Градиент для среза левого нижнего угла
	local cornerGradient = Instance.new("UIGradient")
	cornerGradient.Rotation = 315 -- Направление к левому нижнему
	cornerGradient.Offset = Vector2.new(-0.22, 0.22) -- Смещаем градиент чтобы срез был меньше
	cornerGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), -- Прозрачный (срез в левом нижнем)
		NumberSequenceKeypoint.new(0.045, 1), -- Прозрачный
		NumberSequenceKeypoint.new(0.046, 0), -- Резкий переход к непрозрачному
		NumberSequenceKeypoint.new(1, 0) -- Непрозрачный
	})
	cornerGradient.Parent = closeBtn

	-- Текст кнопки (смещён влево чтобы не перекрывался cyan полоской)
	local closeBtnText = Instance.new("TextLabel")
	closeBtnText.Name = "ButtonText"
	closeBtnText.Size = UDim2.new(1, -10, 1, 0)
	closeBtnText.Position = UDim2.new(0, 5, 0, 0)
	closeBtnText.BackgroundTransparency = 1
	closeBtnText.Text = "CLOSE"
	closeBtnText.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtnText.TextSize = 14
	closeBtnText.Font = Enum.Font.GothamBold
	closeBtnText.Parent = closeBtn

	-- Cyan акцент справа (внутри кнопки)
	local cyanAccent = Instance.new("Frame")
	cyanAccent.Name = "CyanAccent"
	cyanAccent.Size = UDim2.new(0, 3, 1, 0)
	cyanAccent.Position = UDim2.new(1, -3, 0, 0)
	cyanAccent.BackgroundColor3 = Color3.fromRGB(0, 255, 255) -- Cyan
	cyanAccent.BorderSizePixel = 0
	cyanAccent.Parent = closeBtn

	-- Жёлтый фрейм внизу кнопки (как на референсе)
	local bottomFrame = Instance.new("Frame")
	bottomFrame.Name = "BottomFrame"
	bottomFrame.Size = UDim2.new(0, 20, 0, 4) -- Меньше по высоте
	bottomFrame.Position = UDim2.new(1, -32, 1, -4) -- Отступ от правого края
	bottomFrame.BackgroundColor3 = Color3.fromRGB(220, 200, 50) -- Жёлтый
	bottomFrame.BorderSizePixel = 0
	bottomFrame.Parent = closeBtn

	-- Cyan акцент слева в жёлтом фрейме
	local bottomCyanAccent = Instance.new("Frame")
	bottomCyanAccent.Name = "CyanAccent"
	bottomCyanAccent.Size = UDim2.new(0, 2, 1, 0)
	bottomCyanAccent.Position = UDim2.new(0, 0, 0, 0)
	bottomCyanAccent.BackgroundColor3 = Color3.fromRGB(0, 255, 255) -- Cyan
	bottomCyanAccent.BorderSizePixel = 0
	bottomCyanAccent.Parent = bottomFrame

	-- Текст в жёлтом фрейме
	local bottomText = Instance.new("TextLabel")
	bottomText.Name = "BottomText"
	bottomText.Size = UDim2.new(1, -4, 1, 0)
	bottomText.Position = UDim2.new(0, 4, 0, 0)
	bottomText.BackgroundTransparency = 1
	bottomText.Text = "R25"
	bottomText.TextColor3 = Color3.fromRGB(30, 30, 30) -- Тёмный текст
	bottomText.TextSize = 8
	bottomText.Font = Enum.Font.GothamBold
	bottomText.TextXAlignment = Enum.TextXAlignment.Left
	bottomText.Parent = bottomFrame

	-- Hover эффект с glitch анимацией (Cyberpunk style)
	-- Glitch полосы
	local glitchBar1 = Instance.new("Frame")
	glitchBar1.Name = "GlitchBar1"
	glitchBar1.Size = UDim2.new(1, 8, 0.15, 0)
	glitchBar1.Position = UDim2.new(0, -4, 0.2, 0)
	glitchBar1.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	glitchBar1.BorderSizePixel = 0
	glitchBar1.Visible = false
	glitchBar1.ZIndex = 3
	glitchBar1.Parent = closeBtn

	local glitchBar2 = Instance.new("Frame")
	glitchBar2.Name = "GlitchBar2"
	glitchBar2.Size = UDim2.new(1, 8, 0.1, 0)
	glitchBar2.Position = UDim2.new(0, -4, 0.7, 0)
	glitchBar2.BackgroundColor3 = Color3.fromRGB(220, 200, 50)
	glitchBar2.BorderSizePixel = 0
	glitchBar2.Visible = false
	glitchBar2.ZIndex = 3
	glitchBar2.Parent = closeBtn

	-- Glitch текст
	local glitchText = Instance.new("TextLabel")
	glitchText.Name = "GlitchText"
	glitchText.Size = UDim2.new(1, -10, 1, 0)
	glitchText.Position = UDim2.new(0, 7, 0, 0)
	glitchText.BackgroundTransparency = 1
	glitchText.Text = "CLOSE"
	glitchText.TextColor3 = Color3.fromRGB(0, 255, 255)
	glitchText.TextSize = 14
	glitchText.Font = Enum.Font.GothamBold
	glitchText.Visible = false
	glitchText.ZIndex = 4
	glitchText.Parent = closeBtn

	local glitchConnection = nil
	local isHovering = false
	local glitchTimer = 0

	closeBtn.MouseEnter:Connect(function()
		isHovering = true
		glitchTimer = 0

		if glitchConnection then glitchConnection:Disconnect() end
		glitchConnection = RunService.RenderStepped:Connect(function(dt)
			if not isHovering then return end

			glitchTimer = glitchTimer + dt

			-- Glitch полосы
			local showGlitch = math.random() > 0.92
			glitchBar1.Visible = showGlitch
			glitchBar2.Visible = showGlitch
			glitchText.Visible = showGlitch

			if showGlitch then
				glitchBar1.Position = UDim2.new(0, math.random(-8, 8), math.random(0, 70) / 100, 0)
				glitchBar1.Size = UDim2.new(1, 8, math.random(5, 20) / 100, 0)
				glitchBar2.Position = UDim2.new(0, math.random(-8, 8), math.random(30, 90) / 100, 0)
				glitchBar2.Size = UDim2.new(1, 8, math.random(5, 15) / 100, 0)
				glitchText.Position = UDim2.new(0, 5 + math.random(-3, 3), 0, math.random(-2, 2))

				if math.random() > 0.5 then
					glitchBar1.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
					glitchBar2.BackgroundColor3 = Color3.fromRGB(220, 200, 50)
				else
					glitchBar1.BackgroundColor3 = Color3.fromRGB(220, 200, 50)
					glitchBar2.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
				end
			end
		end)
	end)

	closeBtn.MouseLeave:Connect(function()
		isHovering = false
		glitchBar1.Visible = false
		glitchBar2.Visible = false
		glitchText.Visible = false

		if glitchConnection then
			glitchConnection:Disconnect()
			glitchConnection = nil
		end
	end)

	closeBtn.MouseButton1Click:Connect(function()
		CharacterPanel.Close()
	end)

	-- === 3D ЭФФЕКТ ДЛЯ КНОПКИ CLOSE ===
	-- Создаём отдельный ScreenGui для 3D кнопки
	closeBtn3DGui = Instance.new("ScreenGui")
	closeBtn3DGui.Name = "CloseBtn3DGui"
	closeBtn3DGui.ResetOnSpawn = false
	closeBtn3DGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	closeBtn3DGui.IgnoreGuiInset = true
	closeBtn3DGui.Parent = playerGui

	-- Контейнер для кнопки
	local closeBtnContainer = Instance.new("Frame")
	closeBtnContainer.Name = "CloseBtnContainer"
	closeBtnContainer.Size = UDim2.new(0, 100, 0, 30)
	closeBtnContainer.Position = UDim2.new(1, -180, 0, 75)
	closeBtnContainer.BackgroundTransparency = 1
	closeBtnContainer.Parent = closeBtn3DGui

	-- Перемещаем кнопку в 3D контейнер
	closeBtn.Position = UDim2.new(0, 0, 0, 0)
	closeBtn.Parent = closeBtnContainer

	-- Применяем 3D эффект
	local closeBtn3D = Screen3D.new(closeBtn3DGui, 5)
	local closeBtnFrame3D = closeBtn3D:GetComponent3D(closeBtnContainer)
	closeBtnFrame3D:Enable()
	closeBtnFrame3D.offset = CFrame.Angles(0, math.rad(-15), 0) -- Наклон влево для правой кнопки

	-- ============================================
	-- === HOME CONTENT (контейнер для вкладки HOME) ===
	-- ============================================
	local homeContent = Instance.new("Frame")
	homeContent.Name = "HomeContent"
	homeContent.Size = UDim2.new(1, 0, 1, -45)
	homeContent.Position = UDim2.new(0, 0, 0, 45)
	homeContent.BackgroundTransparency = 1
	homeContent.Visible = (selectedTab == "HOME")
	homeContent.Parent = background

	-- HOME tab пустой (панели убраны)

	-- ============================================
	-- === CHARACTER CONTENT (контейнер для вкладки CHARACTER) ===
	-- ============================================
	local characterContent = Instance.new("Frame")
	characterContent.Name = "CharacterContent"
	characterContent.Size = UDim2.new(1, 0, 1, -45)
	characterContent.Position = UDim2.new(0, 0, 0, 45)
	characterContent.BackgroundTransparency = 1
	characterContent.Visible = (selectedTab == "CHARACTER")
	characterContent.Parent = background

	-- === ТЕКУЩИЙ ПЕРСОНАЖ (сверху) ===
	local currentCharLabel = Instance.new("TextLabel")
	currentCharLabel.Name = "CurrentCharLabel"
	currentCharLabel.Size = UDim2.new(0, 400, 0, 25)
	currentCharLabel.Position = UDim2.new(0.5, -200, 0, 20)
	currentCharLabel.BackgroundTransparency = 1
	currentCharLabel.Text = "Current Character:"
	currentCharLabel.TextColor3 = COLORS.PanelBorder
	currentCharLabel.TextSize = 16
	currentCharLabel.Font = Enum.Font.GothamMedium
	currentCharLabel.Parent = characterContent

	local charNameLabel = Instance.new("TextLabel")
	charNameLabel.Name = "CharNameLabel"
	charNameLabel.Size = UDim2.new(0, 500, 0, 45)
	charNameLabel.Position = UDim2.new(0.5, -250, 0, 45)
	charNameLabel.BackgroundTransparency = 1
	charNameLabel.Text = string.upper(playerData.currentCharacter.Name)
	charNameLabel.TextColor3 = CharactersConfig.RarityColors[playerData.currentCharacter.Rarity]
	charNameLabel.TextSize = 36
	charNameLabel.Font = Enum.Font.GothamBlack
	charNameLabel.Parent = characterContent

	local charAnimeLabel = Instance.new("TextLabel")
	charAnimeLabel.Name = "CharAnimeLabel"
	charAnimeLabel.Size = UDim2.new(0, 400, 0, 20)
	charAnimeLabel.Position = UDim2.new(0.5, -200, 0, 90)
	charAnimeLabel.BackgroundTransparency = 1
	charAnimeLabel.Text = "from " .. playerData.currentCharacter.Anime
	charAnimeLabel.TextColor3 = COLORS.TextMuted
	charAnimeLabel.TextSize = 14
	charAnimeLabel.Font = Enum.Font.Gotham
	charAnimeLabel.Parent = characterContent

	-- === ЛЕВАЯ ПАНЕЛЬ - CHARACTER SKILLS ===
	local skillsPanel = Instance.new("Frame")
	skillsPanel.Name = "SkillsPanel"
	skillsPanel.Size = UDim2.new(0, 280, 0, 320)
	skillsPanel.Position = UDim2.new(0, 30, 0, 130)
	skillsPanel.BackgroundColor3 = COLORS.Panel
	skillsPanel.BackgroundTransparency = 0.2
	skillsPanel.BorderSizePixel = 0
	skillsPanel.Parent = characterContent

	local skillsPanelStroke = Instance.new("UIStroke")
	skillsPanelStroke.Color = COLORS.PanelBorder
	skillsPanelStroke.Thickness = 1
	skillsPanelStroke.Transparency = 0.5
	skillsPanelStroke.Parent = skillsPanel

	local skillsTitle = Instance.new("TextLabel")
	skillsTitle.Size = UDim2.new(1, 0, 0, 30)
	skillsTitle.BackgroundColor3 = COLORS.PanelBorder
	skillsTitle.BackgroundTransparency = 0.85
	skillsTitle.Text = "  >> SKILLS"
	skillsTitle.TextColor3 = COLORS.PanelBorder
	skillsTitle.TextSize = 14
	skillsTitle.Font = Enum.Font.GothamBold
	skillsTitle.TextXAlignment = Enum.TextXAlignment.Left
	skillsTitle.Parent = skillsPanel

	local skillsContainer = Instance.new("ScrollingFrame")
	skillsContainer.Name = "SkillsContainer"
	skillsContainer.Size = UDim2.new(1, -16, 1, -45)
	skillsContainer.Position = UDim2.new(0, 8, 0, 38)
	skillsContainer.BackgroundTransparency = 1
	skillsContainer.ScrollBarThickness = 3
	skillsContainer.ScrollBarImageColor3 = COLORS.PanelBorder
	skillsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	skillsContainer.Parent = skillsPanel

	local skillsLayout = Instance.new("UIListLayout")
	skillsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	skillsLayout.Padding = UDim.new(0, 6)
	skillsLayout.Parent = skillsContainer

	-- Функция обновления скиллов
	local function updateSkillsPanel(char)
		for _, child in ipairs(skillsContainer:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		for i, skill in ipairs(char.Skills) do
			local skillFrame = Instance.new("Frame")
			skillFrame.Name = "Skill_" .. i
			skillFrame.Size = UDim2.new(1, 0, 0, 55)
			skillFrame.BackgroundColor3 = COLORS.Panel
			skillFrame.BackgroundTransparency = 0.3
			skillFrame.LayoutOrder = i
			skillFrame.Parent = skillsContainer

			local skillStroke = Instance.new("UIStroke")
			skillStroke.Color = CharactersConfig.RarityColors[char.Rarity]
			skillStroke.Thickness = 1
			skillStroke.Transparency = 0.6
			skillStroke.Parent = skillFrame

			local skillName = Instance.new("TextLabel")
			skillName.Size = UDim2.new(1, -10, 0, 20)
			skillName.Position = UDim2.new(0, 5, 0, 4)
			skillName.BackgroundTransparency = 1
			skillName.Text = skill.Name
			skillName.TextColor3 = Color3.new(1, 1, 1)
			skillName.TextSize = 14
			skillName.Font = Enum.Font.GothamBold
			skillName.TextXAlignment = Enum.TextXAlignment.Left
			skillName.Parent = skillFrame

			local skillDesc = Instance.new("TextLabel")
			skillDesc.Size = UDim2.new(1, -10, 0, 25)
			skillDesc.Position = UDim2.new(0, 5, 0, 26)
			skillDesc.BackgroundTransparency = 1
			skillDesc.Text = skill.Description
			skillDesc.TextColor3 = COLORS.TextMuted
			skillDesc.TextSize = 12
			skillDesc.Font = Enum.Font.Gotham
			skillDesc.TextXAlignment = Enum.TextXAlignment.Left
			skillDesc.TextWrapped = true
			skillDesc.Parent = skillFrame
		end

		skillsContainer.CanvasSize = UDim2.new(0, 0, 0, #char.Skills * 61)
	end

	updateSkillsPanel(playerData.currentCharacter)

	-- === ПРАВАЯ ПАНЕЛЬ - CHARACTER CHANCES ===
	local chancesPanel = Instance.new("Frame")
	chancesPanel.Name = "ChancesPanel"
	chancesPanel.Size = UDim2.new(0, 220, 0, 320)
	chancesPanel.Position = UDim2.new(1, -250, 0, 130)
	chancesPanel.BackgroundColor3 = COLORS.Panel
	chancesPanel.BackgroundTransparency = 0.2
	chancesPanel.BorderSizePixel = 0
	chancesPanel.Parent = characterContent

	local chancesPanelStroke = Instance.new("UIStroke")
	chancesPanelStroke.Color = Color3.fromRGB(255, 0, 255) -- Розовый
	chancesPanelStroke.Thickness = 1
	chancesPanelStroke.Transparency = 0.5
	chancesPanelStroke.Parent = chancesPanel

	local chancesTitle = Instance.new("TextLabel")
	chancesTitle.Size = UDim2.new(1, 0, 0, 30)
	chancesTitle.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
	chancesTitle.BackgroundTransparency = 0.85
	chancesTitle.Text = "  >> DROP RATES"
	chancesTitle.TextColor3 = Color3.fromRGB(255, 0, 255)
	chancesTitle.TextSize = 14
	chancesTitle.Font = Enum.Font.GothamBold
	chancesTitle.TextXAlignment = Enum.TextXAlignment.Left
	chancesTitle.Parent = chancesPanel

	local chancesContainer = Instance.new("ScrollingFrame")
	chancesContainer.Name = "ChancesContainer"
	chancesContainer.Size = UDim2.new(1, -16, 1, -40)
	chancesContainer.Position = UDim2.new(0, 8, 0, 35)
	chancesContainer.BackgroundTransparency = 1
	chancesContainer.ScrollBarThickness = 3
	chancesContainer.ScrollBarImageColor3 = Color3.fromRGB(255, 0, 255)
	chancesContainer.Parent = chancesPanel

	local chancesLayout = Instance.new("UIListLayout")
	chancesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chancesLayout.Padding = UDim.new(0, 2)
	chancesLayout.Parent = chancesContainer

	-- Заполняем список персонажей
	for i, char in ipairs(CharactersConfig.Characters) do
		local chanceLabel = Instance.new("TextLabel")
		chanceLabel.Name = "Chance_" .. char.Name
		chanceLabel.Size = UDim2.new(1, 0, 0, 20)
		chanceLabel.BackgroundTransparency = 1
		chanceLabel.Text = "• " .. char.Name .. " (" .. char.Chance .. "%)"
		chanceLabel.TextColor3 = CharactersConfig.RarityColors[char.Rarity]
		chanceLabel.TextSize = 12
		chanceLabel.Font = Enum.Font.Gotham
		chanceLabel.TextXAlignment = Enum.TextXAlignment.Left
		chanceLabel.LayoutOrder = i
		chanceLabel.Parent = chancesContainer
	end

	chancesContainer.CanvasSize = UDim2.new(0, 0, 0, #CharactersConfig.Characters * 22)

	-- === НИЖНЯЯ ПАНЕЛЬ - КНОПКИ РОЛЛА ===
	local spinsLabel = Instance.new("TextLabel")
	spinsLabel.Name = "SpinsLabel"
	spinsLabel.Size = UDim2.new(0, 200, 0, 25)
	spinsLabel.Position = UDim2.new(0.5, -100, 1, -110)
	spinsLabel.BackgroundTransparency = 1
	spinsLabel.Text = "Spins: " .. playerData.spins
	spinsLabel.TextColor3 = COLORS.PanelBorder
	spinsLabel.TextSize = 18
	spinsLabel.Font = Enum.Font.GothamBold
	spinsLabel.Parent = characterContent

	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "ButtonsContainer"
	buttonsContainer.Size = UDim2.new(0, 400, 0, 50)
	buttonsContainer.Position = UDim2.new(0.5, -200, 1, -80)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.Parent = characterContent

	-- Кнопка ROLL
	local rollButton = Instance.new("TextButton")
	rollButton.Name = "RollButton"
	rollButton.Size = UDim2.new(0, 180, 0, 50)
	rollButton.Position = UDim2.new(0, 0, 0, 0)
	rollButton.BackgroundColor3 = COLORS.ButtonBg
	rollButton.Text = "ROLL"
	rollButton.TextColor3 = Color3.fromRGB(255, 0, 255)
	rollButton.TextSize = 20
	rollButton.Font = Enum.Font.GothamBold
	rollButton.Parent = buttonsContainer

	local rollStroke = Instance.new("UIStroke")
	rollStroke.Color = Color3.fromRGB(255, 0, 255)
	rollStroke.Thickness = 2
	rollStroke.Parent = rollButton

	-- Кнопка QUICK ROLL
	local quickRollButton = Instance.new("TextButton")
	quickRollButton.Name = "QuickRollButton"
	quickRollButton.Size = UDim2.new(0, 100, 0, 50)
	quickRollButton.Position = UDim2.new(0, 190, 0, 0)
	quickRollButton.BackgroundColor3 = COLORS.ButtonBg
	quickRollButton.Text = "QUICK"
	quickRollButton.TextColor3 = COLORS.PanelBorder
	quickRollButton.TextSize = 14
	quickRollButton.Font = Enum.Font.GothamMedium
	quickRollButton.Parent = buttonsContainer

	local quickStroke = Instance.new("UIStroke")
	quickStroke.Color = COLORS.PanelBorder
	quickStroke.Thickness = 1
	quickStroke.Parent = quickRollButton

	-- Кнопка BUY SPINS
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.Size = UDim2.new(0, 100, 0, 50)
	buyButton.Position = UDim2.new(0, 300, 0, 0)
	buyButton.BackgroundColor3 = COLORS.ButtonBg
	buyButton.Text = "BUY"
	buyButton.TextColor3 = COLORS.Green
	buyButton.TextSize = 14
	buyButton.Font = Enum.Font.GothamMedium
	buyButton.Parent = buttonsContainer

	local buyStroke = Instance.new("UIStroke")
	buyStroke.Color = COLORS.Green
	buyStroke.Thickness = 1
	buyStroke.Parent = buyButton

	-- === ЛОГИКА РОЛЛА ===
	local isRolling = false

	local function setCharacter(char)
		playerData.currentCharacter = char
		charNameLabel.Text = string.upper(char.Name)
		charNameLabel.TextColor3 = CharactersConfig.RarityColors[char.Rarity]
		charAnimeLabel.Text = "from " .. char.Anime
		updateSkillsPanel(char)
	end

	local function rollAnimation()
		if isRolling or playerData.spins <= 0 then return end
		isRolling = true

		-- Звук начала ролла
		playSound(CharactersConfig.Sounds.RollStart, 0.4, 1)

		local rollCount = 25 + math.random(5, 15)
		local delay = 0.04

		for i = 1, rollCount do
			local randomChar = CharactersConfig.Characters[math.random(1, #CharactersConfig.Characters)]
			charNameLabel.Text = string.upper(randomChar.Name)
			charNameLabel.TextColor3 = CharactersConfig.RarityColors[randomChar.Rarity]

			-- Звук тика при прокрутке
			local pitch = 0.8 + (i / rollCount) * 0.4
			playSound(CharactersConfig.Sounds.Tick, 0.15, pitch)

			if i > rollCount - 10 then delay = delay + 0.025 end
			if i > rollCount - 5 then delay = delay + 0.04 end

			task.wait(delay)
		end

		-- Серверный ролл (защита от читов)
		local result = nil
		if rollCharacterFunc then
			local success, data = pcall(function()
				return rollCharacterFunc:InvokeServer()
			end)
			if success and data then
				result = data
			end
		end

		if result and result.character then
			local finalChar = result.character
			setCharacter(finalChar)
			playerData.spins = result.spins
			spinsLabel.Text = "Spins: " .. playerData.spins

			-- Звук выпадения в зависимости от редкости
			local dropSound = CharactersConfig.Sounds[finalChar.Rarity] or CharactersConfig.Sounds.Common
			local dropVolume = 0.5
			local dropPitch = 1

			if finalChar.Rarity == "Legendary" or finalChar.Rarity == "Mythic" or finalChar.Rarity == "Divine" then
				dropVolume = 0.8
				dropPitch = 0.9
			elseif finalChar.Rarity == "Epic" then
				dropVolume = 0.7
				dropPitch = 0.95
			elseif finalChar.Rarity == "Rare" then
				dropVolume = 0.6
			end

			playSound(dropSound, dropVolume, dropPitch)

			-- Эффект вспышки для редких персонажей
			if finalChar.Rarity == "Legendary" or finalChar.Rarity == "Mythic" or finalChar.Rarity == "Divine" then
				local flash = Instance.new("Frame")
				flash.Size = UDim2.new(1, 0, 1, 0)
				flash.BackgroundColor3 = CharactersConfig.RarityColors[finalChar.Rarity]
				flash.BackgroundTransparency = 0.7
				flash.ZIndex = 100
				flash.Parent = characterContent

				TweenService:Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
				task.delay(0.5, function()
					flash:Destroy()
				end)
			end
		else
			-- Если сервер не ответил, откатываем UI
			charNameLabel.Text = string.upper(playerData.currentCharacter.Name)
			charNameLabel.TextColor3 = CharactersConfig.RarityColors[playerData.currentCharacter.Rarity]
		end

		isRolling = false
	end

	local function quickRoll()
		if isRolling or playerData.spins <= 0 then return end
		isRolling = true

		-- Серверный ролл
		local result = nil
		if rollCharacterFunc then
			local success, data = pcall(function()
				return rollCharacterFunc:InvokeServer()
			end)
			if success and data then
				result = data
			end
		end

		if result and result.character then
			local finalChar = result.character
			setCharacter(finalChar)
			playerData.spins = result.spins
			spinsLabel.Text = "Spins: " .. playerData.spins

			-- Звук выпадения
			local dropSound = CharactersConfig.Sounds[finalChar.Rarity] or CharactersConfig.Sounds.Common
			playSound(dropSound, 0.5, 1)
		end

		isRolling = false
	end

	rollButton.MouseButton1Click:Connect(rollAnimation)
	quickRollButton.MouseButton1Click:Connect(quickRoll)

	-- Hover эффекты
	rollButton.MouseEnter:Connect(function()
		TweenService:Create(rollButton, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.ButtonHover}):Play()
		TweenService:Create(rollStroke, TweenInfo.new(0.1), {Thickness = 3}):Play()
	end)
	rollButton.MouseLeave:Connect(function()
		TweenService:Create(rollButton, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.ButtonBg}):Play()
		TweenService:Create(rollStroke, TweenInfo.new(0.1), {Thickness = 2}):Play()
	end)

	quickRollButton.MouseEnter:Connect(function()
		TweenService:Create(quickRollButton, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.ButtonHover}):Play()
	end)
	quickRollButton.MouseLeave:Connect(function()
		TweenService:Create(quickRollButton, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.ButtonBg}):Play()
	end)

	buyButton.MouseEnter:Connect(function()
		TweenService:Create(buyButton, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.ButtonHover}):Play()
	end)
	buyButton.MouseLeave:Connect(function()
		TweenService:Create(buyButton, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.ButtonBg}):Play()
	end)

	return menuGui
end

-- === УДАЛЕНИЕ UI МЕНЮ ===
local function destroyMenuUI()
	if menuGui then
		menuGui:Destroy()
		menuGui = nil
	end
	if closeBtn3DGui then
		closeBtn3DGui:Destroy()
		closeBtn3DGui = nil
	end
end


-- === СКРЫТИЕ/ПОКАЗ GUI ===
local guiHidden = false

local function hideGUI()
	if guiHidden then return end
	guiHidden = true

	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end

	local vignette = playerGui:FindFirstChild("StaminaVignette")
	if vignette then
		vignette.Enabled = false
	end

	local hideEvent = player:FindFirstChild("HideGUIEvent")
	if hideEvent then
		hideEvent:Fire()
	end
end

local function showGUI()
	if not guiHidden then return end
	guiHidden = false

	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end

	local vignette = playerGui:FindFirstChild("StaminaVignette")
	if vignette then
		vignette.Enabled = true
	end

	local showEvent = player:FindFirstChild("ShowGUIEvent")
	if showEvent then
		showEvent:Fire()
	end
end

-- === БЛОКИРОВКА ДВИЖЕНИЯ ===
local function disableMovement()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		savedWalkSpeed = humanoid.WalkSpeed
		savedJumpPower = humanoid.JumpPower
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

local function enableMovement()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = savedWalkSpeed or 16
		humanoid.JumpPower = savedJumpPower or 50
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

-- === СЛЕЖЕНИЕ ГОЛОВЫ ЗА КУРСОРОМ ===
local function normalizeAngle(angle)
	while angle > 180 do angle = angle - 360 end
	while angle < -180 do angle = angle + 360 end
	return angle
end

local function startHeadTracking()
	if headTrackingConnection then
		headTrackingConnection:Disconnect()
	end

	headTrackingConnection = RunService.RenderStepped:Connect(function(dt)
		if not CharacterPanel.IsOpen or not characterClone then return end

		local head = characterClone:FindFirstChild("Head")
		local torso = characterClone:FindFirstChild("Torso")
		if not head or not torso then return end

		local neck = torso:FindFirstChild("Neck")
		if not neck then return end

		local ray = mouse.UnitRay
		local lookPoint = ray.Origin + ray.Direction * 1000

		local headPosition = head.Position
		local direction = (lookPoint - headPosition).Unit

		local yAngle = math.atan2(direction.X, direction.Z)
		local xAngle = math.asin(-direction.Y)

		local yDegrees = math.deg(yAngle)
		local xDegrees = math.deg(xAngle)

		local clampedX = math.clamp(xDegrees, -30, 20)
		local clampedY = math.clamp(yDegrees, -45, 45)

		local targetRot = Vector3.new(-clampedX, clampedY, 0)

		local deltaX = normalizeAngle(targetRot.X - currentHeadTargetRot.X)
		local deltaY = normalizeAngle(targetRot.Y - currentHeadTargetRot.Y)
		local deltaZ = normalizeAngle(targetRot.Z - currentHeadTargetRot.Z)

		currentHeadTargetRot = Vector3.new(
			currentHeadTargetRot.X + deltaX * dt * HEAD_TRACK_SMOOTH_SPEED,
			currentHeadTargetRot.Y + deltaY * dt * HEAD_TRACK_SMOOTH_SPEED,
			currentHeadTargetRot.Z + deltaZ * dt * HEAD_TRACK_SMOOTH_SPEED
		)

		local baseC1 = CFrame.new(0, -0.5, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
		local rotationOffset = CFrame.Angles(
			math.rad(currentHeadTargetRot.X),
			0,
			math.rad(currentHeadTargetRot.Y)
		)
		neck.C1 = baseC1 * rotationOffset
	end)
end

local function stopHeadTracking()
	if headTrackingConnection then
		headTrackingConnection:Disconnect()
		headTrackingConnection = nil
	end
	currentHeadTargetRot = Vector3.new(0, 0, 0)
end

-- === ОТКРЫТИЕ ПАНЕЛИ ===
function CharacterPanel.Open()
	if CharacterPanel.IsOpen or isAnimating then return end
	isAnimating = true

	createCharacterClone()

	if not characterClone or not modelPosition then 
		isAnimating = false
		return 
	end

	savedCameraType = camera.CameraType
	savedCameraCFrame = camera.CFrame

	camera.CameraType = Enum.CameraType.Scriptable

	local cameraPosition = modelPosition + Vector3.new(0, 1.5, -5)
	local lookAtPosition = modelPosition + Vector3.new(0, 1, 0)
	camera.CFrame = CFrame.lookAt(cameraPosition, lookAtPosition)

	hideGUI()
	disableMovement()

	local menuOpenFlag = player:FindFirstChild("CharacterPanelOpen")
	if not menuOpenFlag then
		menuOpenFlag = Instance.new("BoolValue")
		menuOpenFlag.Name = "CharacterPanelOpen"
		menuOpenFlag.Parent = player
	end
	menuOpenFlag.Value = true

	createMenuUI()
	startHeadTracking()

	CharacterPanel.IsOpen = true
	isAnimating = false

	print("CharacterPanel: Opened")
end

-- === ЗАКРЫТИЕ ПАНЕЛИ ===
function CharacterPanel.Close()
	if not CharacterPanel.IsOpen or isAnimating then return end
	isAnimating = true

	stopHeadTracking()
	destroyMenuUI()

	if savedCameraType then
		camera.CameraType = savedCameraType
	end

	showGUI()
	enableMovement()
	destroyCharacterClone()

	local menuOpenFlag = player:FindFirstChild("CharacterPanelOpen")
	if menuOpenFlag then
		menuOpenFlag.Value = false
	end

	CharacterPanel.IsOpen = false
	isAnimating = false

	print("CharacterPanel: Closed")
end

-- === ПЕРЕКЛЮЧЕНИЕ ===
function CharacterPanel.Toggle()
	if CharacterPanel.IsOpen then
		CharacterPanel.Close()
	else
		CharacterPanel.Open()
	end
end

-- === ОТКРЫТИЕ С КОНКРЕТНОЙ ВКЛАДКОЙ ===
function CharacterPanel.OpenWithTab(tabName)
	-- Устанавливаем вкладку перед открытием
	if tabName then
		selectedTab = tabName
	end
	CharacterPanel.Open()
end

-- === ОЧИСТКА ПРИ РЕСПАВНЕ ===
player.CharacterAdded:Connect(function()
	if CharacterPanel.IsOpen then
		CharacterPanel.Close()
	end
end)

return CharacterPanel
