class_name GroundShockwave
extends HazardZone

## ECLIPSE: Echoes of the Forgotten
## Milestone 4: Ground Shockwave Hazard
## Traveling ground hazard emitted when the Archive Warden slams the arena floor.
## Travels horizontally along the ground runway, dealing contact damage to grounded players.
## Airborne players can leap over it or down-slash to execute a pogo bounce.

signal dissipated()

@export_group("Shockwave Tuning")
@export var speed: float = 260.0
@export var direction: float = 1.0 # 1.0 = right, -1.0 = left
@export var lifetime: float = 2.5
@export var max_distance: float = 900.0
@export var shockwave_width: float = 32.0
@export var shockwave_height: float = 36.0

var distance_traveled: float = 0.0
var age: float = 0.0
var collision_shape: CollisionShape2D

const COLOR_SHOCK_BASE = Color(0.12, 0.14, 0.20, 0.95)
const COLOR_CYAN_CREST = Color(0.35, 0.90, 1.0, 0.95)
const COLOR_PURPLE_AURA = Color(0.75, 0.20, 0.95, 0.85)
const COLOR_WHITE_CORE = Color(0.95, 0.98, 1.0, 0.95)


func _ready() -> void:
	super._ready()
	allows_pogo = true
	knockback_force = 280.0
	
	_setup_collision()


func _setup_collision() -> void:
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(shockwave_width, shockwave_height)
		collision_shape.shape = rect
		collision_shape.position = Vector2(0.0, -shockwave_height * 0.5)
		add_child(collision_shape)
	elif collision_shape.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(shockwave_width, shockwave_height)
		collision_shape.shape = rect
		collision_shape.position = Vector2(0.0, -shockwave_height * 0.5)


func step_shockwave(delta: float) -> void:
	age += delta
	var move_dist := speed * delta
	global_position.x += direction * move_dist
	distance_traveled += move_dist
	
	if age >= lifetime or distance_traveled >= max_distance:
		dissipate()
		return
	
	# Detect collision with solid walls or closed arena gates (Layer 1: World)
	if is_inside_tree():
		var space := get_world_2d().direct_space_state
		var ray_origin := Vector2(global_position.x, global_position.y - 12.0)
		var ray_target := Vector2(global_position.x + direction * 16.0, global_position.y - 12.0)
		var q := PhysicsRayQueryParameters2D.create(ray_origin, ray_target, 1)
		var col := space.intersect_ray(q)
		if not col.is_empty():
			dissipate()
			return
	
	queue_redraw()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	step_shockwave(delta)


func dissipate() -> void:
	dissipated.emit()
	queue_free()


func _draw() -> void:
	var half_w := shockwave_width * 0.5
	var h := shockwave_height
	var dir_sign := signf(direction) if direction != 0.0 else 1.0
	
	# Jagged ground fracture / energy crest polygon
	# Slanted in direction of motion
	var lead_x := half_w * dir_sign
	var trail_x := -half_w * dir_sign
	
	# Outer purple arcane wave
	var outer_poly := PackedVector2Array([
		Vector2(trail_x * 1.2, 0.0),
		Vector2(trail_x * 0.5, -h * 0.7),
		Vector2(lead_x * 0.3, -h * 1.1),
		Vector2(lead_x * 1.1, -h * 0.5),
		Vector2(lead_x * 1.3, 0.0)
	])
	draw_polygon(outer_poly, [COLOR_PURPLE_AURA])
	
	# Core celestial cyan crest
	var inner_poly := PackedVector2Array([
		Vector2(trail_x * 0.9, 0.0),
		Vector2(trail_x * 0.3, -h * 0.6),
		Vector2(lead_x * 0.2, -h * 0.95),
		Vector2(lead_x * 0.9, -h * 0.4),
		Vector2(lead_x * 1.0, 0.0)
	])
	draw_polygon(inner_poly, [COLOR_CYAN_CREST])
	
	# Hot white leading edge spike
	draw_line(Vector2(trail_x * 0.2, -h * 0.6), Vector2(lead_x * 0.2, -h * 0.95), COLOR_WHITE_CORE, 2.5)
	draw_line(Vector2(lead_x * 0.2, -h * 0.95), Vector2(lead_x * 0.9, -h * 0.4), COLOR_WHITE_CORE, 2.0)
	
	# Base ground crack
	draw_line(Vector2(-half_w - 6.0, 0.0), Vector2(half_w + 6.0, 0.0), COLOR_SHOCK_BASE, 3.0)
