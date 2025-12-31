--[[
	AmbientSound - Фоновая атмосферная музыка
	Автоматически воспроизводит эмбиент при загрузке игры
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- === НАСТРОЙКИ ===
local AMBIENT_CONFIG = {
	-- Основной эмбиент
	MainAmbient = {
		SoundId = "rbxassetid://1837849285", -- Тёмный атмосферный эмбиент
		Volume = 0.3,
		Looped = true,
		PlaybackSpeed = 1,
	},
	-- Дополнительный слой (ветер/природа)
	WindLayer = {
		SoundId = "rbxassetid://9112854440", -- Звук ветра
		Volume = 0.15,
		Looped = true,
		PlaybackSpeed = 1,
	},
}

local FADE_TIME = 2 -- Время плавного появления звука

-- === СОЗДАНИЕ ЗВУКОВ ===
local ambientGroup = Instance.new("SoundGroup")
ambientGroup.Name = "AmbientGroup"
ambientGroup.Volume = 1
ambientGroup.Parent = SoundService

local sounds = {}

for name, config in pairs(AMBIENT_CONFIG) do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = config.SoundId
	sound.Volume = 0 -- Начинаем с 0 для fade in
	sound.Looped = config.Looped
	sound.PlaybackSpeed = config.PlaybackSpeed
	sound.SoundGroup = ambientGroup
	sound.Parent = SoundService
	
	sounds[name] = {
		instance = sound,
		targetVolume = config.Volume
	}
end

-- === ФУНКЦИИ ===
local function fadeIn(sound, targetVolume, duration)
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Volume = targetVolume
	}):Play()
end

local function fadeOut(sound, duration)
	local tween = TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Volume = 0
	})
	tween:Play()
	tween.Completed:Connect(function()
		sound:Stop()
	end)
end

-- === УПРАВЛЕНИЕ ЭМБИЕНТОМ ===
local AmbientSound = {}

function AmbientSound.Start()
	for name, data in pairs(sounds) do
		fadeIn(data.instance, data.targetVolume, FADE_TIME)
	end
end

function AmbientSound.Stop()
	for name, data in pairs(sounds) do
		fadeOut(data.instance, FADE_TIME)
	end
end

function AmbientSound.SetVolume(volume)
	ambientGroup.Volume = math.clamp(volume, 0, 1)
end

function AmbientSound.SetLayerVolume(layerName, volume)
	if sounds[layerName] then
		sounds[layerName].targetVolume = volume
		TweenService:Create(sounds[layerName].instance, TweenInfo.new(0.5), {
			Volume = volume
		}):Play()
	end
end

-- === АВТОЗАПУСК ===
task.delay(1, function()
	AmbientSound.Start()
end)

print("--- AmbientSound loaded ---")
return AmbientSound
