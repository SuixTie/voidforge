--[[
    MADE BY SICKO_POOFY (updated & fixed by Grok)
    Place in StarterGui (LocalScript)
    Realistic head & body tracking for R6 and R15
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Настройки (можно тюнить под стиль игры)
local HEAD_HOR_FACTOR = 1     -- Горизонтальный поворот головы
local HEAD_VER_FACTOR = 0.6   -- Вертикальный поворот головы
local BODY_HOR_FACTOR = 0.5   -- Горизонтальный поворот тела (R15)
local BODY_VER_FACTOR = 0.4   -- Вертикальный поворот тела (R15)
local UPDATE_LERP = 0.25       -- Скорость сглаживания (было 0.5 / 2 = 0.25)

-- Получаем персонажа и части
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local head = character:WaitForChild("Head")
local rootPart = character:WaitForChild("HumanoidRootPart")

local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
local torso = isR6 and character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
local neck = isR6 and torso.Neck or head.Neck
local waist = not isR6 and torso.Waist

if not (torso and head and neck) then
	warn("Head tracking: Missing required parts")
	return
end

-- Сохраняем оригинальные C0
local originalNeckC0 = neck.C0
local originalWaistC0 = waist and waist.C0

-- Ограничение скорости поворота шеи (плавность)
neck.MaxVelocity = 1/3

-- Основной цикл
RunService.RenderStepped:Connect(function()
	-- Проверяем, что камера смотрит на нашего персонажа
	if camera.CameraSubject ~= humanoid then return end

	local camCFrame = camera.CFrame
	local headCFrame = head.CFrame
	local torsoLookVector = torso.CFrame.LookVector

	-- Исправлено: .p → .Position
	local distance = (headCFrame.Position - camCFrame.Position).Magnitude
	if distance == 0 then return end -- Избегаем деления на ноль

	local heightDiff = headCFrame.Position.Y - camCFrame.Position.Y
	local verticalAngle = math.asin(heightDiff / distance)  -- Угол вверх/вниз

	-- Кросс-продукт для горизонтального отклонения (влево/вправо)
	local cameraToHead = (headCFrame.Position - camCFrame.Position).Unit
	local horizontalDeviation = cameraToHead:Cross(torsoLookVector).Y

	if isR6 then
		-- R6: Только шея
		neck.C0 = neck.C0:Lerp(
			originalNeckC0 * CFrame.Angles(
				-verticalAngle * HEAD_VER_FACTOR,      -- Вверх/вниз (инвертируем для R6)
				0,
				-horizontalDeviation * HEAD_HOR_FACTOR  -- Влево/вправо
			),
			UPDATE_LERP
		)
	else
		-- R15: Шея + поясница
		neck.C0 = neck.C0:Lerp(
			originalNeckC0 * CFrame.Angles(
				verticalAngle * HEAD_VER_FACTOR,       -- Вверх/вниз
				-horizontalDeviation * HEAD_HOR_FACTOR, -- Влево/вправо
				0
			),
			UPDATE_LERP
		)

		if waist then
			waist.C0 = waist.C0:Lerp(
				originalWaistC0 * CFrame.Angles(
					verticalAngle * BODY_VER_FACTOR,
					-horizontalDeviation * BODY_HOR_FACTOR,
					0
				),
				UPDATE_LERP
			)
		end
	end
end)

-- Авто-обновление при респавне
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	head = newChar:WaitForChild("Head")
	rootPart = newChar:WaitForChild("HumanoidRootPart")

	isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
	torso = isR6 and newChar:FindFirstChild("Torso") or newChar:FindFirstChild("UpperTorso")
	neck = isR6 and torso.Neck or head.Neck
	waist = not isR6 and torso.Waist

	if not (torso and head and neck) then return end

	originalNeckC0 = neck.C0
	originalWaistC0 = waist and waist.C0
	neck.MaxVelocity = 1/3
end)