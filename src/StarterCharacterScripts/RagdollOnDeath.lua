--[[
	RagdollOnDeath - Рагдолл при смерти (серверный скрипт)
	Визуальные эффекты в DeathEffects.client.lua
]]

local character = script.Parent
local Humanoid = character:WaitForChild('Humanoid')
local rootPart = character:WaitForChild('HumanoidRootPart')
local head = character:WaitForChild('Head')

Humanoid.BreakJointsOnDeath = false

-- === КАСТОМНЫЙ ЗВУК СМЕРТИ ===
local DEATH_SOUND_ID = "rbxassetid://148590801"
local DEATH_SOUND_VOLUME = 0.05

local deathSound = Instance.new("Sound")
deathSound.Name = "DeathSound"
deathSound.SoundId = DEATH_SOUND_ID
deathSound.Volume = DEATH_SOUND_VOLUME
deathSound.RollOffMinDistance = 5
deathSound.RollOffMaxDistance = 30
deathSound.Parent = head

-- === ОБРАБОТКА СМЕРТИ ===
Humanoid.Died:Connect(function()
	-- Проигрываем звук смерти
	deathSound:Play()

	-- Импульс вперёд для падения рагдолла
	local pushDirection = rootPart.CFrame.LookVector * 50 + Vector3.new(0, 30, 0)
	rootPart:ApplyImpulse(pushDirection)

	-- Рагдолл - заменяем Motor6D на BallSocketConstraint
	for _, joint in pairs(character:GetDescendants()) do
		if joint:IsA('Motor6D') then
			local socket = Instance.new('BallSocketConstraint')
			local a1 = Instance.new('Attachment')
			local a2 = Instance.new('Attachment')
			a1.Parent = joint.Part0
			a2.Parent = joint.Part1
			socket.Parent = joint.Parent
			socket.Attachment0 = a1
			socket.Attachment1 = a2
			a1.CFrame = joint.C0
			a2.CFrame = joint.C1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			joint:Destroy()
		end
	end
end)
