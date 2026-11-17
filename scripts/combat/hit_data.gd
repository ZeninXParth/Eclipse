class_name HitData
extends RefCounted

## ECLIPSE: Echoes of the Forgotten
## Data carrier passed during combat hit resolution.

var damage: int = 1
var knockback_direction: Vector2 = Vector2.RIGHT
var knockback_force: float = 220.0
var attacker: Node = null
var attack_direction: Vector2 = Vector2.RIGHT
var is_pogo: bool = false


func _init(
	p_damage: int = 1,
	p_knockback_direction: Vector2 = Vector2.RIGHT,
	p_knockback_force: float = 220.0,
	p_attacker: Node = null,
	p_attack_direction: Vector2 = Vector2.RIGHT,
	p_is_pogo: bool = false
) -> void:
	damage = p_damage
	knockback_direction = p_knockback_direction.normalized() if p_knockback_direction.length_squared() > 0.0 else Vector2.ZERO
	knockback_force = p_knockback_force
	attacker = p_attacker
	attack_direction = p_attack_direction
	is_pogo = p_is_pogo
