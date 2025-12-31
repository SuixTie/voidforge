# Requirements Document

## Introduction

Система Ledge Grab позволяет игроку автоматически цепляться за края блоков во время прыжка, если он находится достаточно близко к краю. Игрок может висеть на краю, перемещаться влево/вправо вдоль края и забираться наверх. Эта механика расширяет возможности паркура и делает перемещение по уровню более динамичным.

## Glossary

- **Ledge (Край)**: Верхняя горизонтальная грань блока, за которую игрок может зацепиться
- **Ledge Grab System**: Система, отвечающая за обнаружение краёв и управление состоянием виса
- **Hang State (Состояние виса)**: Состояние игрока, когда он висит на краю блока
- **Climb Up (Забирание)**: Действие перемещения игрока с позиции виса на верх блока
- **Shimmy (Перемещение вдоль края)**: Горизонтальное движение игрока влево/вправо во время виса
- **Detection Zone (Зона обнаружения)**: Область перед и над игроком, в которой система ищет подходящие края
- **Grabbable Surface (Захватываемая поверхность)**: Поверхность блока, которая может быть использована для Ledge Grab

## Requirements

### Requirement 1

**User Story:** As a player, I want to automatically grab onto ledges when I jump near them, so that I can reach platforms that are too high to jump onto directly.

#### Acceptance Criteria

1. WHEN the player is in the air AND within grab range of a valid ledge THEN the Ledge Grab System SHALL attach the player to the ledge and transition to Hang State
2. WHEN the player enters Hang State THEN the Ledge Grab System SHALL stop all vertical and horizontal velocity of the player character
3. WHEN the player enters Hang State THEN the Ledge Grab System SHALL position the player's hands at the ledge height with the body hanging below
4. WHEN the player is grounded or crouching or prone THEN the Ledge Grab System SHALL NOT attempt ledge detection
5. WHEN the player grabs a ledge THEN the Ledge Grab System SHALL play the hang idle animation

### Requirement 2

**User Story:** As a player, I want to climb up from a hanging position by pressing Space, so that I can get on top of the platform.

#### Acceptance Criteria

1. WHEN the player is in Hang State AND presses the Space key THEN the Ledge Grab System SHALL initiate the climb up sequence
2. WHEN the climb up sequence starts THEN the Ledge Grab System SHALL play the climb up animation
3. WHEN the climb up animation completes THEN the Ledge Grab System SHALL position the player on top of the ledge surface
4. WHEN the climb up sequence completes THEN the Ledge Grab System SHALL restore normal player movement controls
5. IF there is an obstruction above the ledge preventing climb up THEN the Ledge Grab System SHALL keep the player in Hang State and provide visual feedback

### Requirement 3

**User Story:** As a player, I want to move left and right while hanging, so that I can reposition myself along the ledge.

#### Acceptance Criteria

1. WHEN the player is in Hang State AND presses the A key THEN the Ledge Grab System SHALL move the player left along the ledge
2. WHEN the player is in Hang State AND presses the D key THEN the Ledge Grab System SHALL move the player right along the ledge
3. WHEN the player shimmies THEN the Ledge Grab System SHALL play the shimmy animation corresponding to the movement direction
4. WHEN the player reaches the end of a ledge while shimmying THEN the Ledge Grab System SHALL stop horizontal movement at the ledge boundary
5. WHEN the player is shimmying THEN the Ledge Grab System SHALL move the player at a speed of 3 studs per second

### Requirement 4

**User Story:** As a player, I want to drop from a ledge voluntarily, so that I can cancel the grab if needed.

#### Acceptance Criteria

1. WHEN the player is in Hang State AND presses the C key (crouch key) THEN the Ledge Grab System SHALL release the player from the ledge
2. WHEN the player drops from a ledge THEN the Ledge Grab System SHALL restore normal gravity and movement controls
3. WHEN the player drops from a ledge THEN the Ledge Grab System SHALL apply a brief cooldown of 0.5 seconds before allowing another grab

### Requirement 5

**User Story:** As a player, I want to jump from one ledge to another while hanging, so that I can traverse between platforms without climbing up first.

#### Acceptance Criteria

1. WHEN the player is in Hang State AND presses the Space key while holding W THEN the Ledge Grab System SHALL launch the player upward and forward toward a potential ledge
2. WHEN the player is in Hang State AND presses the Space key while holding A THEN the Ledge Grab System SHALL launch the player to the left toward a potential ledge
3. WHEN the player is in Hang State AND presses the Space key while holding D THEN the Ledge Grab System SHALL launch the player to the right toward a potential ledge
4. WHEN the player performs a ledge jump THEN the Ledge Grab System SHALL apply a jump force of 20 studs per second in the specified direction
5. WHEN the player performs a ledge jump AND no valid ledge is detected in the jump direction THEN the Ledge Grab System SHALL allow the player to fall normally with restored controls

### Requirement 6

**User Story:** As a player, I want the ledge grab to feel responsive and integrated with existing movement, so that the gameplay remains smooth.

#### Acceptance Criteria

1. WHEN the Ledge Grab System detects a valid ledge THEN the detection SHALL occur within 2 studs horizontally and 1 stud vertically from the player's head position
2. WHEN transitioning between states THEN the Ledge Grab System SHALL complete transitions within 0.2 seconds
3. WHEN the player is in Hang State THEN the Ledge Grab System SHALL disable running, crouching, prone, and dash abilities
4. WHEN the player exits Hang State THEN the Ledge Grab System SHALL re-enable all previously disabled movement abilities
5. WHILE the player is in Hang State THEN the camera system SHALL adjust to provide a clear view of the ledge and surroundings

### Requirement 7

**User Story:** As a player, I want clear visual and audio feedback during ledge interactions, so that I understand the current state of my character.

#### Acceptance Criteria

1. WHEN the player grabs a ledge THEN the Ledge Grab System SHALL play a grab sound effect
2. WHEN the player climbs up from a ledge THEN the Ledge Grab System SHALL play a climb sound effect
3. WHEN the player drops from a ledge THEN the Ledge Grab System SHALL play a release sound effect
4. WHEN the player shimmies along a ledge THEN the Ledge Grab System SHALL play shuffling sound effects synchronized with movement
