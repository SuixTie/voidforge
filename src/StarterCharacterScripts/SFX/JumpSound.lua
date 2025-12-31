--[[
	JumpSound - Звук прыжка игрока
	Проигрывает звук при прыжке и приземлении
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- === НАСТРОЙКИ ===
local JUMP_SOUND_ID = "rbxassetid://9126137940"  -- Звук прыжка
local LAND_SOUND_ID = "rbxassetid://9126137818"  -- Звук приземления

local JUMP_VOLUME = 0.15
local LAND_VOLUME = 0.2

-- === СОЗДАНИЕ ЗВУКОВ ===
local jumpSound = Instance.new("Sound")
jumpSound.Name = "JumpSound"
jumpSound.SoundId = JUMP_SOUND_ID
jumpSound.Volume = JUMP_VOLUME
jumpSound.RollOffMode = Enum.RollOffMode.InverseTapered
jumpSound.RollOffMinDistance = 5
jumpSound.RollOffMaxDistance = 30
jumpSound.Parent = rootPart

local landSound = Instance.new("Sound")
landSound.Name = "LandSound"
landSound.SoundId = LAND_SOUND_ID
landSound.Volume = LAND_VOLUME
landSound.RollOffMode = Enum.RollOffMode.InverseTapered
landSound.RollOffMinDistance = 5
landSound.RollOffMaxDistance = 30
landSound.Parent = rootPart

-- === СОСТОЯНИЕ ===
local wasInAir = false

-- === ОБРАБОТКА ПРЫЖКА ===
humanoid.StateChanged:Connect(function(oldState, newState)
	-- Звук прыжка
	if newState == Enum.HumanoidStateType.Jumping then
		jumpSound:Play()
		wasInAir = true
	end
	
	-- Звук приземления
	if oldState == Enum.HumanoidStateType.Freefall and newState == Enum.HumanoidStateType.Running then
		if wasInAir then
			landSound:Play()
			wasInAir = false
		end
	end
	
	-- Также проверяем Landing state
	if newState == Enum.HumanoidStateType.Landed then
		if wasInAir then
			landSound:Play()
			wasInAir = false
		end
	end
end)

-- === РЕСПАВН ===
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	rootPart = newChar:WaitForChild("HumanoidRootPart")
	
	-- Пересоздаём звуки
	jumpSound.Parent = rootPart
	landSound.Parent = rootPart
	
	wasInAir = false
end)

print("--- JumpSound loaded ---")
