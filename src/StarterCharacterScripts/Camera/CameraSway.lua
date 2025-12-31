local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Делаем покачивание ЕЩЁ МЕДЛЕННЕЕ
local speedx, x, speedy, y = 42, 0.42, 35, 0.42  -- Скорость ↓ (было 68/55 → теперь 42/35, ~38% медленнее)
local function lerp(s, e, a) return s + (e - s) * a end
local pi2 = math.pi * 2
local sin = math.sin
local cam = workspace.CurrentCamera

local angularSpeedX = (speedx / 1000) * 60
local angularSpeedY = (speedy / 1000) * 60
local ampX = x / 1000
local ampY = y / 1000

-- ЕЩЁ БОЛЬШЕ ПЛАВНОСТИ (больше инерции)
local smoothAlpha = 0.08  -- Было 0.12 → теперь 0.08 (медленнее следует за синусоидой, как густой мёд)

local phaseX, phaseY = 0, 0
local smoothedSwayX, smoothedSwayY = 0, 0
local lastTime = os.clock()

local function resetPhases()
	phaseX, phaseY = 0, 0
	smoothedSwayX, smoothedSwayY = 0, 0
	lastTime = os.clock()
end

player.CharacterAdded:Connect(resetPhases)
if player.Character then
	resetPhases()
end

RunService:UnbindFromRenderStep("Swaying")

RunService:BindToRenderStep("Swaying", Enum.RenderPriority.Camera.Value + 1, function()
	local now = os.clock()
	local dt = now - lastTime
	lastTime = now

	phaseX = (phaseX + angularSpeedX * dt) % pi2
	phaseY = (phaseY + angularSpeedY * dt) % pi2

	local targetSwayX = sin(phaseX) * ampX
	local targetSwayY = sin(phaseY) * ampY

	-- Тройное сглаживание для ультра-медленной и шелковистой плавности
	local tempX = lerp(smoothedSwayX, targetSwayX, smoothAlpha)
	local tempY = lerp(smoothedSwayY, targetSwayY, smoothAlpha)

	local superTempX = lerp(smoothedSwayX, tempX, smoothAlpha * 0.8)
	local superTempY = lerp(smoothedSwayY, tempY, smoothAlpha * 0.8)

	smoothedSwayX = lerp(smoothedSwayX, superTempX, smoothAlpha * 0.6)
	smoothedSwayY = lerp(smoothedSwayY, superTempY, smoothAlpha * 0.6)

	cam.CFrame = cam.CFrame * CFrame.Angles(smoothedSwayX, smoothedSwayY, 0)
end)