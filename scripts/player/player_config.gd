class_name PlayerConfig
extends Resource

## ECLIPSE: Echoes of the Forgotten
## Player Configuration Data Resource (Milestone 1)
## Centralizes all tunable movement physics, forgiveness timings, wall mechanics,
## dash parameters, melee combat, and camera shake / hit-stop response values.

@export_group("Horizontal Locomotion")
## Maximum horizontal run speed in pixels/sec.
@export var max_speed: float = 260.0
## Ground acceleration in pixels/sec^2.
@export var ground_acceleration: float = 2000.0
## Ground deceleration/braking friction in pixels/sec^2.
@export var ground_deceleration: float = 2400.0
## Air steering acceleration in pixels/sec^2.
@export var air_acceleration: float = 1400.0
## Air drag deceleration in pixels/sec^2.
@export var air_deceleration: float = 900.0

@export_group("Jump Physics")
## Target apex jump height in pixels.
@export var jump_height: float = 96.0
## Time in seconds to reach apex height.
@export var time_to_peak: float = 0.34
## Multiplier applied to gravity when falling for weightier feel.
@export var fall_gravity_multiplier: float = 1.35
## Multiplier applied to upward velocity when jump input is released early.
@export var variable_jump_cutoff: float = 0.5
## Maximum downward speed in pixels/sec.
@export var max_fall_speed: float = 650.0

@export_group("Forgiveness Windows")
## Coyote time grace period in seconds after leaving floor.
@export var coyote_duration: float = 0.12
## Jump buffer window in seconds before touching ground.
@export var jump_buffer_duration: float = 0.12
## Landing state duration before returning to IDLE if stationary.
@export var land_duration: float = 0.08

@export_group("Wall Mechanics")
## Maximum downward slide speed while clinging to a vertical wall in px/s.
@export var wall_slide_speed: float = 120.0
## Outward (x) and upward (y) impulse applied when performing a wall jump.
@export var wall_jump_velocity: Vector2 = Vector2(300.0, -480.0)
## Grace window in seconds after leaving a wall during which a wall jump is still valid.
@export var wall_jump_coyote_duration: float = 0.12
## Brief input attenuation duration after a wall jump to prevent immediately canceling momentum.
@export var wall_jump_input_lock_duration: float = 0.12

@export_group("Dash Mechanics")
## Dash speed in pixels/sec.
@export var dash_speed: float = 550.0
## Dash duration in seconds.
@export var dash_duration: float = 0.16
## Cooldown in seconds before another dash can be executed.
@export var dash_cooldown: float = 0.40
## Maximum number of airborne dashes allowed before touching floor or wall.
@export var max_air_dashes: int = 1

@export_group("Melee Combat")
## Base damage dealt per melee strike.
@export var attack_damage: int = 1
## Knockback impulse applied to struck targets.
@export var attack_knockback_force: float = 240.0
## Startup duration before hitbox activates in seconds.
@export var attack_startup_duration: float = 0.05
## Active hitbox duration in seconds.
@export var attack_active_duration: float = 0.07
## Recovery duration after active hitbox before next attack in seconds.
@export var attack_recovery_duration: float = 0.10
## Attack buffer grace period in seconds to queue upcoming swings.
@export var attack_buffer_duration: float = 0.10
## Upward bounce velocity applied on successful downward pogo strike.
@export var pogo_bounce_velocity: float = -460.0

@export_group("Damage & Hit Reactions")
## Maximum player health (masks/shards).
@export var max_health: int = 5
## Knockback impulse applied to player upon taking damage.
@export var hurt_knockback_speed: float = 220.0
## Stun duration during which player control is attenuated following damage.
@export var knockback_stun_duration: float = 0.15
## Hit-stop duration in seconds upon landing or taking a hit.
@export var hit_stop_duration: float = 0.06
## Screen shake intensity for camera.
@export var screen_shake_intensity: float = 6.0
## Screen shake decay duration in seconds.
@export var screen_shake_duration: float = 0.20

@export_group("Soul & Focus Mechanics")
## Maximum Soul/Aether resource capacity.
@export var max_soul: int = 99
## Soul gained per landed melee strike.
@export var soul_per_hit: int = 11
## Soul consumed per Focus heal charge.
@export var soul_heal_cost: int = 33
## Channel duration in seconds to execute a Focus heal.
@export var focus_charge_duration: float = 0.85

@export_group("Advanced Traversal")
## Upward impulse applied on Double Jump in pixels/sec.
@export var double_jump_velocity: float = -460.0
## Horizontal forward reach in pixels to detect ledge corner for mantling.
@export var mantle_reach_distance: float = 24.0
## Duration in seconds of the mantle vault pull-up transition.
@export var mantle_climb_duration: float = 0.20
## Spatial displacement applied when vaulting up onto the ledge surface.
@export var mantle_pull_offset: Vector2 = Vector2(20.0, -32.0)
