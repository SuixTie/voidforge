--[[
	RacesConfig - Расы для Voidforge: Eclipse Legacy
	Основаны на лоре игры: Aether, Void, Eclipse, мутации
]]

local RacesConfig = {}

-- Звуки ролла (замени на свои ID)
RacesConfig.Sounds = {
	Tick = "rbxassetid://6042053626",           -- Звук прокрутки (тик)
	RollStart = "rbxassetid://5853855928",      -- Начало ролла
	Common = "rbxassetid://6042053626",         -- Выпадение Common
	Uncommon = "rbxassetid://6042053626",       -- Выпадение Uncommon
	Rare = "rbxassetid://6042053626",           -- Выпадение Rare
	Epic = "rbxassetid://6042053626",           -- Выпадение Epic
	Legendary = "rbxassetid://6042053626",      -- Выпадение Legendary
	Mythic = "rbxassetid://6042053626",         -- Выпадение Mythic
	Divine = "rbxassetid://6042053626",         -- Выпадение Divine (эпичный)
}

-- Цвета редкости
RacesConfig.RarityColors = {
	Common = Color3.fromRGB(180, 180, 180),      -- Серый
	Uncommon = Color3.fromRGB(50, 205, 50),      -- Зелёный
	Rare = Color3.fromRGB(30, 144, 255),         -- Синий
	Epic = Color3.fromRGB(148, 0, 211),          -- Фиолетовый
	Legendary = Color3.fromRGB(255, 165, 0),     -- Оранжевый
	Mythic = Color3.fromRGB(255, 50, 50),        -- Красный
	Divine = Color3.fromRGB(255, 215, 0),        -- Золотой
}

-- Расы с шансами и перками
RacesConfig.Races = {
	-- COMMON (60% total) - Выжившие после Eclipse
	{
		Name = "Survivor",
		Rarity = "Common",
		Chance = 30,
		Description = "Обычный выживший после Entropic Surge. Адаптировался к новому миру.",
		Perks = {
			{Name = "Воля к жизни", Description = "+10% к регенерации HP вне боя"},
			{Name = "Находчивость", Description = "+15% к найденным ресурсам"},
		}
	},
	{
		Name = "Nexus Remnant",
		Rarity = "Common",
		Chance = 18,
		Description = "Бывший сотрудник Nexus Corp, выживший благодаря корпоративным имплантам.",
		Perks = {
			{Name = "Корпоративные импланты", Description = "+5% ко всем характеристикам"},
			{Name = "Техническое знание", Description = "+10% к качеству крафта реликвий"},
		}
	},
	{
		Name = "Scavenger",
		Rarity = "Common",
		Chance = 12,
		Description = "Мародёр пустошей, научившийся выживать любой ценой.",
		Perks = {
			{Name = "Инстинкт выживания", Description = "+20% к скорости при HP < 30%"},
			{Name = "Глаз падальщика", Description = "Видит редкие ресурсы на миникарте"},
		}
	},
	
	-- UNCOMMON (25% total) - Частично затронутые Void
	{
		Name = "Aether-Touched",
		Rarity = "Uncommon",
		Chance = 10,
		Description = "Осколок Nexus Core даровал частичный иммунитет к Void.",
		Perks = {
			{Name = "Aether-резонанс", Description = "+15% к урону реликвиями"},
			{Name = "Частичный иммунитет", Description = "-10% урона от Void-атак"},
		}
	},
	{
		Name = "Void-Scarred",
		Rarity = "Uncommon",
		Chance = 8,
		Description = "Выжил после контакта с Void, но остались шрамы на теле и душе.",
		Perks = {
			{Name = "Шрамы Бездны", Description = "+20% к Void-урону, -5% к Light-защите"},
			{Name = "Эхо боли", Description = "Отражает 5% полученного урона"},
		}
	},
	{
		Name = "Reaver Blood",
		Rarity = "Uncommon",
		Chance = 7,
		Description = "Потомок мародёров Reavers. Жестокость в крови.",
		Perks = {
			{Name = "Кровожадность", Description = "+25% к урону по раненым врагам"},
			{Name = "Без пощады", Description = "Критический урон +10%"},
		}
	},

	-- RARE (10% total) - Мутанты и особые выжившие
	{
		Name = "Voidspawn Hybrid",
		Rarity = "Rare",
		Chance = 5,
		Description = "Полу-мутант, сохранивший разум после частичной трансформации в Voidspawn.",
		Perks = {
			{Name = "Гибридная форма", Description = "+30% к здоровью, -10% к скорости"},
			{Name = "Void-регенерация", Description = "Медленное восстановление HP в тени"},
			{Name = "Нечеловеческая сила", Description = "+15% к физическому урону"},
		}
	},
	{
		Name = "Scribe Initiate",
		Rarity = "Rare",
		Chance = 3,
		Description = "Ученик Eternal Scribes, познавший тайны Aether Codex.",
		Perks = {
			{Name = "Знание Кодекса", Description = "+25% к получаемому опыту"},
			{Name = "Пророческое видение", Description = "Предупреждение о засадах"},
		}
	},
	{
		Name = "Guardian Elite",
		Rarity = "Rare",
		Chance = 2,
		Description = "Элитный воин Nexus Guardians, прошедший обряд Света.",
		Perks = {
			{Name = "Благословение Света", Description = "+20% к Light-урону"},
			{Name = "Несгибаемый", Description = "+15% к сопротивлению оглушению"},
		}
	},
	
	-- EPIC (4% total) - Сильно мутировавшие или избранные
	{
		Name = "Entropy Walker",
		Rarity = "Epic",
		Chance = 1.5,
		Description = "Существо, научившееся ходить между трещинами реальности.",
		Perks = {
			{Name = "Шаг сквозь Энтропию", Description = "Дэш игнорирует коллизии на 0.5 сек"},
			{Name = "Нестабильная форма", Description = "5% шанс уклониться от любой атаки"},
			{Name = "Эхо Разлома", Description = "+20% к урону после дэша"},
		}
	},
	{
		Name = "Leviathan-Bonded",
		Rarity = "Epic",
		Chance = 1.25,
		Description = "Связан с морским Левиафаном через ритуал Nova.",
		Perks = {
			{Name = "Зов Глубин", Description = "Дыхание под водой, +50% скорости плавания"},
			{Name = "Чешуя Левиафана", Description = "+25% к защите"},
			{Name = "Шёпот Бездны", Description = "Чувствует врагов в воде"},
		}
	},
	{
		Name = "Architect Fragment",
		Rarity = "Epic",
		Chance = 1,
		Description = "Осколок сознания Architect случайно слился с выжившим.",
		Perks = {
			{Name = "Голос в голове", Description = "Architect иногда даёт подсказки"},
			{Name = "Цифровой разум", Description = "+30% к взлому терминалов"},
			{Name = "Эхо Маркуса", Description = "Иммунитет к ментальным атакам"},
		}
	},
	{
		Name = "Draven's Legacy",
		Rarity = "Epic",
		Chance = 0.75,
		Description = "Несёт кровь Каэля Дрейвена - Void-Touched предателя.",
		Perks = {
			{Name = "Кровь Дрейвена", Description = "Атаки накладывают кровотечение"},
			{Name = "Шёпот Void", Description = "+25% к Void-урону"},
			{Name = "Внутренняя борьба", Description = "Берсерк при HP < 20%"},
		}
	},

	-- LEGENDARY (0.75% total) - Избранные судьбой
	{
		Name = "Aether Marked",
		Rarity = "Legendary",
		Chance = 0.4,
		Description = "Истинный Aether Marked - избранный осколком Nexus Core.",
		Perks = {
			{Name = "Метка Эфира", Description = "Полный иммунитет к Entropic Surge"},
			{Name = "Искра Избранного", Description = "+20% ко всем характеристикам"},
			{Name = "Резонанс Core", Description = "Реликвии на 30% эффективнее"},
			{Name = "Голос Architect", Description = "Architect обращается к тебе лично"},
		}
	},
	{
		Name = "Void Prophet",
		Rarity = "Legendary",
		Chance = 0.25,
		Description = "Пророк Бездны, видящий будущее через призму Void.",
		Perks = {
			{Name = "Взгляд в Бездну", Description = "Видит скрытых врагов и ловушки"},
			{Name = "Пророчество", Description = "Предсказывает атаки боссов"},
			{Name = "Тёмное благословение", Description = "+35% к Void-урону"},
		}
	},
	{
		Name = "Light Ascendant",
		Rarity = "Legendary",
		Chance = 0.2,
		Description = "Вознёсшийся через чистый Свет, противоположность Void.",
		Perks = {
			{Name = "Сияние", Description = "Аура наносит урон Void-существам рядом"},
			{Name = "Вознесение", Description = "Двойной прыжок + парение"},
			{Name = "Очищение", Description = "Иммунитет к Void-дебаффам"},
		}
	},
	
	-- MYTHIC (0.15% total) - Почти божественные существа
	{
		Name = "Entropy Lord",
		Rarity = "Mythic",
		Chance = 0.08,
		Description = "Повелитель Энтропии, способный управлять хаосом реальности.",
		Perks = {
			{Name = "Повелитель Хаоса", Description = "Замедление времени вокруг на 3 сек (кд 60 сек)"},
			{Name = "Энтропийный щит", Description = "Поглощает 50% урона раз в минуту"},
			{Name = "Разрыв реальности", Description = "Телепортация на 10 studs"},
			{Name = "Аура Энтропии", Description = "Враги рядом получают -20% к урону"},
		}
	},
	{
		Name = "Nexus Reborn",
		Rarity = "Mythic",
		Chance = 0.05,
		Description = "Перерождённый через Nexus Core - живое воплощение технологии.",
		Perks = {
			{Name = "Цифровое тело", Description = "Иммунитет к кровотечению и яду"},
			{Name = "Нано-регенерация", Description = "Быстрое восстановление HP"},
			{Name = "Системный взлом", Description = "Контроль над вражескими дронами"},
			{Name = "Перезагрузка", Description = "Воскрешение раз в 10 минут"},
		}
	},
	{
		Name = "Voss Bloodline",
		Rarity = "Mythic",
		Chance = 0.02,
		Description = "Прямой потомок доктора Элиаса Восса, создателя Architect.",
		Perks = {
			{Name = "Кровь Создателя", Description = "Architect не атакует первым"},
			{Name = "Наследие Восса", Description = "+40% к эффективности Forge"},
			{Name = "Связь с Маркусом", Description = "Может говорить с Architect"},
			{Name = "Гений", Description = "+50% к получаемому опыту"},
		}
	},
	
	-- DIVINE (0.05% total) - Воплощения Eclipse
	{
		Name = "Eclipse Avatar",
		Rarity = "Divine",
		Chance = 0.05,
		Description = "Воплощение самого Затмения - баланс Света и Тьмы, Aether и Void.",
		Perks = {
			{Name = "Двойственность", Description = "Переключение между Light и Void формой"},
			{Name = "Eclipse Burst", Description = "Ультимативная атака: волна Затмения"},
			{Name = "Избранный Судьбой", Description = "+50% ко всем характеристикам"},
			{Name = "Бессмертная Искра", Description = "Мгновенное воскрешение без штрафа"},
			{Name = "Голос Баланса", Description = "Все фракции нейтральны к тебе"},
		}
	},
}

-- Функция для получения расы по шансу
function RacesConfig.Roll()
	local roll = math.random() * 100
	local cumulative = 0
	
	for _, race in ipairs(RacesConfig.Races) do
		cumulative = cumulative + race.Chance
		if roll <= cumulative then
			return race
		end
	end
	
	-- Fallback на Survivor
	return RacesConfig.Races[1]
end

return RacesConfig
