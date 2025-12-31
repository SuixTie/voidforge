--[[
	RemoveDefaultSounds - Отключает стандартные звуки Roblox
	Серверный скрипт - заглушает звуки установкой Volume = 0
]]

local Players = game:GetService("Players")

-- Звуки для заглушения
local SOUNDS_TO_MUTE = {
	"Died",        -- Звук смерти
	"Ouch",        -- Звук урона
	"FreeFalling", -- Звук падения
}

local function muteSound(sound)
	sound.Volume = 0
	sound.PlaybackSpeed = 0
	-- Также блокируем изменение громкости
	sound:GetPropertyChangedSignal("Volume"):Connect(function()
		if sound.Volume > 0 then
			sound.Volume = 0
		end
	end)
end

local function muteDefaultSounds(character)
	-- Проходим по всем частям персонажа
	for _, part in pairs(character:GetChildren()) do
		if part:IsA("BasePart") then
			for _, soundName in ipairs(SOUNDS_TO_MUTE) do
				local sound = part:FindFirstChild(soundName)
				if sound and sound:IsA("Sound") then
					muteSound(sound)
				end
			end
		end
	end
	
	-- Отслеживаем добавление новых звуков
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Sound") then
			for _, soundName in ipairs(SOUNDS_TO_MUTE) do
				if descendant.Name == soundName then
					task.defer(function()
						muteSound(descendant)
					end)
					break
				end
			end
		end
	end)
end

local function onPlayerAdded(player)
	if player.Character then
		muteDefaultSounds(player.Character)
	end
	
	player.CharacterAdded:Connect(function(character)
		-- Ждём загрузки персонажа
		character:WaitForChild("Head")
		muteDefaultSounds(character)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

print("--- RemoveDefaultSounds (Server) loaded ---")
