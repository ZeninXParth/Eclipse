# ECLIPSE: Echoes of the Forgotten — Game Design Document

**Working Title:** ECLIPSE: Echoes of the Forgotten  
**Genre:** 2D Action-Platformer / Metroidvania  
**Inspiration:** Hollow Knight, Super Metroid, Castlevania: Symphony of the Night  
**Engine:** Godot 4.7.2  

---

## 1. Core Vision & Pillars

1. **Crisp & Responsive Movement**: Player inputs translate instantly into character action. No sluggish turnarounds, no untelegraphed momentum traps. Tight platforming is the primary verb.
2. **Fair, Readable Combat**: Every enemy attack is distinctly telegraphed with clear recovery windows. Player attacks have distinct startup, active, and recovery phases. Success is earned through pattern recognition and reaction.
3. **Atmospheric, Environmental Storytelling**: The world reveals its history through architectural ruins, isolated artifacts, and ambient shifts rather than intrusive expository monologues.
4. **Curiosity-Driven Interconnection**: The map is an interconnected labyrinth of secrets, shortcuts, and ability-gated pathways that reward backtracking with newfound traversal power.

---

## 2. World & Narrative Premise

An ancient gothic-Victorian subterranean civilization once maintained a world-spanning network of monolithic archival sanctuaries and kinetic conduits. Following an unexplained cataclysmic collapse, the network fractured into isolated, decaying biomes submerged beneath stone and shadow.

The player awakens as an **Aristocratic Occult Detective** within a sunken subterranean sanctuary known as *The Forgotten Entrance*. Wearing a tall silk top hat with a royal purple band and brass buckle, a tailored waistcoat with pocket watch chain, a tiered coachman's capelet with billowing purple silk lining, and wielding an engraved **Cane Sword** rapier, the detective investigates the cataclysm. Drawing upon arcane aether manifested as glowing **Ethereal Tarot Cards** with celestial runes, the detective traverses forgotten archives, unlocks dormant kinetic abilities, and unravels the occult mystery behind the collapse.

### Planned Vertical Slice Areas
1. **The Forgotten Entrance**: Safe starting sanctuary. Features a resting gothic bench beneath an archival lamp, stone arches, platforming corridors, variable jumps, and the eastern transition gateway to the archive.
2. **The Sunken Archive**: Atmospheric archival ruins submerged in gloom and crumbling scrolls. Introduces vertical drop shafts, patrolling scavenger husks, gloom bat swoopers, hazard spike pits, and the western transition gateway returning to the entrance.
3. **The Ancient Chamber**: An imposing stone arena housing the first boss encounter—the dormant guardian awakened by player intrusion.

---

## 3. Movement Mechanics Specifications

| Parameter | Value | Design Rationale |
|:---|:---|:---|
| **Move Speed** | `260.0 px/s` | Agile navigation across multi-screen chambers. |
| **Ground Acceleration** | `2000.0 px/s²` | Near-instantaneous response from standstill (~0.13s to full speed). |
| **Ground Friction** | `2400.0 px/s²` | Snappy stops without slippery ice physics (~0.11s to full stop). |
| **Air Acceleration** | `1400.0 px/s²` | Sufficient mid-air steering for micro-adjustments during jumps. |
| **Air Friction** | `900.0 px/s²` | Natural airborne momentum drift while preserving player agency. |
| **Jump Height** | `96.0 px` (~3-4 body lengths) | Clear clearance of standard 32px/64px platforms. |
| **Time to Peak** | `0.34 s` | Fast, snappy jump rise. |
| **Jump Gravity** | `~1660.0 px/s²` | Calculated via `2 * height / time²`. |
| **Fall Gravity Multiplier** | `1.35x` (`~2240 px/s²`) | Faster falling than rising creates a satisfying, weighted jump arc. |
| **Variable Jump Cutoff** | `0.5x` upward velocity on release | Enables tap-to-hop (~24-32px) vs. hold-to-leap (~96px). |
| **Coyote Time** | `0.12 s` (7-8 frames @ 60fps) | Forgiving grace period after walking off a ledge. |
| **Jump Buffer** | `0.12 s` (7-8 frames @ 60fps) | Queues jump input if tapped right before ground contact. |
| **Landing Recovery Duration** | `0.08 s` (~5 frames @ 60fps) | Squash/impact recovery before returning to IDLE (canceled immediately by run/jump). |
| **Max Fall Speed** | `650.0 px/s` | Terminal velocity preventing uncontrollable camera tearing. |

---

## 4. Combat Mechanics (Milestone M2 Implementation)

### 4.1 Player Melee System (The Cane Sword)
- **Weapon Concept**: The detective carries an ornate silver-handled cane. In combat, the slender, engraved rapier blade is drawn with lightning speed, leaving glowing electric cyan and lunar silver slash arcs with purple trailing fringe.
- **Attack Phase Timing**:
  - **Startup**: `0.05s` (~3 frames @ 60fps) — Wind-up anticipation before hitbox activation.
  - **Active Window**: `0.07s` (~4-5 frames @ 60fps) — Hitbox is active on Layer 4 (`PlayerHitbox`), detecting Layer 7 (`EnemyHurtbox`) and Layer 8 (`Hazards`).
  - **Recovery**: `0.10s` (~6 frames @ 60fps) — Follow-through window before next attack initiation can begin.
  - **Total Swing Duration**: `0.22s` (~13-14 frames @ 60fps).
- **Directional Priority**:
  1. **Downward Aerial Slash (Pogo)**: Triggered when airborne and holding `move_down`. Hitbox extends below feet (`(0, +4)` offset). Striking valid hurtboxes or hazards triggers vertical rebound (`-460 px/s`) and refreshes coyote time (`0.12s`).
  2. **Upward Slash**: Triggered when holding `move_up`. Hitbox positioned above player (`(0, -48)` offset, 40x32px).
  3. **Forward Slash**: Default neutral/ground horizontal slash. Hitbox extends in facing direction (`(facing * 26, -20)` offset, 36x30px).
- **Single-Hit Guarantee**:
  - Each individual swing tracks struck target nodes in `_hit_targets`. A target overlapping the active hitbox across multiple physics ticks is struck strictly once per swing.

### 4.2 Damage Resolution, I-Frames & Knockback
- **Player Health**: 5 Masks/Shards (`max_health = 5`).
- **Invulnerability Frames (i-frames)**: `1.0s` grace duration upon receiving damage. Character silhouette flickers (alternating opacity/tint) and completely rejects subsequent hits until timer expiry.
- **Directional Knockback**:
  - Applied opposite to attacker direction, with slight upward bias (`+Vector2.UP * 0.4`).
  - Control attenuation (`knockback_timer = 0.15s`) prevents instant input override of impact velocity.
- **Death & Respawn**: Depleting all 5 masks triggers `player_died` signal and instant respawn at the room's designated spawn anchor with full health restoration.

### 4.3 Training Dummy & Hazard Architecture
- **Training Dummy**: Grounded `CharacterBody2D` on Layer 3 (`Enemies`) with Layer 7 `Hurtbox`, 4 HP, visual hit flash, sliding ground friction, and automated defeat/respawn cycle (2.0s delay).
- **Hazard Zone (Spikes)**: Layer 8 (`Hazards`), mask Layer 5 (`PlayerHurtbox`) and Layer 4 (`PlayerHitbox`). Deals 1 contact damage to players and allows upward aerial pogo bounce.

### 4.4 Soul Resource (Aether) & Focus Healing (Ethereal Tarot Cards)
- **Soul / Aether Accumulation**:
  - Striking an enemy with the cane sword harvests **+11 Soul** into an aether reservoir (maximum cap `99`, representing 3 full charges of 33 soul each).
  - Hazard pogo does NOT reward soul (prevents exploit farming).
- **Focus Healing Mechanics**:
  - Requires player to be grounded and stationary (speed <= 20 px/s).
  - Held channel duration: `0.85s` (`focus_charge_duration`) consumes 33 Soul to restore 1 Health Mask.
  - Channeling can be chained if multiple masks are missing and sufficient Soul remains.
  - Any movement, jump, dash, attack, or incoming damage instantly interrupts the channel (consuming 0 Soul).
- **Thematic Tarot Visuals**:
  - During focus channeling, glowing **Ethereal Tarot Cards** adorned with celestial runes manifest in a protective orbit around the detective.
  - A glowing runic occult circle spins beneath the player's feet with purple/lunar flames rising inward.
  - Channel completion triggers a luminous aether burst that shatters the cards into healing light sparks and mends a health mask.

---

## 5. Gamepad & Keyboard Layout

| Action | Primary Keyboard | Secondary Keyboard | Xbox Controller | PlayStation Controller |
|:---|:---|:---|:---|:---|
| **Move Left** | `A` | `Left Arrow` | `D-Pad Left` / `L-Stick Left` | `D-Pad Left` / `L-Stick Left` |
| **Move Right** | `D` | `Right Arrow` | `D-Pad Right` / `L-Stick Right` | `D-Pad Right` / `L-Stick Right` |
| **Look Up** | `W` | `Up Arrow` | `D-Pad Up` / `L-Stick Up` | `D-Pad Up` / `L-Stick Up` |
| **Crouch / Down** | `S` | `Down Arrow` | `D-Pad Down` / `L-Stick Down` | `D-Pad Down` / `L-Stick Down` |
| **Jump** | `Space` | `Z` | `A` (Button 0) | `Cross` (Button 0) |
| **Attack** | `J` | `X` | `X` (Button 2) | `Square` (Button 2) |
| **Dash** | `Shift` | `C` | `RT` / `RB` / `B` | `R2` / `R1` / `Circle` |
| **Focus Heal** | `F` | `E` | `B` (Button 1) | `Circle` (Button 1) |
| **Interact / Bench** | `E` | `W` / `Up Arrow` | `D-Pad Up` / `Y` | `D-Pad Up` / `Triangle` |
| **Reset / Respawn** | `R` | - | `Y` (Button 3) | `Triangle` (Button 3) |
| **Pause Menu** | `Escape` | `P` | `Start` (Button 6) | `Options` (Button 6) |

---

## 6. World Structure & Hollow Knight Scene Linking (Milestone 3)

Milestone 3 introduces the seamless multi-room world partition architecture inspired by *Hollow Knight*, establishing room streaming, transition gates, camera confinement, checkpoint benches, and persistent data serialization.

### 6.1 Flat Serializable Player Data Ledger (`PlayerData`)
All persistent character progression is maintained in a decoupled `PlayerData` resource (`scripts/core/player_data.gd`):
- **Health & Soul**: `health` (masks), `max_health`, `soul` (aether units), `max_soul`.
- **Abilities**: Boolean capability flags (`has_dash`, `has_wall_jump`, `has_pogo`, `has_focus`).
- **World Tracking**: Array of `visited_rooms`, string-to-variant `story_flags` dictionary.
- **Respawn Anchors**: `current_room_path`, `current_gate_id`, `spawn_position`.
- **Disk Persistence**: Export to and import from `user://save_data.json` with schema validation, fallback defaults, and automated round-trip synchronization with `PlayerController`.

### 6.2 Transition Gate Architecture (`TransitionPoint`)
`TransitionPoint` (`scripts/world/transition_point.gd`) serves as the modular boundary gateway:
- **Layering**: Configured on collision Layer 1 (`World`) and Layer 5 (`PlayerHurtbox`), monitoring Layer 2 (`Player`).
- **Exported Configuration**:
  - `target_room_path`: Path to destination scene (e.g. `res://scenes/levels/sunken_archive.tscn`).
  - `target_gate_id`: Unique identifier of paired landing gate (e.g. `Gate_West`).
  - `travel_direction`: Vector enum (`EAST`, `WEST`, `NORTH`, `SOUTH`) informing spawn offsets and transition velocity.
  - `spawn_offset`: Placement offset (default 48px) ensuring player spawns clear of the destination trigger volume to prevent trigger loops.
- **Trigger Pipeline**: Emits `transition_triggered(target_room_path, target_gate_id, travel_direction)` to `GameManager`.

### 6.3 Room Base & Camera Boundaries (`RoomBase`)
Every level scene derives from `RoomBase` (`scripts/world/room_base.gd`), providing:
- **Camera Confinement**: Exports `limit_left`, `limit_top`, `limit_right`, `limit_bottom`. Automatically locates and clamps the active `Camera2D` viewport within room perimeters on scene load.
- **Gate Registry**: Child `TransitionPoint` nodes register their unique `gate_id` in a central dictionary (`register_gate`), enabling instant lookup via `get_gate_position(gate_id)`.
- **Pit Threshold**: Fall-detection threshold (`pit_threshold_y`) catching accidental out-of-bounds drops and respawning the player at the room's default spawn point.
- **Dynamic Enemy Tracking & Respawn**: All dynamic enemies register via `register_enemy(node, home_pos, scene_path)`. When resting at a bench or entering a room, `respawn_all_enemies()` cleanly clears dead entities and instantiates fresh enemies at original spawn locations with restored health and patrol states.

### 6.4 GameManager Autoload Singleton (`GameManager`)
The central orchestrator registered in `project.godot` manages room streaming:
1. **Input Lockdown**: Freezes player inputs (`player.input_locked = true`), zeroes velocity, and halts physics loops.
2. **Screen Fade-to-Black**: Renders an overlay canvas modulating black opacity over `0.25s`.
3. **Scene Tree Swapping**: Safely frees the current room node and instantiates the destination room via deferred SceneTree root child replacement.
4. **Anchor Alignment**: Retrieves target gate position via `destination_room.get_gate_position(target_gate_id)`, places player with directional offset, and resets velocity.
5. **Camera Re-bounding**: Snaps `Camera2D` limits to destination room boundaries and aligns camera position instantly without interpolation tears.
6. **Screen Fade-In & Input Release**: Fades screen from black over `0.25s` and restores player input control.

### 6.5 Gothic Bench Checkpoint (`BenchCheckpoint`)
Inspired by Hollow Knight benches, the `BenchCheckpoint` (`scripts/world/bench_checkpoint.gd`) provides interactive respite:
- **Thematic Visuals**: Hand-crafted gothic cast-iron bench with scrolled armrests and an attached brass archival post lamp emitting warm golden illumination.
- **Rest Mechanics**:
  - Restores player health masks to maximum (`5/5`).
  - Refills soul reservoir to capacity (`99/99`).
  - Records current room and gate anchor to `PlayerData` and writes save data to disk.
  - Dispatches room-wide enemy respawn (`room.respawn_all_enemies()`), resetting all defeated scavengers and swoopers.
  - Triggers restorative glowing pulse and sit visual state.

### 6.6 Vertical Slice Level Scenes
- **The Forgotten Entrance (`forgotten_entrance.tscn`)**:
  - Dimensions: 1920x720 px (`limit_left: 0`, `limit_top: -100`, `limit_right: 1920`, `limit_bottom: 800`).
  - Features: Sanctuary bench (`Bench_Entrance`), archival post lamp, arched stone platforms, and eastern exit gateway (`Gate_East`).
- **The Sunken Archive (`sunken_archive.tscn`)**:
  - Dimensions: 1600x1200 px (`limit_left: 0`, `limit_top: -100`, `limit_right: 1600`, `limit_bottom: 1250`).
  - Features: Western entrance gateway (`Gate_West`), vertical descent shafts, patrol terraces with Walker and Flyer enemies, and hazard spike pits.
- **Two-Way Seamless Linking**: Walking through `Gate_East` in the Entrance transports the detective to `Gate_West` in the Archive; walking back through `Gate_West` seamlessly returns to `Gate_East`.

