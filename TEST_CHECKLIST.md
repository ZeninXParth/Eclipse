# ECLIPSE: Verification & Quality Assurance Checklist

## Milestone 1: Player Foundation Checklist

### 1. Kinematic & Locomotion Tuning
- [x] **Ground Acceleration & Max Speed**: Player accelerates up to 260 px/s smoothly.
- [x] **Ground Deceleration & Stopping**: Braking halts player cleanly without drifting past zero.
- [x] **Air Steering Responsiveness**: Air acceleration (1400 px/s²) and air deceleration (900 px/s²) tuned lower than ground for precise aerial control.
- [x] **Facing Direction Synchronization**: Sprite and visuals flip on horizontal input and maintain direction during idle.
- [x] **Variable Jump Height**: Jump velocity cut off (halved) upon early jump button release.
- [x] **Gravity Progression & Terminal Fall**: Stronger fall gravity multiplier (1.35x) applied when falling; capped at 650 px/s.
- [x] **Ceiling Collision Resolution**: Vertical velocity zeroes and jump state resets immediately upon ceiling impact.
- [x] **Landing Recovery**: Landing state duration (0.08s) cleanly transitions to IDLE or cancels into RUN.

### 2. Forgiveness Windows
- [x] **Coyote Time (Ground)**: 0.12s grace window after leaving ground allows jump execution.
- [x] **Jump Buffering**: 0.12s pre-touchdown jump input fires immediately upon touching ground.
- [x] **Sub-frame Jump Inputs**: Sub-frame tap jumps initiate with halved velocity cleanly.

### 3. Wall Mechanics (New M1)
- [x] **Wall Slide Entry**: Entering downward descent against a solid wall clamps vertical speed to 120 px/s.
- [x] **Wall Slide Cancellation**: Pressing away from the wall or reaching the ground cancels wall slide.
- [x] **Wall Jump Impulse**: Jumping from wall applies horizontal outward push (300 px/s) and upward lift (-480 px/s).
- [x] **Wall Jump Coyote Time**: Slipping off a wall preserves wall jump viability for 0.12s.
- [x] **Wall Jump Input Lockout**: 0.12s window prevents immediate re-clinging into the wall.
- [x] **Wall Slide Mobility Reset**: Wall sliding refreshes air dash count (just like landing on ground).
- [x] **Wall Slide Stun Cancellation**: Taking damage while wall-sliding cancels the slide into FALL state with knockback.

### 4. Dash Mechanics (New M1)
- [x] **Dash Execution**: Pressing dash performs 550 px/s horizontal impulse in facing direction.
- [x] **Dash Gravity Immunity**: Vertical velocity zeroes and gravity is suspended during dash duration (0.16s).
- [x] **Dash Cooldown**: 0.40s cooldown prevents consecutive dash spamming.
- [x] **Air Dash Limitation**: Exactly 1 air dash permitted until touching ground or wall sliding.
- [x] **Dash Visuals & Ghosts**: Stationary world-anchored after-image ghost trail rendered during dash execution (remains fixed in space rather than translating attached to player).
- [x] **Dash Exit Responsiveness**: Releasing movement input during dash cleanly stops in IDLE (0 px/s) rather than forcing uncommanded forward run velocity.
- [x] **Dash Interruption on Pogo**: Downward pogo strike during dash cancels the dash and initiates upward pogo bounce (-460 px/s).
- [x] **Dash Interruption on Damage**: Taking damage during dash cancels the dash and applies recoil knockback.
- [x] **Stun Lockout**: Dash and jump inputs are locked out during damage knockback stun (0.15s).

### 5. Combat & Impact Feedback
- [x] **Melee Attack Lifecycle**: Startup (0.05s), Active (0.07s), Recovery (0.10s) phases.
- [x] **Directional Slashing**: Forward, Upward, and Downward (airborne pogo) attacks.
- [x] **Pogo Bounce**: Downward strike against enemy or hazard gives -460 px/s upward rebound and resets coyote time.
- [x] **Damage & Knockback Stun**: Player takes damage with 1.0s invulnerability frames, visual damage flash, flicker, and knockback stun (0.15s).
- [x] **White Damage Flash**: Taking damage renders a distinct luminous white damage flash on `PlayerVisuals` (0.14s duration).
- [x] **Hit-Stop Freeze**: Melee strikes trigger a 0.06s freeze frame for punchy impact feel.
- [x] **Trauma-Decay Screen Shake**: Camera2D receives quadratic trauma screen shake with rotational roll and duration truncation safeguards.

### 6. Architecture & Data-Driven Tuning
- [x] **PlayerConfig Resource**: All locomotion, combat, wall, dash, and feedback constants exported on a standalone `Resource`.
- [x] **Inspector Integration**: `default_player_config.tres` loaded and exposed for live tweaking.
- [x] **Clean Decoupled APIs**: Telemetry HUD and automated tests read from standardized properties.
- [x] **System Documentation**: Dedicated README files for `Player/`, `Combat/`, `Camera/`, `Enemies/`, `UI/`, and `World/` systems.

### 7. Automated Test Suite Status Overview
- [x] `tests/test_player_physics.gd`: 63/63 passing (100%)
- [x] `tests/test_combat_system.gd`: 113/113 passing (100%)
- [x] `tests/test_movement_m1.gd`: 79/79 passing (100%)
- [x] `tests/test_combat_m2.gd`: 158/158 passing (100%)
- [x] `tests/test_world_m3.gd`: 160/160 passing (100%)
- [x] `tests/test_boss_m4.gd`: 163/163 passing (100%)
- **Total Tests**: 736 passing across all 6 suites with 0 failures (100% pass rate).

---

## Milestone 2: Combat Core & Mobile Enemies Checklist

### 1. Soul / Aether Resource Pool
- [x] **Soul Gain on Strike**: Every successful melee strike on an enemy yields +11 Soul (up to max capacity of 99).
- [x] **Soul Signal Dispatch**: `soul_changed(current_soul, max_soul)` emitted upon any accumulation or expenditure.
- [x] **Soul Cap Clamping**: Subsequent strikes clamp at 99 soul without overflowing.
- [x] **Pogo Hit Accumulation**: Downward pogo hits against enemies award +11 Soul.

### 2. Focus Healing System
- [x] **Stationary Channeling**: Player must be grounded and stationary (horizontal speed <= 20 px/s) to initiate focus healing.
- [x] **Prerequisite Checks**: Cannot focus at full health (5/5), while airborne, during dash/attack, or with insufficient soul (< 33).
- [x] **Channel Duration**: Requires continuous 0.85s held channel (`focus_charge_duration`) to restore 1 health mask.
- [x] **Resource Consumption**: Exactly 33 soul consumed only on channel completion (not during channeling or on interruption).
- [x] **Vulnerable Interruptions**: Focus immediately canceled by early button release, horizontal movement, jump, dash, attack, loss of ground, or taking damage.
- [x] **Chaining Heals**: Holding focus continuously chains into the next heal charge if health remains missing and soul is available.
- [x] **Visual Feedback**: Concentric converging energy rings, pulsing core aura, and radiant burst ring on heal completion.

### 3. Reusable Enemy Framework (`EnemyBase`)
- [x] **Standard State Machine**: Robust `IDLE`, `PATROL`, `ALERT`, `ATTACK`, `HURT`, `DEAD` lifecycle.
- [x] **Decoupled Components**: Standardized instantiation and routing of `HealthComponent`, `Hurtbox`, and `Hitbox`.
- [x] **Knockback Physics & Resistance**: Directional knockback impulse with ground/air friction damping; configurable `knockback_resistance` (e.g., 50% for Charger).
- [x] **Visual Hit Flash**: Dynamic white flashing and micro-jitter on damage reception.
- [x] **Dead State Cleanup**: Deactivates hitboxes, rejects hurtbox interactions, and cleans up entity.

### 4. Mobile Enemy Archetypes
- [x] **Walker Archetype (Scavenger Husk)**:
  - Ground-based patrol (50 px/s) with edge/cliff detection and wall turnaround.
  - Aggro raycast and alert telegraph pause (0.35s).
  - Forward melee lunge (180 px/s) with single-hit damage window.
  - Pogoable: Player down-slashes rebound upward (-460 px/s) and grant +11 soul.
- [x] **Flyer Archetype (Gloom Bat / Swooper)**:
  - 0 gravity aerial navigation with sinusoidal vertical hover bobbing.
  - Patrol drift (40 px/s) with turnaround boundaries.
  - Downward aggro detection with alert flare and high-speed dive swoop (220 px/s).
  - Smooth parabolic climb recovery back to hover altitude.
  - Aerial pogoable with full rebound physics.
- [x] **Charger Archetype (Armored Beetle)**:
  - Heavy 6 HP tank with 50% knockback resistance.
  - Wind-up roar telegraph (0.45s) upon player detection.
  - High-velocity horizontal charge (280 px/s) dealing heavy contact damage.
  - Solid wall-slam impact: Triggers screen shake, cancels charge, and inflicts 1.2s stunned recovery opening.
  - Carapace pogoable from above.

### 5. Level & HUD Integration
- [x] **Combat Room Arena (`combat_room.tscn`)**: Dedicated multi-tier testing arena with encounter terraces for Walker, Flyer, and Charger archetypes, plus hazard pits and training dummy.
- [x] **Test Room Preservation (`test_room.tscn`)**: Clean integration of all three mobile archetypes alongside M1 platforming obstacles and geometry.
- [x] **Telemetry & HUD Integration (`DebugHUD`)**: Real-time Soul resource meter with 3 visual charges (33 soul each), channel progress bar, and updated control bindings list.

### 6. Robustness & Edge Case Safeguards (Review Fixes)
- [x] **Enemy Hitbox Deactivation on Hurt/Interrupt**: Hitboxes immediately deactivated when entering `HURT` or transitioning out of `ATTACK` to prevent lingering active damage volumes during recoil or patrol.
- [x] **Fatal Damage Focus Interruption**: Taking fatal damage during focus channeling triggers `interrupt_focus()` cleanly and dispatches `focus_interrupted` even if `hurtbox.hit_received` was suppressed by death.
- [x] **Landing State Focus Buffering**: Focus can be initiated from `State.LAND` as well as `State.IDLE`, aligning state transition handling with `can_focus()` permission.
- [x] **Flyer Aerial Altitude Recovery**: Flyers steer smoothly vertically back toward their home roost altitude (`home_position.y`) after knockback, rather than remaining trapped at floor level.
- [x] **Charger Respawn Wall-Stun & Timer Cleanup**: Respawning a Charger clears `is_wall_stunned` and resets `charge_timer`.
- [x] **Hazard Soul Farming Immunity**: Non-enemy pogo targets (e.g. hazard spikes) do not grant Soul resource.

---

## Milestone 3: World Structure & Scene Linking Checklist

### 1. PlayerData Serialization & Persistence
- [x] **Default Ledger Initialization**: Generates health (5), max_health (5), soul (0), max_soul (99), abilities flags, visited rooms, and spawn anchors.
- [x] **Dictionary Roundtrip**: `to_dict()` and `from_dict()` serialize and deserialize without loss of typing or data fidelity.
- [x] **JSON Disk Serialization**: `save_to_file()` and `load_from_file()` write/read UTF-8 JSON from `user://` correctly.
- [x] **Corrupted File Fallback**: Invalid JSON or missing files gracefully return a fresh fallback `PlayerData` instance.
- [x] **Controller Synchronization**: `apply_to_player()` and `update_from_player()` reliably sync health, soul, and ability state bidirectionally.
- [x] **Room & Flag Mutators**: `mark_room_visited()`, `has_visited_room()`, `set_story_flag()`, and `get_story_flag()` function deterministically.

### 2. RoomBase & Boundary Management
- [x] **Camera2D Discovery & Clamping**: Automatically locates active `Camera2D` and applies exported `limit_left`, `limit_top`, `limit_right`, and `limit_bottom`.
- [x] **Gate Registry**: Child gateways automatically register their `gate_id` in `_gates`; `get_gate_position()` retrieves exact global coordinates.
- [x] **Pit Threshold Out-of-Bounds Detection**: Detects character dropping below `pit_threshold_y` and safely resets coordinates to `default_spawn_point`.
- [x] **Custom Camera Limit Overrides**: Accommodates variable room dimensions across small, tall, and wide chambers.

### 3. TransitionPoint Gateway Architecture
- [x] **Physics Layer Allocation**: Area2D properly listens on Layer 1/5 and monitors Layer 2 (`Player`).
- [x] **Exported Properties**: Target path, gate ID, travel direction (EAST, WEST, NORTH, SOUTH), and spawn offset (48px).
- [x] **Spawn Offset Geometry**: Directional offset correctly positions incoming player in front of gate, preventing re-trigger loops.
- [x] **Signal Dispatch**: Emits `transition_triggered` with valid parameters upon player character overlap.
- [x] **Debounce Safeguard**: Suppresses duplicate trigger events during active transitions.

### 4. BenchCheckpoint Rest & Save Mechanics
- [x] **Thematic Gothic Visuals**: Renders gothic iron bench with scrolled armrests and warm brass archival post lamp.
- [x] **Restoration Mechanics**: Fully restores player health masks (`5/5`) and fills soul reservoir (`99/99`).
- [x] **Persistence Trigger**: Automatically synchronizes `PlayerData` and writes save file to disk on rest.
- [x] **Enemy Respawn Broadcast**: Emits `bench_rested` signal triggering room-wide `respawn_all_enemies()`.
- [x] **Resting Visual Feedback**: Triggers restorative glowing pulse and sit visual state.
- [x] **Proximity Detection**: Activates interaction prompt only when player is within interaction radius on Layer 9 (`Interactables`).

### 5. Dynamic Enemy Tracking & Respawn
- [x] **Dynamic Enemy Registration**: `RoomBase.register_enemy()` registers live enemy instances, home coordinates, and scene paths.
- [x] **Room-Wide Respawn Loop**: `RoomBase.respawn_all_enemies()` cleanly frees dead or damaged instances and re-instantiates fresh enemies.
- [x] **State & Health Reset**: Respawned enemies start with full health, default patrol state, and zero residual stun or knockback.
- [x] **Exclusion of Non-Enemies**: Benches, doors, collectibles, and terrain are never disturbed by enemy respawn routines.

### 6. GameManager Scene Transition & Lifecycle
- [x] **Autoload Configuration**: Properly registered in `project.godot` without class_name namespace conflicts.
- [x] **Headless Test Preload**: Fully decoupled via `preload("res://scripts/core/game_manager.gd").instance` for headless CLI testing.
- [x] **Transition Execution Sequence**: Locks input -> 0.25s fade to black -> swaps SceneTree room -> positions player at gate -> snaps camera limits -> 0.25s fade in -> unlocks input.
- [x] **Velocity Neutralization**: Zeroes player velocity during room swap, preventing carry-over momentum.
- [x] **Double Transition Suppression**: Prevents overlapping room changes while a transition is in progress.

### 7. Two-Way Level Scene Integration
- [x] **The Forgotten Entrance (`forgotten_entrance.tscn`)**:
  - Sanctuary bench (`Bench_Entrance`), lamp, arches, corridors.
  - Gateway `Gate_East` linked to `scenes/levels/sunken_archive.tscn` -> `Gate_West`.
- [x] **The Sunken Archive (`sunken_archive.tscn`)**:
  - Archival ruins, vertical descent shafts, Walker and Flyer enemies, hazard spikes.
  - Gateway `Gate_West` linked to `scenes/levels/forgotten_entrance.tscn` -> `Gate_East`.
- [x] **Roundtrip Seamlessness**: Entering archive from entrance and returning from archive to entrance places player at exact corresponding gates with correct offsets and zero physics anomalies.

### 8. Robustness & Edge Case Safeguards (Review Fixes)
- [x] **Spawn Marker Priority & Infinite Transition Loop Prevention**: `RoomBase.get_gate_position()` prioritizes dedicated `<gate_id>_Spawn` Marker2Ds (`Archive_West_Spawn` and `Entrance_East_Spawn`), placing player safely outside gateway trigger volumes and eliminating transition ping-pong loops.
- [x] **Transition In-Flight Input Locking**: Incoming player node is locked during `_perform_scene_swap()` so the player cannot move, jump, dash, or re-enter transition triggers in the dark during the 0.20s screen fade-in.
- [x] **Bench Respawn Death Routing**: Player death in connected rooms (`player.player_died`) routes through `GameManager.respawn_at_last_bench()`, restoring full health masks (5/5), resetting soul to 0, and transitioning to the saved bench without overwriting stats from the dead entity.
- [x] **JSON Disk Serialization & Type Recovery**: `PlayerData.save_to_file()` and `load_from_file()` fully support `.json` disk persistence with defensive type coercion and fallback clamping against corrupted values (e.g., `"current_health": "five"`).
- [x] **Mid-Air & Knockback Bench Sitting Rejection**: `BenchCheckpoint._process` verifies `is_on_floor()` / `_is_grounded()`, `knockback_timer <= 0`, and `not input_locked` before allowing rest interaction.
- [x] **Lethal Damage & Input Lock Gateway Rejection**: `TransitionPoint._on_body_entered` suppresses transition if incoming character has 0 HP (lethal damage) or active `input_locked`.
- [x] **Tarot Card Energy Gain FX**: `PlayerVisuals` connects `soul_changed` and renders floating celestial tarot rune sparks when card energy is accumulated from melee hits.

### 9. Comprehensive Automated Verification Suite
- [x] `tests/test_player_physics.gd`: **63/63 passing**
- [x] `tests/test_combat_system.gd`: **113/113 passing**
- [x] `tests/test_movement_m1.gd`: **79/79 passing**
- [x] `tests/test_combat_m2.gd`: **158/158 passing**
- [x] `tests/test_world_m3.gd`: **160/160 passing**
- [x] `tests/test_boss_m4.gd`: **150/150 passing**
- **Grand Total**: **723/723 tests passing across all 6 suites (100% pass rate, 0 failures, 0 regressions)**.

---

## Milestone 4: The Ancient Chamber & First Boss Encounter Checklist

### 1. First Boss Encounter Architecture (`ArchiveWarden`)
- [x] **Imposing Automaton Profile**: Massive occult basalt sentry automaton inheriting from `EnemyBase` with 30 HP, 85% knockback resistance, and dedicated component routing (`HealthComponent`, `Hurtbox`, `Hitbox`).
- [x] **Encounter Trigger & Initialization**: Starts in `DORMANT` state and transitions into combat pacing upon player crossing the arena trigger line.
- [x] **Phase 1 Stalking Pacing**: Menacing horizontal patrol stalking player across the 960px arena runway.
- [x] **Overhead Mace/Blade Slam Attack**:
  - 0.50s wind-up telegraph with luminous white/cyan charge flashes and `telegraph_started` signal.
  - Crushing ground impact with active melee hitbox and `ground_slammed` signal.
  - Emits traveling `GroundShockwave` along the arena floor in facing direction.
  - Generous 0.85s post-slam recovery window providing clear player counter-attack openings.
- [x] **Sweeping Forward Thrust Charge**:
  - 0.40s telegraph wind-up stance.
  - Rapid forward rush (340 px/s) with active hitbox and heavy 360 px/s knockback force.
  - 0.85s recovery window on charge completion.
- [x] **Phase 2 Enrage Transition (< 50% HP / <= 15 HP)**:
  - Triggered immediately when health drops to 15 HP or lower.
  - 1.20s enrage roar sequence with screen shake and temporary invulnerability armor to protect phase entry.
  - Pulsing celestial purple/cyan aura (`enraged_aura`) active for the remainder of the battle.
  - Accelerated attack cadence: slam windup accelerated to 0.40s, recovery windows reduced to ~0.45s.
- [x] **Phase 2 Leaping Ground Pound**:
  - Leaps high into the air (-520 px/s upward impulse) towards player's position.
  - Crushing arena floor impact emitting dual opposing `GroundShockwave` hazards (left and right simultaneously).
- [x] **Defeat Sequence & Rewards**:
  - Triggers on 0 HP: deactivates hitboxes, makes hurtbox invulnerable, emits `boss_defeated` and `gates_unlocked`.
  - Awards restorative Soul reward (+33 Soul) to player.
  - Unlocks arena confinement gates permanently.
  - Persists `boss_warden_defeated = true` in `PlayerData`.

### 2. Ground Shockwave Hazard (`GroundShockwave`)
- [x] **Horizontal Floor Travel**: Moves along floor surface at 260 px/s up to 900px or 2.5s before clean dissipation.
- [x] **Hazard Collision**: Layer 8 Hazard (`collision_layer = 128`), dealing contact damage to grounded players.
- [x] **Pogo Rebound Support**: In group `"pogo_hazard"` and responds to `is_pogo_hazard() -> true`.
- [x] **Downward Slash Rebound**: Player downward slash collision against shockwave triggers `pogo_bounced` with -460 px/s upward rebound velocity.
- [x] **Occult Visuals**: Custom polygon rendering with celestial cyan crest, purple arcane corona, and white core sparks.

### 3. Arena Confinement Gates (`ArenaGate`)
- [x] **Solid Portcullis Collision**: `StaticBody2D` on Layer 1 (World).
- [x] **Dynamic Lock/Unlock**: Disables collision and retracts bars when open; activates solid blocking collision and drops bars when locked.
- [x] **Encounter Lockdown**: Automatically drops and seals both `ArenaGate_West` and `ArenaGate_East` upon crossing arena encounter trigger.
- [x] **Permanent Defeat Unlock**: Automatically unlocks and opens both gates upon boss defeat.
- [x] **Gothic Visuals**: Stone lintel archway, spiked iron portcullis bars, and glowing runic central lock crest.

### 4. The Ancient Chamber Arena (`ancient_chamber.tscn`)
- [x] **Dedicated Arena Level**: Dedicated boss arena scene inheriting from `RoomBase`.
- [x] **Camera Boundaries**: Tuned boundaries (limit_left = -100, limit_right = 1850, limit_top = -250, limit_bottom = 850).
- [x] **960px Runway Span**: 1000px wide flat open arena runway (x = 360 to x = 1360) for boss pacing and maneuvering.
- [x] **Flanking Elevated Stone Platforms**: Two 64px elevated stone platforms (Left at x = 220..360, Right at x = 1360..1500; surface y = 496 vs runway y = 560) designed for leaping over floor shockwaves.
- [x] **Two-Way Scene Transition**:
  - `sunken_archive.tscn` -> `Gate_East` (`Archive_East`) connects to `ancient_chamber.tscn` -> `Gate_West` (`Chamber_West`).
  - `ancient_chamber.tscn` -> `Gate_West` (`Chamber_West`) connects back to `sunken_archive.tscn` -> `Gate_East` (`Archive_East`).
  - Dedicated spawn markers (`Archive_East_Spawn` at `(2070, 630)` and `Chamber_West_Spawn` at `(120, 520)`) prevent gateway bounce loops.

### 5. Boss Cinematic Health Bar HUD (`BossHealthBar`)
- [x] **Cinematic Bottom-Center Presentation**: Anchored at bottom-center of the screen.
- [x] **Occult Typography & Framing**: Displays "ARCHIVE WARDEN — Ancient Sentry" with dark basalt backing and ornate borders.
- [x] **Dual Fill Tracking**: Crimson current health fill and trailing amber damage lag fill that smoothly catches up to damage taken.
- [x] **Dynamic Alpha Transitions**: Smooth fade-in upon encounter start (`show_bar`) and fade-out upon boss defeat (`fade_out`).

### 6. PlayerData Persistence & Room Re-entry Safeguards
- [x] **Story Flag Recording**: `set_story_flag("boss_warden_defeated", true)` recorded in `PlayerData` ledger and committed to disk.
- [x] **Re-entry Check**: `AncientChamber._ready()` inspects `boss_warden_defeated` on room load.
- [x] **Defeated Re-entry State**: If already defeated, boss is permanently removed, arena gates remain open, and encounter trigger is deactivated.
- [x] **Room Respawn Defense**: Calling `respawn_enemies()` (e.g. bench rest) on cleared chamber never revives the defeated boss.
- [x] **Boss Poise & Strike Integrity**: Taking damage during active strike execution (thrust charge, overhead slam, leap) retains active attack hitboxes without interruption.
- [x] **Roar & Slam Screen Shake**: Camera receives quadratic trauma screen shake requests on enrage roar and ground slams.
- [x] **Shockwave Obstacle Dissipation**: Ground shockwaves detect solid World barriers (Layer 1) and dissipate upon reaching closed gates or walls.
- [x] **One-Way Platform Collision**: Elevated stone platforms enable smooth jump-through ascension for evading ground shockwaves.

### 7. Comprehensive Automated Verification Suite Status
- [x] `tests/test_player_physics.gd`: **63/63 passing**
- [x] `tests/test_combat_system.gd`: **113/113 passing**
- [x] `tests/test_movement_m1.gd`: **79/79 passing**
- [x] `tests/test_combat_m2.gd`: **158/158 passing**
- [x] `tests/test_world_m3.gd`: **160/160 passing**
- [x] `tests/test_boss_m4.gd`: **163/163 passing**
- [x] `tests/test_progression_m5.gd`: **98/98 passing**
- **Grand Total**: **834/834 tests passing across all 7 suites (100% pass rate, 0 failures, 0 regressions)**.

---

## Milestone 5: Progression Systems & Traversal Abilities Checklist

### 1. Double Jump (Wings of the Lunar Eclipse)
- [x] **Ability Gating**: Gated by `double_jump_unlocked` on `PlayerController` and `PlayerData.has_ability("double_jump")`.
- [x] **Airborne Execution**: Mid-air jump input launches detective upward with `-460 px/s` velocity.
- [x] **Charge Depletion**: Exactly 1 double jump charge per airborne state (`can_double_jump = false`).
- [x] **Variable Cutoff**: Releasing jump early halves upward velocity (`velocity.y *= variable_jump_cutoff`), ensuring short hops and full leaps are player-controlled.
- [x] **Reset Conditions**: Touching ground (`_handle_landing`), wall sliding (`_handle_wall_mechanics`), wall jumping, or successful downward pogo bounces reset `can_double_jump = true`.
- [x] **Visual Feedback**: Procedural spectral wings unfurl in `PlayerVisuals` with cyan starlight spines and royal purple occult plumage.
- [x] **Air Dash Synergy**: Full compatibility with air dash; dash and double jump chain seamlessly in any order.

### 2. Athletic Ledge Grab / Mantle
- [x] **Ledge Detection**: Multi-ray physics query detects solid chest-level wall with open overhead air space and solid surface lip.
- [x] **Mantle State**: Clings to ledge lip with zeroed velocity (`State.MANTLE`) for up to 0.40s.
- [x] **Vault Input**: Pressing JUMP or UP vaults up onto the ledge surface with `mantle_pull_offset` (x = 20px, y = -32px) and transitions to `State.IDLE`.
- [x] **Drop Input**: Pressing DOWN cleanly cancels mantle into `State.FALL`.
- [x] **Damage Interruption**: Taking damage cancels mantle into `State.FALL` with standard recoil knockback.
- [x] **Athletic Recovery**: Refreshes air dashes and double jump upon grabbing the ledge.

### 3. AbilityPickup Altar Entity (`AbilityPickup`)
- [x] **Layer Routing**: Registered on Layer 9 (`Interactables` = 256), monitoring Player on Layer 2.
- [x] **Pickup Typologies**: Fully supports `ABILITY` (permanent traversal unlocks), `MASK_SHARD` (health upgrades), `CURRENCY` (Stygian Shards), and `RELIC` (lore artifacts).
- [x] **Touch & Inspection Collection**: Auto-collects on player contact with freeze frame and signal dispatch.
- [x] **Altar Aesthetics**: Carved basalt pedestal, sinusoidal hovering sigil, radial pulse corona, and distinct runic icons per type.
- [x] **Persistence Integration**: Writes `"collected_" + pickup_id = true` to `PlayerData.story_flags` and despawns permanently on room re-entry.

### 4. Economy & Upgrades System
- [x] **Stygian Shards Currency**: Dedicated ledger tracking `PlayerData.currency` with safe bounds clamping (0..999999).
- [x] **Enemy Drop Integration**: Defeating any enemy automatically awards Stygian Shards (Walker: 2, Flyer: 3, Charger: 6, Boss: 25) directly to active save data.
- [x] **Currency Transactions**: `spend_currency()` safely deducts balances and rejects underfunded purchases.
- [x] **Mask Shards Progression**: Tracking 4 fragments per health upgrade; collecting the 4th shard increments `max_health` by +1 and restores player health to full (6/6).
- [x] **Relic Registry**: Array of collected relics/lore artifacts in `PlayerData.collected_items`.

### 5. Progression Persistence Serialization
- [x] **Dictionary Roundtrip**: `to_dict()` and `from_dict()` serialize abilities, currency, mask shards, and relics.
- [x] **JSON Disk Serialization**: Writing to and reading from JSON format preserves all progression state intact.
- [x] **Type Coercion Safeguards**: Defensive fallbacks protect against malformed or missing progression keys.

### 6. The Celestial Sanctuary (`celestial_sanctuary.tscn`)
- [x] **New Sanctuary Room**: Gothic sanctuary with midnight marble arches and starlight beams.
- [x] **Camera Bounds**: Tuned limits (left: -100, right: 1600, top: -200, bottom: 800).
- [x] **Sanctuary Bench**: Dedicated checkpoint bench `Bench_Sanctuary` on Layer 9 for rest and saving.
- [x] **Wings Altar**: Pedestal holding the `Wings of the Lunar Eclipse` (`double_jump`) pickup.
- [x] **Ability Gate**: High stone balcony at y = 380 (180px above floor) is physically impossible with a 96px single jump, requiring Double Jump + Mantle to scale.
- [x] **Secret Balcony Shard**: Shelters a secret `Fragment of the Ancient Mask` (`mask_shard_sanctuary`).
- [x] **Two-Way Gate Integration**: Two-way seamless transitions between `ancient_chamber.tscn` (`Chamber_East`) and `celestial_sanctuary.tscn` (`Sanctuary_West`).



