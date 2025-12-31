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
CombatConfig.Attacks = {
	Light = {
		{name = "Slash1", damage = 10, staminaCost = 8, duration = 0.4, range = 5, hitTime = 0.2},
		{name = "Slash2", damage = 12, staminaCost = 9, duration = 0.45, range = 5, hitTime = 0.22},
		{name = "Slash3", damage = 15, staminaCost = 10, duration = 0.5, range = 5.5, hitTime = 0.25},
		{name = "Slash4", damage = 20, staminaCost = 12, duration = 0.6, range = 6, hitTime = 0.3},
	},
	Heavy = {
		{name = "Heavy1", damage = 25, staminaCost = 18, duration = 0.8, range = 6, hitTime = 0.4},
		{name = "Heavy2", damage = 30, staminaCost = 22, duration = 0.9, range = 6.5, hitTime = 0.45},
		{name = "Heavy3", damage = 40, staminaCost = 28, duration = 1.1, range = 7, hitTime = 0.55},
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
