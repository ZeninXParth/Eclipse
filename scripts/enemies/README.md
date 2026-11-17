# Enemy Framework (Milestones 1 & 2)

## Purpose
Provides base templates, damage reception, visual hit feedback, and respawn life-cycles for enemies and combat practice targets in *ECLIPSE: Echoes of the Forgotten*.

## Core Components
- **`EnemyBase` (`res://scripts/enemies/enemy_base.gd`)**: Abstract base class providing a complete state machine (`IDLE`, `PATROL`, `ALERT`, `ATTACK`, `HURT`, `DEAD`), collision routing, automatic node discovery (`HealthComponent`, `Hurtbox`, `Hitbox`), knockback decay with friction, configurable `knockback_resistance`, damage flash timers, and simulation step hooks for headless unit tests.
- **`WalkerEnemy` (`res://scripts/enemies/walker_enemy.gd`)**: Scavenger Husk archetype. Ground-patrolling biped with ledge/cliff and wall turn-around raycasts, alert telegraph stance (0.35s), forward melee lunge (180 px/s), and pogo support.
- **`FlyerEnemy` (`res://scripts/enemies/flyer_enemy.gd`)**: Gloom Bat archetype. Zero-gravity aerial flyer with sinusoidal vertical hover bobbing, horizontal drift boundaries, vertical downward aggro detection, swooping dive attack (220 px/s), smooth parabolic climb recovery, and full aerial pogo bounce support.
- **`ChargerEnemy` (`res://scripts/enemies/charger_enemy.gd`)**: Armored Beetle archetype. Heavy 6 HP tank with 50% knockback resistance, wind-up roar telegraph (0.45s), high-speed horizontal charge (280 px/s), solid wall-slam stun impact (1.2s vulnerable opening), and carapace pogo bounce.
- **`TrainingDummy` (`res://scripts/enemies/training_dummy.gd`)**: `CharacterBody2D` implementation of a combat practice dummy. Integrates `HealthComponent` and `Hurtbox`, applies ground knockback friction, renders visual white hit flashes with micro-jitter, and enters a rubble state upon defeat before automatically respawning after `respawn_delay` (2.0s).

## Architecture & Collision Filtering

| Entity Component | Collision Layer | Collision Mask | Purpose |
| :--- | :--- | :--- | :--- |
| `EnemyBase` body | Layer 3: Enemies (4) | Layer 1: World (1) | Physical terrain collision |
| Child `Hurtbox` | Layer 7: EnemyHurtbox (64) | Layer 4: PlayerHitbox (8) | Vulnerability to player strikes |
| Child `Hitbox` | Layer 6: EnemyHitbox (32) | Layer 5: PlayerHurtbox (16) | Dealing contact damage to player |

## Public API (`EnemyBase`)

### States
- `State.IDLE`: Stationary pause or post-attack recovery.
- `State.PATROL`: Routine patrol movement.
- `State.ALERT`: Telegraphing impending attack.
- `State.ATTACK`: Executing attack movement or strike volume.
- `State.HURT`: Knockback recoil and hit flash state.
- `State.DEAD`: Health depleted; hitboxes disabled and entity queued for cleanup.

### Configurable Parameters
- `patrol_speed: float` — Routine patrol speed.
- `detection_radius: float` — Distance threshold to spot player.
- `knockback_resistance: float` — Fraction [0.0..1.0] of knockback absorbed (e.g. 0.5 = 50% reduction).
- `hurt_duration: float` — Duration of knockback/stun recovery.

### Signals
- `state_changed(new_state, previous_state)`
- `telegraph_started()`
- `attack_performed()`
- `damaged(amount, remaining_hp)`
- `died()`

## Hitbox Safety & State Lifecycle Contracts

### Hitbox Deactivation Guarantee
To prevent enemies from dealing illegitimate contact damage while reeling or patrolling:
- Whenever an enemy is struck and enters `State.HURT`, `hitbox.deactivate()` is called immediately.
- Whenever an enemy transitions out of `State.ATTACK` for any reason, its hitbox is automatically deactivated in `_set_state()`.
- Upon `State.DEAD`, all hitboxes and hurtboxes are disabled immediately.

### Archetype Invariants & Respawn Cleanups
- **Flyer Altitude / Roost Recovery**: If an aerial flyer is knocked down to ground level by attacks or pogo bounces, it smoothly steers vertically back up toward its home roost elevation (`home_position.y`) during patrol.
- **Charger Wall-Stun Cleanup**: Wall-stunned chargers reset `is_wall_stunned = false` and zero their `charge_timer` upon `respawn()`.
- **Walker State Reset**: Walkers zero `attack_timer` and `walk_cycle` upon `respawn()`.
