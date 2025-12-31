--[[
	ResetTimer - Кастомный ресет с таймером
	
	Особенности:
	- При нажатии Esc -> Reset появляется таймер над головой
	- Таймер на 5 секунд
	- Отменяется при движении или получении урона
	- BillboardGui над головой показывает обратный отсчёт
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local head = character:WaitForChild("Head")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- === НАСТРОЙКИ ===
local CONFIG = {
	ResetTime = 5,              -- Секунд до ресета
	CancelOnMove = true,        -- Отменять при движении
	CancelOnDamage = true,      -- Отменять при получении урона
	TimerColor = Color3.fromRGB(255, 100, 100),  -- Цвет таймера
	TimerSize = 2,              -- Размер текста
}

-- === СОСТОЯНИЕ ===
local isResetting = false
local resetTimer = 0
local lastHealth = humanoid.Health
local timerGui = nil
local timerLabel = nil

-- === ОТКЛЮЧАЕМ СТАНДАРТНЫЙ РЕСЕТ ===
local function disableDefaultReset()
	local success, err = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
	if not success then
		-- Повторяем попытку через небольшую задержку
		task.delay(1, disableDefaultReset)
	end
end

-- Пробуем отключить сразу и с задержкой
disableDefaultReset()
task.delay(2, disableDefaultReset)

-- === СОЗДАНИЕ GUI ТАЙМЕРА ===
local function createTimerGui()
	if timerGui then
		timerGui:Destroy()
	end
	
	timerGui = Instance.new("BillboardGui")
	timerGui.Name = "ResetTimerGui"
	timerGui.Size = UDim2.new(2, 0, 0.8, 0)
	timerGui.StudsOffset = Vector3.new(0, 2.5, 0)
	timerGui.AlwaysOnTop = true
	timerGui.Parent = head
	
	timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(1, 0, 1, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextColor3 = CONFIG.TimerColor
	timerLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	timerLabel.TextStrokeTransparency = 0.3
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.Text = ""
	timerLabel.Parent = timerGui
	
	return timerGui, timerLabel
end

-- === УДАЛЕНИЕ GUI ТАЙМЕРА ===
local function removeTimerGui()
	if timerGui then
		timerGui:Destroy()
		timerGui = nil
		timerLabel = nil
	end
end

-- === ОТМЕНА РЕСЕТА ===
local function cancelReset(reason)
	if not isResetting then return end
	
	isResetting = false
	resetTimer = 0
	removeTimerGui()
	print("ResetTimer: Cancelled -", reason)
end

-- === НАЧАЛО РЕСЕТА ===
local function startReset()
	if isResetting then
		-- Если уже идёт таймер - отменяем
		cancelReset("Player pressed reset again")
		return
	end
	
	if humanoid.Health <= 0 then return end
	
	isResetting = true
	resetTimer = CONFIG.ResetTime
	lastHealth = humanoid.Health
	
	createTimerGui()
	print("ResetTimer: Started")
end

-- === ВЫПОЛНЕНИЕ РЕСЕТА ===
local function executeReset()
	isResetting = false
	removeTimerGui()
	
	-- Убиваем персонажа через TakeDamage (работает надёжнее с клиента)
	humanoid:TakeDamage(humanoid.Health + humanoid.MaxHealth)
	print("ResetTimer: Executed")
end

-- === КАСТОМНЫЙ CALLBACK ДЛЯ РЕСЕТА ===
local function setupResetCallback()
	local bindable = Instance.new("BindableEvent")
	bindable.Event:Connect(function()
		startReset()
	end)
	
	local success, err = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", bindable)
	end)
	
	if not success then
		task.delay(1, setupResetCallback)
	end
end

setupResetCallback()
task.delay(2, setupResetCallback)

-- === ГЛАВНЫЙ ЦИКЛ ===
RunService.Heartbeat:Connect(function(dt)
	if not isResetting then return end
	
	-- Проверяем движение
	if CONFIG.CancelOnMove then
		local velocity = rootPart.AssemblyLinearVelocity
		local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
		if horizontalSpeed > 1 or humanoid.MoveDirection.Magnitude > 0.1 then
			cancelReset("Player moved")
			return
		end
	end
	
	-- Проверяем урон
	if CONFIG.CancelOnDamage then
		if humanoid.Health < lastHealth then
			cancelReset("Player took damage")
			return
		end
		lastHealth = humanoid.Health
	end
	
	-- Обновляем таймер
	resetTimer = resetTimer - dt
	
	-- Обновляем GUI
	if timerLabel then
		local displayTime = math.ceil(resetTimer)
		timerLabel.Text = tostring(displayTime)
		
		-- Пульсация при низком времени
		if displayTime <= 2 then
			local pulse = math.abs(math.sin(tick() * 5))
			timerLabel.TextColor3 = CONFIG.TimerColor:Lerp(Color3.new(1, 1, 1), pulse * 0.3)
		end
	end
	
	-- Выполняем ресет
	if resetTimer <= 0 then
		executeReset()
	end
end)

-- === ОЧИСТКА ПРИ СМЕРТИ ===
humanoid.Died:Connect(function()
	isResetting = false
	removeTimerGui()
end)

print("--- ResetTimer loaded ---")
