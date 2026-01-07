--[[
	CharactersConfig - Конфиг аниме-персонажей для ролла
	Anime Wars
	
	Редкость зависит от силы способностей персонажа
	Каждый персонаж только один раз (самая сильная версия)
]]

local CharactersConfig = {}

-- === ЦВЕТА РЕДКОСТИ ===
CharactersConfig.RarityColors = {
	Common = Color3.fromRGB(150, 150, 150),      -- Серый
	Uncommon = Color3.fromRGB(50, 200, 50),      -- Зелёный
	Rare = Color3.fromRGB(50, 150, 255),         -- Синий
	Epic = Color3.fromRGB(180, 50, 255),         -- Фиолетовый
	Legendary = Color3.fromRGB(255, 200, 50),    -- Золотой
	Mythic = Color3.fromRGB(255, 100, 150),      -- Розовый
	Divine = Color3.fromRGB(255, 255, 255),      -- Белый
}

-- === ЗВУКИ ===
CharactersConfig.Sounds = {
	RollStart = "rbxassetid://6895079853",
	Tick = "rbxassetid://6895079853",
	Common = "rbxassetid://6895079853",
	Uncommon = "rbxassetid://6895079853",
	Rare = "rbxassetid://6895079853",
	Epic = "rbxassetid://6895079853",
	Legendary = "rbxassetid://6895079853",
	Mythic = "rbxassetid://6895079853",
	Divine = "rbxassetid://6895079853",
}

-- === СПИСОК ПЕРСОНАЖЕЙ ===
CharactersConfig.Characters = {
	-- ═══════════════════════════════════════
	-- COMMON (40%)
	-- ═══════════════════════════════════════
	{
		Name = "Sakura Haruno",
		Anime = "Naruto",
		Rarity = "Common",
		Chance = 7,
		Archetype = "Support",
		Skills = {
			{Name = "Healing Palm", Description = "Восстанавливает HP союзнику"},
			{Name = "Cherry Blossom Impact", Description = "Мощный удар кулаком"},
		},
	},
	{
		Name = "Chopper",
		Anime = "One Piece",
		Rarity = "Common",
		Chance = 7,
		Archetype = "Support",
		Skills = {
			{Name = "Monster Point", Description = "Гигантская форма"},
			{Name = "Medical Knowledge", Description = "Лечение союзников"},
		},
	},
	{
		Name = "Zenitsu Agatsuma",
		Anime = "Demon Slayer",
		Rarity = "Common",
		Chance = 7,
		Archetype = "Speed",
		Skills = {
			{Name = "Thunder Breathing", Description = "Молниеносная атака"},
			{Name = "Godspeed", Description = "Невероятная скорость"},
		},
	},
	{
		Name = "Usopp",
		Anime = "One Piece",
		Rarity = "Common",
		Chance = 7,
		Archetype = "Ranged",
		Skills = {
			{Name = "Pop Green", Description = "Растительные снаряды"},
			{Name = "Observation Haki", Description = "Предвидение атак"},
		},
	},
	{
		Name = "Aqua",
		Anime = "KonoSuba",
		Rarity = "Common",
		Chance = 7,
		Archetype = "Support",
		Skills = {
			{Name = "Purification", Description = "Очищение и лечение"},
			{Name = "God Blow", Description = "Божественный удар"},
		},
	},
	{
		Name = "Koichi Hirose",
		Anime = "JoJo's Bizarre Adventure",
		Rarity = "Common",
		Chance = 6,
		Archetype = "Support",
		Skills = {
			{Name = "Echoes ACT 3", Description = "Утяжеление объектов"},
			{Name = "3 Freeze", Description = "Обездвиживание врага"},
		},
	},
	{
		Name = "Nobara Kugisaki",
		Anime = "Jujutsu Kaisen",
		Rarity = "Common",
		Chance = 6,
		Archetype = "Ranged",
		Skills = {
			{Name = "Straw Doll Technique", Description = "Техника соломенной куклы"},
			{Name = "Resonance", Description = "Урон через связь"},
		},
	},
	
	-- ═══════════════════════════════════════
	-- UNCOMMON (25%)
	-- ═══════════════════════════════════════
	{
		Name = "Rock Lee",
		Anime = "Naruto",
		Rarity = "Uncommon",
		Chance = 5,
		Archetype = "Melee",
		Skills = {
			{Name = "Eight Gates", Description = "Открытие врат силы"},
			{Name = "Primary Lotus", Description = "Первичный лотос"},
		},
	},
	{
		Name = "Inosuke Hashibira",
		Anime = "Demon Slayer",
		Rarity = "Uncommon",
		Chance = 5,
		Archetype = "Melee",
		Skills = {
			{Name = "Beast Breathing", Description = "Звериное дыхание"},
			{Name = "Spatial Awareness", Description = "Чувствует всё вокруг"},
		},
	},
	{
		Name = "Denki Kaminari",
		Anime = "My Hero Academia",
		Rarity = "Uncommon",
		Chance = 5,
		Archetype = "Ranged",
		Skills = {
			{Name = "Electrification", Description = "Электрический разряд"},
			{Name = "Indiscriminate Shock", Description = "Шок по области"},
		},
	},
	{
		Name = "Gray Fullbuster",
		Anime = "Fairy Tail",
		Rarity = "Uncommon",
		Chance = 5,
		Archetype = "Mage",
		Skills = {
			{Name = "Ice Devil Slayer", Description = "Магия убийцы демонов льда"},
			{Name = "Ice Make", Description = "Создание ледяных конструкций"},
		},
	},
	{
		Name = "Okuyasu Nijimura",
		Anime = "JoJo's Bizarre Adventure",
		Rarity = "Uncommon",
		Chance = 5,
		Archetype = "Melee",
		Skills = {
			{Name = "The Hand", Description = "Стирает пространство"},
			{Name = "Space Erasure", Description = "Притягивает объекты"},
		},
	},
	{
		Name = "Megumi Fushiguro",
		Anime = "Jujutsu Kaisen",
		Rarity = "Uncommon",
		Chance = 5,
		Archetype = "Mage",
		Skills = {
			{Name = "Ten Shadows", Description = "Техника десяти теней"},
			{Name = "Mahoraga", Description = "Призыв Махораги"},
		},
	},
	{
		Name = "Panda",
		Anime = "Jujutsu Kaisen",
		Rarity = "Uncommon",
		Chance = 4,
		Archetype = "Tank",
		Skills = {
			{Name = "Gorilla Mode", Description = "Режим гориллы"},
			{Name = "Unblockable Drumming Beat", Description = "Неблокируемый удар"},
		},
	},
	
	-- ═══════════════════════════════════════
	-- RARE (18%)
	-- ═══════════════════════════════════════
	{
		Name = "Tanjiro Kamado",
		Anime = "Demon Slayer",
		Rarity = "Rare",
		Chance = 4,
		Archetype = "Melee",
		Skills = {
			{Name = "Sun Breathing", Description = "Дыхание солнца"},
			{Name = "Demon Slayer Mark", Description = "Метка истребителя демонов"},
		},
	},
	{
		Name = "Shoto Todoroki",
		Anime = "My Hero Academia",
		Rarity = "Rare",
		Chance = 4,
		Archetype = "Mage",
		Skills = {
			{Name = "Half-Cold Half-Hot", Description = "Лёд и огонь"},
			{Name = "Flashfire Fist", Description = "Огненный кулак"},
		},
	},
	{
		Name = "Roronoa Zoro",
		Anime = "One Piece",
		Rarity = "Rare",
		Chance = 3,
		Archetype = "Melee",
		Skills = {
			{Name = "King of Hell", Description = "Стиль короля ада"},
			{Name = "Asura", Description = "Демоническая форма"},
		},
	},
	{
		Name = "Killua Zoldyck",
		Anime = "Hunter x Hunter",
		Rarity = "Rare",
		Chance = 3,
		Archetype = "Speed",
		Skills = {
			{Name = "Godspeed", Description = "Молниеносная скорость"},
			{Name = "Thunderbolt", Description = "Электрические атаки"},
		},
	},
	{
		Name = "Josuke Higashikata",
		Anime = "JoJo's Bizarre Adventure",
		Rarity = "Rare",
		Chance = 3,
		Archetype = "Support",
		Skills = {
			{Name = "Crazy Diamond", Description = "Восстановление объектов"},
			{Name = "DORA DORA", Description = "Серия мощных ударов"},
		},
	},
	{
		Name = "Yuji Itadori",
		Anime = "Jujutsu Kaisen",
		Rarity = "Rare",
		Chance = 3,
		Archetype = "Melee",
		Skills = {
			{Name = "Black Flash", Description = "Чёрная вспышка"},
			{Name = "Divergent Fist", Description = "Расходящийся кулак"},
		},
	},
	{
		Name = "Toge Inumaki",
		Anime = "Jujutsu Kaisen",
		Rarity = "Rare",
		Chance = 3,
		Archetype = "Mage",
		Skills = {
			{Name = "Cursed Speech", Description = "Проклятая речь"},
			{Name = "Blast Away", Description = "Приказ взорваться"},
		},
	},
	
	-- ═══════════════════════════════════════
	-- EPIC (10%)
	-- ═══════════════════════════════════════
	{
		Name = "Naruto Uzumaki",
		Anime = "Naruto",
		Rarity = "Epic",
		Chance = 2,
		Archetype = "Melee",
		Skills = {
			{Name = "Baryon Mode", Description = "Барионный режим"},
			{Name = "Rasenshuriken", Description = "Расен-сюрикен"},
			{Name = "Shadow Clones", Description = "Теневые клоны"},
		},
	},
	{
		Name = "Ichigo Kurosaki",
		Anime = "Bleach",
		Rarity = "Epic",
		Chance = 2,
		Archetype = "Melee",
		Skills = {
			{Name = "True Bankai", Description = "Истинный Банкай"},
			{Name = "Gran Rey Cero", Description = "Великий королевский серо"},
			{Name = "Mugetsu", Description = "Последний Гецуга Теншо"},
		},
	},
	{
		Name = "Levi Ackerman",
		Anime = "Attack on Titan",
		Rarity = "Epic",
		Chance = 2,
		Archetype = "Speed",
		Skills = {
			{Name = "Ackerman Power", Description = "Сила Аккермана"},
			{Name = "Spinning Slash", Description = "Вращающийся разрез"},
		},
	},
	{
		Name = "Deku",
		Anime = "My Hero Academia",
		Rarity = "Epic",
		Chance = 2,
		Archetype = "Melee",
		Skills = {
			{Name = "One For All 100%", Description = "Один за всех на полную"},
			{Name = "Gearshift", Description = "Переключение передач"},
			{Name = "Fa Jin", Description = "Накопление энергии"},
		},
	},
	{
		Name = "Jotaro Kujo",
		Anime = "JoJo's Bizarre Adventure",
		Rarity = "Epic",
		Chance = 2,
		Archetype = "Melee",
		Skills = {
			{Name = "Star Platinum: The World", Description = "Остановка времени"},
			{Name = "ORA ORA ORA", Description = "Серия сверхбыстрых ударов"},
		},
	},
	{
		Name = "Gojo Satoru",
		Anime = "Jujutsu Kaisen",
		Rarity = "Epic",
		Chance = 1.5,
		Archetype = "Mage",
		Skills = {
			{Name = "Unlimited Void", Description = "Безграничная пустота"},
			{Name = "Hollow Purple", Description = "Пустотная фиолетовая"},
			{Name = "Infinity", Description = "Бесконечность"},
		},
	},
	
	-- ═══════════════════════════════════════
	-- LEGENDARY (5%)
	-- ═══════════════════════════════════════
	{
		Name = "Goku",
		Anime = "Dragon Ball",
		Rarity = "Legendary",
		Chance = 1.2,
		Archetype = "Melee",
		Skills = {
			{Name = "Ultra Instinct", Description = "Ультра инстинкт"},
			{Name = "Kamehameha", Description = "Волна черепахи"},
			{Name = "Instant Transmission", Description = "Мгновенная телепортация"},
		},
	},
	{
		Name = "Itachi Uchiha",
		Anime = "Naruto",
		Rarity = "Legendary",
		Chance = 1.2,
		Archetype = "Mage",
		Skills = {
			{Name = "Tsukuyomi", Description = "Лунное чтение"},
			{Name = "Amaterasu", Description = "Чёрное пламя"},
			{Name = "Susanoo", Description = "Призыв Сусаноо"},
		},
	},
	{
		Name = "Escanor",
		Anime = "Seven Deadly Sins",
		Rarity = "Legendary",
		Chance = 1,
		Archetype = "Tank",
		Skills = {
			{Name = "The One", Description = "Пиковая форма в полдень"},
			{Name = "Cruel Sun", Description = "Миниатюрное солнце"},
		},
	},
	{
		Name = "Madara Uchiha",
		Anime = "Naruto",
		Rarity = "Legendary",
		Chance = 1,
		Archetype = "Mage",
		Skills = {
			{Name = "Infinite Tsukuyomi", Description = "Бесконечное лунное чтение"},
			{Name = "Limbo", Description = "Клоны из другого измерения"},
			{Name = "Perfect Susanoo", Description = "Идеальный Сусаноо"},
		},
	},
	{
		Name = "DIO",
		Anime = "JoJo's Bizarre Adventure",
		Rarity = "Legendary",
		Chance = 1,
		Archetype = "Melee",
		Skills = {
			{Name = "The World", Description = "Остановка времени на 9 секунд"},
			{Name = "MUDA MUDA MUDA", Description = "Серия сверхбыстрых ударов"},
			{Name = "Road Roller", Description = "Бросок дорожного катка"},
		},
	},
	{
		Name = "Sukuna",
		Anime = "Jujutsu Kaisen",
		Rarity = "Legendary",
		Chance = 0.8,
		Archetype = "Melee",
		Skills = {
			{Name = "Malevolent Shrine", Description = "Злобный храм"},
			{Name = "Divine Flame", Description = "Божественное пламя"},
			{Name = "World Cutting Slash", Description = "Разрез мира"},
		},
	},
	
	-- ═══════════════════════════════════════
	-- MYTHIC (1.5%)
	-- ═══════════════════════════════════════
	{
		Name = "Saitama",
		Anime = "One Punch Man",
		Rarity = "Mythic",
		Chance = 0.5,
		Archetype = "Melee",
		Skills = {
			{Name = "Serious Punch", Description = "Серьёзный удар"},
			{Name = "Serious Series", Description = "Серьёзная серия"},
		},
	},
	{
		Name = "Aizen Sosuke",
		Anime = "Bleach",
		Rarity = "Mythic",
		Chance = 0.4,
		Archetype = "Mage",
		Skills = {
			{Name = "Kyoka Suigetsu", Description = "Полная иллюзия"},
			{Name = "Hogyoku", Description = "Бессмертие и эволюция"},
		},
	},
	{
		Name = "Giorno Giovanna",
		Anime = "JoJo's Bizarre Adventure",
		Rarity = "Mythic",
		Chance = 0.4,
		Archetype = "Mage",
		Skills = {
			{Name = "Gold Experience Requiem", Description = "Возврат к нулю"},
			{Name = "Infinite Death Loop", Description = "Бесконечная петля смерти"},
		},
	},
	{
		Name = "Kars",
		Anime = "JoJo's Bizarre Adventure",
		Rarity = "Mythic",
		Chance = 0.3,
		Archetype = "Melee",
		Skills = {
			{Name = "Ultimate Life Form", Description = "Идеальное существо"},
			{Name = "Light Mode", Description = "Клинки из света"},
			{Name = "Adaptation", Description = "Адаптация к любой угрозе"},
		},
	},
	
	-- ═══════════════════════════════════════
	-- DIVINE (0.5%)
	-- ═══════════════════════════════════════
	{
		Name = "Zeno",
		Anime = "Dragon Ball",
		Rarity = "Divine",
		Chance = 0.2,
		Archetype = "Mage",
		Skills = {
			{Name = "Erase", Description = "Стирание из существования"},
			{Name = "Omni-King Power", Description = "Абсолютная власть"},
		},
	},
	{
		Name = "Rimuru Tempest",
		Anime = "That Time I Got Reincarnated as a Slime",
		Rarity = "Divine",
		Chance = 0.2,
		Archetype = "Mage",
		Skills = {
			{Name = "Void God Azathoth", Description = "Бог пустоты"},
			{Name = "Predator", Description = "Поглощение способностей"},
		},
	},
	{
		Name = "Anos Voldigoad",
		Anime = "The Misfit of Demon King Academy",
		Rarity = "Divine",
		Chance = 0.1,
		Archetype = "Mage",
		Skills = {
			{Name = "Venuzdonoa", Description = "Меч, разрушающий всё"},
			{Name = "Source Destruction", Description = "Уничтожение источника"},
		},
	},
}

-- === ФУНКЦИЯ РОЛЛА ===
function CharactersConfig.Roll()
	local totalChance = 0
	for _, char in ipairs(CharactersConfig.Characters) do
		totalChance = totalChance + char.Chance
	end
	
	local roll = math.random() * totalChance
	local cumulative = 0
	
	for _, char in ipairs(CharactersConfig.Characters) do
		cumulative = cumulative + char.Chance
		if roll <= cumulative then
			return char
		end
	end
	
	return CharactersConfig.Characters[1]
end

-- === ПОЛУЧИТЬ ПЕРСОНАЖЕЙ ПО РЕДКОСТИ ===
function CharactersConfig.GetByRarity(rarity)
	local result = {}
	for _, char in ipairs(CharactersConfig.Characters) do
		if char.Rarity == rarity then
			table.insert(result, char)
		end
	end
	return result
end

-- === ПОЛУЧИТЬ ПЕРСОНАЖА ПО ИМЕНИ ===
function CharactersConfig.GetByName(name)
	for _, char in ipairs(CharactersConfig.Characters) do
		if char.Name == name then
			return char
		end
	end
	return nil
end

return CharactersConfig
