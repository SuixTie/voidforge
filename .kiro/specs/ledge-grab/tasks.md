# Implementation Plan

- [x] 1. Create configuration module and project structure





  - [x] 1.1 Create LedgeGrabConfig ModuleScript in ReplicatedStorage


    - Define all configuration constants (detection range, speeds, cooldowns)
    - Add placeholder animation and sound IDs


    - Add runtime state flags (IsHanging, CanGrab, etc.)


    - _Requirements: 6.1, 3.5, 4.3_
  - [ ] 1.2 Create LedgeGrabScript LocalScript skeleton in StarterCharacterScripts/Movement
    - Set up service references (Players, RunService, UserInputService, TweenService)
    - Require RunConfig and LedgeGrabConfig
    - Set up character references (humanoid, rootPart, animator)

    - _Requirements: 6.3, 6.4_

- [ ] 2. Implement ledge detection system
  - [ ] 2.1 Implement detectLedge() function
    - Create horizontal raycast from chest level forward
    - Create vertical raycast downward from above head position
    - Calculate ledge position, normal, and bounds
    - Return LedgeData or nil

    - _Requirements: 1.1, 6.1_
  - [ ]* 2.2 Write property test for ledge detection range
    - **Property 1: Ledge Detection Range**
    - **Validates: Requirements 1.1, 6.1**
  - [ ] 2.3 Implement state blocking logic
    - Check grounded state via humanoid.FloorMaterial
    - Check crouching via IsCrouching BoolValue
    - Check prone via RunConfig.isProne
    - Return nil from detectLedge if any blocking state is active
    - _Requirements: 1.4_

  - [ ]* 2.4 Write property test for state blocking
    - **Property 3: Grounded State Blocks Detection**
    - **Validates: Requirements 1.4**

- [ ] 3. Implement hang state management
  - [ ] 3.1 Implement enterHangState() function
    - Create BodyPosition constraint to hold player at ledge
    - Create BodyGyro constraint to face away from wall
    - Set velocity to zero
    - Update LedgeGrabConfig.IsHanging = true
    - Call disableMovementSystems()
    - _Requirements: 1.1, 1.2, 6.3_

  - [ ]* 3.2 Write property test for velocity reset
    - **Property 2: Velocity Reset on Hang**
    - **Validates: Requirements 1.2**
  - [ ]* 3.3 Write property test for movement disable
    - **Property 9: Hang State Disables Movement**
    - **Validates: Requirements 6.3**
  - [x] 3.4 Implement exitHangState() function

    - Destroy BodyPosition and BodyGyro constraints
    - Update LedgeGrabConfig.IsHanging = false
    - Call enableMovementSystems()
    - _Requirements: 2.4, 4.2, 6.4_
  - [ ]* 3.5 Write property test for control restoration
    - **Property 5: State Exit Restores Controls**
    - **Validates: Requirements 2.4, 4.2, 6.4**
  - [ ] 3.6 Implement disableMovementSystems() and enableMovementSystems()
    - Store original values of RunConfig.CanRun, RunConfig.Running
    - Set RunConfig.CanRun = false, RunConfig.Running = false
    - Set IsCrouching.Value = false

    - Disable DashAbility (set canslide = false or similar)
    - Restore all values in enable function
    - _Requirements: 6.3, 6.4_

- [ ] 4. Checkpoint - Ensure detection and hang state work
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement shimmy movement

  - [ ] 5.1 Implement performShimmy() function
    - Calculate movement direction along ledge (perpendicular to normal)
    - Move player at ShimmySpeed (3 studs/sec)
    - Check ledge boundaries and stop at edges
    - Update BodyPosition target accordingly
    - _Requirements: 3.1, 3.2, 3.4, 3.5_

  - [ ]* 5.2 Write property test for shimmy direction and speed
    - **Property 6: Shimmy Direction and Speed**
    - **Validates: Requirements 3.1, 3.2, 3.5**
  - [ ] 5.3 Implement shimmy input handling
    - Detect A/D key presses via UserInputService
    - Call performShimmy with direction (-1 for A, 1 for D)
    - Stop shimmy when keys released
    - _Requirements: 3.1, 3.2_


- [ ] 6. Implement climb up mechanic
  - [ ] 6.1 Implement performClimbUp() function
    - Check for obstruction above ledge via raycast
    - If obstructed, return false and stay in hang state
    - Set IsClimbingUp = true
    - Tween player position to top of ledge over ClimbUpDuration

    - Call exitHangState() when complete
    - _Requirements: 2.1, 2.3, 2.5_
  - [ ]* 6.2 Write property test for climb positioning
    - **Property 4: Climb Up Positioning**
    - **Validates: Requirements 2.3**
  - [ ] 6.3 Implement climb up input handling
    - Detect Space key press while in Hang State
    - Check if no directional keys (W/A/D) are held

    - Call performClimbUp()
    - _Requirements: 2.1_

- [ ] 7. Implement drop mechanic
  - [x] 7.1 Implement performDrop() function

    - Call exitHangState()
    - Set CanGrab = false
    - Start cooldown timer (0.5 seconds)
    - Set CanGrab = true after cooldown
    - _Requirements: 4.1, 4.2, 4.3_
  - [ ]* 7.2 Write property test for drop cooldown
    - **Property 7: Drop Cooldown**

    - **Validates: Requirements 4.3**
  - [ ] 7.3 Implement drop input handling
    - Detect C key (crouch key) press while in Hang State
    - Call performDrop()
    - _Requirements: 4.1_

- [ ] 8. Implement ledge jump mechanic
  - [ ] 8.1 Implement performLedgeJump() function
    - Calculate jump direction based on held keys (W/A/D)
    - Apply velocity of LedgeJumpForce (20 studs/sec) in direction

    - Call exitHangState()
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  - [ ]* 8.2 Write property test for ledge jump
    - **Property 8: Ledge Jump Direction and Force**

    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4**
  - [ ] 8.3 Implement ledge jump input handling
    - Detect Space key press while in Hang State

    - Check if W, A, or D is held
    - Calculate direction vector based on held key
    - Call performLedgeJump(direction)
    - _Requirements: 5.1, 5.2, 5.3_

- [ ] 9. Checkpoint - Ensure all movement mechanics work
  - Ensure all tests pass, ask the user if questions arise.


- [ ] 10. Implement main update loop
  - [x] 10.1 Create RenderStepped connection for ledge detection

    - Check if player is airborne and CanGrab is true
    - Call detectLedge()
    - If valid ledge found, call enterHangState()
    - _Requirements: 1.1_
  - [ ] 10.2 Create RenderStepped connection for hang state updates
    - If IsHanging, update hang position based on current ledge
    - Handle shimmy movement if A/D held

    - _Requirements: 3.1, 3.2_
  - [ ] 10.3 Implement character respawn handling
    - Connect to player.CharacterAdded
    - Reset all state flags


    - Destroy any existing constraints
    - Re-acquire character references
    - _Requirements: 6.4_

- [ ] 11. Implement animations
  - [ ] 11.1 Load and set up animation tracks
    - Load HangIdleAnim, ShimmyLeftAnim, ShimmyRightAnim, ClimbUpAnim
    - Set appropriate priorities (Action3 or higher)
    - _Requirements: 1.5, 2.2, 3.3_
  - [ ] 11.2 Integrate animations with state changes
    - Play HangIdleAnim on enterHangState
    - Play shimmy animations during performShimmy
    - Play ClimbUpAnim during performClimbUp
    - Stop all ledge animations on exitHangState
    - _Requirements: 1.5, 2.2, 3.3_

- [ ] 12. Implement sound effects
  - [ ] 12.1 Create sound instances
    - Create Sound objects for grab, climb, drop, shimmy
    - Parent to rootPart for 3D audio
    - Set RollOffMaxDistance for appropriate hearing range
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - [ ] 12.2 Integrate sounds with actions
    - Play grab sound in enterHangState
    - Play climb sound in performClimbUp
    - Play drop sound in performDrop
    - Play shimmy sound during shimmy movement
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 13. Final integration and polish
  - [ ] 13.1 Add LedgeGrabConfig to PreloadManager
    - Add animation IDs to assetsToPreload list
    - _Requirements: 6.2_
  - [ ] 13.2 Integrate with camera system
    - Adjust CameraBobble behavior during hang state
    - Optionally adjust camera offset for better view
    - _Requirements: 6.5_

- [ ] 14. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
