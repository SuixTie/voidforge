--[[
	GuiTheme - Единый конфиг стилей GUI
	Anime Wars - Стиль "Неон-Аниме"
	Референсы: Persona 5, Genshin Impact, SAO
]]

local GuiTheme = {}

-- === ОСНОВНЫЕ ЦВЕТА ===
GuiTheme.Colors = {
	-- Фоны
	Background = Color3.fromRGB(10, 10, 26),        -- #0a0a1a - тёмно-синий/чёрный
	BackgroundAlt = Color3.fromRGB(26, 26, 58),     -- #1a1a3a - чуть светлее
	Panel = Color3.fromRGB(15, 15, 35),             -- Панели
	PanelDark = Color3.fromRGB(10, 10, 25),         -- Тёмные панели
	
	-- Акценты (неоновые)
	Cyan = Color3.fromRGB(0, 255, 255),             -- #00ffff - основной акцент
	Pink = Color3.fromRGB(255, 0, 255),             -- #ff00ff - розовый/магента
	Gold = Color3.fromRGB(255, 215, 0),             -- #ffd700 - золотой
	
	-- Вариации акцентов
	CyanDim = Color3.fromRGB(0, 180, 180),          -- Приглушённый циан
	CyanDark = Color3.fromRGB(0, 100, 100),         -- Тёмный циан
	PinkDim = Color3.fromRGB(180, 0, 180),          -- Приглушённый розовый
	PinkDark = Color3.fromRGB(100, 0, 100),         -- Тёмный розовый
	
	-- Текст
	Text = Color3.fromRGB(255, 255, 255),           -- Белый
	TextDim = Color3.fromRGB(180, 180, 200),        -- Приглушённый
	TextMuted = Color3.fromRGB(120, 120, 140),      -- Серый
	
	-- Состояния
	Active = Color3.fromRGB(0, 255, 255),           -- Активный элемент
	Inactive = Color3.fromRGB(80, 80, 100),         -- Неактивный
	Hover = Color3.fromRGB(40, 40, 60),             -- При наведении
	
	-- Слоты/элементы
	SlotBg = Color3.fromRGB(25, 25, 45),            -- Фон слота
	SlotEmpty = Color3.fromRGB(35, 35, 55),         -- Пустой слот
	SlotBorder = Color3.fromRGB(0, 180, 180),       -- Обводка слота
	
	-- Редкость предметов
	RarityCommon = Color3.fromRGB(150, 150, 150),   -- Серый
	RarityUncommon = Color3.fromRGB(50, 200, 50),   -- Зелёный
	RarityRare = Color3.fromRGB(50, 150, 255),      -- Синий
	RarityEpic = Color3.fromRGB(180, 50, 255),      -- Фиолетовый
	RarityLegendary = Color3.fromRGB(255, 200, 50), -- Золотой
	RarityMythic = Color3.fromRGB(255, 100, 150),   -- Радужный/розовый
	
	-- Специальные
	Health = Color3.fromRGB(255, 50, 100),          -- HP бар
	HealthLow = Color3.fromRGB(150, 30, 60),        -- HP низкий
	Stamina = Color3.fromRGB(0, 255, 255),          -- Стамина
	Awakening = Color3.fromRGB(255, 200, 50),       -- Пробуждение
	
	-- Кнопки
	ButtonBg = Color3.fromRGB(30, 30, 50),          -- Фон кнопки
	ButtonHover = Color3.fromRGB(45, 45, 70),       -- Hover кнопки
	ButtonActive = Color3.fromRGB(0, 200, 200),     -- Активная кнопка
	
	-- Ошибки/успех
	Error = Color3.fromRGB(255, 80, 80),            -- Красный
	Success = Color3.fromRGB(80, 255, 120),         -- Зелёный
	Warning = Color3.fromRGB(255, 200, 50),         -- Жёлтый
}

-- === ШРИФТЫ ===
GuiTheme.Fonts = {
	Title = Enum.Font.GothamBold,                   -- Заголовки
	Subtitle = Enum.Font.GothamMedium,              -- Подзаголовки
	Body = Enum.Font.Gotham,                        -- Основной текст
	Button = Enum.Font.GothamBold,                  -- Кнопки
	Number = Enum.Font.GothamBlack,                 -- Числа (урон, комбо)
	Code = Enum.Font.Code,                          -- Код/технический текст
}

-- === РАЗМЕРЫ ТЕКСТА ===
GuiTheme.TextSizes = {
	Title = 24,
	Subtitle = 18,
	Body = 14,
	Small = 12,
	Tiny = 10,
	Large = 32,
	Huge = 48,
}

-- === АНИМАЦИИ ===
GuiTheme.Tweens = {
	Fast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Bounce = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Elastic = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
}

-- === ЗВУКИ ===
GuiTheme.Sounds = {
	Hover = "rbxassetid://6895079853",
	Click = "rbxassetid://6895079853",
	Open = "rbxassetid://70452176150315",
	Close = "rbxassetid://8968249849",
	Success = "rbxassetid://6895079853",
	Error = "rbxassetid://6895079853",
}

-- === УТИЛИТЫ ===

-- Создание стандартной обводки
function GuiTheme.CreateStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or GuiTheme.Colors.Cyan
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

-- Создание градиента для обводки
function GuiTheme.CreateGlowStroke(parent, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or GuiTheme.Colors.Cyan
	stroke.Thickness = 2
	stroke.Parent = parent
	
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.8)
	})
	gradient.Parent = stroke
	
	return stroke
end

-- Создание скошенных углов (45°)
function GuiTheme.CreateCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = parent
	return corner
end

-- Создание градиента фона
function GuiTheme.CreateBackgroundGradient(parent)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GuiTheme.Colors.Background),
		ColorSequenceKeypoint.new(1, GuiTheme.Colors.BackgroundAlt)
	})
	gradient.Rotation = 90
	gradient.Parent = parent
	return gradient
end

-- Создание неонового свечения (через дополнительный frame)
function GuiTheme.CreateGlow(parent, color, size)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.Size = UDim2.new(1, size or 10, 1, size or 10)
	glow.Position = UDim2.new(0, -(size or 10)/2, 0, -(size or 10)/2)
	glow.BackgroundColor3 = color or GuiTheme.Colors.Cyan
	glow.BackgroundTransparency = 0.8
	glow.BorderSizePixel = 0
	glow.ZIndex = parent.ZIndex - 1
	glow.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = glow
	
	return glow
end

-- Применение стандартного стиля к панели
function GuiTheme.StylePanel(panel, options)
	options = options or {}
	
	panel.BackgroundColor3 = options.bgColor or GuiTheme.Colors.Panel
	panel.BackgroundTransparency = options.transparency or 0.1
	panel.BorderSizePixel = 0
	
	if options.stroke ~= false then
		GuiTheme.CreateStroke(panel, options.strokeColor or GuiTheme.Colors.CyanDim)
	end
	
	if options.corner ~= false then
		GuiTheme.CreateCorner(panel, options.cornerRadius)
	end
end

-- Применение стандартного стиля к кнопке
function GuiTheme.StyleButton(button, options)
	options = options or {}
	
	button.BackgroundColor3 = options.bgColor or GuiTheme.Colors.ButtonBg
	button.BorderSizePixel = 0
	button.TextColor3 = options.textColor or GuiTheme.Colors.Text
	button.Font = options.font or GuiTheme.Fonts.Button
	button.TextSize = options.textSize or GuiTheme.TextSizes.Body
	
	if options.stroke ~= false then
		GuiTheme.CreateStroke(button, options.strokeColor or GuiTheme.Colors.Cyan)
	end
	
	if options.corner ~= false then
		GuiTheme.CreateCorner(button, options.cornerRadius or 4)
	end
end

-- Применение стандартного стиля к слоту
function GuiTheme.StyleSlot(slot, options)
	options = options or {}
	
	slot.BackgroundColor3 = options.bgColor or GuiTheme.Colors.SlotEmpty
	slot.BackgroundTransparency = options.transparency or 0.3
	slot.BorderSizePixel = 0
	
	local stroke = GuiTheme.CreateStroke(slot, options.strokeColor or GuiTheme.Colors.SlotBorder)
	stroke.Name = "SlotStroke"
	
	return stroke
end

return GuiTheme
