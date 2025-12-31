local LedgeGrabConfig = {}

-- === DETECTION SETTINGS ===
LedgeGrabConfig.HorizontalDetectionRange = 3    -- studs forward from chest (increased for easier grab)
LedgeGrabConfig.VerticalDetectionRange = 2.5    -- studs above head (increased range)
LedgeGrabConfig.MinLedgeWidth = 0.5             -- minimum grabbable surface width
LedgeGrabConfig.MinLedgeDepth = 0.3             -- minimum surface depth to grab

-- === MOVEMENT SETTINGS ===
LedgeGrabConfig.ShimmySpeed = 3                 -- studs per second
LedgeGrabConfig.ClimbUpDuration = 0.4           -- seconds for climb animation
LedgeGrabConfig.LedgeJumpForce = 20             -- studs per second
LedgeGrabConfig.DropCooldown = 0.5              -- seconds before can grab again

-- === POSITIONING ===
LedgeGrabConfig.HangOffset = Vector3.new(0, -2.5, 0.5) -- offset from ledge edge (Y down, Z away from wall)

-- === STATE FLAGS (runtime) ===
LedgeGrabConfig.IsHanging = false
LedgeGrabConfig.IsClimbingUp = false
LedgeGrabConfig.IsShimmying = false
LedgeGrabConfig.CanGrab = true

-- === ANIMATION IDs (replace with actual IDs) ===
LedgeGrabConfig.HangIdleAnimId = "rbxassetid://115547859009589"      -- висение idle
LedgeGrabConfig.ShimmyLeftAnimId = "rbxassetid://95582132875195"   -- движение влево
LedgeGrabConfig.ShimmyRightAnimId = "rbxassetid://97021240514388"  -- движение вправо
LedgeGrabConfig.ClimbUpAnimId = "rbxassetid://118027386762916"      -- забирание наверх
LedgeGrabConfig.DropAnimId = "rbxassetid://100141886398745"                       -- отпускание края (замени на свой ID)

-- === SOUND IDs (replace with actual IDs) ===
LedgeGrabConfig.GrabSoundId = "rbxassetid://103059372417639"        -- звук захвата
LedgeGrabConfig.ClimbSoundId = "rbxassetid://9113814440"       -- звук забирания
LedgeGrabConfig.DropSoundId = "rbxassetid://137033663835090"        -- звук отпускания
LedgeGrabConfig.ShimmySoundId = "rbxassetid://9113814752"      -- звук перемещения
LedgeGrabConfig.CornerSoundId = "rbxassetid://9113813085"               -- звук перехода Q/E (замени на свой ID)

-- === KEYBINDS ===
LedgeGrabConfig.ClimbKey = Enum.KeyCode.Space
LedgeGrabConfig.DropKey = Enum.KeyCode.C

return LedgeGrabConfig
