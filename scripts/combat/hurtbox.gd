class_name Hurtbox
extends Area2D

## ECLIPSE: Echoes of the Forgotten
## Vulnerable collision area detecting opposing hitboxes and routing damage.

const HitDataScript = preload("res://scripts/combat/hit_data.gd")
const HealthComponentScript = preload("res://scripts/combat/health_component.gd")

signal hit_received(hit_data: RefCounted)

@export var health_component: HealthComponent
@export var is_player_hurtbox: bool = false

var is_invulnerable: bool:
	get:
		if _manual_invulnerable:
			return true
		if health_component:
			return health_component.is_invulnerable
		return false

var _manual_invulnerable: bool = false


func _ready() -> void:
	if is_player_hurtbox:
		collision_layer = 16 # Layer 5: PlayerHurtbox
		collision_mask = 32 | 128 # Layer 6: EnemyHitbox | Layer 8: Hazards
	else:
		collision_layer = 64 # Layer 7: EnemyHurtbox
		collision_mask = 8 # Layer 4: PlayerHitbox


func set_manual_invulnerable(value: bool) -> void:
	_manual_invulnerable = value


func can_receive_hit() -> bool:
	if is_invulnerable:
		return false
	if health_component and health_component.current_health <= 0:
		return false
	return true


func receive_hit(hit_data: RefCounted) -> bool:
	if not can_receive_hit():
		return false
	
	var is_fatal: bool = false
	if health_component:
		var dmg: int = hit_data.get("damage") if hit_data.get("damage") != null else 1
		if health_component.current_health <= dmg:
			is_fatal = true
		var damaged := health_component.take_damage(dmg)
		if not damaged:
			return false
	
	if not is_fatal:
		hit_received.emit(hit_data)
	return true
