local CombatVFX = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local VFX_ASSETS = {
	ParryShockwave = "rbxassetid://88220699827337",
	RadialGlow = "rbxassetid://5028857084",
	Vignette = "rbxassetid://2778230947",
}

local VFX_COLORS = {
	Parry = Color3.fromRGB(0, 255, 255),
	ParryPerfect = Color3.fromRGB(255, 255, 255),
	Block = Color3.fromRGB(80, 150, 255),
	Critical = Color3.fromRGB(255, 100, 50),
	ComboFinisher = Color3.fromRGB(255, 200, 100),
	LowHealth = Color3.fromRGB(255, 50, 50),
	Stagger = Color3.fromRGB(255, 220, 80),
}

local lowHealthGui = nil
local lowHealthActive = false

function CombatVFX:CreateParryEffect(position, isPerfect)
	local color = isPerfect and VFX_COLORS.ParryPerfect or VFX_COLORS.Parry
	
	local shockwave = Instance.new("Part")
	shockwave.Name = "ParryShockwave"
	shockwave.Size = Vector3.new(0.1, 0.1, 0.1)
	shockwave.Position = position
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.Transparency = 1
	shockwave.Parent = workspace
	
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 100)
	billboard.Adornee = shockwave
	billboard.AlwaysOnTop = false
	billboard.Parent = shockwave
	
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.new(1, 0, 1, 0)
	image.BackgroundTransparency = 1
	image.Image = VFX_ASSETS.ParryShockwave
	image.ImageColor3 = color
	image.ImageTransparency = 0.3
	image.Parent = billboard
	
	TweenService:Create(billboard, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, isPerfect and 400 or 250, 0, isPerfect and 400 or 250)
	}):Play()
	
	TweenService:Create(image, TweenInfo.new(0.4), {
		ImageTransparency = 1
	}):Play()
	
	for i = 1, (isPerfect and 15 or 8) do
		local spark = Instance.new("Part")
		spark.Name = "ParrySpark"
		spark.Size = Vector3.new(0.1, 0.1, math.random(5, 12) / 10)
		spark.Position = position
		spark.Anchored = true
		spark.CanCollide = false
		spark.Material = Enum.Material.Neon
		spark.Color = color
		spark.Parent = workspace
		
		local angle = math.rad(math.random(0, 360))
		local elevation = math.rad(math.random(-30, 30))
		local speed = math.random(15, 30)
		local direction = Vector3.new(
			math.cos(angle) * math.cos(elevation),
			math.sin(elevation),
			math.sin(angle) * math.cos(elevation)
		) * speed
		
		task.spawn(function()
			local startTime = tick()
			while tick() - startTime < 0.3 do
				spark.Position = spark.Position + direction * 0.016
				spark.Transparency = (tick() - startTime) / 0.3
				direction = direction * 0.95
				task.wait()
			end
			spark:Destroy()
		end)
	end
	
	local flash = Instance.new("PointLight")
	flash.Color = color
	flash.Brightness = isPerfect and 5 or 3
	flash.Range = isPerfect and 15 or 10
	flash.Parent = shockwave
	
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.02)
			flash.Brightness = flash.Brightness * 0.7
		end
	end)
	
	if isPerfect then
		self:ApplyTimeSlow(0.2, 0.3)
	end
	
	Debris:AddItem(shockwave, 0.5)
end


function CombatVFX:ApplyTimeSlow(duration, speed)
	local originalSpeed = workspace:GetAttribute("TimeScale") or 1
	
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("Humanoid") then
			local origWalk = desc.WalkSpeed
			desc.WalkSpeed = origWalk * speed
			task.delay(duration, function()
				if desc and desc.Parent then
					desc.WalkSpeed = origWalk
				end
			end)
		end
	end
	
	local blur = Lighting:FindFirstChild("TimeSlowBlur")
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "TimeSlowBlur"
		blur.Parent = Lighting
	end
	blur.Size = 8
	blur.Enabled = true
	
	TweenService:Create(blur, TweenInfo.new(duration), {Size = 0}):Play()
	task.delay(duration, function()
		blur.Enabled = false
	end)
end

function CombatVFX:CreateBlockShield()
	local shield = Instance.new("Part")
	shield.Name = "BlockShield"
	shield.Size = Vector3.new(4, 5, 0.2)
	shield.CFrame = rootPart.CFrame * CFrame.new(0, 0, -2)
	shield.Anchored = true
	shield.CanCollide = false
	shield.Material = Enum.Material.ForceField
	shield.Color = VFX_COLORS.Block
	shield.Transparency = 0.7
	shield.Parent = workspace
	
	local shieldConnection = RunService.Heartbeat:Connect(function()
		if shield and shield.Parent then
			shield.CFrame = rootPart.CFrame * CFrame.new(0, 0, -2)
		end
	end)
	
	task.spawn(function()
		while shield and shield.Parent do
			local pulse = 0.6 + math.sin(tick() * 4) * 0.1
			shield.Transparency = pulse
			task.wait()
		end
	end)
	
	return shield, shieldConnection
end

function CombatVFX:CreateBlockImpact(position)
	local ripple = Instance.new("Part")
	ripple.Name = "BlockRipple"
	ripple.Shape = Enum.PartType.Cylinder
	ripple.Size = Vector3.new(0.1, 2, 2)
	ripple.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ripple.Anchored = true
	ripple.CanCollide = false
	ripple.Material = Enum.Material.Neon
	ripple.Color = VFX_COLORS.Block
	ripple.Transparency = 0.5
	ripple.Parent = workspace
	
	TweenService:Create(ripple, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 8, 8),
		Transparency = 1
	}):Play()
	
	for i = 1, 6 do
		local spark = Instance.new("Part")
		spark.Size = Vector3.new(0.08, 0.08, 0.4)
		spark.Position = position
		spark.Anchored = true
		spark.CanCollide = false
		spark.Material = Enum.Material.Neon
		spark.Color = VFX_COLORS.Block
		spark.Parent = workspace
		
		local angle = math.rad(i * 60)
		local dir = Vector3.new(math.cos(angle), math.random() * 0.5, math.sin(angle)) * 20
		
		task.spawn(function()
			for j = 1, 15 do
				spark.Position = spark.Position + dir * 0.016
				spark.Transparency = j / 15
				dir = dir * 0.9
				task.wait()
			end
			spark:Destroy()
		end)
	end
	
	Debris:AddItem(ripple, 0.4)
end

function CombatVFX:CreateCriticalHitEffect(position)
	self:ApplyTimeSlow(0.15, 0.4)
	
	local cc = Lighting:FindFirstChild("CriticalCC")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CriticalCC"
		cc.Parent = Lighting
	end
	cc.Enabled = true
	cc.Saturation = 0.5
	cc.Contrast = 0.3
	cc.TintColor = Color3.fromRGB(255, 220, 200)
	
	TweenService:Create(cc, TweenInfo.new(0.3), {
		Saturation = 0,
		Contrast = 0,
		TintColor = Color3.new(1, 1, 1)
	}):Play()
	
	task.delay(0.3, function()
		cc.Enabled = false
	end)
	
	local camera = workspace.CurrentCamera
	local originalFOV = camera.FieldOfView
	
	TweenService:Create(camera, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = originalFOV - 5
	}):Play()
	
	task.delay(0.1, function()
		TweenService:Create(camera, TweenInfo.new(0.2), {
			FieldOfView = originalFOV
		}):Play()
	end)
	
	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = VFX_COLORS.Critical
	flash.BackgroundTransparency = 0.7
	flash.BorderSizePixel = 0
	flash.Parent = player.PlayerGui:FindFirstChild("DeathEffectsGui") or Instance.new("ScreenGui", player.PlayerGui)
	
	TweenService:Create(flash, TweenInfo.new(0.15), {
		BackgroundTransparency = 1
	}):Play()
	
	Debris:AddItem(flash, 0.2)
end


function CombatVFX:CreateComboFinisherEffect(position)
	local bigShockwave = Instance.new("Part")
	bigShockwave.Name = "ComboShockwave"
	bigShockwave.Shape = Enum.PartType.Cylinder
	bigShockwave.Size = Vector3.new(0.2, 3, 3)
	bigShockwave.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	bigShockwave.Anchored = true
	bigShockwave.CanCollide = false
	bigShockwave.Material = Enum.Material.Neon
	bigShockwave.Color = VFX_COLORS.ComboFinisher
	bigShockwave.Transparency = 0.3
	bigShockwave.Parent = workspace
	
	TweenService:Create(bigShockwave, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 20, 20),
		Transparency = 1
	}):Play()
	
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 150, 0, 150)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = false
	
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace
	
	billboard.Adornee = anchor
	billboard.Parent = anchor
	
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.new(1, 0, 1, 0)
	image.BackgroundTransparency = 1
	image.Image = VFX_ASSETS.ParryShockwave
	image.ImageColor3 = VFX_COLORS.ComboFinisher
	image.ImageTransparency = 0.2
	image.Parent = billboard
	
	TweenService:Create(billboard, TweenInfo.new(0.5), {
		Size = UDim2.new(0, 500, 0, 500)
	}):Play()
	TweenService:Create(image, TweenInfo.new(0.5), {
		ImageTransparency = 1
	}):Play()
	
	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = VFX_COLORS.ComboFinisher
	flash.BackgroundTransparency = 0.5
	flash.BorderSizePixel = 0
	
	local gui = player.PlayerGui:FindFirstChild("CombatVFXGui")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "CombatVFXGui"
		gui.IgnoreGuiInset = true
		gui.Parent = player.PlayerGui
	end
	flash.Parent = gui
	
	TweenService:Create(flash, TweenInfo.new(0.2), {
		BackgroundTransparency = 1
	}):Play()
	
	Debris:AddItem(flash, 0.3)
	Debris:AddItem(bigShockwave, 0.6)
	Debris:AddItem(anchor, 0.6)
end

function CombatVFX:CreateDodgeAfterImages()
	for i = 1, 4 do
		task.delay(i * 0.05, function()
			local ghost = character:Clone()
			ghost.Name = "DodgeGhost"
			
			for _, desc in ipairs(ghost:GetDescendants()) do
				if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
					desc:Destroy()
				elseif desc:IsA("BasePart") then
					desc.Anchored = true
					desc.CanCollide = false
					desc.Transparency = 0.5
					desc.Material = Enum.Material.Neon
					desc.Color = Color3.fromRGB(150, 200, 255)
				elseif desc:IsA("Decal") or desc:IsA("Texture") then
					desc.Transparency = 0.7
				end
			end
			
			local humanoidGhost = ghost:FindFirstChild("Humanoid")
			if humanoidGhost then
				humanoidGhost:Destroy()
			end
			
			ghost.Parent = workspace
			
			task.spawn(function()
				for j = 1, 15 do
					for _, part in ipairs(ghost:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Transparency = 0.5 + (j / 15) * 0.5
						end
					end
					task.wait(0.02)
				end
				ghost:Destroy()
			end)
		end)
	end
	
	for i = 1, 8 do
		local line = Instance.new("Part")
		line.Name = "SpeedLine"
		line.Size = Vector3.new(0.05, 0.05, math.random(8, 15) / 10)
		line.CFrame = rootPart.CFrame * CFrame.new(
			math.random(-20, 20) / 10,
			math.random(-10, 20) / 10,
			math.random(-5, 5) / 10
		)
		line.Anchored = true
		line.CanCollide = false
		line.Material = Enum.Material.Neon
		line.Color = Color3.fromRGB(200, 220, 255)
		line.Transparency = 0.3
		line.Parent = workspace
		
		local moveDir = -rootPart.CFrame.LookVector * 30
		
		task.spawn(function()
			for j = 1, 10 do
				line.Position = line.Position + moveDir * 0.016
				line.Transparency = 0.3 + (j / 10) * 0.7
				task.wait()
			end
			line:Destroy()
		end)
	end
end


function CombatVFX:StartLowHealthEffect()
	if lowHealthActive then return end
	lowHealthActive = true
	
	if not lowHealthGui then
		lowHealthGui = Instance.new("ScreenGui")
		lowHealthGui.Name = "LowHealthVFX"
		lowHealthGui.IgnoreGuiInset = true
		lowHealthGui.DisplayOrder = 100
		lowHealthGui.Parent = player.PlayerGui
		
		local vignette = Instance.new("ImageLabel")
		vignette.Name = "Vignette"
		vignette.Size = UDim2.new(1, 0, 1, 0)
		vignette.BackgroundTransparency = 1
		vignette.Image = VFX_ASSETS.Vignette
		vignette.ImageColor3 = VFX_COLORS.LowHealth
		vignette.ImageTransparency = 0.5
		vignette.ScaleType = Enum.ScaleType.Stretch
		vignette.Parent = lowHealthGui
	end
	
	local vignette = lowHealthGui:FindFirstChild("Vignette")
	if vignette then
		vignette.ImageTransparency = 1
		TweenService:Create(vignette, TweenInfo.new(0.5), {
			ImageTransparency = 0.4
		}):Play()
	end
	
	task.spawn(function()
		while lowHealthActive and lowHealthGui and lowHealthGui.Parent do
			local vig = lowHealthGui:FindFirstChild("Vignette")
			if vig then
				local pulse = 0.3 + math.sin(tick() * 2) * 0.15
				vig.ImageTransparency = pulse
			end
			task.wait()
		end
	end)
end

function CombatVFX:StopLowHealthEffect()
	lowHealthActive = false
	
	if lowHealthGui then
		local vignette = lowHealthGui:FindFirstChild("Vignette")
		if vignette then
			TweenService:Create(vignette, TweenInfo.new(0.5), {
				ImageTransparency = 1
			}):Play()
		end
		task.delay(0.5, function()
			if lowHealthGui and not lowHealthActive then
				lowHealthGui:Destroy()
				lowHealthGui = nil
			end
		end)
	end
end

function CombatVFX:CreateStaggerEffect(targetCharacter)
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end
	
	local starsGui = Instance.new("BillboardGui")
	starsGui.Name = "StaggerStars"
	starsGui.Size = UDim2.new(0, 80, 0, 40)
	starsGui.StudsOffset = Vector3.new(0, 3.5, 0)
	starsGui.Adornee = targetRoot
	starsGui.Parent = targetCharacter
	
	for i = 1, 3 do
		local star = Instance.new("TextLabel")
		star.Size = UDim2.new(0, 25, 0, 25)
		star.Position = UDim2.new((i - 1) * 0.33, 0, 0.5, 0)
		star.AnchorPoint = Vector2.new(0, 0.5)
		star.BackgroundTransparency = 1
		star.Text = "★"
		star.TextColor3 = VFX_COLORS.Stagger
		star.TextSize = 24
		star.Font = Enum.Font.GothamBold
		star.Parent = starsGui
		
		task.spawn(function()
			local offset = i * 2
			while starsGui and starsGui.Parent do
				star.Rotation = math.sin(tick() * 3 + offset) * 15
				star.Position = UDim2.new(
					(i - 1) * 0.33 + math.sin(tick() * 2 + offset) * 0.05,
					0,
					0.5 + math.cos(tick() * 2.5 + offset) * 0.1,
					0
				)
				task.wait()
			end
		end)
	end
	
	local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
	if targetHumanoid then
		local animator = targetHumanoid:FindFirstChild("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:AdjustSpeed(0.3)
			end
		end
	end
	
	return starsGui
end

function CombatVFX:StopStaggerEffect(starsGui, targetCharacter)
	if starsGui then
		TweenService:Create(starsGui, TweenInfo.new(0.3), {
			Size = UDim2.new(0, 0, 0, 0)
		}):Play()
		Debris:AddItem(starsGui, 0.4)
	end
	
	local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
	if targetHumanoid then
		local animator = targetHumanoid:FindFirstChild("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:AdjustSpeed(1)
			end
		end
	end
end

humanoid.HealthChanged:Connect(function(health)
	local maxHealth = humanoid.MaxHealth
	local percent = health / maxHealth
	
	if percent <= 0.3 then
		CombatVFX:StartLowHealthEffect()
	else
		CombatVFX:StopLowHealthEffect()
	end
end)

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	rootPart = newChar:WaitForChild("HumanoidRootPart")
	lowHealthActive = false
	if lowHealthGui then
		lowHealthGui:Destroy()
		lowHealthGui = nil
	end
end)

return CombatVFX
