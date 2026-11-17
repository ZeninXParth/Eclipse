class_name Hitbox
extends Area2D

## ECLIPSE: Echoes of the Forgotten
## Offensive collision area applying damage and knockback with single-hit per swing guarantee.

const HitDataScript = preload("res://scripts/combat/hit_data.gd")
const HurtboxScript = preload("res://scripts/combat/hurtbox.gd")

signal hit_landed(target: Node, hit_data: HitData)
signal pogo_triggered(target: Node)

@export var is_player_hitbox: bool = true
@export var damage: int = 1
@export var knockback_force: float = 220.0
@export var attacker: Node

var attack_direction: Vector2 = Vector2.RIGHT
var is_pogo: bool = false
var is_active: bool = false
var _hit_targets: Array[Node] = []
var _pogo_triggered_this_swing: bool = false


func _init() -> void:
	monitoring = false
	monitorable = false


func _ready() -> void:
	if is_player_hitbox:
		collision_layer = 8 # Layer 4: PlayerHitbox
		collision_mask = 64 | 128 # Layer 7: EnemyHurtbox | Layer 8: Hazards
	else:
		collision_layer = 32 # Layer 6: EnemyHitbox
		collision_mask = 16 # Layer 5: PlayerHurtbox
	
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	deactivate()


func reset_swing() -> void:
	_hit_targets.clear()
	_pogo_triggered_this_swing = false


func activate(dir: Vector2, pogo: bool = false) -> void:
	is_active = true
	attack_direction = dir
	is_pogo = pogo
	reset_swing()
	monitoring = true
	monitorable = true
	_set_shapes_disabled(false)


func deactivate() -> void:
	is_active = false
	monitoring = false
	monitorable = false
	_set_shapes_disabled(true)
	reset_swing()


func _set_shapes_disabled(disabled_state: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = disabled_state
			child.set_deferred("disabled", disabled_state)
		elif child is CollisionPolygon2D:
			child.disabled = disabled_state
			child.set_deferred("disabled", disabled_state)


func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	
	# Single-hit per target guarantee: identify the logical target
	var target_entity: Node = area
	if area is HurtboxScript and area.get_parent() != null:
		target_entity = area.get_parent()
	
	if _hit_targets.has(target_entity) or _hit_targets.has(area):
		return # Already hit during this swing
	
	# Determine knockback direction
	var kb_dir: Vector2 = attack_direction
	if kb_dir.length_squared() < 0.01:
		kb_dir = (area.global_position - global_position).normalized()
	
	var hit_data = HitDataScript.new(
		damage,
		kb_dir,
		knockback_force,
		attacker if attacker != null else self,
		attack_direction,
		is_pogo
	)
	
	if area is HurtboxScript:
		if area.can_receive_hit():
			_hit_targets.append(target_entity)
			_hit_targets.append(area)
			var success: bool = area.receive_hit(hit_data)
			if success:
				hit_landed.emit(target_entity, hit_data)
				if is_pogo and not _pogo_triggered_this_swing:
					_pogo_triggered_this_swing = true
					pogo_triggered.emit(target_entity)
	elif area.is_in_group("pogo_hazard") or (area.has_method("is_pogo_hazard") and area.is_pogo_hazard()):
		_hit_targets.append(target_entity)
		_hit_targets.append(area)
		hit_landed.emit(target_entity, hit_data)
		if is_pogo and not _pogo_triggered_this_swing:
			_pogo_triggered_this_swing = true
			pogo_triggered.emit(target_entity)
