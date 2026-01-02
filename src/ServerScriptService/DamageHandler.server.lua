--[[
	DamageHandler - Серверная обработка урона
	Позволяет клиентской боевой системе наносить урон NPC/дамми
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Создаём RemoteEvent для урона
local damageEvent = Instance.new("RemoteEvent")
damageEvent.Name = "DamageEvent"
damageEvent.Parent = ReplicatedStorage

-- Загружаем конфиг боевой системы
local CombatConfig = require(ReplicatedStorage:WaitForChild("CombatConfig"))

print("DamageHandler: RemoteEvent created")

-- Проверка блокирует ли игрок
local function isTargetBlocking(targetCharacter)
	-- Проверяем есть ли у цели значение блока
	local blockingValue = targetCharacter:FindFirstChild("IsBlocking")
	if blockingValue and blockingValue.Value then
		return true
	end
	return false
end

-- Проверка является ли цель неуязвимым NPC
local function isInvulnerableNPC(targetCharacter)
	return CollectionService:HasTag(targetCharacter, "InvulnerableNPC") or 
	       CollectionService:HasTag(targetCharacter, "DialogueNPC")
end

-- Обработка запроса на урон от клиента
damageEvent.OnServerEvent:Connect(function(player, targetCharacter, damage, knockbackDirection, knockbackForce)
	-- Проверяем что цель существует
	if not targetCharacter or not targetCharacter:IsA("Model") then
		return
	end
	
	local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end
	
	-- Проверяем что это не неуязвимый NPC
	if isInvulnerableNPC(targetCharacter) then
		print("DamageHandler: Target is invulnerable NPC -", targetCharacter.Name)
		return
	end
	
	-- Проверяем что это не сам игрок
	local attackerCharacter = player.Character
	if targetCharacter == attackerCharacter then
		return
	end
	
	-- Базовая проверка дистанции (анти-чит)
	local attackerRoot = attackerCharacter and attackerCharacter:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	
	if attackerRoot and targetRoot then
		local distance = (attackerRoot.Position - targetRoot.Position).Magnitude
		if distance > 15 then -- Максимальная дистанция атаки
			warn("DamageHandler: Attack rejected - too far:", distance)
			return
		end
	end
	
	-- Проверяем блок цели
	local finalDamage = damage
	local wasBlocked = false
	
	if isTargetBlocking(targetCharacter) then
		-- Снижаем урон при блоке
		finalDamage = damage * (1 - CombatConfig.Block.DamageReduction)
		wasBlocked = true
		print("DamageHandler: Attack blocked! Damage reduced from", damage, "to", finalDamage)
	end
	
	-- Наносим урон
	targetHumanoid:TakeDamage(finalDamage)
	print("DamageHandler: Dealt", finalDamage, "damage to", targetCharacter.Name, "- Health:", targetHumanoid.Health)
	
	-- Применяем отталкивание (меньше если заблокировано)
	if targetRoot and knockbackDirection and knockbackForce then
		local actualKnockback = wasBlocked and (knockbackForce * 0.3) or knockbackForce
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = knockbackDirection * actualKnockback + Vector3.new(0, actualKnockback * 0.3, 0)
		bodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
		bodyVelocity.Parent = targetRoot
		
		game:GetService("Debris"):AddItem(bodyVelocity, 0.2)
	end
end)

print("DamageHandler: Initialized")
