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

-- Создаём RemoteEvent для уведомления о блоке
local blockHitEvent = Instance.new("RemoteEvent")
blockHitEvent.Name = "BlockHitEvent"
blockHitEvent.Parent = ReplicatedStorage

-- Загружаем конфиг боевой системы
local CombatConfig = require(ReplicatedStorage:WaitForChild("CombatConfig"))

print("DamageHandler: RemoteEvent created")

-- Проверка блокирует ли игрок/дамми
local function isTargetBlocking(targetCharacter)
	-- Проверяем атрибут IsBlocking (для блокирующих дамми)
	if targetCharacter:GetAttribute("IsBlocking") then
		return true, targetCharacter:GetAttribute("BlockDamageReduction") or CombatConfig.Block.DamageReduction
	end
	
	-- Проверяем есть ли у цели значение блока (для игроков)
	local blockingValue = targetCharacter:FindFirstChild("IsBlocking")
	if blockingValue and blockingValue.Value then
		return true, CombatConfig.Block.DamageReduction
	end
	return false, 0
end

-- Проверка является ли цель неуязвимым NPC
local function isInvulnerableNPC(targetCharacter)
	return CollectionService:HasTag(targetCharacter, "InvulnerableNPC") or 
	       CollectionService:HasTag(targetCharacter, "DialogueNPC")
end

-- Обработка запроса на урон от клиента
damageEvent.OnServerEvent:Connect(function(player, targetCharacter, damage, knockbackDirection, knockbackForce, isHeavyAttack)
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
	
	local blocking, damageReduction = isTargetBlocking(targetCharacter)
	if blocking then
		-- Блок полностью поглощает урон
		finalDamage = 0
		wasBlocked = true
		print("DamageHandler: Attack blocked! Damage absorbed")
		
		-- Уведомляем игрока-цель о попадании по блоку (для системы прочности)
		local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
		if targetPlayer then
			blockHitEvent:FireClient(targetPlayer, damage, isHeavyAttack or false)
		end
	end
	
	-- Наносим урон только если не заблокировано
	if finalDamage > 0 then
		targetHumanoid:TakeDamage(finalDamage)
		print("DamageHandler: Dealt", finalDamage, "damage to", targetCharacter.Name, "- Health:", targetHumanoid.Health)
	end
	
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
