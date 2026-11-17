# Combat System (Milestones 1 & 2)

## Purpose
The Combat system delivers a precise, frame-accurate melee combat loop inspired by *Hollow Knight*. It encompasses directional slashing (forward, upward, downward pogo), hitbox/hurtbox collision resolution, single-hit guarantees per swing, damage calculations, directional knockback physics, invulnerability frames (i-frames), and hazard rebound mechanics.

## Core Components
- **`Hitbox` (`res://scripts/combat/hitbox.gd`)**: `Area2D` sub-class representing active strike volumes. Manages active monitoring states, attacker tracking, single-hit recipient dictionaries, directional knockback vectors, and pogo trigger emissions.
- **`Hurtbox` (`res://scripts/combat/hurtbox.gd`)**: `Area2D` sub-class representing strike reception volumes. Manages reception filters (player vs enemy), invulnerability checks, hit delegation to `HealthComponent`, and incoming damage feedback.
- **`HealthComponent` (`res://scripts/combat/health_component.gd`)**: Reusable entity health manager tracking current/maximum health, invulnerability timers, and lifecycle signals (`damaged`, `healed`, `died`).
- **`HitData` (`res://scripts/combat/hit_data.gd`)**: Lightweight `RefCounted` data object transferring damage quantity, knockback direction, knockback impulse, attacker reference, impact coordinates, and pogo flags.
- **`HazardZone` (`res://scripts/combat/hazard_zone.gd`)**: Environmental hazard volume (spikes, acid) supporting contact damage, continuous hurt during overlap, and downward pogo rebound support.

## Public API

### `Hitbox`
- `damage: int` — Attack damage value.
- `knockback_force: float` — Knockback speed in px/s applied to hit targets.
- `attack_direction: Vector2` — Vector indicating strike trajectory.
- `is_pogo: bool` — True if strike triggers upward rebound on valid targets.
- `activate(direction: Vector2, pogo: bool = false)` — Arms hitbox, enables monitoring and collision shape.
- `deactivate()` — Disables monitoring and clears struck targets list.
- `signal hit_landed(target: Node, hit_data: HitData)` — Emitted when a strike connects.
- `signal pogo_triggered(target: Node)` — Emitted when pogo rebound occurs.

### `Hurtbox`
- `health_component: HealthComponent` — Bound health manager.
- `is_player_hurtbox: bool` — Determines collision filtering.
- `receive_hit(hit_data: HitData) -> bool` — Processes incoming hit; returns true if accepted, false if invulnerable or dead.
- `signal hit_received(hit_data: HitData)` — Emitted when a hit successfully damages this hurtbox.

### `HealthComponent`
- `max_health: int` — Maximum capacity.
- `current_health: int` — Current hit points.
- `default_invulnerability_duration: float` — Post-damage immunity duration (e.g. 1.0s).
- `take_damage(amount: int, i_frame_duration: float = -1.0) -> bool` — Applies damage; returns true if damaged.
- `heal(amount: int)` — Restores health up to max.
- `reset_health()` — Restores health to max and clears invulnerability.
- `signal damaged(amount: int)` — Emitted on damage.
- `signal healed(amount: int)` — Emitted on heal.
- `signal died()` — Emitted when health reaches 0.

## Soul / Aether & Focus Healing System (Milestone 2)

### 1. Soul Resource Mechanics
- **Soul Meter Capacity**: 99 max soul (`max_soul`).
- **Resource Accumulation**: Successful melee strikes on enemies route via `Hitbox.hit_landed` -> `PlayerController.add_soul(11)`.
- **Heal Cost**: 33 soul per mask restored (`soul_heal_cost`), providing up to 3 discrete heal charges from a full soul vessel.
- **Signals**:
  - `soul_changed(current_soul: int, max_soul: int)`: Emitted on every delta for UI gauges and telemetry.

### 2. Focus Healing State Machine (`State.FOCUS`)
- **Stationary Channeling**: Player must be grounded and stationary (`absf(velocity.x) <= 20.0`) with missing health and `>= 33` soul.
- **Vulnerable Channel**: Takes 0.85s (`focus_charge_duration`) continuous channel.
- **Interruption Rules**: Any movement input, jump, dash, attack, loss of ground contact, early button release, or damage interrupts channel with zero soul penalty.
- **Healing Execution**: At 0.85s channel completion, 33 soul is consumed, 1 health mask is healed, and `focus_completed` is emitted. If the button remains held and soul/damage remains, focus seamlessly chains into the next charge.
- **Signals**:
  - `focus_started()`: Channeling begins.
  - `focus_charged(progress: float)`: Normalized progress [0.0..1.0] for VFX/shaders.
  - `focus_completed()`: Successfully healed.
  - `focus_interrupted()`: Canceled early without resource consumption.

## How to Extend
1. **Adding New Attack Types (e.g. Great Slash, Spells)**:
   - Instantiate `HitData` with custom damage and knockback parameters.
   - Adjust hitbox collision extents or shape dynamically in `PlayerController._activate_hitbox()`.
2. **Adding Combat Entities (Enemies, Breakable Objects)**:
   - Add a `HealthComponent` and `Hurtbox` node as children of the entity.
   - Connect `Hurtbox.hit_received` to play hit animations or damage flash.
   - Connect `HealthComponent.died` to trigger destruction or defeat state.
