--[[
	FootstepDust - VFX эффекты пыли при беге
	Использует ParticleEmitter из ReplicatedStorage.Fx.Dust
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local character = script.Parent.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local RunConfig = require(game.ReplicatedStorage.RunConfig)

-- === НАСТРОЙКИ ===
local DUST_INTERVAL = 0.2       -- Интервал между эффектами (секунды)
local DUST_OFFSET = Vector3.new(0, -2.5, 0)  -- Смещение от rootPart
local PARTICLE_COUNT = 1        -- Количество частиц за раз
local SPRINT_PARTICLE_COUNT = 2 -- Количество при спринте
local MIN_SPEED = 14            -- Минимальная скорость для пыли
local DUST_TRANSPARENCY = 0.5   -- Прозрачность эффекта (0-1, больше = прозрачнее)

-- === STATE ===
local db = true  -- debounce

-- === ПРОВЕРКА DUST ЭФФЕКТА ===
local dustTemplate = game.ReplicatedStorage:FindFirstChild("Fx") and game.ReplicatedStorage.Fx:FindFirstChild("Dust")
if not dustTemplate then
	warn("FootstepDust: Не найден ReplicatedStorage.Fx.Dust!")
	return
end

-- === СОЗДАНИЕ ЭФФЕКТА ПЫЛИ ===
local function createDustEffect()
	-- Проверяем состояния
	local isOnGround = humanoid.FloorMaterial ~= Enum.Material.Air
	local isMoving = humanoid.MoveDirection.Magnitude > 0.1
	local isSprinting = RunConfig.Running or RunConfig.Sprinting
	
	-- Проверяем crouch/prone/slide
	local isCrouchingVal = player:FindFirstChild("IsCrouching")
	local isSlidingVal = player:FindFirstChild("IsSliding")
	local isCrouching = isCrouchingVal and isCrouchingVal.Value or false
	local isSliding = isSlidingVal and isSlidingVal.Value or false
	local isProne = RunConfig.isProne
	
	-- Создаём пыль только при беге на земле
	if isOnGround and isMoving and db and not isCrouching and not isSliding and not isProne then
		-- Проверяем скорость (пыль только при быстром движении)
		local speed = rootPart.AssemblyLinearVelocity.Magnitude
		if speed < MIN_SPEED then return end
		
		db = false
		
		local dust = dustTemplate:Clone()
		dust.Position = rootPart.Position + DUST_OFFSET
		dust.Parent = workspace:FindFirstChild("Fx") or workspace
		dust.Name = "SprintDust"
		
		-- Emit частицы с прозрачностью
		local attachment = dust:FindFirstChild("Attachment")
		if attachment then
			local dustEmitter = attachment:FindFirstChild("Dust")
			if dustEmitter then
				-- Устанавливаем прозрачность
				local originalTransparency = dustEmitter.Transparency
				dustEmitter.Transparency = NumberSequence.new(DUST_TRANSPARENCY, 1)
				
				local count = isSprinting and SPRINT_PARTICLE_COUNT or PARTICLE_COUNT
				dustEmitter:Emit(count)
			end
		end
		
		-- Удаляем через время
		Debris:AddItem(dust, 2.5)
		
		-- Cooldown
		task.wait(DUST_INTERVAL)
		db = true
	end
end

-- === ОСНОВНОЙ ЦИКЛ ===
RunService.Heartbeat:Connect(function()
	if not rootPart or not humanoid then return end
	createDustEffect()
end)

-- === RESPAWN ===
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	rootPart = newChar:WaitForChild("HumanoidRootPart")
	db = true
end)

print("--- FootstepDust VFX loaded (ParticleEmitter) ---")
