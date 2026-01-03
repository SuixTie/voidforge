--[[
	CharacterPanel - Панель персонажа с 3D превью
	Voidforge: Eclipse Legacy
	
	При открытии:
	- Камера перемещается к копии модели игрока
	- HUD и компас плавно уходят за экран
	- Показывается UI меню как в SCP
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

local CharacterPanel = {}
CharacterPanel.IsOpen = false

-- === НАСТРОЙКИ ===
local TWEEN_TIME = 0.5

-- === ЦВЕТА ===
local COLORS = {
	Background = Color3.fromRGB(0, 0, 0),
	BackgroundTransparent = 0.3,
	Panel = Color3.fromRGB(20, 20, 20),
	PanelTransparent = 0.5,
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(150, 150, 150),
	Accent = Color3.fromRGB(200, 160, 80), -- Золотистый акцент
	ButtonHover = Color3.fromRGB(40, 40, 40),
	ButtonActive = Color3.fromRGB(60, 60, 60),
	Border = Color3.fromRGB(80, 80, 80),
}

-- === СОСТОЯНИЕ ===
local characterClone = nil
local originalPreviewModel = nil
local savedCameraType = nil
local savedCameraCFrame = nil
local savedWalkSpeed = nil
local savedJumpPower = nil
local cameraConnection = nil
local isAnimating = false
local idleAnimation = nil
local idleTrack = nil
local modelPosition = nil
local menuGui = nil
local selectedTab = "HOME"
local selectedRace = nil

-- === ДАННЫЕ РАС ===
local RACES_DATA = {
	{name = "Human", description = "Обычные люди. Сбалансированные характеристики без особых бонусов или штрафов."},
	{name = "Elf", description = "Древняя раса с повышенной ловкостью и магическими способностями."},
	{name = "Dwarf", description = "Крепкие и выносливые. Повышенная защита и сопротивление."},
	{name = "Orc", description = "Сильные воины с повышенным уроном, но сниженной магией."},
	{name = "Undead", description = "Восставшие из мёртвых. Иммунитет к яду, но уязвимы к свету."},
}

-- === СОЗДАНИЕ КОПИИ ПЕРСОНАЖА ===
local function createCharacterClone()
	-- Находим существующую модель CharacterPreview в workspace
	originalPreviewModel = workspace:FindFirstChild("CharacterPreview")
	if not originalPreviewModel then
		warn("CharacterPanel: CharacterPreview model not found in workspace!")
		return nil
	end

	-- Получаем позицию из существующей модели
	local existingRoot = originalPreviewModel:FindFirstChild("HumanoidRootPart") or originalPreviewModel:FindFirstChild("Torso") or originalPreviewModel.PrimaryPart
	if existingRoot then
		modelPosition = existingRoot.Position
	else
		-- Если нет корневой части, берём позицию первой BasePart
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

	-- Скрываем оригинальную модель (не удаляем!)
	for _, part in ipairs(originalPreviewModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end

	-- Удаляем старую копию если есть
	if characterClone then
		characterClone:Destroy()
		characterClone = nil
	end

	local character = player.Character
	if not character then return nil end

	-- Временно включаем Archivable для клонирования
	local wasArchivable = character.Archivable
	character.Archivable = true

	-- Клонируем персонажа
	characterClone = character:Clone()

	-- Возвращаем Archivable обратно
	character.Archivable = wasArchivable

	if not characterClone then return nil end

	characterClone.Name = "CharacterPreviewClone"

	-- Удаляем скрипты и ненужные объекты
	for _, child in ipairs(characterClone:GetDescendants()) do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
			child:Destroy()
		end
	end

	-- Отключаем физику у Humanoid и настраиваем анимации
	local humanoid = characterClone:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false -- Нужно false чтобы анимации работали

		-- ПОЛНОСТЬЮ удаляем старый Animator (он связан с оригиналом)
		local oldAnimator = humanoid:FindFirstChildOfClass("Animator")
		if oldAnimator then
			oldAnimator:Destroy()
		end

		-- Удаляем AnimationController если есть
		local animController = characterClone:FindFirstChildOfClass("AnimationController")
		if animController then
			animController:Destroy()
		end

		-- Удаляем Animate скрипт если остался
		local animateScript = characterClone:FindFirstChild("Animate")
		if animateScript then
			animateScript:Destroy()
		end

		-- Удаляем RealisticHeadMovement скрипт (управляет поворотом головы)
		local headMovement = characterClone:FindFirstChild("RealisticHeadMovement", true)
		if headMovement then
			headMovement:Destroy()
		end

		-- ПЕРЕСОЗДАЁМ ВСЕ Motor6D с нуля (R6)
		local torso = characterClone:FindFirstChild("Torso")
		local head = characterClone:FindFirstChild("Head")
		local leftArm = characterClone:FindFirstChild("Left Arm")
		local rightArm = characterClone:FindFirstChild("Right Arm")
		local leftLeg = characterClone:FindFirstChild("Left Leg")
		local rightLeg = characterClone:FindFirstChild("Right Leg")
		local hrp = characterClone:FindFirstChild("HumanoidRootPart")

		if torso then
			-- Удаляем ВСЕ старые Motor6D из ВСЕХ частей
			for _, part in ipairs(characterClone:GetDescendants()) do
				if part:IsA("Motor6D") then
					part:Destroy()
				end
			end

			-- СНАЧАЛА позиционируем все части вручную относительно Torso
			-- Это сбросит любые изменения от RealisticHeadMovement
			torso.CFrame = CFrame.new(modelPosition)

			if hrp then
				hrp.CFrame = torso.CFrame
			end

			if head then
				-- Голова на 1.5 studs выше центра торса
				head.CFrame = torso.CFrame * CFrame.new(0, 1.5, 0)
			end

			if leftArm then
				leftArm.CFrame = torso.CFrame * CFrame.new(-1.5, 0, 0)
			end

			if rightArm then
				rightArm.CFrame = torso.CFrame * CFrame.new(1.5, 0, 0)
			end

			if leftLeg then
				leftLeg.CFrame = torso.CFrame * CFrame.new(-0.5, -2, 0)
			end

			if rightLeg then
				rightLeg.CFrame = torso.CFrame * CFrame.new(0.5, -2, 0)
			end

			-- Теперь создаём новые Motor6D
			-- RootJoint
			if hrp then
				local rootJoint = Instance.new("Motor6D")
				rootJoint.Name = "RootJoint"
				rootJoint.Part0 = hrp
				rootJoint.Part1 = torso
				rootJoint.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
				rootJoint.C1 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
				rootJoint.Parent = hrp
			end

			-- Neck
			if head then
				local neck = Instance.new("Motor6D")
				neck.Name = "Neck"
				neck.Part0 = torso
				neck.Part1 = head
				neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
				neck.C1 = CFrame.new(0, -0.5, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
				neck.Parent = torso
			end

			-- Left Shoulder
			if leftArm then
				local leftShoulder = Instance.new("Motor6D")
				leftShoulder.Name = "Left Shoulder"
				leftShoulder.Part0 = torso
				leftShoulder.Part1 = leftArm
				leftShoulder.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0)
				leftShoulder.C1 = CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0)
				leftShoulder.Parent = torso
			end

			-- Right Shoulder
			if rightArm then
				local rightShoulder = Instance.new("Motor6D")
				rightShoulder.Name = "Right Shoulder"
				rightShoulder.Part0 = torso
				rightShoulder.Part1 = rightArm
				rightShoulder.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi/2, 0)
				rightShoulder.C1 = CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi/2, 0)
				rightShoulder.Parent = torso
			end

			-- Left Hip
			if leftLeg then
				local leftHip = Instance.new("Motor6D")
				leftHip.Name = "Left Hip"
				leftHip.Part0 = torso
				leftHip.Part1 = leftLeg
				leftHip.C0 = CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi/2, 0)
				leftHip.C1 = CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi/2, 0)
				leftHip.Parent = torso
			end

			-- Right Hip
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

		-- Ждём кадр чтобы изменения применились
		task.wait()

		-- Пересоздаём Weld'ы для аксессуаров
		for _, accessory in ipairs(characterClone:GetChildren()) do
			if accessory:IsA("Accessory") then
				local handle = accessory:FindFirstChild("Handle")
				if handle then
					-- Удаляем старый AccessoryWeld
					local oldWeld = handle:FindFirstChild("AccessoryWeld")
					if oldWeld then
						oldWeld:Destroy()
					end

					-- Находим к какой части тела крепится аксессуар
					local attachment = handle:FindFirstChildOfClass("Attachment")
					if attachment then
						local attachmentName = attachment.Name
						-- Ищем соответствующий Attachment на частях тела
						for _, part in ipairs(characterClone:GetDescendants()) do
							if part:IsA("Attachment") and part.Name == attachmentName and part.Parent ~= handle then
								-- Создаём новый Weld
								local newWeld = Instance.new("Weld")
								newWeld.Name = "AccessoryWeld"
								newWeld.Part0 = part.Parent
								newWeld.Part1 = handle
								newWeld.C0 = part.CFrame
								newWeld.C1 = attachment.CFrame
								newWeld.Parent = handle

								-- Позиционируем Handle правильно
								handle.CFrame = part.Parent.CFrame * part.CFrame * attachment.CFrame:Inverse()
								break
							end
						end
					end
				end
			end
		end

		-- Создаём НОВЫЙ Animator
		local newAnimator = Instance.new("Animator")
		newAnimator.Parent = humanoid

		-- Создаём и запускаем Idle анимацию
		idleAnimation = Instance.new("Animation")
		idleAnimation.AnimationId = "rbxassetid://125068773366975"

		idleTrack = newAnimator:LoadAnimation(idleAnimation)
		idleTrack.Looped = true
		idleTrack.Priority = Enum.AnimationPriority.Action
		idleTrack:Play(0)
	end

	-- Настраиваем части для анимации
	-- Только HumanoidRootPart anchored, остальные части двигаются через Motor6D
	local hrpClone = characterClone:FindFirstChild("HumanoidRootPart")
	for _, part in ipairs(characterClone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			if part == hrpClone then
				part.Anchored = true -- Только HRP anchored
			else
				part.Anchored = false -- Остальные части двигаются анимацией
			end
		end
	end

	-- Финальный поворот модели (без поворота - смотрит в сторону камеры)
	local rootPart = characterClone:FindFirstChild("HumanoidRootPart") or characterClone:FindFirstChild("Torso")
	if rootPart then
		characterClone.PrimaryPart = rootPart
		-- Без поворота (0 градусов) - персонаж смотрит в +Z, камера в -Z
		rootPart.CFrame = CFrame.new(modelPosition)
	end

	characterClone.Parent = workspace
	return characterClone
end

-- === УДАЛЕНИЕ КОПИИ ===
local function destroyCharacterClone()
	-- Останавливаем анимацию
	if idleTrack then
		idleTrack:Stop()
		idleTrack = nil
	end
	if idleAnimation then
		idleAnimation:Destroy()
		idleAnimation = nil
	end

	-- Удаляем копию игрока
	if characterClone then
		characterClone:Destroy()
		characterClone = nil
	end

	-- Показываем оригинальную модель CharacterPreview обратно
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

-- === СОЗДАНИЕ UI МЕНЮ ===
local function createMenuUI()
	if menuGui then
		menuGui:Destroy()
	end

	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end

	-- Главный ScreenGui
	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "CharacterPanelMenu"
	menuGui.ResetOnSpawn = false
	menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	menuGui.IgnoreGuiInset = true
	menuGui.Parent = playerGui

	-- Контейнер для UI (без тёмного фона)
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.Parent = menuGui

	-- === ВЕРХНЯЯ НАВИГАЦИЯ (стиль как на картинке) ===
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 45)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(15, 12, 10)
	topBar.BackgroundTransparency = 0.3
	topBar.BorderSizePixel = 0
	topBar.Parent = background

	-- Нижняя линия навигации
	local bottomLine = Instance.new("Frame")
	bottomLine.Name = "BottomLine"
	bottomLine.Size = UDim2.new(1, 0, 0, 2)
	bottomLine.Position = UDim2.new(0, 0, 1, -2)
	bottomLine.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
	bottomLine.BorderSizePixel = 0
	bottomLine.Parent = topBar

	-- Градиент для линии (затухание по краям)
	local lineGradient = Instance.new("UIGradient")
	lineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.3),
		NumberSequenceKeypoint.new(0.9, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	lineGradient.Parent = bottomLine

	-- Навигационные кнопки с иконками
	local navButtons = {
		{name = "HOME", icon = "rbxassetid://7733960981"},
		{name = "SETTINGS", icon = "rbxassetid://7734053495"},
		{name = "STORE", icon = "rbxassetid://9405933217"}
	}

	local navContainer = Instance.new("Frame")
	navContainer.Name = "NavContainer"
	navContainer.Size = UDim2.new(0, 500, 1, 0)
	navContainer.Position = UDim2.new(0.5, -250, 0, 0)
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
		navBtn.Size = UDim2.new(0, 120, 0, 30)
		navBtn.BackgroundTransparency = 1
		navBtn.Text = ""
		navBtn.Parent = navContainer

		-- Иконка
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(0, 16, 0, 16)
		icon.Position = UDim2.new(0, 0, 0.5, -8)
		icon.BackgroundTransparency = 1
		icon.Image = tabData.icon
		icon.ImageColor3 = selectedTab == tabData.name and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 110, 100)
		icon.Parent = navBtn

		-- Текст
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, -24, 1, 0)
		label.Position = UDim2.new(0, 24, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = tabData.name
		label.TextColor3 = selectedTab == tabData.name and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 110, 100)
		label.TextSize = 13
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = navBtn

		navBtn.MouseButton1Click:Connect(function()
			selectedTab = tabData.name
			-- Обновляем цвета кнопок (иконка + текст)
			for _, btn in ipairs(navContainer:GetChildren()) do
				if btn:IsA("TextButton") then
					local isSelected = btn.Name == selectedTab
					local btnIcon = btn:FindFirstChild("Icon")
					local btnLabel = btn:FindFirstChild("Label")
					local activeColor = Color3.fromRGB(255, 255, 255)
					local inactiveColor = Color3.fromRGB(120, 110, 100)

					if btnIcon then
						btnIcon.ImageColor3 = isSelected and activeColor or inactiveColor
					end
					if btnLabel then
						btnLabel.TextColor3 = isSelected and activeColor or inactiveColor
					end
				end
			end
		end)
	end

	-- Имя игрока справа
	local playerNameLabel = Instance.new("TextLabel")
	playerNameLabel.Name = "PlayerName"
	playerNameLabel.Size = UDim2.new(0, 150, 0, 30)
	playerNameLabel.Position = UDim2.new(1, -160, 0.5, -15)
	playerNameLabel.BackgroundTransparency = 1
	playerNameLabel.Text = player.Name
	playerNameLabel.TextColor3 = COLORS.TextMuted
	playerNameLabel.TextSize = 12
	playerNameLabel.Font = Enum.Font.Gotham
	playerNameLabel.TextXAlignment = Enum.TextXAlignment.Right
	playerNameLabel.Parent = topBar

	-- === ЛЕВАЯ ПАНЕЛЬ - РАСЫ ===
	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = UDim2.new(0, 400, 0, 500)
	leftPanel.Position = UDim2.new(0, 30, 0, 100)
	leftPanel.BackgroundTransparency = 1
	leftPanel.Parent = background

	-- Заголовок RACES
	local racesTitle = Instance.new("TextLabel")
	racesTitle.Name = "RacesTitle"
	racesTitle.Size = UDim2.new(1, 0, 0, 40)
	racesTitle.Position = UDim2.new(0, 0, 0, 0)
	racesTitle.BackgroundTransparency = 1
	racesTitle.Text = "RACES"
	racesTitle.TextColor3 = COLORS.Text
	racesTitle.TextSize = 28
	racesTitle.Font = Enum.Font.GothamBold
	racesTitle.TextXAlignment = Enum.TextXAlignment.Left
	racesTitle.Parent = leftPanel

	-- Описание
	local racesDesc = Instance.new("TextLabel")
	racesDesc.Name = "RacesDesc"
	racesDesc.Size = UDim2.new(1, 0, 0, 40)
	racesDesc.Position = UDim2.new(0, 0, 0, 45)
	racesDesc.BackgroundTransparency = 1
	racesDesc.Text = "Choose your race to define your character's abilities\nand starting attributes."
	racesDesc.TextColor3 = COLORS.TextMuted
	racesDesc.TextSize = 12
	racesDesc.Font = Enum.Font.Gotham
	racesDesc.TextXAlignment = Enum.TextXAlignment.Left
	racesDesc.TextYAlignment = Enum.TextYAlignment.Top
	racesDesc.TextWrapped = true
	racesDesc.Parent = leftPanel

	-- Подзаголовок Available Races
	local availableTitle = Instance.new("TextLabel")
	availableTitle.Name = "AvailableTitle"
	availableTitle.Size = UDim2.new(1, 0, 0, 25)
	availableTitle.Position = UDim2.new(0, 0, 0, 100)
	availableTitle.BackgroundTransparency = 1
	availableTitle.Text = "Available Races:"
	availableTitle.TextColor3 = COLORS.TextMuted
	availableTitle.TextSize = 14
	availableTitle.Font = Enum.Font.GothamMedium
	availableTitle.TextXAlignment = Enum.TextXAlignment.Left
	availableTitle.Parent = leftPanel

	-- Список рас
	local racesList = Instance.new("Frame")
	racesList.Name = "RacesList"
	racesList.Size = UDim2.new(1, 0, 0, 300)
	racesList.Position = UDim2.new(0, 0, 0, 130)
	racesList.BackgroundTransparency = 1
	racesList.Parent = leftPanel

	local racesLayout = Instance.new("UIListLayout")
	racesLayout.FillDirection = Enum.FillDirection.Vertical
	racesLayout.Padding = UDim.new(0, 5)
	racesLayout.Parent = racesList

	-- Создаём кнопки рас
	for i, raceData in ipairs(RACES_DATA) do
		local raceRow = Instance.new("Frame")
		raceRow.Name = "Race_" .. raceData.name
		raceRow.Size = UDim2.new(1, 0, 0, 40)
		raceRow.BackgroundTransparency = 1
		raceRow.Parent = racesList

		-- Разделитель слева (золотая линия для выбранной расы)
		local divider = Instance.new("Frame")
		divider.Name = "Divider"
		divider.Size = UDim2.new(0, 3, 1, -10)
		divider.Position = UDim2.new(0, 0, 0, 5)
		divider.BackgroundColor3 = COLORS.Accent
		divider.BackgroundTransparency = 1
		divider.BorderSizePixel = 0
		divider.Parent = raceRow

		-- Название расы
		local raceName = Instance.new("TextButton")
		raceName.Name = "RaceName"
		raceName.Size = UDim2.new(0, 200, 1, 0)
		raceName.Position = UDim2.new(0, 15, 0, 0)
		raceName.BackgroundTransparency = 1
		raceName.Text = raceData.name
		raceName.TextColor3 = COLORS.Accent
		raceName.TextSize = 16
		raceName.Font = Enum.Font.GothamMedium
		raceName.TextXAlignment = Enum.TextXAlignment.Left
		raceName.Parent = raceRow

		-- Кнопка SELECT
		local selectBtn = Instance.new("TextButton")
		selectBtn.Name = "SelectBtn"
		selectBtn.Size = UDim2.new(0, 80, 0, 30)
		selectBtn.Position = UDim2.new(1, -90, 0.5, -15)
		selectBtn.BackgroundTransparency = 1
		selectBtn.Text = "SELECT"
		selectBtn.TextColor3 = COLORS.Text
		selectBtn.TextSize = 14
		selectBtn.Font = Enum.Font.GothamBold
		selectBtn.Parent = raceRow

		-- Обработчики
		local function selectRace()
			selectedRace = raceData
			-- Обновляем визуал всех рас
			for _, row in ipairs(racesList:GetChildren()) do
				if row:IsA("Frame") then
					local div = row:FindFirstChild("Divider")
					if div then
						div.BackgroundTransparency = row.Name == "Race_" .. raceData.name and 0 or 1
					end
				end
			end
			-- Обновляем описание внизу
			updateRaceDescription()
		end

		raceName.MouseButton1Click:Connect(selectRace)
		selectBtn.MouseButton1Click:Connect(selectRace)
	end

	-- === ПРАВАЯ ПАНЕЛЬ - CHARACTER OPTIONS ===
	local rightPanel = Instance.new("Frame")
	rightPanel.Name = "RightPanel"
	rightPanel.Size = UDim2.new(0, 300, 0, 100)
	rightPanel.Position = UDim2.new(1, -330, 0, 100)
	rightPanel.BackgroundTransparency = 1
	rightPanel.Parent = background

	-- CHARACTER label
	local charLabel = Instance.new("TextLabel")
	charLabel.Name = "CharLabel"
	charLabel.Size = UDim2.new(0, 100, 0, 20)
	charLabel.Position = UDim2.new(0, 0, 0, 0)
	charLabel.BackgroundTransparency = 1
	charLabel.Text = "CHARACTER"
	charLabel.TextColor3 = COLORS.TextMuted
	charLabel.TextSize = 10
	charLabel.Font = Enum.Font.GothamBold
	charLabel.TextXAlignment = Enum.TextXAlignment.Left
	charLabel.Parent = rightPanel

	-- MALE / FEMALE buttons
	local maleBtn = Instance.new("TextButton")
	maleBtn.Name = "MaleBtn"
	maleBtn.Size = UDim2.new(0, 70, 0, 25)
	maleBtn.Position = UDim2.new(0, 0, 0, 25)
	maleBtn.BackgroundColor3 = COLORS.ButtonActive
	maleBtn.BackgroundTransparency = 0.5
	maleBtn.Text = "MALE"
	maleBtn.TextColor3 = COLORS.Text
	maleBtn.TextSize = 11
	maleBtn.Font = Enum.Font.GothamBold
	maleBtn.Parent = rightPanel

	local femaleBtn = Instance.new("TextButton")
	femaleBtn.Name = "FemaleBtn"
	femaleBtn.Size = UDim2.new(0, 70, 0, 25)
	femaleBtn.Position = UDim2.new(0, 75, 0, 25)
	femaleBtn.BackgroundTransparency = 1
	femaleBtn.Text = "FEMALE"
	femaleBtn.TextColor3 = COLORS.TextMuted
	femaleBtn.TextSize = 11
	femaleBtn.Font = Enum.Font.GothamBold
	femaleBtn.Parent = rightPanel

	-- LOAD AS label
	local loadAsLabel = Instance.new("TextLabel")
	loadAsLabel.Name = "LoadAsLabel"
	loadAsLabel.Size = UDim2.new(0, 100, 0, 20)
	loadAsLabel.Position = UDim2.new(0, 160, 0, 0)
	loadAsLabel.BackgroundTransparency = 1
	loadAsLabel.Text = "LOAD AS:"
	loadAsLabel.TextColor3 = COLORS.TextMuted
	loadAsLabel.TextSize = 10
	loadAsLabel.Font = Enum.Font.GothamBold
	loadAsLabel.TextXAlignment = Enum.TextXAlignment.Left
	loadAsLabel.Parent = rightPanel

	-- CUSTOM / DEFAULT buttons
	local customBtn = Instance.new("TextButton")
	customBtn.Name = "CustomBtn"
	customBtn.Size = UDim2.new(0, 70, 0, 25)
	customBtn.Position = UDim2.new(0, 160, 0, 25)
	customBtn.BackgroundColor3 = COLORS.ButtonActive
	customBtn.BackgroundTransparency = 0.5
	customBtn.Text = "CUSTOM"
	customBtn.TextColor3 = COLORS.Text
	customBtn.TextSize = 11
	customBtn.Font = Enum.Font.GothamBold
	customBtn.Parent = rightPanel

	local defaultBtn = Instance.new("TextButton")
	defaultBtn.Name = "DefaultBtn"
	defaultBtn.Size = UDim2.new(0, 70, 0, 25)
	defaultBtn.Position = UDim2.new(0, 235, 0, 25)
	defaultBtn.BackgroundTransparency = 1
	defaultBtn.Text = "DEFAULT"
	defaultBtn.TextColor3 = COLORS.TextMuted
	defaultBtn.TextSize = 11
	defaultBtn.Font = Enum.Font.GothamBold
	defaultBtn.Parent = rightPanel

	-- === НИЖНЯЯ ПАНЕЛЬ - ОПИСАНИЕ РАСЫ ===
	local bottomPanel = Instance.new("Frame")
	bottomPanel.Name = "BottomPanel"
	bottomPanel.Size = UDim2.new(0, 400, 0, 100)
	bottomPanel.Position = UDim2.new(1, -430, 1, -130)
	bottomPanel.BackgroundTransparency = 1
	bottomPanel.Parent = background

	-- Название расы
	local raceNameBottom = Instance.new("TextLabel")
	raceNameBottom.Name = "RaceNameBottom"
	raceNameBottom.Size = UDim2.new(0, 250, 0, 30)
	raceNameBottom.Position = UDim2.new(0, 0, 0, 0)
	raceNameBottom.BackgroundTransparency = 1
	raceNameBottom.Text = "Select a Race"
	raceNameBottom.TextColor3 = COLORS.Accent
	raceNameBottom.TextSize = 20
	raceNameBottom.Font = Enum.Font.GothamBold
	raceNameBottom.TextXAlignment = Enum.TextXAlignment.Left
	raceNameBottom.Parent = bottomPanel

	-- Счётчик (0/5)
	local raceCounter = Instance.new("TextLabel")
	raceCounter.Name = "RaceCounter"
	raceCounter.Size = UDim2.new(0, 50, 0, 30)
	raceCounter.Position = UDim2.new(0, 260, 0, 0)
	raceCounter.BackgroundTransparency = 1
	raceCounter.Text = "0/5"
	raceCounter.TextColor3 = COLORS.Text
	raceCounter.TextSize = 18
	raceCounter.Font = Enum.Font.GothamBold
	raceCounter.TextXAlignment = Enum.TextXAlignment.Left
	raceCounter.Parent = bottomPanel

	-- Описание расы
	local raceDescBottom = Instance.new("TextLabel")
	raceDescBottom.Name = "RaceDescBottom"
	raceDescBottom.Size = UDim2.new(1, 0, 0, 60)
	raceDescBottom.Position = UDim2.new(0, 0, 0, 35)
	raceDescBottom.BackgroundTransparency = 1
	raceDescBottom.Text = "Choose a race from the list to see its description."
	raceDescBottom.TextColor3 = COLORS.TextMuted
	raceDescBottom.TextSize = 13
	raceDescBottom.Font = Enum.Font.Gotham
	raceDescBottom.TextXAlignment = Enum.TextXAlignment.Left
	raceDescBottom.TextYAlignment = Enum.TextYAlignment.Top
	raceDescBottom.TextWrapped = true
	raceDescBottom.Parent = bottomPanel

	-- === КНОПКА MENU (внизу слева) ===
	local menuBtn = Instance.new("TextButton")
	menuBtn.Name = "MenuBtn"
	menuBtn.Size = UDim2.new(0, 80, 0, 35)
	menuBtn.Position = UDim2.new(0, 20, 1, -55)
	menuBtn.BackgroundColor3 = COLORS.Panel
	menuBtn.BackgroundTransparency = 0.5
	menuBtn.Text = "≡ Menu"
	menuBtn.TextColor3 = COLORS.Text
	menuBtn.TextSize = 14
	menuBtn.Font = Enum.Font.GothamMedium
	menuBtn.Parent = background

	local menuBtnCorner = Instance.new("UICorner")
	menuBtnCorner.CornerRadius = UDim.new(0, 4)
	menuBtnCorner.Parent = menuBtn

	menuBtn.MouseButton1Click:Connect(function()
		CharacterPanel.Close()
	end)

	-- Функция обновления описания расы
	function updateRaceDescription()
		local nameLabel = bottomPanel:FindFirstChild("RaceNameBottom")
		local descLabel = bottomPanel:FindFirstChild("RaceDescBottom")

		if selectedRace then
			if nameLabel then nameLabel.Text = selectedRace.name end
			if descLabel then descLabel.Text = selectedRace.description end
		else
			if nameLabel then nameLabel.Text = "Select a Race" end
			if descLabel then descLabel.Text = "Choose a race from the list to see its description." end
		end
	end

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

	-- Скрываем StaminaVignette
	local vignette = playerGui:FindFirstChild("StaminaVignette")
	if vignette then
		vignette.Enabled = false
	end

	-- Вызываем событие скрытия GUI (PlayerHUD и CompassGui3D сами отключат свои 3D компоненты)
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

	-- Показываем StaminaVignette
	local vignette = playerGui:FindFirstChild("StaminaVignette")
	if vignette then
		vignette.Enabled = true
	end

	-- Вызываем событие показа GUI (PlayerHUD и CompassGui3D сами включат свои 3D компоненты)
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

-- === АНИМАЦИЯ ВРАЩЕНИЯ МОДЕЛИ ===
local rotationAngle = 0
local function startModelRotation()
	if cameraConnection then
		cameraConnection:Disconnect()
	end

	cameraConnection = RunService.RenderStepped:Connect(function(dt)
		if not CharacterPanel.IsOpen or not characterClone or not modelPosition then return end

		-- Медленное вращение модели
		rotationAngle = rotationAngle + dt * 20 -- 20 градусов в секунду

		local rootPart = characterClone:FindFirstChild("HumanoidRootPart") or characterClone:FindFirstChild("Torso")
		if rootPart and characterClone.PrimaryPart then
			characterClone:SetPrimaryPartCFrame(
				CFrame.new(modelPosition) * CFrame.Angles(0, math.rad(rotationAngle), 0)
			)
		end
	end)
end

local function stopModelRotation()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
end

-- === ОТКРЫТИЕ ПАНЕЛИ ===
function CharacterPanel.Open()
	if CharacterPanel.IsOpen or isAnimating then return end
	isAnimating = true

	-- Создаём копию персонажа (заменяет CharacterPreview)
	createCharacterClone()

	if not characterClone or not modelPosition then 
		isAnimating = false
		return 
	end

	-- Сохраняем состояние камеры
	savedCameraType = camera.CameraType
	savedCameraCFrame = camera.CFrame

	-- Переключаем камеру в Scriptable
	camera.CameraType = Enum.CameraType.Scriptable

	-- Позиция камеры перед моделью, смотрит на персонажа (с противоположной стороны - Z = -5)
	local cameraPosition = modelPosition + Vector3.new(0, 1.5, -5) -- Сзади и чуть выше
	local lookAtPosition = modelPosition + Vector3.new(0, 1, 0) -- Смотрим на центр персонажа (грудь)
	camera.CFrame = CFrame.lookAt(cameraPosition, lookAtPosition)

	-- Скрываем GUI
	hideGUI()

	-- Блокируем движение
	disableMovement()

	-- Создаём флаг для других скриптов
	local menuOpenFlag = player:FindFirstChild("CharacterPanelOpen")
	if not menuOpenFlag then
		menuOpenFlag = Instance.new("BoolValue")
		menuOpenFlag.Name = "CharacterPanelOpen"
		menuOpenFlag.Parent = player
	end
	menuOpenFlag.Value = true

	-- Создаём UI меню
	createMenuUI()

	CharacterPanel.IsOpen = true
	isAnimating = false

	print("CharacterPanel: Opened")
end

-- === ЗАКРЫТИЕ ПАНЕЛИ ===
function CharacterPanel.Close()
	if not CharacterPanel.IsOpen or isAnimating then return end
	isAnimating = true

	-- Удаляем UI меню
	destroyMenuUI()

	-- Восстанавливаем тип камеры СНАЧАЛА
	if savedCameraType then
		camera.CameraType = savedCameraType
	end

	-- Показываем GUI
	showGUI()

	-- Разблокируем движение
	enableMovement()

	-- Удаляем копию персонажа
	destroyCharacterClone()

	-- Убираем флаг
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
