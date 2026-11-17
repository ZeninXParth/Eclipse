# ECLIPSE: Echoes of the Forgotten — Game Logic & Developer Onboarding Guide

Welcome to the **ECLIPSE** development team! This document is a complete technical guide to the game logic, system architecture, physics formulas, combat pipelines, and state machines powering the project.

Whether you are implementing a new enemy, designing a room, adding an ability, or tuning gameplay feel, this guide explains how the entire codebase connects and how to contribute without breaking existing functionality.

---

## 1. Project Overview & Design Philosophy

- **Title:** *ECLIPSE: Echoes of the Forgotten*
- **Genre:** 2D Action Metroidvania / Gothic Platformer
- **Engine:** Godot Engine 4.7.2 (GDScript, Forward+ / D3D12)
- **Primary Influences:** *Hollow Knight*, *Castlevania: Symphony of the Night*, *Hollow Knight: Silksong*
- **Protagonist:** **The Aristocratic Occult Detective**
  - Wields an engraved silver **Cane Sword** (rapier) with electric cyan/lunar light trails.
  - Channels occult aether into glowing **Ethereal Tarot Cards** for Focus Healing.
  - Clad in a tall obsidian silk top hat (royal purple band, brass buckle), tailored waistcoat, pocket watch chain, and coachman's capelet with purple silk lining.

### The 4 Core Design Pillars
1. **Immediate, Tight Locomotion:** No sluggish floatiness. Snappy acceleration (`2000 px/s²`), instant stopping friction (`2400 px/s²`), variable jump height, coyote time, and pre-landing jump buffering.
2. **Readable, Fair Combat:** Every enemy and boss attack has distinct startup telegraphs, active damage frames, and post-attack recovery openings. The player has a 0.05s startup, single-hit tracking, directional attacks (up, forward, down-pogo), and hit-stop freeze frames.
3. **Risk & Rhythm Resource Loop:** Striking enemies harvests Soul/Aether (+11 per hit). Stationary Focus Healing channels 33 Soul over 0.85s to heal 1 mask, but leaves the player completely vulnerable to interruption.
4. **Interconnected World & Ability Gating:** Hand-crafted rooms connected via two-way transition gates with camera viewport clamping, checkpoint resting benches, and persistent save data.

---

## 2. Directory & File Organization

The codebase is strictly modularized into decoupled subsystems:

```text
res://
├── project.godot                     # Project settings, physics layers, viewport (1280x720)
├── TEST_CHECKLIST.md                 # Master QA checklist (834 automated tests passing)
├── docs/                             # Architecture specifications & Design Decisions (ADRs)
│   ├── GAME_DESIGN.md                # Game mechanics & narrative design document
│   ├── TECHNICAL_ARCHITECTURE.md     # Node hierarchies, physics collision matrix
│   ├── DEVELOPMENT_ROADMAP.md        # Milestone completion status
│   └── DECISIONS.md                  # Architectural Decision Records (ADR-001 to ADR-017)
├── resources/
│   └── player/
│       └── default_player_config.tres # Central tuning resource (all kinematic/combat constants)
├── scenes/
│   ├── player/
│   │   └── player.tscn               # Detective player scene (CharacterBody2D + Components)
│   ├── levels/                       # Interconnected world rooms (all inherit from RoomBase)
│   │   ├── forgotten_entrance.tscn   # Sanctuary starting area with Bench_Entrance
│   │   ├── sunken_archive.tscn       # Archival ruins, vertical descent, hazard pits, enemies
│   │   ├── ancient_chamber.tscn      # Boss arena with Archive Warden & confinement gates
│   │   ├── celestial_sanctuary.tscn  # Post-boss oasis with Bench_Sanctuary & Double Jump altar
│   │   ├── test_room.tscn            # Kinematics & platforming calibration arena
│   │   └── combat_room.tscn          # Combat sparring arena with dummy & mobile enemies
│   ├── enemies/                      # Mobile enemy archetypes & training targets
│   │   ├── walker_enemy.tscn         # Scavenger Husk (ground patrol & lunge)
│   │   ├── flyer_enemy.tscn          # Gloom Bat (hover bob & dive swoop)
│   │   ├── charger_enemy.tscn        # Armored Beetle (heavy rush & wall-stun)
│   │   └── training_dummy.tscn       # Responsive combat sparring target
│   ├── bosses/
│   │   ├── archive_warden.tscn       # First boss: Archive Warden (Phase 1 & Phase 2 enrage)
│   │   └── ground_shockwave.tscn     # Traveling floor shockwave hazard (pogoable)
│   ├── objects/
│   │   ├── transition_point.tscn     # Two-way room gateway trigger
│   │   ├── bench_checkpoint.tscn     # Gothic rest bench & disk save point
│   │   └── ability_pickup.tscn       # World altar for abilities, shards, currency, relics
│   └── ui/
│       ├── debug_hud.tscn            # Real-time telemetry, soul charges, inputs
│       └── boss_health_bar.tscn      # Cinematic boss HUD with trailing damage lag bar
├── scripts/
│   ├── core/                         # Singletons, save data, and game state
│   │   ├── game_manager.gd           # Room streaming orchestrator & fade-to-black singleton
│   │   └── player_data.gd            # Flat serializable save data (health, soul, flags, abilities)
│   ├── player/                       # Character mechanics & visuals
│   │   ├── player_controller.gd      # CharacterBody2D state machine & kinematics
│   │   ├── player_config.gd          # Tunable PlayerConfig resource script
│   │   └── player_visuals.gd         # Occult Detective procedural vector rendering & VFX
│   ├── combat/                       # Decoupled component-based combat system
│   │   ├── hit_data.gd               # RefCounted damage & knockback payload
│   │   ├── health_component.gd       # Generic health, i-frames, and death dispatcher
│   │   ├── hitbox.gd                 # Damage-dealing Area2D component
│   │   ├── hurtbox.gd                # Damage-receiving Area2D component
│   │   └── hazard_zone.gd            # Static damage zone (spikes) with pogo rebound
│   ├── enemies/                      # Reusable AI state machines
│   │   ├── enemy_base.gd             # Base class for all hostile entities
│   │   ├── walker_enemy.gd           # Ground patrolling scavenger logic
│   │   ├── flyer_enemy.gd            # Aerial swooper logic
│   │   ├── charger_enemy.gd          # Heavy charging tank logic
│   │   └── training_dummy.gd         # Sparring target logic
│   ├── bosses/
│   │   ├── archive_warden.gd         # Boss AI state machine, shockwaves, and hyper-armor
│   │   └── ground_shockwave.gd       # Shockwave projectile logic & Layer 1 barrier dissipation
│   ├── world/                        # Level scripting & interactables
│   │   ├── room_base.gd              # Base class for rooms (camera clamping, enemy respawn)
│   │   ├── transition_point.gd       # Gateway trigger & spawn offset positioning
│   │   ├── bench_checkpoint.gd       # Rest interaction, vitals recovery & persistence trigger
│   │   ├── arena_gate.gd             # Solid portcullis confinement barrier
│   │   ├── ancient_chamber.gd        # Boss arena coordinator script
│   │   ├── celestial_sanctuary.gd    # Sanctuary room script
│   │   └── ability_pickup.gd         # World altar pickup script
│   ├── ui/
│   │   ├── debug_hud.gd              # Diagnostic telemetry overlay
│   │   └── boss_health_bar.gd        # Cinematic boss health HUD
│   └── camera/
│       └── camera_controller.gd      # Camera2D bounds clamping & quadratic trauma shake
└── tests/                            # Headless automated verification test suites
    ├── test_player_physics.gd        # Locomotion kinematics & forgiveness windows (63 tests)
    ├── test_combat_system.gd         # Hitbox/hurtbox, directional slash, pogo (113 tests)
    ├── test_movement_m1.gd           # Wall slide, wall jump, dash, camera shake (79 tests)
    ├── test_combat_m2.gd             # Soul pool, focus heal, Walker/Flyer/Charger (158 tests)
    ├── test_world_m3.gd              # RoomBase, GameManager, PlayerData, Bench (160 tests)
    ├── test_boss_m4.gd               # Archive Warden, shockwaves, gates, boss HUD (163 tests)
    └── test_progression_m5.gd        # Double jump, mantle, pickups, currency economy (98 tests)
```

---

## 3. The 2D Collision Layer Matrix

Never guess collision masks or layers! All physics interactions in *ECLIPSE* rely on this strict 9-layer allocation:

| Layer | Bit | Layer Name | Collision Purpose | Monitors / Collides With |
|:---:|:---:|:---|:---|:---|
| **1** | `1` | `World` | Solid geometry, floors, walls, ceilings, one-way platforms, closed arena gates. | Solid bodies. |
| **2** | `2` | `Player` | Player `CharacterBody2D` body. | Mask: Layer 1 (`World`). |
| **3** | `4` | `Enemies` | Enemy `CharacterBody2D` bodies. | Mask: Layer 1 (`World`). |
| **4** | `8` | `PlayerHitbox` | Player Cane Sword attack volume (`Hitbox`). | Mask: Layer 7 (`EnemyHurtbox`), Layer 8 (`Hazards`). |
| **5** | `16` | `PlayerHurtbox`| Player vulnerable damage receiver (`Hurtbox`). | Mask: Layer 6 (`EnemyHitbox`), Layer 8 (`Hazards`). |
| **6** | `32` | `EnemyHitbox` | Enemy attacks & contact damage (`Hitbox`). | Mask: Layer 5 (`PlayerHurtbox`). |
| **7** | `64` | `EnemyHurtbox`| Enemy vulnerable damage receiver (`Hurtbox`). | Mask: Layer 4 (`PlayerHitbox`). |
| **8** | `128`| `Hazards` | Spikes, acid, floor shockwaves. | Deals damage to Layer 5; rebounds Layer 4 pogo. |
| **9** | `256`| `Interactables`| Checkpoint benches, ability altars, NPC dialogue. | Mask: Layer 2 (`Player`). |

---

## 4. Player Mechanics & Locomotion Logic

The character controller lives in `scripts/player/player_controller.gd`. All tunable constants are exposed through `scripts/player/player_config.gd` (`res://resources/player/default_player_config.tres`).

### 4.1 Locomotion State Machine (`PlayerController.State`)
The player is strictly in one of these states at any given moment:
1. `IDLE`: Grounded, zero horizontal input.
2. `RUN`: Grounded, running with horizontal velocity (`max_speed = 260.0 px/s`).
3. `JUMP`: Airborne, moving upward (`velocity.y < 0`).
4. `FALL`: Airborne, falling downward (`velocity.y >= 0`).
5. `LAND`: Ground touchdown recovery state (`land_duration = 0.08s`), instantly cancelable into `RUN` or `JUMP`.
6. `WALL_SLIDE`: Clinging against a vertical wall, sliding downward at clamped speed (`wall_slide_speed = 120.0 px/s`).
7. `WALL_JUMP`: Airborne leap launched away from a wall (`wall_jump_velocity = Vector2(300, -480)`).
8. `DASH`: High-speed horizontal impulse (`dash_speed = 550.0 px/s`, `duration = 0.16s`, `gravity = 0`).
9. `FOCUS`: Grounded stationary healing channel (velocity locked, cards circling).
10. `MANTLE`: Clinging to a platform ledge corner (velocity zeroed, awaiting vault or drop input).

### 4.2 Exact Kinematics & Forgiveness Formulas
- **Gravity Calculation:**
  ```gdscript
  jump_gravity = (2.0 * jump_height) / (time_to_peak * time_to_peak)  # ~1660 px/s²
  jump_velocity = -jump_gravity * time_to_peak                         # -564.7 px/s
  fall_gravity = jump_gravity * fall_gravity_multiplier                 # ~2241 px/s² (1.35x)
  ```
- **Variable Jump Height Cutoff:** Releasing the jump button early immediately cuts vertical ascent velocity in half (`velocity.y *= variable_jump_cutoff`, default `0.5`).
- **Coyote Time (`coyote_duration = 0.12s`):** Walking off a ledge grants 7-8 frames of grace where jumping is still fully permitted.
- **Jump Buffering (`jump_buffer_duration = 0.12s`):** Pressing jump slightly before touching the ground buffers the input and executes on the exact physics tick of touchdown.
- **Air Dash Limitation:** Exactly 1 air dash permitted per airtime. Touching ground, sliding on a wall, executing a wall jump, or landing a downward pogo rebound refreshes `air_dashes_remaining = 1`.
- **Double Jump (`Wings of the Lunar Eclipse`):**
  - Gated by `double_jump_unlocked` (and `PlayerData.has_ability("double_jump")`).
  - Pressing Jump while airborne applies `double_jump_velocity = -460.0 px/s` with early release cutoff.
  - Consumes `can_double_jump = false`.
  - Refreshes on ground contact, wall slide, wall jump, or pogo bounce.
- **Athletic Mantle / Ledge Grab:**
  - Performs a 3-ray direct space query when airborne and falling near a wall:
    1. Chest ray (`y - 18px`): Detects solid wall face within `24px`.
    2. Head ray (`y - 42px`): Verifies open air clearance above the wall.
    3. Downward ray: Verifies solid flat top surface of the ledge lip.
  - On detection: Enters `State.MANTLE` with zeroed velocity.
  - Input: Pressing `JUMP` or `UP` vaults onto the platform (`position += Vector2(facing * 20, -32)`). Pressing `DOWN` cancels the grab into `State.FALL`. Taking damage interrupts into `State.FALL`.

---

## 5. Combat & Resource Loop Logic

### 5.1 Cane Sword Attack Pipeline
Combat uses an explicit 4-phase finite state machine (`PlayerController.AttackState`):
```text
[NONE] ──(attack input)──► [STARTUP: 0.05s] ──► [ACTIVE: 0.07s] ──► [RECOVERY: 0.10s] ──► [NONE]
                                                      │
                                            Hitbox enabled on Layer 4
                                            Single-hit tracking per target
                                            Directional positioning
```
1. **Startup (0.05s):** Wind-up animation. Facing direction locks to prevent mid-swing flipping. Hitbox is inactive.
2. **Active (0.07s):** Hitbox activates on Layer 4 (`PlayerHitbox`).
   - **Forward Slash:** Positioned `Vector2(facing * 26, -20)`, size `36x30px`.
   - **Upward Slash:** Triggered by holding `UP`. Positioned `Vector2(0, -48)`, size `40x32px`.
   - **Downward Slash (Pogo):** Triggered airborne by holding `DOWN`. Positioned `Vector2(0, 4)`, size `36x24px`.
3. **Recovery (0.10s):** Hitbox deactivates. Attack buffer window queues next attack if tapped early.
4. **Hit-Stop Freeze Frame:** Landed melee strikes freeze both attacker and target for `0.06s` (`hit_stop_timer`), providing visceral impact feedback.
5. **Camera Shake Trauma:** Landed hits and explosions apply quadratic decaying trauma (`shake = trauma²`) to `Camera2D`.

### 5.2 Aerial Downward Pogo Rebound
- When a downward slash strikes any enemy hurtbox (Layer 7) or hazard spike / shockwave (Layer 8):
  - Emits `pogo_bounced` signal.
  - Imparts instant upward impulse: `velocity.y = pogo_bounce_velocity` (`-460.0 px/s`).
  - Resets `coyote_timer`, refreshes `air_dashes_remaining = 1`, and refreshes `can_double_jump = true`.
  - Cancels active horizontal dash into `State.JUMP`.

### 5.3 Soul (Aether) & Focus Healing Loop
- **Soul Harvesting:**
  - Striking any living enemy with the cane sword grants **+11 Soul** into an aether pool (clamped to max `99`).
  - Hitting inanimate hazards (spikes) does NOT award Soul (prevents farming exploits).
- **Focus Healing (Ethereal Tarot Cards):**
  - **Preconditions:** Player must be grounded, stationary (`|velocity.x| <= 20 px/s`), not at full health (`current_health < max_health`), and have at least `33 Soul`.
  - **Channel Duration:** Holding the Focus key for `0.85s` (`focus_charge_duration`) channels tarot cards in orbit.
  - **Execution:** Upon reaching 100% progress, exactly 33 Soul is deducted and 1 Health Mask is restored.
  - **Vulnerability:** Moving, jumping, dashing, attacking, or taking damage immediately interrupts the channel (consuming 0 Soul).

---

## 6. Enemy AI & Boss Architecture

All hostile entities derive from `EnemyBase` (`scripts/enemies/enemy_base.gd`).

### 6.1 `EnemyBase` State Lifecycle
- States: `IDLE` ──► `PATROL` ──► `ALERT` ──► `ATTACK` ──► `HURT` ──► `DEAD`.
- Standard components: Built-in `HealthComponent`, Layer 7 `Hurtbox`, and Layer 6 `Hitbox`.
- **Knockback Physics:** Directional impulse attenuated by `knockback_resistance` (e.g. 0.0 for Husks, 0.50 for Chargers, 0.85 for Bosses).
- **Hit Flash:** Damaged enemies flash white for 0.12s.
- **Currency Drop:** Defeating any enemy automatically awards Stygian Shards to `PlayerData.currency` (Walker: 2, Flyer: 3, Charger: 6, Boss: 25).

### 6.2 Mobile Enemy Archetypes
1. **Walker (`WalkerEnemy` / Scavenger Husk):**
   - Ground patrol (`50 px/s`) with edge/cliff detection and wall bounce.
   - Alert telegraph (`0.35s`) upon seeing player, followed by a forward melee lunge (`180 px/s`).
2. **Flyer (`FlyerEnemy` / Gloom Bat):**
   - Sinusoidal floating hover flight at zero gravity.
   - Detects player below, emits alert flare, and dives downward at high speed (`220 px/s`), recovering parabolically back to roost altitude.
3. **Charger (`ChargerEnemy` / Armored Beetle):**
   - 6 HP tank with 50% knockback resistance.
   - Wind-up roar telegraph (`0.45s`), followed by high-velocity forward rush (`280 px/s`).
   - Colliding with solid Layer 1 walls inflicts screen shake, cancels charge, and inflicts `1.2s` wall-stun vulnerability.

### 6.3 First Boss: Archive Warden (`ArchiveWarden`)
- Located in `ancient_chamber.tscn`. 30 HP, 85% knockback resistance.
- **Boss Poise / Hyper-Armor:** Boss attack hitboxes are NOT canceled when struck by the player.
- **Phase 1 (HP > 15):**
  - Stalks player horizontally across the 1000px runway.
  - **Overhead Slam:** 0.50s wind-up telegraph -> Crushing ground impact -> Emits traveling `GroundShockwave` along floor -> 0.85s recovery window.
  - **Forward Thrust:** 0.40s stance telegraph -> Rapid forward rush (340 px/s) with heavy knockback -> 0.85s recovery.
- **Phase 2 Enrage Transition (HP <= 15):**
  - Roar sequence (1.20s) with invulnerability armor and screen shake.
  - Unlocks permanent purple celestial aura.
  - Accelerates attack wind-ups (0.40s) and recovery windows (0.45s).
  - **Leaping Ground Pound:** Leaps high into the air (-520 px/s) toward player -> Slams arena floor -> Spawns dual opposing `GroundShockwave` hazards traveling left and right simultaneously.
- **Arena Confinement Gates:** `ArenaGate_West` and `ArenaGate_East` lock upon crossing the encounter trigger; permanently unlock upon boss defeat.
- **Persistence:** Defeat records `boss_warden_defeated = true` in `PlayerData`; resting at benches never revives the cleared boss.

---

## 7. World Scene Streaming & Save/Load Persistence

### 7.1 Room Streaming Pipeline (`GameManager`)
Rooms are streamed cleanly via `GameManager.change_room(target_scene_path, target_gate_id, travel_direction)`:
1. `GameManager` locks incoming player inputs (`input_locked = true`) and zeroes velocity.
2. Screen fades to black over `0.20s` via CanvasLayer overlay.
3. Old room node is safely queued for deletion (`queue_free()`).
4. New room scene instantiates and is added to the SceneTree.
5. Player node is positioned at the paired `<gate_id>_Spawn` Marker2D (offset safely from trigger volumes to prevent ping-pong bounce loops).
6. Camera limits snap instantly to `RoomBase` boundaries without frame tearing.
7. Screen fades in from black (`0.20s`) and player input is unlocked.

### 7.2 Checkpoint Benches (`BenchCheckpoint`)
- Interacting (`E` or `Up`) restores 5/5 health masks and 99/99 soul units.
- Calls `PlayerData.save_to_file()` committing current progression to disk.
- Emits `bench_rested`, triggering `RoomBase.respawn_all_enemies()` to revive room scavengers and flyers without disturbing non-enemy world entities.

### 7.3 PlayerData Ledger (`scripts/core/player_data.gd`)
A flat serializable resource managing:
- `current_health`, `max_health`
- `soul`, `max_soul`
- `currency` (Stygian Shards)
- `mask_shards` (4 shards increment `max_health` and fully heal player)
- `unlocked_abilities` (`Array[String]`: `"dash"`, `"wall_jump"`, `"double_jump"`, `"mantle"`)
- `collected_items` (`Array[String]` for relics/lore)
- `story_flags` (`Dictionary` for boss defeat, unlocked gates, collected pickups)
- `last_bench_id`, `respawn_room_path`, `respawn_gate_id`
- Persists to `user://save_slot_1.res` or `.json` with corrupted file fallbacks.

---

## 8. Automated Testing & Verification Suite

The project enforces a **Zero Broken Tests Policy**. We currently maintain **834 passing automated tests** across 7 headless suites with a 100% pass rate.

### How to Run All Tests Headless (CLI)
From the project directory, run this command using Godot Console:

```powershell
python -c "
import subprocess
tests = [
    'test_player_physics.gd',
    'test_combat_system.gd',
    'test_movement_m1.gd',
    'test_combat_m2.gd',
    'test_world_m3.gd',
    'test_boss_m4.gd',
    'test_progression_m5.gd'
]
for t in tests:
    cmd = ['D:/EREN/Godot_v4.7.2-stable_win64_console.exe', '--headless', '--path', 'C:/Users/HARSHAL/OneDrive/Desktop/Godot/eclipse', '-s', f'tests/{t}']
    res = subprocess.run(cmd, capture_output=True, text=True)
    p = [l for l in res.stdout.splitlines() if 'Passed:' in l][-1].strip()
    f = [l for l in res.stdout.splitlines() if 'Failed:' in l][-1].strip()
    print(f'{t:25} -> {p}, {f}')
"
```

Expected output:
```text
test_player_physics.gd    -> Passed:  63, Failed:  0
test_combat_system.gd     -> Passed: 113, Failed:  0
test_movement_m1.gd       -> Passed:  79, Failed:  0
test_combat_m2.gd         -> Passed: 158, Failed:  0
test_world_m3.gd          -> Passed: 160, Failed:  0
test_boss_m4.gd           -> Passed: 163, Failed:  0
test_progression_m5.gd    -> Passed:  98, Failed:  0
==================================================
GRAND TOTAL: 834 Passed, 0 Failed across 7 suites (100% Pass Rate)
```

---

## 9. Golden Rules for Contributors

When writing code or adding content:
1. **Never Hardcode Numbers:** Export speeds, timers, gravities, and damage on `PlayerConfig` or at the top of scripts.
2. **Always Use Explicit Static Typing:** Write `func take_damage(amount: int) -> void:`, never untyped GDScript.
3. **Decouple via Signals:** Call down directly to children; signal up to parents/managers. Never reach up into parent nodes with brittle paths like `$"../../SomeNode"`.
4. **Preserve Single-Hit per Swing:** When creating melee attacks or multi-frame hazards, always track struck nodes in an array/dictionary to avoid multi-hit-per-frame bugs.
5. **Respect Collision Layers:** Strictly follow the 9 collision layers defined in Section 3.
6. **Keep Automated Tests Green:** Run the test suite before and after making changes. If a change modifies behavior intentionally, update the corresponding test suite and `TEST_CHECKLIST.md`.
7. **Zero Git Initialization Unless Instructed:** Do not initialize or alter git repository files unless explicitly requested by the project lead.

Welcome aboard! If you have questions about specific systems, check the respective `README.md` files located in each subsystem directory under `scripts/`.
