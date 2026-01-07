--[[
	CombatConfig - Конфигурация боевой системы
	Souls-like combat для Voidforge: Eclipse Legacy
]]

local CombatConfig = {}

-- === СОСТОЯНИЯ БОЕВОЙ СИСТЕМЫ ===
CombatConfig.IsAttacking = false
CombatConfig.IsBlocking = false
CombatConfig.IsParrying = false
CombatConfig.IsStaggered = false
CombatConfig.IsLockedOn = false -- Lock-on активен
CombatConfig.ComboCount = 0
CombatConfig.LastAttackTime = 0
CombatConfig.CurrentStance = "Light"

-- === НАСТРОЙКИ АТАК ===
-- Атаки кулаками (без оружия)
CombatConfig.Attacks = {
	Light = {
		{name = "Punch1", damage = 10, staminaCost = 8, duration = 0.4, range = 5, hitTime = 0.15},
		{name = "Punch2", damage = 12, staminaCost = 9, duration = 0.45, range = 5, hitTime = 0.17},
		{name = "Punch3", damage = 15, staminaCost = 10, duration = 0.5, range = 5.5, hitTime = 0.18},
		{name = "Punch4", damage = 20, staminaCost = 12, duration = 0.6, range = 6, hitTime = 0.22},
	},
	Heavy = {
		{name = "HeavyPunch1", damage = 25, staminaCost = 18, duration = 0.8, range = 6, hitTime = 0.25},
		{name = "HeavyPunch2", damage = 30, staminaCost = 22, duration = 0.9, range = 6.5, hitTime = 0.28},
		{name = "HeavyPunch3", damage = 40, staminaCost = 28, duration = 1.1, range = 7, hitTime = 0.32},
	},
}

-- Атаки с мечом (Sword)
CombatConfig.WeaponAttacks = {
	["Sword"] = {
		Light = {
			{name = "Slash1", damage = 18, staminaCost = 10, duration = 0.45, range = 6, hitTime = 0.15},
			{name = "Slash2", damage = 20, staminaCost = 11, duration = 0.5, range = 6, hitTime = 0.17},
			{name = "Slash3", damage = 24, staminaCost = 12, duration = 0.55, range = 6.5, hitTime = 0.18},
			{name = "Slash4", damage = 30, staminaCost = 14, duration = 0.65, range = 7, hitTime = 0.22},
		},
		Heavy = {
			{name = "HeavySlash1", damage = 40, staminaCost = 22, duration = 0.9, range = 7, hitTime = 0.08},
			{name = "HeavySlash2", damage = 50, staminaCost = 26, duration = 1.0, range = 7.5, hitTime = 0.1},
			{name = "HeavySlash3", damage = 65, staminaCost = 32, duration = 1.2, range = 8, hitTime = 0.15},
		},
		-- Анимации для меча (R6)
		Animations = {
			Light = {
				"rbxassetid://121572756510807", -- Slash 1
				"rbxassetid://99098264806325", -- Slash 2
				"rbxassetid://137910826270893", -- Slash 3
				"rbxassetid://134962871921879",  -- Slash 4
			},
			Heavy = {
				"rbxassetid://134962871921879", -- Heavy Slash 1
				"rbxassetid://134962871921879", -- Heavy Slash 2
				"rbxassetid://134962871921879", -- Heavy Slash 3
			},
			Block = "rbxassetid://121454684276110", -- Блок мечом (меч перед собой)
			Parry = "rbxassetid://121913695047313", -- Парирование мечом (быстрый отбив)
		},
	},
	["Axe"] = {
		Light = {
			{name = "AxeSwing1", damage = 22, staminaCost = 12, duration = 0.5, range = 5.5, hitTime = 0.18},
			{name = "AxeSwing2", damage = 25, staminaCost = 13, duration = 0.55, range = 5.5, hitTime = 0.2},
			{name = "AxeSwing3", damage = 30, staminaCost = 15, duration = 0.6, range = 6, hitTime = 0.22},
			{name = "AxeSwing4", damage = 38, staminaCost = 18, duration = 0.7, range = 6.5, hitTime = 0.25},
		},
		Heavy = {
			{name = "HeavyAxe1", damage = 55, staminaCost = 28, duration = 1.0, range = 6.5, hitTime = 0.9},
			{name = "HeavyAxe2", damage = 70, staminaCost = 32, duration = 1.1, range = 7, hitTime = 0.9},
			{name = "HeavyAxe3", damage = 90, staminaCost = 40, duration = 1.3, range = 7.5, hitTime = 0.9},
		},
		-- Анимации для топора (R6) - используем те же что и для меча, можно заменить на свои
		Animations = {
			Light = {
				"rbxassetid://87937177607072", -- Axe Swing 1
				"rbxassetid://100347694468031", -- Axe Swing 2
				"rbxassetid://87937177607072", -- Axe Swing 3
				"rbxassetid://100347694468031",  -- Axe Swing 4
			},
			Heavy = {
				"rbxassetid://71578631096974", -- Heavy Axe 1
				"rbxassetid://71578631096974", -- Heavy Axe 2
				"rbxassetid://71578631096974", -- Heavy Axe 3
			},
			Block = "rbxassetid://121454684276110", -- Блок топором
			Parry = "rbxassetid://121913695047313", -- Парирование топором
		},
	},
}

-- Дефолтные анимации блока и парирования (кулаки)
CombatConfig.FistBlock = "rbxassetid://73242144324267"
CombatConfig.FistParry = "rbxassetid://73242144324267"

-- Дефолтные анимации для кулаков
CombatConfig.FistAnimations = {
	Light = {
		"rbxassetid://137575236164710", -- Punch 1
		"rbxassetid://121638502161356", -- Punch 2
		"rbxassetid://129891425687355", -- Punch 3
		"rbxassetid://95780408707133",  -- Punch 4
	},
	Heavy = {
		"rbxassetid://139627771045628", -- Heavy Punch 1
		"rbxassetid://106072166770452", -- Heavy Punch 2
		"rbxassetid://124496557087153", -- Heavy Punch 3
	},
}

-- === НАСТРОЙКИ ПАРИРОВАНИЯ ===
CombatConfig.Parry = {
	Window = 0.2,
	PerfectWindow = 0.1,
	StaminaCost = 5,
	Cooldown = 0.5,
	StaggerDuration = 1.5,
}

-- === НАСТРОЙКИ БЛОКА ===
CombatConfig.Block = {
	DamageReduction = 0.7,
	StaminaDrain = 1.5,
	BreakThreshold = 30,
	-- Прочность блока
	MaxDurability = 100,        -- Максимальная прочность
	DurabilityDrain = 15,       -- Сколько прочности снимает лёгкий удар
	HeavyDurabilityDrain = 30,  -- Сколько прочности снимает тяжёлый удар
	RegenDelay = 2,             -- Задержка перед восстановлением (сек)
	RegenRate = 20,             -- Скорость восстановления в секунду
	BreakStunDuration = 1.5,    -- Длительность стана при сломе блока
}

-- === НАСТРОЙКИ КОМБО ===
CombatConfig.Combo = {
	Window = 0.8,
	MaxChain = 4,
	DamageMultiplier = 1.1,
}

-- === НАСТРОЙКИ LOCK-ON ===
CombatConfig.LockOn = {
	MaxDistance = 50,
	BreakDistance = 60,
	SwitchCooldown = 0.3,
}

return CombatConfig
