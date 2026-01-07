--[[
	ShopMenu - Меню магазина Game Passes
	Стиль: Cyberpunk
	Закрытие на TAB или клик вне меню
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

-- === ЦВЕТА НЕОН-АНИМЕ ===
local COLORS = {
	Panel = Color3.fromRGB(15, 15, 35),
	Border = Color3.fromRGB(255, 0, 255),           -- Розовый (магазин = деньги = розовый)
	BorderDim = Color3.fromRGB(180, 0, 180),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(140, 140, 160),
	Price = Color3.fromRGB(100, 255, 150),          -- Зелёный для цены
	Owned = Color3.fromRGB(0, 255, 255),            -- Циан для "куплено"
	ItemBg = Color3.fromRGB(25, 25, 50),
}

-- === ЗВУКИ ===
local hoverSound = Instance.new("Sound")
hoverSound.SoundId = "rbxassetid://6895079853"
hoverSound.Volume = 0.3
hoverSound.Parent = playerGui

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6895079853"
clickSound.Volume = 0.4
clickSound.Parent = playerGui

-- === СОСТОЯНИЕ ===
local shopOpen = false

-- === ГЛОБАЛЬНЫЙ ФЛАГ ===
local shopOpenValue = player:FindFirstChild("ShopMenuOpen")
if not shopOpenValue then
	shopOpenValue = Instance.new("BoolValue")
	shopOpenValue.Name = "ShopMenuOpen"
	shopOpenValue.Value = false
	shopOpenValue.Parent = player
end

-- === БЛЮР ===
local shopBlur = Lighting:FindFirstChild("ShopBlur")
if not shopBlur then
	shopBlur = Instance.new("BlurEffect")
	shopBlur.Name = "ShopBlur"
	shopBlur.Size = 0
	shopBlur.Enabled = false
	shopBlur.Parent = Lighting
end

-- === GUI ===
local shopGui = Instance.new("ScreenGui")
shopGui.Name = "ShopMenuGui"
shopGui.ResetOnSpawn = false
shopGui.IgnoreGuiInset = true
shopGui.DisplayOrder = 200
shopGui.Enabled = false
shopGui.Parent = playerGui

-- Затемнение
local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = shopGui

-- === ГЛАВНАЯ ПАНЕЛЬ ===
local mainPanel = Instance.new("Frame")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 450, 0, 400)
mainPanel.Position = UDim2.new(0.5, -225, 0.5, -200)
mainPanel.BackgroundColor3 = COLORS.Panel
mainPanel.BackgroundTransparency = 0.05
mainPanel.BorderSizePixel = 0
mainPanel.Parent = shopGui

local outerBorder = Instance.new("UIStroke")
outerBorder.Color = COLORS.Border
outerBorder.Thickness = 2
outerBorder.Parent = mainPanel

-- Угловые изображения
local panelCornerBL = Instance.new("ImageLabel")
panelCornerBL.Size = UDim2.new(0, 18, 0, 18)
panelCornerBL.Position = UDim2.new(0, 0, 1, -18)
panelCornerBL.BackgroundTransparency = 1
panelCornerBL.Image = "rbxassetid://132921287217893"
panelCornerBL.ImageColor3 = COLORS.Border
panelCornerBL.Rotation = -90
panelCornerBL.Parent = mainPanel

local panelCornerBR = Instance.new("ImageLabel")
panelCornerBR.Size = UDim2.new(0, 18, 0, 18)
panelCornerBR.Position = UDim2.new(1, -18, 1, -18)
panelCornerBR.BackgroundTransparency = 1
panelCornerBR.Image = "rbxassetid://132921287217893"
panelCornerBR.ImageColor3 = COLORS.Border
panelCornerBR.Rotation = 180
panelCornerBR.Parent = mainPanel


-- === ЗАГОЛОВОК ===
local headerBar = Instance.new("Frame")
headerBar.Name = "HeaderBar"
headerBar.Size = UDim2.new(1, -4, 0, 45)
headerBar.Position = UDim2.new(0, 2, 0, 2)
headerBar.BackgroundColor3 = Color3.fromRGB(10, 3, 25)
headerBar.BackgroundTransparency = 0.1
headerBar.BorderSizePixel = 0
headerBar.Parent = mainPanel

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, 0, 1, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "GAME PASSES"
headerTitle.TextColor3 = COLORS.Border
headerTitle.TextSize = 22
headerTitle.Font = Enum.Font.GothamBold
headerTitle.Parent = headerBar

-- Угловые изображения заголовка
local cornerTL = Instance.new("ImageLabel")
cornerTL.Size = UDim2.new(0, 12, 0, 12)
cornerTL.Position = UDim2.new(0, 0, 0, 0)
cornerTL.BackgroundTransparency = 1
cornerTL.Image = "rbxassetid://132921287217893"
cornerTL.ImageColor3 = COLORS.Border
cornerTL.Parent = headerBar

local cornerTR = Instance.new("ImageLabel")
cornerTR.Size = UDim2.new(0, 12, 0, 12)
cornerTR.Position = UDim2.new(1, -12, 0, 0)
cornerTR.BackgroundTransparency = 1
cornerTR.Image = "rbxassetid://132921287217893"
cornerTR.ImageColor3 = COLORS.Border
cornerTR.Rotation = 90
cornerTR.Parent = headerBar

local cornerBL = Instance.new("ImageLabel")
cornerBL.Size = UDim2.new(0, 12, 0, 12)
cornerBL.Position = UDim2.new(0, 0, 1, -12)
cornerBL.BackgroundTransparency = 1
cornerBL.Image = "rbxassetid://132921287217893"
cornerBL.ImageColor3 = COLORS.Border
cornerBL.Rotation = -90
cornerBL.Parent = headerBar

local cornerBR = Instance.new("ImageLabel")
cornerBR.Size = UDim2.new(0, 12, 0, 12)
cornerBR.Position = UDim2.new(1, -12, 1, -12)
cornerBR.BackgroundTransparency = 1
cornerBR.Image = "rbxassetid://132921287217893"
cornerBR.ImageColor3 = COLORS.Border
cornerBR.Rotation = 180
cornerBR.Parent = headerBar

-- Линии под заголовком
local headerLine = Instance.new("Frame")
headerLine.Size = UDim2.new(1, 4, 0, 2)
headerLine.Position = UDim2.new(0, -2, 1, 0)
headerLine.BackgroundColor3 = Color3.fromRGB(15, 5, 30)
headerLine.BorderSizePixel = 0
headerLine.Parent = headerBar

local headerLine2 = Instance.new("Frame")
headerLine2.Size = UDim2.new(1, 4, 0, 2)
headerLine2.Position = UDim2.new(0, -2, 1, 2)
headerLine2.BackgroundColor3 = COLORS.Border
headerLine2.BorderSizePixel = 0
headerLine2.Parent = headerBar

-- === КОНТЕНТ ===
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -20, 1, -70)
contentFrame.Position = UDim2.new(0, 10, 0, 60)
contentFrame.BackgroundTransparency = 1
contentFrame.ScrollBarThickness = 0
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.BorderSizePixel = 0
contentFrame.Parent = mainPanel

local contentLayout = Instance.new("UIListLayout")
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 10)
contentLayout.Parent = contentFrame


-- === GAME PASSES ===
-- Замени ID на свои реальные Game Pass ID
local gamePasses = {
	{id = 0, name = "VIP Pass", desc = "2x XP, exclusive items, VIP badge", price = "99 R$", icon = "👑"},
	{id = 0, name = "Double Coins", desc = "Earn 2x coins from all sources", price = "49 R$", icon = "💰"},
	{id = 0, name = "Speed Boost", desc = "+25% movement speed permanently", price = "79 R$", icon = "⚡"},
	{id = 0, name = "Extra Lives", desc = "Start with 3 extra lives each run", price = "59 R$", icon = "❤️"},
}

-- === СОЗДАНИЕ КАРТОЧКИ ПАССА ===
local function createPassCard(passData, order)
	local owned = false
	if passData.id > 0 then
		pcall(function()
			owned = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passData.id)
		end)
	end
	
	local card = Instance.new("Frame")
	card.Name = "Pass_" .. passData.name
	card.Size = UDim2.new(1, 0, 0, 80)
	card.BackgroundColor3 = COLORS.ItemBg
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = contentFrame
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = owned and COLORS.Owned or COLORS.BorderDim
	cardStroke.Thickness = 1
	cardStroke.Parent = card
	
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 6)
	cardCorner.Parent = card
	
	-- Иконка
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(0, 50, 0, 50)
	iconLabel.Position = UDim2.new(0, 15, 0.5, -25)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = passData.icon
	iconLabel.TextSize = 32
	iconLabel.Parent = card
	
	-- Название
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 200, 0, 24)
	nameLabel.Position = UDim2.new(0, 75, 0, 12)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = passData.name
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card
	
	-- Описание
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0, 250, 0, 20)
	descLabel.Position = UDim2.new(0, 75, 0, 38)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = passData.desc
	descLabel.TextColor3 = COLORS.TextDim
	descLabel.TextSize = 12
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = card
	
	-- Кнопка покупки / статус
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0, 90, 0, 36)
	buyBtn.Position = UDim2.new(1, -105, 0.5, -18)
	buyBtn.BackgroundColor3 = owned and COLORS.Owned or COLORS.Border
	buyBtn.BorderSizePixel = 0
	buyBtn.Text = owned and "OWNED" or passData.price
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.TextSize = 14
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.AutoButtonColor = not owned
	buyBtn.Parent = card
	
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 4)
	buyCorner.Parent = buyBtn
	
	if not owned then
		buyBtn.MouseEnter:Connect(function()
			hoverSound:Play()
			TweenService:Create(buyBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 50, 150)}):Play()
		end)
		buyBtn.MouseLeave:Connect(function()
			TweenService:Create(buyBtn, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.Border}):Play()
		end)
		buyBtn.MouseButton1Click:Connect(function()
			clickSound:Play()
			if passData.id > 0 then
				MarketplaceService:PromptGamePassPurchase(player, passData.id)
			end
		end)
	end
	
	return card
end

-- Создаём карточки
for i, pass in ipairs(gamePasses) do
	createPassCard(pass, i)
end


-- === БЛОКИРОВКА УПРАВЛЕНИЯ ===
local controlsDisabled = false
local savedMouseBehavior = nil

local function disableControls()
	if controlsDisabled then return end
	controlsDisabled = true
	
	savedMouseBehavior = UserInputService.MouseBehavior
	
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpHeight = 0
			humanoid.JumpPower = 0
		end
	end
	
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	
	ContextActionService:BindAction(
		"DisableMovementShop",
		function() return Enum.ContextActionResult.Sink end,
		false,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
	
	ContextActionService:BindAction(
		"DisableCameraRotationShop",
		function() return Enum.ContextActionResult.Sink end,
		false,
		Enum.UserInputType.MouseMovement,
		Enum.UserInputType.MouseWheel
	)
end

local function enableControls()
	if not controlsDisabled then return end
	controlsDisabled = false
	
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			local RunConfig = ReplicatedStorage:FindFirstChild("RunConfig")
			if RunConfig then
				local config = require(RunConfig)
				humanoid.WalkSpeed = config.WalkSpeed or 16
				humanoid.JumpHeight = config.JumpHeight or 7.2
				humanoid.JumpPower = 50
			else
				humanoid.WalkSpeed = 16
				humanoid.JumpHeight = 7.2
				humanoid.JumpPower = 50
			end
		end
	end
	
	local isShiftLocked = player:FindFirstChild("IsShiftLocked")
	if isShiftLocked and isShiftLocked.Value then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = savedMouseBehavior or Enum.MouseBehavior.Default
	end
	
	ContextActionService:UnbindAction("DisableMovementShop")
	ContextActionService:UnbindAction("DisableCameraRotationShop")
end

-- === АНИМАЦИИ ===
local function openShop()
	if shopOpen then return end
	shopOpen = true
	shopOpenValue.Value = true
	shopGui.Enabled = true
	
	disableControls()

	shopBlur.Enabled = true
	TweenService:Create(shopBlur, TweenInfo.new(0.4), {Size = 15}):Play()
	TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.5}):Play()

	mainPanel.Position = UDim2.new(0.5, -225, 0, -450)
	
	TweenService:Create(mainPanel, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -225, 0.5, -200)
	}):Play()
end

local function closeShop()
	if not shopOpen then return end
	shopOpen = false
	shopOpenValue.Value = false
	
	enableControls()

	TweenService:Create(shopBlur, TweenInfo.new(0.3), {Size = 0}):Play()
	task.delay(0.3, function()
		if not shopOpen then shopBlur.Enabled = false end
	end)

	TweenService:Create(overlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()

	TweenService:Create(mainPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5, -225, 1, 100)
	}):Play()

	task.delay(0.35, function()
		if not shopOpen then
			shopGui.Enabled = false
			mouse.Icon = ""
		end
	end)
end

-- === ЗАКРЫТИЕ НА TAB ===
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Tab and shopOpen then
		closeShop()
	end
end)

-- === ЗАКРЫТИЕ ПО КЛИКУ НА OVERLAY ===
overlay.MouseButton1Click:Connect(function()
	if shopOpen then
		closeShop()
	end
end)

-- === МОДУЛЬ ===
local ShopMenu = {}
function ShopMenu.Open() openShop() end
function ShopMenu.Close() closeShop() end
function ShopMenu.Toggle()
	if shopOpen then closeShop() else openShop() end
end
function ShopMenu.IsOpen() return shopOpen end

return ShopMenu
