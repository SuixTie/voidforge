--[[
	DisableRbxSounds - Отключает стандартный скрипт звуков Roblox
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Отключаем RbxCharacterSounds если он есть
local function disableRbxSounds()
	local playerScripts = player:WaitForChild("PlayerScripts", 5)
	if playerScripts then
		local rbxSounds = playerScripts:FindFirstChild("RbxCharacterSounds")
		if rbxSounds then
			rbxSounds:Destroy()
			print("DisableRbxSounds: RbxCharacterSounds destroyed")
		end
	end
end

disableRbxSounds()

-- Также заглушаем звуки на персонаже
local function muteCharacterSounds(character)
	local function muteSound(sound)
		sound.Volume = 0
	end
	
	for _, desc in pairs(character:GetDescendants()) do
		if desc:IsA("Sound") and (desc.Name == "Died" or desc.Name == "Ouch") then
			muteSound(desc)
		end
	end
	
	character.DescendantAdded:Connect(function(desc)
		if desc:IsA("Sound") and (desc.Name == "Died" or desc.Name == "Ouch") then
			task.defer(function()
				muteSound(desc)
			end)
		end
	end)
end

if player.Character then
	muteCharacterSounds(player.Character)
end

player.CharacterAdded:Connect(muteCharacterSounds)

print("--- DisableRbxSounds loaded ---")
