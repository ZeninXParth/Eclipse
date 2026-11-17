# Player System (Milestone 1 & 2)

## Purpose
The Player system manages character locomotion, input translation, physics integration, air mobility forgiveness, wall interactions, dashing, and state transitions for the player character in *ECLIPSE: Echoes of the Forgotten*. It is designed around tight, responsive controls inspired by *Hollow Knight*, utilizing a data-driven `PlayerConfig` resource to centralize all tunable physical parameters.

## Core Components
- **`PlayerController` (`res://scripts/player/player_controller.gd`)**: Primary coordinator and character body implementation. Encapsulates state machine states (`IDLE`, `RUN`, `JUMP`, `FALL`, `LAND`, `WALL_SLIDE`, `WALL_JUMP`, `DASH`, `FOCUS`, `MANTLE`), physics integration, coyote/jump buffer grace timers, directional attack activation, hit-stop freeze frames, pogo bounces, Soul/Focus healing resource mechanics, Double Jump (Wings of the Lunar Eclipse), and athletic Ledge Grab / Mantle.
- **`PlayerConfig` (`res://scripts/player/player_config.gd`)**: Standalone `Resource` exporting kinematic speeds, gravity timings, wall constants, dash parameters, Soul resource thresholds, Double Jump velocity, Mantle reach/offsets, and feedback durations. Serialized in `res://resources/player/default_player_config.tres`.
- **`PlayerVisuals` (`res://scripts/player/player_visuals.gd`)**: Procedural visual rendering node providing squash/stretch responsiveness, walk-cycle bobbing, leaning, lunar slash arcs, world-anchored after-image dash ghosts, wall friction dust, white damage flash feedback, concentric Soul/Focus healing auras with radiant burst rings, and ethereal spectral lunar wings on Double Jump.

## Public API (`PlayerController`)

### Properties & Configuration
- `config: PlayerConfig` — Tunable movement and combat configuration resource.
- `current_state: State` — Current movement state enum (`IDLE`, `RUN`, `JUMP`, `FALL`, `LAND`, `WALL_SLIDE`, `WALL_JUMP`, `DASH`, `FOCUS`, `MANTLE`).
- `facing_direction: int` — 1 (right) or -1 (left).
- `max_speed`, `ground_acceleration`, `ground_deceleration`, `air_acceleration`, `air_deceleration` — Forwarding properties backed by `PlayerConfig`.
- `jump_height`, `time_to_peak`, `fall_gravity_multiplier`, `variable_jump_cutoff`, `max_fall_speed` — Forwarding jump tuning properties.
- `coyote_duration`, `jump_buffer_duration`, `land_duration` — Forgiveness timing windows.
- `wall_slide_speed`, `wall_jump_velocity`, `wall_jump_coyote_duration`, `wall_jump_input_lock_duration` — Wall mobility parameters.
- `dash_speed`, `dash_duration`, `dash_cooldown`, `max_air_dashes` — Dash parameters.
- `double_jump_velocity: float` — Upward impulse applied on Double Jump (default -460 px/s).
- `mantle_reach_distance: float` — Horizontal ledge detection reach in pixels (default 24 px).
- `mantle_pull_offset: Vector2` — Spatial displacement applied when vaulting onto a ledge (default Vector2(20, -32)).
- `double_jump_unlocked: bool` / `mantle_unlocked: bool` — Ability gating flags.
- `current_soul: int` / `max_soul: int` — Current and maximum Soul resource accumulation (default 0 / 99).
- `soul_per_hit: int` — Soul gained per melee strike on an enemy (default 11).
- `soul_heal_cost: int` — Soul consumed per focus heal charge (default 33).
- `focus_charge_duration: float` — Continuous hold duration required to restore 1 health mask (default 0.85s).

### Signals
- `state_changed(new_state: State, previous_state: State)` — Emitted on state transitions.
- `jumped()` — Emitted when a ground or coyote jump initiates.
- `double_jumped()` — Emitted when mid-air double jump initiates.
- `mantled()` — Emitted upon catching a platform ledge.
- `mantle_completed()` — Emitted when vaulting up onto the platform surface.
- `landed()` — Emitted upon ground touchdown.
- `wall_slid()` — Emitted when wall slide engages.
- `wall_jumped()` — Emitted when a wall jump executes.
- `dashed(direction: Vector2)` — Emitted on dash start.
- `hit_stop_triggered(duration: float)` — Emitted when a freeze frame is applied.
- `screen_shake_requested(intensity: float, duration: float)` — Emitted to request camera trauma/shake.
- `pogo_bounced()` — Emitted when downward slash rebounds off a target or hazard.
- `player_damaged(damage: int, remaining_health: int)` — Emitted on incoming damage.
- `player_died()` — Emitted when health reaches zero.
- `soul_changed(current_soul: int, max_soul: int)` — Emitted whenever Soul is gained or spent.
- `focus_started()` — Emitted when the player enters stationary focus channel state.
- `focus_charged()` — Emitted when the hold timer reaches the heal threshold before consumption.
- `focus_completed()` — Emitted when 1 mask is successfully restored and 33 soul is consumed.
- `focus_interrupted()` — Emitted when focus is canceled by release, damage, movement, or death.

### Methods
- `reset_to_spawn()` — Resets position, velocity, and all runtime timers to spawn defaults.
- `trigger_hit_stop(duration: float = -1.0)` — Triggers an engine freeze frame.
- `get_state_name() -> String` — Returns human-readable state string.
- `get_current_health() -> int` / `get_max_health() -> int` — Health queries.
- `is_invulnerable() -> bool` — I-frame status query.
- `is_dashing() -> bool` / `is_wall_sliding() -> bool` — Locomotion state queries.
- `is_focusing() -> bool` — Returns `true` while actively channeling focus.
- `can_focus() -> bool` — Checks whether player is grounded, stationary, damaged, and has >= 33 soul.
- `start_focus()` / `interrupt_focus()` — Initiates or aborts focus channel.
- `get_current_soul() -> int` / `get_max_soul() -> int` — Soul resource queries.

## How to Extend
1. **Adding an Ability (e.g. Double Jump, Super Dash)**:
   - Add new exported constants to `PlayerConfig` with defaults.
   - Define a new state enum in `PlayerController.State` if the ability alters physics integration.
   - Guard input consumption and transitions in `_handle_jump()` or create a dedicated `_handle_<ability>()` method.
   - Ensure the ability properly cancels or respects `knockback_timer > 0.0` (stun lockout).
2. **Custom Visuals**:
   - Replace procedural polygon drawing in `PlayerVisuals` with an `AnimatedSprite2D` or `AnimationPlayer`, listening to `PlayerController` signals (`jumped`, `landed`, `dashed`, `wall_jumped`, `player_damaged`).
