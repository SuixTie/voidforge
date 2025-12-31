local ContentProvider = game:GetService("ContentProvider")

-- Список ID анимаций, которые должны работать мгновенно
local assetsToPreload = {
	"rbxassetid://103470705707880", -- Твой перекат
	"rbxassetid://115304249930882", -- Твой слайд
	"rbxassetid://90733220824264",  -- Ходьба
	"rbxassetid://104126574030880", -- Бег
	"rbxassetid://98312921959273",  -- Присед Idle
	"rbxassetid://119603108687029", -- Присед walk
	"rbxassetid://73102068604815",  -- Прыжок
	"rbxassetid://108445839371180", -- Prone Idle
	"rbxassetid://117557870100193", -- Prone Move
	-- Добавь сюда остальные важные ID
}

local function preloadAnimations()
	local instances = {}

	for _, id in ipairs(assetsToPreload) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		table.insert(instances, anim)
	end

	-- Принудительная загрузка в память
	local success, err = pcall(function()
		ContentProvider:PreloadAsync(instances)
	end)

	if success then
		print("--- Все анимации успешно загружены в память ---")
	else
		warn("Ошибка при загрузке анимаций:", err)
	end
end

-- Запускаем загрузку
task.spawn(preloadAnimations)