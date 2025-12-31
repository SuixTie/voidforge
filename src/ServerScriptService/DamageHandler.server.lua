--[[
	DamageHandler - Серверная обработка урона
	Позволяет клиентской боевой системе наносить урон NPC/дамми
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Создаём RemoteEvent для урона
local damageEvent = Instance.new("RemoteEvent")
damageEvent.Name = "DamageEvent"
damageEvent.Parent = ReplicatedStorage

print("DamageHandler: RemoteEvent created")

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
	
	-- Наносим урон
	targetHumanoid:TakeDamage(damage)
	print("DamageHandler: Dealt", damage, "damage to", targetCharacter.Name, "- Health:", targetHumanoid.Health)
	
	-- Применяем отталкивание
	if targetRoot and knockbackDirection and knockbackForce then
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = knockbackDirection * knockbackForce + Vector3.new(0, knockbackForce * 0.3, 0)
		bodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
		bodyVelocity.Parent = targetRoot
		
		game:GetService("Debris"):AddItem(bodyVelocity, 0.2)
	end
end)

print("DamageHandler: Initialized")
