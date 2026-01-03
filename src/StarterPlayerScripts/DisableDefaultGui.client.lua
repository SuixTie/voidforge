--[[
	DisableDefaultGui - Отключает стандартные GUI Roblox
	Voidforge: Eclipse Legacy
	
	Оставляет только чат
]]

local StarterGui = game:GetService("StarterGui")

-- Отключаем все стандартные GUI
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

-- Включаем обратно только чат
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)

print("DisableDefaultGui: Default Roblox GUI disabled (except Chat)")
