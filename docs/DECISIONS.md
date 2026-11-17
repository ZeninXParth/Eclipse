# ECLIPSE: Echoes of the Forgotten — Architecture & Design Decisions

This document records key architectural decisions and their trade-offs.

---

## Architectural Decision Records (ADRs)

### ADR-001: Godot 4.7.2 Selection & Forward+ / D3D12 Renderer
- **Date:** 2026-10-17
- **Context:** Project was initialized with Godot 4.7 forward+ renderer on Windows.
- **Decision:** Target Godot 4.7.x stable using typed GDScript for fast iteration, native scene composition, and clean 2D engine features.
- **Consequences:** Code must strictly use Godot 4.x APIs (`CharacterBody2D`, typed arrays, new Callable and Signal syntax).

### ADR-002: Base Virtual Resolution (1280x720) with Canvas Items Stretch
- **Date:** 2026-10-17
- **Context:** Metroidvanias need consistent visual scale and clean rendering across 1080p, 1440p, 4K, and Steam Deck screens.
- **Decision:** Set base viewport to `1280x720` with `stretch/mode = "canvas_items"` and `stretch/aspect = "expand"`.
- **Consequences:** Assets drawn at 1x scale remain crisp; dynamic letterbox/pillarbox or extended viewports adapt cleanly without breaking gameplay coordinate calculations.

### ADR-003: Pure Math Jump Arc with Coyote Time & Jump Buffering
- **Date:** 2026-10-17
- **Context:** Standard rigid body physics feels floaty and imprecise for precision Metroidvania platforming.
- **Decision:** Formulate jump parameters from human-interpretable values: `jump_height` (96px) and `time_to_peak` (0.34s). Calculate `jump_gravity = (2 * height) / (time_to_peak ^ 2)` and `jump_velocity = -jump_gravity * time_to_peak`. Implement coyote time (0.12s) and jump buffering (0.12s) via elapsed delta timers.
- **Consequences:** Guarantees frame-rate independent, responsive, pixel-predictable jumping that feels snappy and fair.

### ADR-004: Standard Input Actions Configuration
- **Date:** 2026-10-17
- **Context:** Input checks scattered with raw keycodes (e.g. `KEY_A`) make remapping and gamepad support fragile.
- **Decision:** Define project input actions (`move_left`, `move_right`, `move_up`, `move_down`, `jump`, `attack`, `dash`, `reset`, `pause`) mapped to both WASD/Arrows and standard Gamepad buttons.
- **Consequences:** All gameplay scripts query `Input.get_axis()`, `Input.is_action_just_pressed()`, etc., enabling seamless controller support and future rebinding UI.

### ADR-005: Landing Recovery Window & Sub-frame Tap Jump Cutoff
- **Date:** 2026-10-17
- **Context:** Immediate landing without recovery duration skips impact squash feedback, while unbounded LAND state locks the character permanently if stationary. Furthermore, single-frame `is_action_just_released` queries missed sub-frame and pre-landing buffered jump taps, accidentally generating full apex jumps instead of short hops.
- **Decision:** Parameterize `land_duration` (0.08s, ~5 frames @ 60fps) with automatic transition to `IDLE` upon timeout, and instant interruption upon horizontal move or jump input. Evaluate both `is_action_just_released` and `not is_action_pressed` on jump initiation and rise frames to guarantee short-hop responsiveness on rapid taps.
- **Consequences:** Visual landing squash remains perceptible and crisp without locking the player; tap jumps reliably produce short hops across all input timings.

### ADR-006: Area2D Hitbox / Hurtbox Component Architecture & Single-Hit Swing Tracking
- **Date:** 2026-10-17
- **Context:** Direct body collision queries for melee attacks suffer from multi-hit frame bugs, lack of granular hurtbox tuning, and coupling between movement physics and weapon hit arcs.
- **Decision:** Decouple combat interactions into dedicated `Hitbox` (Layer 4 `PlayerHitbox` / Layer 6 `EnemyHitbox`) and `Hurtbox` (Layer 5 `PlayerHurtbox` / Layer 7 `EnemyHurtbox`) `Area2D` components. The `Hitbox` maintains an internal `_hit_targets` tracking array cleared only upon swing initiation, ensuring overlapping targets receive strictly one damage resolution and knockback event per swing cycle.
- **Consequences:** Eliminates multi-hit bugs; enables modular health and damage resolution across players, enemies, and hazards.

### ADR-007: Directional Attack Parsing, Downward Pogo Rebound & Jump Isolation
- **Date:** 2026-10-17
- **Context:** Metroidvania combat requires directional slashes and down-slash pogo bouncing for fluid combat traversal. Downward attacks on the ground must not bounce or conflict with crouch, while aerial down-slashes must reliably launch the player over hazards without being compromised by jump button state.
- **Decision:** Parse attack direction hierarchically: (1) Airborne + Holding Down -> Downward Pogo Slash, (2) Holding Up -> Overhead Slash, (3) Otherwise -> Horizontal Forward Slash. When a downward attack strikes a valid hurtbox or hazard, immediately assign upward rebound velocity (`pogo_bounce_velocity = -460 px/s`), refresh coyote time (`0.12s`), and ensure `is_jumping = false` (decoupling pogo weapon rebound from jump-held early release cutoff). Track `_pogo_triggered_this_swing` and `has_pogo_bounced` to guarantee exactly one bounce impulse even when striking overlapping targets simultaneously.
- **Consequences:** Fluid, responsive combat traversal; allows players to bounce across enemy heads and spike pits with frame-exact reliability, with full coyote time jump chaining available.

### ADR-008: Invulnerability Frames (I-Frames) & Directional Impact Attenuation
- **Date:** 2026-10-17
- **Context:** Taking damage without invulnerability frames causes unfair instant death from continuous overlapping hitboxes, while immediate player movement input can instantly cancel knockback feel.
- **Decision:** Implement a modular `HealthComponent` with a 1.0s invulnerability window on damage taken, coupled with procedural sprite alpha flickering in `PlayerVisuals`. Apply upward-biased directional knockback with a 0.15s control attenuation window during which horizontal friction decelerates the player rather than instant user steering.
- **Consequences:** Combat impacts feel readable, weighty, and fair; players cannot be chain-hit in a single damage instance.

### ADR-009: Attack Input Buffering & Swing Direction Lock
- **Date:** 2026-10-17
- **Context:** Attacks pressed during the recovery window of a prior swing were previously lost, leading to dropped inputs in combat sequences. Additionally, turning mid-swing caused visual and hitbox orientation de-synchronization.
- **Decision:** Implement a 0.10s `attack_buffer_duration` that queues upcoming attacks during recovery or landing, immediately triggering upon entering `NONE`. Lock character horizontal facing direction during active forward swings (`STARTUP` and `ACTIVE`), permitting orientation updates only upon entering `RECOVERY` or `NONE`.
- **Consequences:** Fluid, responsive attack chaining without dropped keystrokes; guarantees visual and physical hitbox alignment at all times.

### ADR-010: Fatal Damage Pipeline & Continuous Hazard Overlap Resolution
- **Date:** 2026-10-17
- **Context:** Lethal hits previously allowed living knockback and stun impulses to be applied to the player after respawning at the spawn location. Defeated dummies also retained knockback velocity and slid as rubble. Furthermore, standing continuously on hazard spikes failed to deal damage after i-frame expiration due to relying solely on `area_entered`.
- **Decision:** Check if damage is fatal in `Hurtbox.receive_hit` prior to emitting `hit_received`, preventing knockback and stun application on defeated entities. Guard `_on_hit_received` in both Player and Dummy against dead/defeated states. Implement continuous overlap evaluation in `HazardZone._physics_process` across `get_overlapping_areas()` to re-apply hazard damage the moment player i-frames expire.
- **Consequences:** Eliminates lingering post-death knockback slides at spawn points and rubble states; prevents hazard zone immunity exploits.

### ADR-011: Thematic Occult Detective & Cane Sword / Ethereal Tarot Visual Integration
- **Date:** 2026-10-24
- **Context:** Initial prototype relied on generic silhouette geometry and a placeholder shattered blade. Approved concept art established the protagonist as an Aristocratic Occult Detective featuring a tall silk top hat with royal purple band and brass buckle, shadowed face with an electric cyan occult eye, tailored waistcoat with pocket watch chain, tiered coachman's capelet with animated inner purple silk lining billowing during jumps/sprints, polished boots, a drawn Cane Sword rapier with sweeping lunar trails, and Ethereal Tarot Cards with celestial runes for Focus Healing.
- **Decision:** Fully overhaul `PlayerVisuals` procedural drawing to render the complete Aristocratic Occult Detective silhouette. Implement drawn silver cane-sword rapier with electric cyan edge and lunar slash arcs with purple trailing fringe. Implement orbiting Ethereal Tarot Cards with glowing celestial runes and a spinning occult floor circle with purple/lunar flames during Focus Healing.
- **Consequences:** Delivers distinct gothic-Victorian visual identity matching concept designs; cleanly communicates locomotion, combat, and healing states while remaining 100% vector-procedural and resolution-independent.

### ADR-012: Hollow Knight Scene-Linking Pipeline (`RoomBase`, `TransitionPoint`, `GameManager` Autoload)
- **Date:** 2026-10-24
- **Context:** Multi-room Metroidvania exploration requires seamless room transitions: freezing player inputs, fading screen to black, swapping root scenes, indexing destination gates, offsetting player spawn position to prevent gateway re-trigger loops, and snapping camera boundaries without visual tearing. Furthermore, headless test runners (`--script`) do not initialize engine autoloads, requiring autoload decoupling.
- **Decision:** Implement `GameManager` autoload singleton orchestrating input locking (`input_locked`), 0.25s screen fade tweens, deferred SceneTree level swapping, gate alignment with travel direction offsets (`48 px`), and Camera2D limit synchronization. Create `RoomBase` base class providing camera limit exports (`limit_left`, `limit_top`, etc.), gate dictionary indexing (`register_gate`), pit threshold fall catching, and dynamic enemy respawn management. Implement `TransitionPoint` Area2Ds on Layer 1/5 detecting Layer 2. Preload `GameManager` in scripts via `const GameManagerScript = preload("res://scripts/core/game_manager.gd")` and access `GameManagerScript.instance` to guarantee flawless execution in both game runtime and headless test environments.
- **Consequences:** Flawless, two-way room transitions matching *Hollow Knight* conventions; zero camera popping; 100% testable in automated headless CI suites.

### ADR-013: Flat Serializable `PlayerData` Ledger & Bench Save Checkpoint Architecture
- **Date:** 2026-10-24
- **Context:** Character progression (health, soul, unlocked abilities, visited rooms, story flags, spawn anchors) must survive scene transitions and persist across game sessions. Resting at benches must restore vitals, save progression to disk, and respawn room enemies without re-spawning non-enemy world entities.
- **Decision:** Create flat serializable `PlayerData` resource (`scripts/core/player_data.gd`) with dictionary roundtrip and JSON disk persistence to `user://save_data.json` with schema validation and fallback defaults. Create `BenchCheckpoint` Area2D interactable on Layer 9 (`Interactables`) restoring health (5/5), soul (99/99), updating `PlayerData` anchors, writing to disk, and triggering room-wide dynamic enemy respawns (`room.respawn_all_enemies()`).
- **Consequences:** Clean, decoupled progression persistence; resilient against corrupted save files; provides authentic Metroidvania resting and respawn gameplay loop.

### ADR-014: Scene Transition Gateway Priority Spawning, In-Flight Input Locking, and Death Routing
- **Date:** 2026-10-24
- **Context:** Integration testing revealed that placing arriving players at gate origin positions created infinite re-entry transition loops between connected rooms (`Entrance_East` <-> `Archive_West`). Furthermore, newly instantiated player characters in target scenes were initialized with `input_locked = false`, permitting locomotion in the dark during the 0.20s fade-in. Finally, lethal damage in non-sanctuary rooms lacked automatic routing back to the player's saved bench checkpoint.
- **Decision:**
  1. Priority Spawning: `RoomBase.get_gate_position()` resolves spatial anchors with precedence: dedicated `<gate_id>_Spawn` Marker2Ds (`Archive_West_Spawn` at `120, 470`, `Entrance_East_Spawn` at `1620, 470`), child `SpawnPoint` nodes, `TransitionPoint.get_spawn_position()` with `spawn_offset`, and fallback gate origin.
  2. In-Flight Input Lock: `GameManager._perform_scene_swap()` immediately invokes `lock_player(new_player)` on the incoming character, holding input locked until the fade-in tween completes.
  3. Death Respawn Routing: `GameManager` connects to `player.player_died`, invoking `respawn_at_last_bench()` with `sync_stats = false` to restore full health masks (5/5) and reset soul (0) without propagating dead entity statistics back to `PlayerData`.
  4. Gateway & Bench Guards: `TransitionPoint` rejects triggers if the player has 0 HP (lethal damage) or active `input_locked`. `BenchCheckpoint` rejects sit requests unless the player is grounded (`is_on_floor()`) and free of knockback stun.
- **Consequences:** Eliminates transition bounce loops, prevents rogue inputs during screen fade-in, guarantees authentic *Hollow Knight* bench death respawns, and hardens edge cases across world navigation.

### ADR-015: First Boss Encounter ("Archive Warden"), Ground Shockwaves, and Arena Confinement Gate Architecture
- **Date:** 2026-10-24
- **Context:** Delivering a multi-phase boss encounter requires arena lockdown to prevent player flee-escapes, readable telegraphs with distinct wind-up/recovery openings, poise hyper-armor during heavy strikes, aerial pogoable ground hazards, cinematic bottom-center health bar HUD with damage lag, and permanent defeat persistence in `PlayerData`.
- **Decision:**
  1. `ArchiveWarden` Boss State Machine: Two-phase lifecycle with 30 HP, 85% knockback resistance, overhead mace slams emitting traveling `GroundShockwave` hazards, sweeping thrust charges with active poise, and Phase 2 (< 50% HP) enrage sequence unlocking leaping ground pounds with dual shockwaves.
  2. `GroundShockwave` Pogo Hazard: Layer 8 Hazard entity traveling across the floor at 260 px/s with `is_pogo_hazard() -> true`, rebounding downward player slashes with `-460 px/s` upward velocity.
  3. `ArenaGate` Portcullises: Solid Layer 1 barriers automatically sealing the western and eastern perimeter during combat and permanently unlocking upon boss defeat.
  4. `BossHealthBar` HUD: Bottom-center CanvasLayer with damage lag bar and smooth alpha fades.
  5. Persistence: `boss_warden_defeated = true` flag in `PlayerData` prevents boss re-spawning upon room re-entry or bench rests.
- **Consequences:** Delivers a challenging, fair, and cinematic first boss fight satisfying all Hollow Knight architectural pillars.

### ADR-016: Advanced Traversal (Double Jump & Athletic Mantle / Ledge Grab) Kinematics
- **Date:** 2026-10-24
- **Context:** Expanding traversal beyond basic jumping and dashing requires ability-gated vertical mobility for Metroidvania progression and fluid corner recovery inspired by modern genre benchmarks (*Silksong* / *Hollow Knight*).
- **Decision:**
  1. Double Jump (`Wings of the Lunar Eclipse`): Gated by `double_jump_unlocked` and `PlayerData.has_ability("double_jump")`. Applies `-460 px/s` upward impulse with variable jump height cutoff (`* 0.5`). Exactly 1 charge per airtime, refreshed upon touching ground, wall sliding, wall jumping, or downward pogo strikes.
  2. Athletic Mantle / Ledge Grab: Multi-ray physics query detects a solid chest-level wall combined with open head-level air clearance and a solid floor lip. Clings to the ledge with zeroed velocity (`State.MANTLE`) for up to 0.40s. Vaulting up via JUMP or UP displaces player onto the surface (`mantle_pull_offset = Vector2(20, -32)`); pressing DOWN cleanly drops into `State.FALL`. Taking damage interrupts mantle into `State.FALL` with recoil stun.
- **Consequences:** Elevates the Aristocratic Occult Detective's platforming athleticism, eliminates frustrating ledge slips, and provides core ability-gating keys for world progression.

### ADR-017: AbilityPickup Altar Entity, Progression Economy & Mask Shard Health Upgrade Architecture
- **Date:** 2026-10-24
- **Context:** Traversal abilities, health upgrades, currency, and lore collectibles must be discoverable in the world, interactable with celebratory presentation, and persisted across game sessions and room re-entries.
- **Decision:**
  1. `AbilityPickup`: Standalone Layer 9 (`Interactables` = 256) altar entity with procedural basalt pedestal, sinusoidal hovering sigils, radial pulse shaders, and distinct iconography per type (`ABILITY`, `MASK_SHARD`, `CURRENCY`, `RELIC`).
  2. Auto-Collection & Persistence: Contact with player node unlocks ability in `PlayerData` (and synchronizes live controller properties), awards currency/shards, records `"collected_" + pickup_id = true` in `PlayerData.story_flags`, and permanently despawns on subsequent room visits.
  3. Stygian Shards Currency: Flat ledger in `PlayerData.currency` with enemy defeat rewards (Walker: 2, Flyer: 3, Charger: 6, Boss: 25).
  4. Mask Shard Upgrade: Finding 4 Mask Shards resets `mask_shards = 0`, increments `max_health += 1`, and completely heals the player to full capacity.
  5. The Celestial Sanctuary (`celestial_sanctuary.tscn`): Interconnected oasis east of the Ancient Chamber featuring `Bench_Sanctuary`, the Double Jump altar, and an 180px elevated gallery sheltering a secret Mask Shard requiring the newly acquired double jump to reach.
- **Consequences:** Establishes a complete, self-sustaining Metroidvania progression and reward economy.

---

## Items Requiring Project Owner Approval (Pending Decisions)

Per Section 13 of the project brief, the following decisions are explicitly deferred to the project owner:
1. **Final Game Title & Commercial Branding.**
2. **Final Lore Canon, Dialogue Scripts, and Ending.**
3. **Exact Art Style & Resolution Pipeline** (e.g., Hand-drawn vector/raster vs. High-resolution pixel art).
4. **Default Controller / Keyboard Binding Preset Selection.**
5. **Death Penalty Mechanic** (e.g. Geo/Soul shade recovery vs. simple checkpoint respawn).
6. **Total World Scope & Biome Count.**
7. **Target Platforms beyond Windows PC** (e.g. Linux, Steam Deck, Switch).
8. **Third-Party Plugins & Asset Pack Purchases.**
