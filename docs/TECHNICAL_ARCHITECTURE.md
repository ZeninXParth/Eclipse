# ECLIPSE: Echoes of the Forgotten — Technical Architecture

**Engine:** Godot 4.7.2 (GDScript)  
**Render Driver:** D3D12 / Forward+  
**Target Architecture:** Modular 2D Node-Component Hierarchy  

---

## 1. Directory Structure

```text
res://
├── project.godot
├── docs/
│   ├── GAME_DESIGN.md
│   ├── TECHNICAL_ARCHITECTURE.md
│   ├── DEVELOPMENT_ROADMAP.md
│   ├── DECISIONS.md
│   └── ASSET_REGISTER.md
├── scenes/
│   ├── player/
│   │   └── player.tscn
│   ├── levels/
│   │   ├── forgotten_entrance.tscn
│   │   ├── sunken_archive.tscn
│   │   ├── combat_room.tscn
│   │   └── test_room.tscn
│   ├── enemies/
│   │   ├── training_dummy.tscn
│   │   ├── walker_enemy.tscn
│   │   ├── flyer_enemy.tscn
│   │   └── charger_enemy.tscn
│   ├── objects/
│   │   ├── transition_point.tscn
│   │   └── bench_checkpoint.tscn
│   └── ui/
│       └── debug_hud.tscn
├── scripts/
│   ├── core/
│   │   ├── game_manager.gd
│   │   ├── player_data.gd
│   │   └── README.md
│   ├── player/
│   │   ├── player_controller.gd
│   │   ├── player_visuals.gd
│   │   ├── player_config.gd
│   │   └── README.md
│   ├── combat/
│   │   ├── hit_data.gd
│   │   ├── health_component.gd
│   │   ├── hitbox.gd
│   │   ├── hurtbox.gd
│   │   ├── hazard_zone.gd
│   │   └── README.md
│   ├── enemies/
│   │   ├── enemy_base.gd
│   │   ├── walker_enemy.gd
│   │   ├── flyer_enemy.gd
│   │   ├── charger_enemy.gd
│   │   ├── training_dummy.gd
│   │   └── README.md
│   ├── world/
│   │   ├── room_base.gd
│   │   ├── transition_point.gd
│   │   ├── bench_checkpoint.gd
│   │   ├── test_room.gd
│   │   ├── combat_room.gd
│   │   └── README.md
│   ├── camera/
│   │   ├── camera_controller.gd
│   │   └── README.md
│   └── ui/
│       ├── debug_hud.gd
│       └── README.md
├── resources/
│   └── default_player_config.tres
├── assets/
└── tests/
    ├── test_player_physics.gd
    ├── test_combat_system.gd
    ├── test_movement_m1.gd
    ├── test_combat_m2.gd
    └── test_world_m3.gd
```

---

## 2. Collision Matrix & Physics Layers

To prevent brittle collision queries, standard 2D collision layers are allocated as follows:

| Layer | Bit | Name | Description |
|:---:|:---:|:---|:---|
| 1 | 1 | `World` | Solid geometry, floors, walls, ceilings, static platforms. |
| 2 | 2 | `Player` | Player CharacterBody2D physics body. |
| 3 | 4 | `Enemies` | Enemy physics bodies. |
| 4 | 8 | `PlayerHitbox` | Attacks initiated by the player damaging enemies (`mask = 64 | 128`). |
| 5 | 16 | `PlayerHurtbox` | Vulnerable area of player detecting enemy attacks/hazards (`mask = 32 | 128`). |
| 6 | 32 | `EnemyHitbox` | Enemy attack hitboxes damaging the player (`mask = 16`). |
| 7 | 64 | `EnemyHurtbox` | Vulnerable area of enemies detecting player attacks (`mask = 8`). |
| 8 | 128 | `Hazards` | Spikes, acid, death zones (`mask = 16 | 8`). Supports pogo rebounds. |
| 9 | 256 | `Interactables` | Checkpoints, levers, doors, collectibles. |

---

## 3. Player & Combat Node Hierarchy

```text
Player (CharacterBody2D) [Layer 2: Player, Mask 1: World]
├── CollisionShape2D (CapsuleShape2D 20x40 px)
├── Visuals (Node2D, PlayerVisuals)
│   └── Procedural cloak, visor, glowing lunar eye, dynamic slash arcs
├── HealthComponent (Node, max_hp: 5, iframes: 1.0s)
├── Hurtbox (Area2D) [Layer 5: PlayerHurtbox, Mask 32 | 128]
│   └── CollisionShape2D (CapsuleShape2D 22x40 px)
├── Hitbox (Area2D) [Layer 4: PlayerHitbox, Mask 64 | 128]
│   └── CollisionShape2D (RectangleShape2D dynamically positioned per directional swing)
└── Camera2D (Position smoothing, drag margins, bounds limits)

TrainingDummy (CharacterBody2D) [Layer 3: Enemies, Mask 1: World]
├── CollisionShape2D (CapsuleShape2D 24x44 px)
├── HealthComponent (Node, max_hp: 4, iframes: 0.15s)
└── Hurtbox (Area2D) [Layer 7: EnemyHurtbox, Mask 8: PlayerHitbox]
    └── CollisionShape2D (CapsuleShape2D 28x46 px)
```

---

## 4. State Management

The player controller uses dual explicit finite state machines:

### Locomotion State Machine
- `IDLE`: Velocity X = 0, on floor.
- `RUN`: Velocity X != 0, on floor.
- `JUMP`: Moving upward (`velocity.y < 0`) after jump trigger.
- `FALL`: Moving downward (`velocity.y >= 0`) airborne.
- `LAND`: Brief recovery state (0.08s) upon ground impact.

### Attack State Machine
- `NONE`: No attack in progress. Ready for new input or queued buffered swings.
- `STARTUP`: (0.05s) Wind-up phase. Hitbox remains inactive. Facing direction locked to prevent mid-swing flipping.
- `ACTIVE`: (0.07s) Hitbox monitoring enabled on Layer 4 (`PlayerHitbox`). Position and shape configured for Forward, Upward, or Downward Pogo. Evaluates single-hit per target and single-bounce per swing.
- `RECOVERY`: (0.10s) Hitbox disabled. Buffered attacks (0.10s window) received during this phase immediately trigger upon transition to `NONE`. Facing direction unlock permitted.

### State Transition Diagram
```
        ┌─────────────┐
        │    IDLE     │◄─────────────┐ (0.08s timeout)
        └──────┬──────┘              │
           ▲   │ (move input)        │
(no input) │   ▼                     │
        ┌─────────────┐       ┌─────────────┐
        │     RUN     │◄──────┤    LAND     │
        └──────┬──────┘(move) └──────▲──────┘
           ▲   │ (jump)              │
           │   ▼                     │
        ┌─────────────┐              │
        │    JUMP     │              │ (touchdown)
        └──────┬──────┘              │
               │ (apex / fall)       │
               ▼                     │
        ┌─────────────┐              │
        │    FALL     │──────────────┘
        └─────────────┘
```

---

## 5. GDScript Engineering Standards

1. **Static Typing Everywhere**: All variables, function parameters, and return types must be explicitly typed (`func _physics_process(delta: float) -> void:`).
2. **Signal Decoupling**: Systems communicate outward via signals (`health_changed`, `died`, `checkpoint_reached`). Upward signaling, downward method calling.
3. **No Brittle Node Paths**: Use `@export` node references or child queries rather than hardcoded global paths (`$"../../SomeManager"`).
4. **Frame-Rate Independence**: All acceleration, friction, and velocity changes must strictly incorporate `delta`.
5. **No Magic Numbers**: Export or declare constants for speeds, gravities, timers, and thresholds at the top of scripts.

---

## 6. Milestone 3 World Structure & Scene Streaming Architecture

Milestone 3 implements the foundational world partitioning, room transitions, camera confinement, checkpoint mechanics, and serialization systems.

```text
                               ┌────────────────────────────────┐
                               │           GameManager          │
                               │      (Autoload Singleton)      │
                               └──────────────┬─────────────────┘
                                              │ Orchestrates
            ┌─────────────────────────────────┼────────────────────────────────┐
            ▼                                 ▼                                ▼
┌───────────────────────┐         ┌───────────────────────┐         ┌───────────────────────┐
│     TransitionPoint   │         │       RoomBase        │         │    BenchCheckpoint    │
│  (Area2D Gateways)    │         │ (Level Root / Limits) │         │ (Rest & Disk Save)    │
└───────────┬───────────┘         └───────────┬───────────┘         └───────────┬───────────┘
            │ Triggers transition             │ Indexes gates & bounds          │ Writes ledger
            ▼                                 ▼                                 ▼
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│                                       PlayerData                                          │
│                   (Flat Serializable Ledger & user://save_data.json)                     │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### 6.1 Autoload Singleton Architecture (`GameManager`)
- **Autoload Registration**: Configured in `project.godot` under `[autoload]` as `GameManager="*res://scripts/core/game_manager.gd"`.
- **GDScript Singleton Pattern**: Extends `Node` without explicit `class_name` to prevent parser namespace collisions (`Parse Error: Class "GameManager" hides an autoload singleton`). Exposes a static `instance` reference initialized in `_ready()`.
- **Headless Test Compatibility**: Scripts reference `GameManager` via `const GameManagerScript = preload("res://scripts/core/game_manager.gd")` and access `GameManagerScript.instance`, enabling execution in headless test runners where engine autoloads are uninitialized.
- **Scene Transition Pipeline**:
  1. `change_room(target_path, gate_id, direction)` sets `is_transitioning = true`.
  2. Locks player inputs (`player.input_locked = true`), zeroes velocity, and cancels active actions.
  3. Fades screen to black (`0.25s` tween on overlay `ColorRect`).
  4. Swaps active level node in SceneTree via deferred removal and instantiation.
  5. Queries destination room for target gate position (`room.get_gate_position(gate_id)`).
  6. Places player character at landing coordinates offset by travel direction (`spawn_offset = 48.0 px`).
  7. Snaps active `Camera2D` to destination room limits (`limit_left`, `limit_top`, `limit_right`, `limit_bottom`) and instantly aligns position.
  8. Fades screen in from black (`0.25s` tween).
  9. Restores player input control (`player.input_locked = false`) and clears `is_transitioning`.

### 6.2 Modular Room Controller (`RoomBase`)
- **Camera Boundary Clamping**: Automatically discovers `Camera2D` within the scene tree and clamps viewport scroll boundaries to exported integer properties (`limit_left`, `limit_top`, `limit_right`, `limit_bottom`).
- **Gate Registry**: Maintained in `_gates: Dictionary[String, Vector2]`. Child `TransitionPoint` nodes register their unique `gate_id` and global position upon entering tree.
- **Dynamic Enemy Respawn Registry**:
  - All room enemies register via `register_enemy(enemy_node, home_position, scene_path)`.
  - On bench rest or room entry, `respawn_all_enemies()` frees defeated or dead enemy instances and spawns fresh instances at their original spawn coordinates with reset health and states.
- **Out-of-Bounds Safeguard**: Continuous check against `pit_threshold_y` (default `1200.0 px`) catches unhandled physics fall-throughs and safely teleports the player back to default room spawn.

### 6.3 Gateways (`TransitionPoint`)
- Area2D nodes placed at room boundaries on Layer 1 (`World`) and Layer 5 (`PlayerHurtbox`), monitoring Layer 2 (`Player`).
- Exports `target_room_path`, `target_gate_id`, `travel_direction`, and `spawn_offset`.
- Upon player entry, invokes `GameManager.change_room(...)` with debounce protection.

### 6.4 Rest Benches (`BenchCheckpoint`)
- Interactive Area2D on Layer 9 (`Interactables`), monitoring Layer 2 (`Player`).
- Restores player health (`health_component.current_health = max_health`) and refills soul reservoir (`player.current_soul = 99`).
- Synchronizes with `PlayerData` and writes save file to disk (`save_to_disk()`).
- Emits `bench_rested` signal triggering room-wide `respawn_all_enemies()`.

### 6.5 Save Data Ledger (`PlayerData`)
- **Serializable Schema**:
  ```gdscript
  {
      "health": int,
      "max_health": int,
      "soul": int,
      "max_soul": int,
      "has_dash": bool,
      "has_wall_jump": bool,
      "has_pogo": bool,
      "has_focus": bool,
      "visited_rooms": Array[String],
      "story_flags": Dictionary,
      "current_room_path": String,
      "current_gate_id": String,
      "spawn_position": Vector2
  }
  ```
- **Robust Persistence**: Reads/writes JSON with UTF-8 encoding. Gracefully handles missing files, malformed JSON, and corrupted keys by falling back to verified defaults.

