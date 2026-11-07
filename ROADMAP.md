# Tide & Hook - Project Roadmap & Architecture Specification

> **Game Title**: Tide & Hook  
> **Genre**: Cozy 2D Top-Down Coastal Fishing & Gathering Simulator  
> **Engine**: Godot Engine 4.x (Forward+ / Mobile / Compatibility)  
> **Language**: GDScript 2.0 (Strictly English code, variables, UI, and documentation)

---

## 1. System Architecture & State Conventions

### 1.1 Architecture Overview
The project follows a **Decoupled Event-Driven & Component-Centric Architecture**:
- **Autoload Singletons (Global Core)**:
  - `GameEvents` (`res://scripts/core/game_events.gd`): Central event bus for cross-system communication without direct node coupling.
  - `GameState` (`res://scripts/core/game_state.gd`): Single source of truth for player persistent stats, inventory (bait, tools, fish catches), time-of-day, and world flags.
- **Node Hierarchies & Separation of Concerns**:
  - `Player`: Physics processing, input handling, tool holding states, and interaction raycasting.
  - `Mechanics`: Modular world interactables (`DigSpot`, `WaterBody`, `DryingRack`) with area detection and lifecycle states.
  - `UI/HUD`: Reactive canvas layers listening to `GameEvents` and `GameState` signals; never polled in `_process`.

### 1.2 Naming Conventions & Code Standards
- **Scenes & Files**: `snake_case.tscn`, `snake_case.gd`.
- **Classes**: `PascalCase` (`class_name PlayerCharacter extends CharacterBody2D`).
- **Variables & Functions**: `snake_case`, strictly typed (`var current_tool: ToolType = ToolType.NONE`, `func dig_spot() -> void:`).
- **Constants & Enums**: `ALL_CAPS` or `PascalCase` for enum type, `SCREAMING_SNAKE_CASE` for members.
- **Signals**: Past-tense or action-triggered (`tool_swapped(new_tool: int)`, `worm_collected(new_total: int)`).

---

## 2. Phase Breakdown & Execution Checklist

### Phase 1: Player Movement, Tool Swapping, and Worm Digging Mechanic
- [x] **Project Foundation & Input Map**
  - [x] Configure project settings (1280x720 viewport, canvas_items stretch mode, custom action mappings for WASD/Arrows, Interact/Action, Tool cycle, hotkeys 1-3).
  - [x] Create core Autoloads: `GameEvents.gd` and `GameState.gd`.
- [x] **Player Controller (`Player.tscn`)**
  - [x] Implement top-down 8-directional movement with acceleration, friction, and normalized diagonal speed.
  - [x] Facing direction tracker (Up, Down, Left, Right) with visual character orientation.
  - [x] Dynamic character visualization (cozy fisher with raincoat/beanie and tool socket).
  - [x] Tool state machine: `NONE`, `SHOVEL`, `FISHING_ROD`.
  - [x] Interaction Raycast/Shapecast aiming in player's facing direction.
- [x] **Tool Swapping & Equipment System**
  - [x] Hotbar cycling with Mouse Wheel, Q/E, and number keys (1: None, 2: Shovel, 3: Fishing Rod).
  - [x] Visual tool attachments rendering the active held item in the player's hands.
  - [x] Tool swap notifications via `GameEvents`.
- [x] **Worm Digging Mechanic (`DigSpot.tscn`)**
  - [x] Interactive sandy mound / sand hole mechanic along coastal zones.
  - [x] Shovel validation check (only usable when shovel is equipped and player interacts with dig spot).
  - [x] Digging action: Player dig animation, sand puff particles, and audio-visual feedback.
  - [x] Loot drop logic: Sand Worms (Lugworms) awarded to `GameState` bait inventory.
  - [x] Dig spot cooldown, exhausted hole state, and progressive regeneration.
- [x] **User Interface & HUD (`HUD.tscn`)**
  - [x] Cozy hotbar displaying tool slots with active selection highlight.
  - [x] Bait inventory counter (Worm icon + count).
  - [x] Interactive floating prompt ("Press Space to Dig") when near dig spots.
  - [x] Floating text notification system ("+1 Sand Worm!").
- [x] **Beach Sandbox Scene (`BeachMain.tscn`)**
  - [x] Playable coastal environment with sand terrain, shoreline boundary, decorative beach elements.
  - [x] Smooth Camera2D with limits and target tracking.
  - [x] Multiple interactive `DigSpot` instances distributed across the beach.

---

### Phase 2: Coastal Water Shader, Fishing Minigame, and Fish Catch Registry
- [ ] **Coastal Water Shader & Environment**
  - [ ] 2D procedural water shader with foam edge, wave distortion, and depth gradient.
  - [ ] Shoreline wet sand effect and tide bobbing dynamics.
  - [ ] Ambient coastal sound triggers.
- [x] **Cast & Bobber Mechanics**
  - [x] Cast trajectory with distance charge meter (60px to 180px) and power gauge.
  - [x] Bobber floating physics on water surface with ripple particles and parabolic launch.
  - [x] Nibble tension system (subtle pre-bite twitches, 2-5s delay, and 1.2s "!" bite reaction window).
- [x] **Reeling Minigame**
  - [x] Cozy tension bar minigame (tappable/holdable hook physics inside moving target zone for 3 seconds).
  - [x] Line tension warning, failure escape states, and animated feedback.
  - [x] Bait consumption upon catch or loss (`worms_count -= 1`).
- [x] **Fish Catch Registry & Species Data**
  - [x] Resource-based `FishData` architecture (species, weight, rarity, sell value, preferred bait).
  - [x] Weighted random catch distribution according to species `rarity_weight`.
  - [x] Catch celebration modal (`CatchPopup.tscn`) showcasing caught fish sprite, size, and lore blurb.
  - [ ] Catch logbook / journal indexing discovered coastal species.

---

### Phase 3: Shoreline Fish Drying/Display Rack and Seagull Theft AI
- [x] **Fish Storage & Inventory System**
  - [x] Global player fish inventory (`fish_inventory` array with `fish_id`, `display_name`, `weight`, `texture_path`, `value`).
  - [x] `CatchPopup.tscn` updated to pocket catches into the active player fish inventory.
  - [x] `FishBasket.tscn` inventory overlay toggleable via [B] or [Tab] with scrollable list and live counters.
- [x] **Fish Drying / Display Rack (`FishDryingRack.tscn`)**
  - [x] Placeable wooden shoreline drying rack using `fish-drying-rack.png` with static collision and interaction area.
  - [x] Player placement tool (Hotbar [4] "Drying Rack Kit") with sand validation and ghost placement preview.
  - [x] Deposit / Retrieve mechanics: Press [E] / [Space] to hang or collect fish.
  - [x] Renders fish horizontally on rack; exposes `has_fish: bool` and `current_fish: Dictionary`.
- [x] **Seagull Theft & Coastal Bird AI (`Seagull.tscn`)**
  - [x] 6-frame flight/glide/dive `SpriteFrames` (`seagull_frames.tres`, 9 FPS).
  - [x] 2.5D flight simulation with ground projection shadow scaling with altitude.
  - [x] State machine: `PATROL` (high sine-wave cruising) -> `DETECT` (scans for exposed racks with fish) -> `DIVE_STEAL` (alert "!" + swoop) -> `ESCAPE` (snatches fish in beak and flies away).
  - [x] Player defense / `FLEE` reaction: If player approaches (< 90px), seagull squawks, bursts feathers, aborts dive, and flees into the high sky.
- [x] **Cottage Safe Storage Boundary (`SafeStorageCrate.tscn`)**
  - [x] Seagull-proof storage crate stub where fish are completely immune to seagull theft.

---

### Phase 4: Cottage Inventory Hub, NPC Fisher Market, and P2P Trading Data Stubs
- [ ] **Fisherman's Cottage Interior Hub**
  - [ ] Cozy indoor scene transition (fireplace, fish storage chest, tackle workbench).
  - [ ] Extended storage chest for preserving high-grade fish and surplus bait.
- [ ] **NPC Fisher Market & Economy**
  - [ ] Old Salt NPC shopkeeper with cozy dialogue tree.
  - [ ] Sell caught/dried fish for Sea Coins; purchase upgraded rods, tackle, and lures.
- [ ] **P2P Trading Data Stubs**
  - [ ] Serializable trade packet schema for peer-to-peer catch exchange.
  - [ ] Offline export/import ledger format for trade stubs.
  - [ ] Inventory validation and anti-tamper checksums.

---

## 3. Directory Layout

```text
res://
├── ROADMAP.md
├── project.godot
├── scenes/
│   ├── core/
│   │   └── game_state.tscn (or autoload scripts)
│   ├── player/
│   │   ├── player.tscn
│   │   └── player_visuals.tscn
│   ├── mechanics/
│   │   ├── dig_spot.tscn
│   │   └── floating_text.tscn
│   ├── ui/
│   │   └── hud.tscn
│   └── world/
│       └── beach_main.tscn
├── scripts/
│   ├── core/
│   │   ├── game_events.gd
│   │   └── game_state.gd
│   ├── player/
│   │   └── player.gd
│   ├── mechanics/
│   │   ├── dig_spot.gd
│   │   └── floating_text.gd
│   ├── ui/
│   │   └── hud.gd
│   └── world/
│       └── beach_main.gd
└── assets/
    ├── textures/
    ├── shaders/
    └── audio/
```

---

## 4. Phase 1 Implementation Plan & Verification

1. **Autoloads**: Implement `GameEvents` and `GameState`.
2. **Project Settings**: Configure InputMap (`move_left`, `move_right`, `move_up`, `move_down`, `interact`, `tool_next`, `tool_prev`, `tool_slot_1`, `tool_slot_2`, `tool_slot_3`), viewport resolution (1280x720), and autoload registrations in `project.godot`.
3. **Player Controller**: Create `player.tscn` with `player.gd`, smooth physics movement, tool switching, visual facing direction, and tool interaction detection.
4. **Worm Digging Mechanic**: Create `dig_spot.tscn` with `dig_spot.gd`, collision detection with player, shovel interaction validation, sand particles, worm drop event, and regeneration timer.
5. **HUD & Feedback**: Create `hud.tscn` with hotbar, tool icons, bait counter, and `floating_text.tscn` for visual popup on collecting worms.
6. **Main Beach Scene**: Create `beach_main.tscn` integrating sand shore, boundaries, player, multiple dig spots, camera, and HUD.
7. **Verification**: Run `godot_rescan_filesystem`, run project test via Godot MCP / command line, confirm clean startup and error-free execution.

