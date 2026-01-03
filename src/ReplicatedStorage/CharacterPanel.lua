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

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Загружаем конфиг рас
local RacesConfig = require(ReplicatedStorage:WaitForChild("RacesConfig"))

local CharacterPanel = {}
CharacterPanel.IsOpen = false

-- === НАСТРОЙКИ ===
local TWEEN_TIME = 0.5

-- === ЦВЕТА ===
local COLORS = {
	Background = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(25, 20, 18),
	PanelBorder = Color3.fromRGB(60, 50, 40),
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(150, 140, 130),
	Accent = Color3.fromRGB(200, 160, 80),
	ButtonBg = Color3.fromRGB(80, 60, 50),
	ButtonHover = Color3.fromRGB(100, 80, 60),
	Green = Color3.fromRGB(100, 180, 100),
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
local selectedTab = "HOME"
local mouse = player:GetMouse()

-- === ДАННЫЕ ИГРОКА (временные, потом из DataStore) ===
local playerData = {
	currentRace = RacesConfig.Races[1], -- Survivor по умолчанию
	spins = 4,
	raceSlots = {
		{level = 1, race = RacesConfig.Races[1], unlocked = true},
		{level = 30, race = nil, unlocked = false},
		{level = 100, race = nil, unlocked = false},
	}
}

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
		{name = "RACE", icon = "rbxassetid://7743876094"}, -- Иконка персонажа/расы
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
			local raceContent = background:FindFirstChild("RaceContent")
			if homeContent then homeContent.Visible = (selectedTab == "HOME") end
			if raceContent then raceContent.Visible = (selectedTab == "RACE") end
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


	-- === КНОПКА CLOSE (справа вверху) ===
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 80, 0, 35)
	closeBtn.Position = UDim2.new(1, -100, 0, 60)
	closeBtn.BackgroundColor3 = COLORS.Green
	closeBtn.Text = "Close"
	closeBtn.TextColor3 = COLORS.Text
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = background

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 6)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		CharacterPanel.Close()
	end)

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

	-- === ДАННЫЕ СТАТИСТИКИ (временные, потом из DataStore) ===
	local playerStats = {
		level = 15,
		experience = 2450,
		experienceToNext = 5000,
		gold = 12500,
		souls = 340,
		playTime = 14520, -- в секундах
		kills = 127,
		deaths = 43,
		bossesDefeated = 3,
		damageDealt = 45230,
		damageTaken = 28100,
		criticalHits = 234,
		parries = 56,
		dodges = 189,
		-- Базовые характеристики
		health = 100,
		maxHealth = 100,
		stamina = 100,
		maxStamina = 100,
		strength = 10,
		dexterity = 8,
		vitality = 12,
		endurance = 9,
	}

	-- Активные квесты (временные данные)
	local activeQuests = {
		{
			name = "The Lost Artifact",
			description = "Find the ancient artifact in the Void Temple",
			progress = 2,
			maxProgress = 3,
			reward = "500 Gold, 50 Souls",
			type = "Main",
		},
		{
			name = "Hunter's Mark",
			description = "Defeat 10 Shadow Beasts",
			progress = 7,
			maxProgress = 10,
			reward = "200 Gold",
			type = "Side",
		},
		{
			name = "Gather Resources",
			description = "Collect 20 Iron Ore",
			progress = 15,
			maxProgress = 20,
			reward = "100 Gold",
			type = "Daily",
		},
	}

	-- Функция форматирования времени
	local function formatPlayTime(seconds)
		local hours = math.floor(seconds / 3600)
		local minutes = math.floor((seconds % 3600) / 60)
		return string.format("%dh %dm", hours, minutes)
	end

	-- === ЛЕВАЯ ПАНЕЛЬ - ВСЕ ХАРАКТЕРИСТИКИ ===
	local homeLeftPanel = Instance.new("Frame")
	homeLeftPanel.Name = "HomeLeftPanel"
	homeLeftPanel.Size = UDim2.new(0, 300, 0, 480)
	homeLeftPanel.Position = UDim2.new(0, 20, 0, 15)
	homeLeftPanel.BackgroundColor3 = COLORS.Panel
	homeLeftPanel.BackgroundTransparency = 0.3
	homeLeftPanel.BorderSizePixel = 0
	homeLeftPanel.Parent = homeContent

	local homeLeftCorner = Instance.new("UICorner")
	homeLeftCorner.CornerRadius = UDim.new(0, 8)
	homeLeftCorner.Parent = homeLeftPanel

	local homeLeftStroke = Instance.new("UIStroke")
	homeLeftStroke.Color = COLORS.PanelBorder
	homeLeftStroke.Thickness = 1
	homeLeftStroke.Parent = homeLeftPanel

	-- Заголовок Character Stats
	local charStatsTitle = Instance.new("TextLabel")
	charStatsTitle.Name = "CharStatsTitle"
	charStatsTitle.Size = UDim2.new(1, -20, 0, 25)
	charStatsTitle.Position = UDim2.new(0, 10, 0, 8)
	charStatsTitle.BackgroundTransparency = 1
	charStatsTitle.Text = "Character Stats"
	charStatsTitle.TextColor3 = COLORS.Text
	charStatsTitle.TextSize = 16
	charStatsTitle.Font = Enum.Font.GothamBold
	charStatsTitle.TextXAlignment = Enum.TextXAlignment.Left
	charStatsTitle.Parent = homeLeftPanel

	-- Level и XP Bar
	local levelContainer = Instance.new("Frame")
	levelContainer.Name = "LevelContainer"
	levelContainer.Size = UDim2.new(1, -20, 0, 50)
	levelContainer.Position = UDim2.new(0, 10, 0, 38)
	levelContainer.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
	levelContainer.BorderSizePixel = 0
	levelContainer.Parent = homeLeftPanel

	local levelCorner = Instance.new("UICorner")
	levelCorner.CornerRadius = UDim.new(0, 6)
	levelCorner.Parent = levelContainer

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.new(0, 80, 0, 20)
	levelLabel.Position = UDim2.new(0, 10, 0, 5)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level"
	levelLabel.TextColor3 = COLORS.TextMuted
	levelLabel.TextSize = 11
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = levelContainer

	local levelValue = Instance.new("TextLabel")
	levelValue.Size = UDim2.new(0, 50, 0, 25)
	levelValue.Position = UDim2.new(1, -60, 0, 3)
	levelValue.BackgroundTransparency = 1
	levelValue.Text = tostring(playerStats.level)
	levelValue.TextColor3 = COLORS.Accent
	levelValue.TextSize = 20
	levelValue.Font = Enum.Font.GothamBold
	levelValue.TextXAlignment = Enum.TextXAlignment.Right
	levelValue.Parent = levelContainer

	-- XP Bar
	local xpBarBg = Instance.new("Frame")
	xpBarBg.Name = "XPBarBg"
	xpBarBg.Size = UDim2.new(1, -20, 0, 10)
	xpBarBg.Position = UDim2.new(0, 10, 0, 30)
	xpBarBg.BackgroundColor3 = Color3.fromRGB(20, 18, 15)
	xpBarBg.BorderSizePixel = 0
	xpBarBg.Parent = levelContainer

	local xpBarBgCorner = Instance.new("UICorner")
	xpBarBgCorner.CornerRadius = UDim.new(0, 4)
	xpBarBgCorner.Parent = xpBarBg

	local xpProgress = playerStats.experience / playerStats.experienceToNext
	local xpBarFill = Instance.new("Frame")
	xpBarFill.Name = "XPBarFill"
	xpBarFill.Size = UDim2.new(xpProgress, 0, 1, 0)
	xpBarFill.BackgroundColor3 = COLORS.Accent
	xpBarFill.BorderSizePixel = 0
	xpBarFill.Parent = xpBarBg

	local xpBarFillCorner = Instance.new("UICorner")
	xpBarFillCorner.CornerRadius = UDim.new(0, 4)
	xpBarFillCorner.Parent = xpBarFill

	local xpText = Instance.new("TextLabel")
	xpText.Size = UDim2.new(1, 0, 1, 0)
	xpText.BackgroundTransparency = 1
	xpText.Text = playerStats.experience .. " / " .. playerStats.experienceToNext
	xpText.TextColor3 = COLORS.Text
	xpText.TextSize = 8
	xpText.Font = Enum.Font.GothamMedium
	xpText.Parent = xpBarBg

	-- ScrollingFrame для всех статов
	local statsScroll = Instance.new("ScrollingFrame")
	statsScroll.Name = "StatsScroll"
	statsScroll.Size = UDim2.new(1, -20, 0, 375)
	statsScroll.Position = UDim2.new(0, 10, 0, 95)
	statsScroll.BackgroundTransparency = 1
	statsScroll.BorderSizePixel = 0
	statsScroll.ScrollBarThickness = 4
	statsScroll.ScrollBarImageColor3 = COLORS.PanelBorder
	statsScroll.CanvasSize = UDim2.new(0, 0, 0, 600)
	statsScroll.Parent = homeLeftPanel

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.FillDirection = Enum.FillDirection.Vertical
	statsLayout.Padding = UDim.new(0, 5)
	statsLayout.Parent = statsScroll

	-- Функция создания строки статистики
	local function createStatRow(parent, name, value, color)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -5, 0, 24)
		row.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
		row.BorderSizePixel = 0
		row.Parent = parent

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 4)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 10, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = name
		nameLabel.TextColor3 = COLORS.TextMuted
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0.4, -10, 1, 0)
		valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = tostring(value)
		valueLabel.TextColor3 = color or COLORS.Text
		valueLabel.TextSize = 11
		valueLabel.Font = Enum.Font.GothamMedium
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Parent = row

		return row
	end

	-- Функция создания заголовка секции
	local function createSectionHeader(parent, title)
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -5, 0, 22)
		header.BackgroundTransparency = 1
		header.Text = title
		header.TextColor3 = COLORS.Accent
		header.TextSize = 12
		header.Font = Enum.Font.GothamBold
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = parent
		return header
	end

	-- === GENERAL ===
	createSectionHeader(statsScroll, "General")
	createStatRow(statsScroll, "Race", playerData.currentRace.Name, RacesConfig.RarityColors[playerData.currentRace.Rarity])
	createStatRow(statsScroll, "Gold", playerStats.gold, Color3.fromRGB(255, 215, 0))
	createStatRow(statsScroll, "Souls", playerStats.souls, Color3.fromRGB(150, 100, 255))
	createStatRow(statsScroll, "Play Time", formatPlayTime(playerStats.playTime), COLORS.TextMuted)
	createStatRow(statsScroll, "Spins Left", playerData.spins, COLORS.Accent)

	-- === ATTRIBUTES ===
	createSectionHeader(statsScroll, "Attributes")
	createStatRow(statsScroll, "Strength", playerStats.strength, Color3.fromRGB(255, 100, 100))
	createStatRow(statsScroll, "Dexterity", playerStats.dexterity, Color3.fromRGB(100, 255, 100))
	createStatRow(statsScroll, "Vitality", playerStats.vitality, Color3.fromRGB(255, 150, 150))
	createStatRow(statsScroll, "Endurance", playerStats.endurance, Color3.fromRGB(100, 200, 255))

	-- === COMBAT ===
	createSectionHeader(statsScroll, "Combat")
	createStatRow(statsScroll, "Kills", playerStats.kills, COLORS.Green)
	createStatRow(statsScroll, "Deaths", playerStats.deaths, Color3.fromRGB(200, 80, 80))
	local kdRatio = playerStats.deaths > 0 and (playerStats.kills / playerStats.deaths) or playerStats.kills
	createStatRow(statsScroll, "K/D Ratio", string.format("%.2f", kdRatio), COLORS.Accent)
	createStatRow(statsScroll, "Damage Dealt", playerStats.damageDealt, Color3.fromRGB(255, 150, 100))
	createStatRow(statsScroll, "Damage Taken", playerStats.damageTaken, Color3.fromRGB(100, 150, 255))
	createStatRow(statsScroll, "Critical Hits", playerStats.criticalHits, Color3.fromRGB(255, 100, 100))
	createStatRow(statsScroll, "Parries", playerStats.parries, Color3.fromRGB(100, 200, 255))
	createStatRow(statsScroll, "Dodges", playerStats.dodges, Color3.fromRGB(150, 255, 150))
	createStatRow(statsScroll, "Bosses Defeated", playerStats.bossesDefeated, Color3.fromRGB(255, 200, 50))

	-- === ПРАВАЯ ПАНЕЛЬ - АКТИВНЫЕ КВЕСТЫ ===
	local homeRightPanel = Instance.new("Frame")
	homeRightPanel.Name = "HomeRightPanel"
	homeRightPanel.Size = UDim2.new(0, 280, 0, 480)
	homeRightPanel.Position = UDim2.new(1, -300, 0, 15)
	homeRightPanel.BackgroundColor3 = COLORS.Panel
	homeRightPanel.BackgroundTransparency = 0.3
	homeRightPanel.BorderSizePixel = 0
	homeRightPanel.Parent = homeContent

	local homeRightCorner = Instance.new("UICorner")
	homeRightCorner.CornerRadius = UDim.new(0, 8)
	homeRightCorner.Parent = homeRightPanel

	local homeRightStroke = Instance.new("UIStroke")
	homeRightStroke.Color = COLORS.PanelBorder
	homeRightStroke.Thickness = 1
	homeRightStroke.Parent = homeRightPanel

	-- Заголовок Active Quests
	local questsTitle = Instance.new("TextLabel")
	questsTitle.Name = "QuestsTitle"
	questsTitle.Size = UDim2.new(1, -60, 0, 25)
	questsTitle.Position = UDim2.new(0, 10, 0, 8)
	questsTitle.BackgroundTransparency = 1
	questsTitle.Text = "Active Quests"
	questsTitle.TextColor3 = COLORS.Text
	questsTitle.TextSize = 16
	questsTitle.Font = Enum.Font.GothamBold
	questsTitle.TextXAlignment = Enum.TextXAlignment.Left
	questsTitle.Parent = homeRightPanel

	-- Количество квестов
	local questCountLabel = Instance.new("TextLabel")
	questCountLabel.Size = UDim2.new(0, 50, 0, 25)
	questCountLabel.Position = UDim2.new(1, -60, 0, 8)
	questCountLabel.BackgroundTransparency = 1
	questCountLabel.Text = #activeQuests .. "/5"
	questCountLabel.TextColor3 = COLORS.TextMuted
	questCountLabel.TextSize = 12
	questCountLabel.Font = Enum.Font.Gotham
	questCountLabel.TextXAlignment = Enum.TextXAlignment.Right
	questCountLabel.Parent = homeRightPanel

	-- ScrollingFrame для квестов
	local questsScroll = Instance.new("ScrollingFrame")
	questsScroll.Name = "QuestsScroll"
	questsScroll.Size = UDim2.new(1, -20, 0, 430)
	questsScroll.Position = UDim2.new(0, 10, 0, 40)
	questsScroll.BackgroundTransparency = 1
	questsScroll.BorderSizePixel = 0
	questsScroll.ScrollBarThickness = 4
	questsScroll.ScrollBarImageColor3 = COLORS.PanelBorder
	questsScroll.CanvasSize = UDim2.new(0, 0, 0, #activeQuests * 115)
	questsScroll.Parent = homeRightPanel

	local questsLayout = Instance.new("UIListLayout")
	questsLayout.FillDirection = Enum.FillDirection.Vertical
	questsLayout.Padding = UDim.new(0, 8)
	questsLayout.Parent = questsScroll

	-- Цвета типов квестов
	local questTypeColors = {
		Main = Color3.fromRGB(255, 200, 50),
		Side = Color3.fromRGB(100, 200, 255),
		Daily = Color3.fromRGB(100, 255, 100),
	}

	-- Создаём карточки квестов
	for _, quest in ipairs(activeQuests) do
		local questCard = Instance.new("Frame")
		questCard.Name = "Quest_" .. quest.name
		questCard.Size = UDim2.new(1, -5, 0, 105)
		questCard.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
		questCard.BorderSizePixel = 0
		questCard.Parent = questsScroll

		local questCardCorner = Instance.new("UICorner")
		questCardCorner.CornerRadius = UDim.new(0, 6)
		questCardCorner.Parent = questCard

		-- Индикатор типа квеста
		local typeIndicator = Instance.new("Frame")
		typeIndicator.Size = UDim2.new(0, 4, 1, -10)
		typeIndicator.Position = UDim2.new(0, 5, 0, 5)
		typeIndicator.BackgroundColor3 = questTypeColors[quest.type] or COLORS.TextMuted
		typeIndicator.BorderSizePixel = 0
		typeIndicator.Parent = questCard

		local indicatorCorner = Instance.new("UICorner")
		indicatorCorner.CornerRadius = UDim.new(0, 2)
		indicatorCorner.Parent = typeIndicator

		-- Тип квеста
		local questType = Instance.new("TextLabel")
		questType.Size = UDim2.new(0, 50, 0, 14)
		questType.Position = UDim2.new(0, 15, 0, 5)
		questType.BackgroundTransparency = 1
		questType.Text = quest.type
		questType.TextColor3 = questTypeColors[quest.type] or COLORS.TextMuted
		questType.TextSize = 9
		questType.Font = Enum.Font.GothamBold
		questType.TextXAlignment = Enum.TextXAlignment.Left
		questType.Parent = questCard

		-- Название квеста
		local questName = Instance.new("TextLabel")
		questName.Size = UDim2.new(1, -25, 0, 18)
		questName.Position = UDim2.new(0, 15, 0, 18)
		questName.BackgroundTransparency = 1
		questName.Text = quest.name
		questName.TextColor3 = COLORS.Text
		questName.TextSize = 12
		questName.Font = Enum.Font.GothamBold
		questName.TextXAlignment = Enum.TextXAlignment.Left
		questName.TextTruncate = Enum.TextTruncate.AtEnd
		questName.Parent = questCard

		-- Описание квеста
		local questDesc = Instance.new("TextLabel")
		questDesc.Size = UDim2.new(1, -25, 0, 28)
		questDesc.Position = UDim2.new(0, 15, 0, 36)
		questDesc.BackgroundTransparency = 1
		questDesc.Text = quest.description
		questDesc.TextColor3 = COLORS.TextMuted
		questDesc.TextSize = 10
		questDesc.Font = Enum.Font.Gotham
		questDesc.TextXAlignment = Enum.TextXAlignment.Left
		questDesc.TextWrapped = true
		questDesc.Parent = questCard

		-- Прогресс бар
		local progressBg = Instance.new("Frame")
		progressBg.Size = UDim2.new(1, -30, 0, 8)
		progressBg.Position = UDim2.new(0, 15, 0, 68)
		progressBg.BackgroundColor3 = Color3.fromRGB(20, 18, 15)
		progressBg.BorderSizePixel = 0
		progressBg.Parent = questCard

		local progressBgCorner = Instance.new("UICorner")
		progressBgCorner.CornerRadius = UDim.new(0, 3)
		progressBgCorner.Parent = progressBg

		local progressPercent = quest.progress / quest.maxProgress
		local progressFill = Instance.new("Frame")
		progressFill.Size = UDim2.new(progressPercent, 0, 1, 0)
		progressFill.BackgroundColor3 = questTypeColors[quest.type] or COLORS.Accent
		progressFill.BorderSizePixel = 0
		progressFill.Parent = progressBg

		local progressFillCorner = Instance.new("UICorner")
		progressFillCorner.CornerRadius = UDim.new(0, 3)
		progressFillCorner.Parent = progressFill

		-- Прогресс текст
		local progressText = Instance.new("TextLabel")
		progressText.Size = UDim2.new(0, 60, 0, 14)
		progressText.Position = UDim2.new(1, -75, 0, 66)
		progressText.BackgroundTransparency = 1
		progressText.Text = quest.progress .. "/" .. quest.maxProgress
		progressText.TextColor3 = COLORS.TextMuted
		progressText.TextSize = 10
		progressText.Font = Enum.Font.GothamMedium
		progressText.TextXAlignment = Enum.TextXAlignment.Right
		progressText.Parent = questCard

		-- Награда
		local rewardLabel = Instance.new("TextLabel")
		rewardLabel.Size = UDim2.new(1, -25, 0, 14)
		rewardLabel.Position = UDim2.new(0, 15, 0, 85)
		rewardLabel.BackgroundTransparency = 1
		rewardLabel.Text = "Reward: " .. quest.reward
		rewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		rewardLabel.TextSize = 9
		rewardLabel.Font = Enum.Font.Gotham
		rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
		rewardLabel.Parent = questCard
	end

	-- Если нет активных квестов
	if #activeQuests == 0 then
		local noQuestsLabel = Instance.new("TextLabel")
		noQuestsLabel.Size = UDim2.new(1, 0, 0, 50)
		noQuestsLabel.Position = UDim2.new(0, 0, 0.4, 0)
		noQuestsLabel.BackgroundTransparency = 1
		noQuestsLabel.Text = "No active quests\nTalk to NPCs to get quests"
		noQuestsLabel.TextColor3 = COLORS.TextMuted
		noQuestsLabel.TextSize = 12
		noQuestsLabel.Font = Enum.Font.Gotham
		noQuestsLabel.Parent = questsScroll
	end

	-- ============================================
	-- === RACE CONTENT (контейнер для вкладки RACE) ===
	-- ============================================
	local raceContent = Instance.new("Frame")
	raceContent.Name = "RaceContent"
	raceContent.Size = UDim2.new(1, 0, 1, -45)
	raceContent.Position = UDim2.new(0, 0, 0, 45)
	raceContent.BackgroundTransparency = 1
	raceContent.Visible = (selectedTab == "RACE")
	raceContent.Parent = background

	-- === CURRENT RACE (сверху по центру) ===
	local currentRaceLabel = Instance.new("TextLabel")
	currentRaceLabel.Name = "CurrentRaceLabel"
	currentRaceLabel.Size = UDim2.new(0, 300, 0, 25)
	currentRaceLabel.Position = UDim2.new(0.5, -150, 0, 15)
	currentRaceLabel.BackgroundTransparency = 1
	currentRaceLabel.Text = "Current Race:"
	currentRaceLabel.TextColor3 = COLORS.TextMuted
	currentRaceLabel.TextSize = 16
	currentRaceLabel.Font = Enum.Font.Gotham
	currentRaceLabel.Parent = raceContent

	local currentRaceName = Instance.new("TextLabel")
	currentRaceName.Name = "CurrentRaceName"
	currentRaceName.Size = UDim2.new(0, 400, 0, 40)
	currentRaceName.Position = UDim2.new(0.5, -200, 0, 40)
	currentRaceName.BackgroundTransparency = 1
	currentRaceName.Text = playerData.currentRace.Name
	currentRaceName.TextColor3 = RacesConfig.RarityColors[playerData.currentRace.Rarity]
	currentRaceName.TextSize = 32
	currentRaceName.Font = Enum.Font.GothamBold
	currentRaceName.Parent = raceContent

	-- === ЛЕВАЯ ПАНЕЛЬ - RACE STATS ===
	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = UDim2.new(0, 280, 0, 400)
	leftPanel.Position = UDim2.new(0, 20, 0, 85)
	leftPanel.BackgroundColor3 = COLORS.Panel
	leftPanel.BackgroundTransparency = 0.3
	leftPanel.BorderSizePixel = 0
	leftPanel.Parent = raceContent

	local leftPanelCorner = Instance.new("UICorner")
	leftPanelCorner.CornerRadius = UDim.new(0, 8)
	leftPanelCorner.Parent = leftPanel

	local leftPanelStroke = Instance.new("UIStroke")
	leftPanelStroke.Color = COLORS.PanelBorder
	leftPanelStroke.Thickness = 1
	leftPanelStroke.Parent = leftPanel

	-- Race Stats заголовок
	local raceStatsTitle = Instance.new("TextLabel")
	raceStatsTitle.Name = "RaceStatsTitle"
	raceStatsTitle.Size = UDim2.new(1, -20, 0, 30)
	raceStatsTitle.Position = UDim2.new(0, 10, 0, 10)
	raceStatsTitle.BackgroundTransparency = 1
	raceStatsTitle.Text = "Race Stats"
	raceStatsTitle.TextColor3 = COLORS.Text
	raceStatsTitle.TextSize = 18
	raceStatsTitle.Font = Enum.Font.GothamBold
	raceStatsTitle.TextXAlignment = Enum.TextXAlignment.Left
	raceStatsTitle.Parent = leftPanel

	-- Race Slots заголовок
	local raceSlotsTitle = Instance.new("TextLabel")
	raceSlotsTitle.Name = "RaceSlotsTitle"
	raceSlotsTitle.Size = UDim2.new(1, -20, 0, 20)
	raceSlotsTitle.Position = UDim2.new(0, 10, 0, 45)
	raceSlotsTitle.BackgroundTransparency = 1
	raceSlotsTitle.Text = "Race Slots:"
	raceSlotsTitle.TextColor3 = COLORS.TextMuted
	raceSlotsTitle.TextSize = 12
	raceSlotsTitle.Font = Enum.Font.Gotham
	raceSlotsTitle.TextXAlignment = Enum.TextXAlignment.Left
	raceSlotsTitle.Parent = leftPanel

	-- Race Slots контейнер
	local slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "SlotsContainer"
	slotsContainer.Size = UDim2.new(1, -20, 0, 70)
	slotsContainer.Position = UDim2.new(0, 10, 0, 65)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.Parent = leftPanel

	local slotsLayout = Instance.new("UIListLayout")
	slotsLayout.FillDirection = Enum.FillDirection.Horizontal
	slotsLayout.Padding = UDim.new(0, 10)
	slotsLayout.Parent = slotsContainer

	-- Создаём слоты рас
	for i, slot in ipairs(playerData.raceSlots) do
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "Slot" .. i
		slotFrame.Size = UDim2.new(0, 75, 0, 70)
		slotFrame.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
		slotFrame.BorderSizePixel = 0
		slotFrame.Parent = slotsContainer

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slotFrame

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = slot.unlocked and COLORS.Accent or Color3.fromRGB(50, 45, 40)
		slotStroke.Thickness = slot.unlocked and 2 or 1
		slotStroke.Parent = slotFrame

		if slot.unlocked and slot.race then
			-- Показываем расу
			local raceName = Instance.new("TextLabel")
			raceName.Size = UDim2.new(1, -6, 0, 30)
			raceName.Position = UDim2.new(0, 3, 0, 5)
			raceName.BackgroundTransparency = 1
			raceName.Text = "- " .. slot.race.Name .. " -"
			raceName.TextColor3 = RacesConfig.RarityColors[slot.race.Rarity]
			raceName.TextSize = 10
			raceName.Font = Enum.Font.GothamMedium
			raceName.TextWrapped = true
			raceName.Parent = slotFrame

			local selectedLabel = Instance.new("TextLabel")
			selectedLabel.Size = UDim2.new(1, 0, 0, 15)
			selectedLabel.Position = UDim2.new(0, 0, 1, -20)
			selectedLabel.BackgroundTransparency = 1
			selectedLabel.Text = "(Selected)"
			selectedLabel.TextColor3 = COLORS.TextMuted
			selectedLabel.TextSize = 9
			selectedLabel.Font = Enum.Font.Gotham
			selectedLabel.Parent = slotFrame
		else
			-- Показываем locked
			local lvlLabel = Instance.new("TextLabel")
			lvlLabel.Size = UDim2.new(1, 0, 0, 20)
			lvlLabel.Position = UDim2.new(0, 0, 0, 10)
			lvlLabel.BackgroundTransparency = 1
			lvlLabel.Text = "Lvl. " .. slot.level
			lvlLabel.TextColor3 = COLORS.TextMuted
			lvlLabel.TextSize = 12
			lvlLabel.Font = Enum.Font.GothamMedium
			lvlLabel.Parent = slotFrame

			local lockIcon = Instance.new("ImageLabel")
			lockIcon.Size = UDim2.new(0, 20, 0, 20)
			lockIcon.Position = UDim2.new(0.5, -10, 0.5, 0)
			lockIcon.BackgroundTransparency = 1
			lockIcon.Image = "rbxassetid://7734056665"
			lockIcon.ImageColor3 = COLORS.TextMuted
			lockIcon.Parent = slotFrame

			local lockedLabel = Instance.new("TextLabel")
			lockedLabel.Size = UDim2.new(1, 0, 0, 15)
			lockedLabel.Position = UDim2.new(0, 0, 1, -18)
			lockedLabel.BackgroundTransparency = 1
			lockedLabel.Text = "(Locked)"
			lockedLabel.TextColor3 = COLORS.TextMuted
			lockedLabel.TextSize = 9
			lockedLabel.Font = Enum.Font.Gotham
			lockedLabel.Parent = slotFrame
		end
	end


	-- Race Perks заголовок
	local racePerksTitle = Instance.new("TextLabel")
	racePerksTitle.Name = "RacePerksTitle"
	racePerksTitle.Size = UDim2.new(1, -20, 0, 20)
	racePerksTitle.Position = UDim2.new(0, 10, 0, 145)
	racePerksTitle.BackgroundTransparency = 1
	racePerksTitle.Text = "Race Perks:"
	racePerksTitle.TextColor3 = COLORS.TextMuted
	racePerksTitle.TextSize = 12
	racePerksTitle.Font = Enum.Font.Gotham
	racePerksTitle.TextXAlignment = Enum.TextXAlignment.Left
	racePerksTitle.Parent = leftPanel

	-- Perks контейнер
	local perksContainer = Instance.new("Frame")
	perksContainer.Name = "PerksContainer"
	perksContainer.Size = UDim2.new(1, -20, 0, 230)
	perksContainer.Position = UDim2.new(0, 10, 0, 165)
	perksContainer.BackgroundTransparency = 1
	perksContainer.Parent = leftPanel

	local perksLayout = Instance.new("UIListLayout")
	perksLayout.FillDirection = Enum.FillDirection.Vertical
	perksLayout.Padding = UDim.new(0, 8)
	perksLayout.Parent = perksContainer

	-- Создаём перки текущей расы
	for i, perk in ipairs(playerData.currentRace.Perks) do
		local perkFrame = Instance.new("Frame")
		perkFrame.Name = "Perk" .. i
		perkFrame.Size = UDim2.new(1, 0, 0, 50)
		perkFrame.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
		perkFrame.BorderSizePixel = 0
		perkFrame.Parent = perksContainer

		local perkCorner = Instance.new("UICorner")
		perkCorner.CornerRadius = UDim.new(0, 6)
		perkCorner.Parent = perkFrame

		local perkName = Instance.new("TextLabel")
		perkName.Size = UDim2.new(1, -10, 0, 18)
		perkName.Position = UDim2.new(0, 8, 0, 5)
		perkName.BackgroundTransparency = 1
		perkName.Text = perk.Name .. ":"
		perkName.TextColor3 = COLORS.Accent
		perkName.TextSize = 12
		perkName.Font = Enum.Font.GothamBold
		perkName.TextXAlignment = Enum.TextXAlignment.Left
		perkName.Parent = perkFrame

		local perkDesc = Instance.new("TextLabel")
		perkDesc.Size = UDim2.new(1, -10, 0, 25)
		perkDesc.Position = UDim2.new(0, 8, 0, 22)
		perkDesc.BackgroundTransparency = 1
		perkDesc.Text = perk.Description
		perkDesc.TextColor3 = COLORS.TextMuted
		perkDesc.TextSize = 10
		perkDesc.Font = Enum.Font.Gotham
		perkDesc.TextXAlignment = Enum.TextXAlignment.Left
		perkDesc.TextWrapped = true
		perkDesc.Parent = perkFrame
	end

	-- === ПРАВАЯ ПАНЕЛЬ - RACE CHANCES ===
	local rightPanel = Instance.new("Frame")
	rightPanel.Name = "RightPanel"
	rightPanel.Size = UDim2.new(0, 200, 0, 400)
	rightPanel.Position = UDim2.new(1, -220, 0, 85)
	rightPanel.BackgroundColor3 = COLORS.Panel
	rightPanel.BackgroundTransparency = 0.3
	rightPanel.BorderSizePixel = 0
	rightPanel.Parent = raceContent

	local rightPanelCorner = Instance.new("UICorner")
	rightPanelCorner.CornerRadius = UDim.new(0, 8)
	rightPanelCorner.Parent = rightPanel

	local rightPanelStroke = Instance.new("UIStroke")
	rightPanelStroke.Color = COLORS.PanelBorder
	rightPanelStroke.Thickness = 1
	rightPanelStroke.Parent = rightPanel

	-- Race Chances заголовок
	local raceChancesTitle = Instance.new("TextLabel")
	raceChancesTitle.Name = "RaceChancesTitle"
	raceChancesTitle.Size = UDim2.new(1, -20, 0, 30)
	raceChancesTitle.Position = UDim2.new(0, 10, 0, 10)
	raceChancesTitle.BackgroundTransparency = 1
	raceChancesTitle.Text = "Race Chances"
	raceChancesTitle.TextColor3 = COLORS.Text
	raceChancesTitle.TextSize = 16
	raceChancesTitle.Font = Enum.Font.GothamBold
	raceChancesTitle.TextXAlignment = Enum.TextXAlignment.Left
	raceChancesTitle.Parent = rightPanel

	-- ScrollingFrame для списка рас
	local chancesScroll = Instance.new("ScrollingFrame")
	chancesScroll.Name = "ChancesScroll"
	chancesScroll.Size = UDim2.new(1, -20, 1, -50)
	chancesScroll.Position = UDim2.new(0, 10, 0, 45)
	chancesScroll.BackgroundTransparency = 1
	chancesScroll.BorderSizePixel = 0
	chancesScroll.ScrollBarThickness = 4
	chancesScroll.ScrollBarImageColor3 = COLORS.PanelBorder
	chancesScroll.CanvasSize = UDim2.new(0, 0, 0, #RacesConfig.Races * 22)
	chancesScroll.Parent = rightPanel

	local chancesLayout = Instance.new("UIListLayout")
	chancesLayout.FillDirection = Enum.FillDirection.Vertical
	chancesLayout.Padding = UDim.new(0, 4)
	chancesLayout.SortOrder = Enum.SortOrder.LayoutOrder -- Используем LayoutOrder вместо Name
	chancesLayout.Parent = chancesScroll

	-- Порядок редкости (от Common до Divine)
	local rarityOrder = {
		Common = 1,
		Uncommon = 2,
		Rare = 3,
		Epic = 4,
		Legendary = 5,
		Mythic = 6,
		Divine = 7,
	}

	-- Копируем и сортируем расы по редкости
	local sortedRaces = {}
	for _, race in ipairs(RacesConfig.Races) do
		table.insert(sortedRaces, race)
	end
	table.sort(sortedRaces, function(a, b)
		local orderA = rarityOrder[a.Rarity] or 99
		local orderB = rarityOrder[b.Rarity] or 99
		if orderA == orderB then
			return a.Chance > b.Chance -- Внутри редкости сортируем по шансу (больший шанс выше)
		end
		return orderA < orderB
	end)

	-- Создаём список шансов рас (отсортированный по редкости)
	for i, race in ipairs(sortedRaces) do
		local chanceRow = Instance.new("Frame")
		chanceRow.Name = "Chance_" .. race.Name
		chanceRow.Size = UDim2.new(1, 0, 0, 18)
		chanceRow.BackgroundTransparency = 1
		chanceRow.LayoutOrder = i -- Устанавливаем порядок
		chanceRow.Parent = chancesScroll

		local bullet = Instance.new("TextLabel")
		bullet.Size = UDim2.new(0, 15, 1, 0)
		bullet.Position = UDim2.new(0, 0, 0, 0)
		bullet.BackgroundTransparency = 1
		bullet.Text = "•"
		bullet.TextColor3 = RacesConfig.RarityColors[race.Rarity]
		bullet.TextSize = 14
		bullet.Font = Enum.Font.GothamBold
		bullet.Parent = chanceRow

		local raceName = Instance.new("TextLabel")
		raceName.Size = UDim2.new(1, -15, 1, 0)
		raceName.Position = UDim2.new(0, 15, 0, 0)
		raceName.BackgroundTransparency = 1
		raceName.Text = race.Name .. " (" .. race.Chance .. "%)"
		raceName.TextColor3 = RacesConfig.RarityColors[race.Rarity]
		raceName.TextSize = 11
		raceName.Font = Enum.Font.Gotham
		raceName.TextXAlignment = Enum.TextXAlignment.Left
		raceName.Parent = chanceRow
	end


	-- === НИЖНЯЯ ПАНЕЛЬ - SPINS И REROLL ===
	local bottomPanel = Instance.new("Frame")
	bottomPanel.Name = "BottomPanel"
	bottomPanel.Size = UDim2.new(0, 350, 0, 80)
	bottomPanel.Position = UDim2.new(0.5, -175, 1, -55)
	bottomPanel.BackgroundTransparency = 1
	bottomPanel.Parent = raceContent

	-- Spins label
	local spinsLabel = Instance.new("TextLabel")
	spinsLabel.Name = "SpinsLabel"
	spinsLabel.Size = UDim2.new(1, 0, 0, 25)
	spinsLabel.Position = UDim2.new(0, 0, 0, 0)
	spinsLabel.BackgroundTransparency = 1
	spinsLabel.Text = "Spins: " .. playerData.spins
	spinsLabel.TextColor3 = COLORS.TextMuted
	spinsLabel.TextSize = 14
	spinsLabel.Font = Enum.Font.Gotham
	spinsLabel.Parent = bottomPanel

	-- Кнопки контейнер
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "ButtonsContainer"
	buttonsContainer.Size = UDim2.new(1, 0, 0, 45)
	buttonsContainer.Position = UDim2.new(0, 0, 0, 30)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.Parent = bottomPanel

	local buttonsLayout = Instance.new("UIListLayout")
	buttonsLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonsLayout.Padding = UDim.new(0, 15)
	buttonsLayout.Parent = buttonsContainer

	-- Reroll кнопка
	local rerollBtn = Instance.new("TextButton")
	rerollBtn.Name = "RerollBtn"
	rerollBtn.Size = UDim2.new(0, 150, 0, 45)
	rerollBtn.BackgroundColor3 = COLORS.ButtonBg
	rerollBtn.Text = "Reroll"
	rerollBtn.TextColor3 = COLORS.Text
	rerollBtn.TextSize = 20
	rerollBtn.Font = Enum.Font.GothamBold
	rerollBtn.Parent = buttonsContainer

	local rerollCorner = Instance.new("UICorner")
	rerollCorner.CornerRadius = UDim.new(0, 8)
	rerollCorner.Parent = rerollBtn

	local rerollStroke = Instance.new("UIStroke")
	rerollStroke.Color = COLORS.PanelBorder
	rerollStroke.Thickness = 2
	rerollStroke.Parent = rerollBtn

	-- Buy Rerolls кнопка
	local buyRerollsBtn = Instance.new("TextButton")
	buyRerollsBtn.Name = "BuyRerollsBtn"
	buyRerollsBtn.Size = UDim2.new(0, 120, 0, 45)
	buyRerollsBtn.BackgroundColor3 = Color3.fromRGB(50, 45, 40)
	buyRerollsBtn.Text = "Buy Rerolls"
	buyRerollsBtn.TextColor3 = COLORS.TextMuted
	buyRerollsBtn.TextSize = 14
	buyRerollsBtn.Font = Enum.Font.GothamMedium
	buyRerollsBtn.Parent = buttonsContainer

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 8)
	buyCorner.Parent = buyRerollsBtn

	local buyStroke = Instance.new("UIStroke")
	buyStroke.Color = COLORS.PanelBorder
	buyStroke.Thickness = 1
	buyStroke.Parent = buyRerollsBtn

	-- Hover эффекты для кнопок
	rerollBtn.MouseEnter:Connect(function()
		rerollBtn.BackgroundColor3 = COLORS.ButtonHover
	end)
	rerollBtn.MouseLeave:Connect(function()
		rerollBtn.BackgroundColor3 = COLORS.ButtonBg
	end)

	buyRerollsBtn.MouseEnter:Connect(function()
		buyRerollsBtn.BackgroundColor3 = Color3.fromRGB(60, 55, 50)
	end)
	buyRerollsBtn.MouseLeave:Connect(function()
		buyRerollsBtn.BackgroundColor3 = Color3.fromRGB(50, 45, 40)
	end)

	-- Reroll функционал
	rerollBtn.MouseButton1Click:Connect(function()
		if playerData.spins > 0 then
			playerData.spins = playerData.spins - 1
			spinsLabel.Text = "Spins: " .. playerData.spins

			-- Роллим новую расу
			local newRace = RacesConfig.Roll()
			playerData.currentRace = newRace
			playerData.raceSlots[1].race = newRace

			-- Обновляем UI
			currentRaceName.Text = newRace.Name
			currentRaceName.TextColor3 = RacesConfig.RarityColors[newRace.Rarity]

			-- Перестраиваем перки
			for _, child in ipairs(perksContainer:GetChildren()) do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end

			for i, perk in ipairs(newRace.Perks) do
				local perkFrame = Instance.new("Frame")
				perkFrame.Name = "Perk" .. i
				perkFrame.Size = UDim2.new(1, 0, 0, 50)
				perkFrame.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
				perkFrame.BorderSizePixel = 0
				perkFrame.Parent = perksContainer

				local perkCorner = Instance.new("UICorner")
				perkCorner.CornerRadius = UDim.new(0, 6)
				perkCorner.Parent = perkFrame

				local perkName = Instance.new("TextLabel")
				perkName.Size = UDim2.new(1, -10, 0, 18)
				perkName.Position = UDim2.new(0, 8, 0, 5)
				perkName.BackgroundTransparency = 1
				perkName.Text = perk.Name .. ":"
				perkName.TextColor3 = COLORS.Accent
				perkName.TextSize = 12
				perkName.Font = Enum.Font.GothamBold
				perkName.TextXAlignment = Enum.TextXAlignment.Left
				perkName.Parent = perkFrame

				local perkDesc = Instance.new("TextLabel")
				perkDesc.Size = UDim2.new(1, -10, 0, 25)
				perkDesc.Position = UDim2.new(0, 8, 0, 22)
				perkDesc.BackgroundTransparency = 1
				perkDesc.Text = perk.Description
				perkDesc.TextColor3 = COLORS.TextMuted
				perkDesc.TextSize = 10
				perkDesc.Font = Enum.Font.Gotham
				perkDesc.TextXAlignment = Enum.TextXAlignment.Left
				perkDesc.TextWrapped = true
				perkDesc.Parent = perkFrame
			end

			-- Обновляем первый слот
			local slot1 = slotsContainer:FindFirstChild("Slot1")
			if slot1 then
				for _, child in ipairs(slot1:GetChildren()) do
					if child:IsA("TextLabel") then
						child:Destroy()
					end
				end

				local raceName = Instance.new("TextLabel")
				raceName.Size = UDim2.new(1, -6, 0, 30)
				raceName.Position = UDim2.new(0, 3, 0, 5)
				raceName.BackgroundTransparency = 1
				raceName.Text = "- " .. newRace.Name .. " -"
				raceName.TextColor3 = RacesConfig.RarityColors[newRace.Rarity]
				raceName.TextSize = 10
				raceName.Font = Enum.Font.GothamMedium
				raceName.TextWrapped = true
				raceName.Parent = slot1

				local selectedLabel = Instance.new("TextLabel")
				selectedLabel.Size = UDim2.new(1, 0, 0, 15)
				selectedLabel.Position = UDim2.new(0, 0, 1, -20)
				selectedLabel.BackgroundTransparency = 1
				selectedLabel.Text = "(Selected)"
				selectedLabel.TextColor3 = COLORS.TextMuted
				selectedLabel.TextSize = 9
				selectedLabel.Font = Enum.Font.Gotham
				selectedLabel.Parent = slot1
			end
		end
	end)

	return menuGui
end

-- === УДАЛЕНИЕ UI МЕНЮ ===
local function destroyMenuUI()
	if menuGui then
		menuGui:Destroy()
		menuGui = nil
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

-- === ОЧИСТКА ПРИ РЕСПАВНЕ ===
player.CharacterAdded:Connect(function()
	if CharacterPanel.IsOpen then
		CharacterPanel.Close()
	end
end)

return CharacterPanel
