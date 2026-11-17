class_name TrainingDummy
extends CharacterBody2D

## ECLIPSE: Echoes of the Forgotten
## Responsive Training Dummy for Milestone M2 Melee Combat Verification.
## Demonstrates health tracking, damage resolution, knockback physics,
## visual hit flash feedback, and automatic defeat/respawn cycles.

const HitDataScript = preload("res://scripts/combat/hit_data.gd")
const HealthComponentScript = preload("res://scripts/combat/health_component.gd")
const HurtboxScript = preload("res://scripts/combat/hurtbox.gd")

signal dummy_damaged(damage: int, remaining_hp: int)
signal dummy_defeated()
signal dummy_respawned()

@export var max_health: int = 4
@export var respawn_delay: float = 2.0
@export var knockback_friction: float = 1400.0
@export var gravity: float = 1400.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox

var spawn_position: Vector2 = Vector2.ZERO
var is_defeated: bool = false
var respawn_timer: float = 0.0
var flash_timer: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	collision_layer = 4 # Layer 3: Enemies
	collision_mask = 1 # Layer 1: World
	spawn_position = global_position
	
	if not health_component:
		health_component = HealthComponentScript.new()
		health_component.name = "HealthComponent"
		health_component.max_health = max_health
		health_component.default_invulnerability_duration = 0.15
		add_child(health_component)
	
	health_component.max_health = max_health
	health_component.default_invulnerability_duration = 0.15
	health_component.reset_health()
	if not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)
	if not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)
	
	if hurtbox:
		hurtbox.health_component = health_component
		if not hurtbox.hit_received.is_connected(_on_hit_received):
			hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	if is_defeated:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn()
		return
	
	# Flash update
	if flash_timer > 0.0:
		flash_timer -= delta
		shake_offset = Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0)) * (flash_timer / 0.15)
	else:
		shake_offset = Vector2.ZERO
	
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = minf(velocity.y, 600.0)
	
	# Ground knockback friction / deceleration
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, (knockback_friction * 0.5) * delta)
	
	move_and_slide()
	queue_redraw()


func _on_hit_received(hit_data: RefCounted) -> void:
	if is_defeated or (health_component and health_component.current_health <= 0):
		velocity = Vector2.ZERO
		return
	
	# Apply directional knockback
	var kb_dir: Vector2 = hit_data.get("knockback_direction") if hit_data.get("knockback_direction") != null else Vector2.RIGHT
	var kb_force: float = hit_data.get("knockback_force") if hit_data.get("knockback_force") != null else 220.0
	velocity = kb_dir * kb_force
	flash_timer = 0.15


func _on_damaged(amount: int) -> void:
	dummy_damaged.emit(amount, health_component.current_health if health_component else max_health)


func _on_died() -> void:
	is_defeated = true
	respawn_timer = respawn_delay
	velocity = Vector2.ZERO
	if hurtbox:
		hurtbox.set_manual_invulnerable(true)
	dummy_defeated.emit()


func respawn() -> void:
	is_defeated = false
	respawn_timer = 0.0
	flash_timer = 0.0
	global_position = spawn_position
	velocity = Vector2.ZERO
	if health_component:
		health_component.reset_health()
	if hurtbox:
		hurtbox.set_manual_invulnerable(false)
	dummy_respawned.emit()
	queue_redraw()


func _draw() -> void:
	if is_defeated:
		var rubble_pts := PackedVector2Array([
			Vector2(-14, 0), Vector2(-8, -8), Vector2(0, -4), Vector2(10, -10), Vector2(16, 0)
		])
		draw_colored_polygon(rubble_pts, Color(0.2, 0.22, 0.26, 0.6))
		return
	
	var base_pos := shake_offset
	var is_flashing := flash_timer > 0.0
	
	var body_color: Color = Color(0.9, 0.9, 0.9, 1.0) if is_flashing else Color(0.25, 0.28, 0.35, 1.0)
	var trim_color: Color = Color(1.0, 0.4, 0.4, 1.0) if is_flashing else Color(0.38, 0.42, 0.52, 1.0)
	var core_color: Color = Color(1.0, 0.2, 0.2, 1.0) if is_flashing else Color(0.3, 0.8, 0.95, 1.0)
	
	# Pedestal
	var pedestal := PackedVector2Array([
		base_pos + Vector2(-12, 0),
		base_pos + Vector2(-10, -8),
		base_pos + Vector2(10, -8),
		base_pos + Vector2(12, 0)
	])
	draw_colored_polygon(pedestal, Color(0.15, 0.17, 0.22, 1.0))
	
	# Torso
	var torso := PackedVector2Array([
		base_pos + Vector2(-10, -8),
		base_pos + Vector2(-12, -28),
		base_pos + Vector2(-8, -44),
		base_pos + Vector2(8, -44),
		base_pos + Vector2(12, -28),
		base_pos + Vector2(10, -8)
	])
	draw_colored_polygon(torso, body_color)
	draw_polyline(torso, trim_color, 1.5)
	
	# Practice target crossbands
	draw_line(base_pos + Vector2(-8, -26), base_pos + Vector2(8, -26), trim_color, 2.0)
	draw_line(base_pos + Vector2(0, -34), base_pos + Vector2(0, -18), trim_color, 2.0)
	
	# Glowing runic core
	draw_circle(base_pos + Vector2(0, -26), 4.0, core_color)
	draw_circle(base_pos + Vector2(0, -26), 2.0, Color.WHITE)
	
	# Health pips above head
	if health_component:
		var total_pips: int = health_component.max_health
		var current_pips: int = health_component.current_health
		var bar_width: float = float(total_pips) * 6.0
		var start_x: float = base_pos.x - (bar_width * 0.5) + 3.0
		var pip_y: float = base_pos.y - 52.0
		
		for i in range(total_pips):
			var pip_color := Color(0.2, 0.85, 0.4, 0.9) if i < current_pips else Color(0.3, 0.35, 0.4, 0.4)
			draw_rect(Rect2(start_x + (float(i) * 6.0), pip_y, 4.0, 4.0), pip_color, true)
