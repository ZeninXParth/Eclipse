class_name FlyerEnemy
extends EnemyBase

## ECLIPSE: Echoes of the Forgotten
## Flyer Archetype ("Gloom Bat" / "Swooper") (Milestone 2)
## Aerial enemy with suspended gravity that bobs on a sinusoidal hover path,
## detects the player below, telegraphs an alert dive angle,
## and swoops downward in a dive arc before recovering upward to its roost altitude.
## Fully supports player downward aerial pogo bounce chains.

@export_group("Flyer Archetype Tuning")
@export var dive_speed: float = 220.0
@export var recovery_speed: float = 120.0
@export var hover_amplitude: float = 30.0
@export var hover_frequency: float = 4.0
@export var patrol_radius: float = 80.0
@export var attack_cooldown: float = 1.20

var home_position: Vector2 = Vector2.ZERO
var hover_time: float = 0.0
var dive_target: Vector2 = Vector2.ZERO
var dive_direction: Vector2 = Vector2.DOWN
var swoop_phase: int = 0 # 0: Diving downward, 1: Climbing upward
var swoop_timer: float = 0.0


func _init() -> void:
	max_health = 2
	patrol_speed = 40.0
	contact_damage = 1
	contact_knockback_force = 200.0
	knockback_resistance = 0.0
	detection_range = 180.0
	lose_interest_range = 280.0
	alert_duration = 0.35
	hurt_duration = 0.20
	gravity = 0.0 # Suspended gravity for aerial unit


func _ready() -> void:
	super._ready()
	home_position = global_position
	# Tune hurtbox & hitbox for aerial flyer shape
	if hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:
		(hurtbox_shape.shape as CapsuleShape2D).radius = 14.0
		(hurtbox_shape.shape as CapsuleShape2D).height = 28.0
		hurtbox_shape.position = Vector2(0.0, -10.0)
	if hitbox_shape and hitbox_shape.shape is CapsuleShape2D:
		(hitbox_shape.shape as CapsuleShape2D).radius = 12.0
		(hitbox_shape.shape as CapsuleShape2D).height = 24.0
		hitbox_shape.position = Vector2(0.0, -10.0)


func respawn() -> void:
	swoop_phase = 0
	swoop_timer = 0.0
	hover_time = 0.0
	super.respawn()


func _handle_patrol(delta: float) -> void:
	hover_time += delta * hover_frequency
	
	# Vertical roost altitude recovery vs sinusoidal hover bobbing
	var alt_diff := home_position.y - global_position.y
	if absf(alt_diff) > 12.0:
		velocity.y = move_toward(velocity.y, signf(alt_diff) * recovery_speed, 400.0 * delta)
	else:
		velocity.y = sin(hover_time) * hover_amplitude
	
	# Horizontal patrol drift
	velocity.x = float(facing_direction) * patrol_speed
	
	# Turn around if drifted past patrol radius from home position
	var dist_from_home_x := global_position.x - home_position.x
	if absf(dist_from_home_x) > patrol_radius:
		facing_direction = -1 if dist_from_home_x > 0 else 1
		velocity.x = float(facing_direction) * patrol_speed
	
	# Wall turnaround
	if has_wall_ahead():
		turn_around()
		velocity.x = float(facing_direction) * patrol_speed
	
	# Target detection: looks for player below
	var target := find_player_target()
	if target != null:
		var dist := global_position.distance_to(target.global_position)
		var is_below := target.global_position.y > (global_position.y - 20.0)
		
		if dist <= detection_range and is_below:
			velocity = Vector2.ZERO
			dive_target = target.global_position
			state_timer = alert_duration
			_set_state(EnemyState.ALERT)
			telegraph_started.emit(alert_duration)


func _handle_alert(delta: float) -> void:
	# Subtle shivering hover in place
	hover_time += delta * 12.0
	velocity = Vector2(sin(hover_time) * 10.0, 0.0)
	state_timer -= delta
	
	# Update target coordinates until dive initiates
	var target := find_player_target()
	if target != null:
		dive_target = target.global_position
		facing_direction = 1 if dive_target.x > global_position.x else -1
	
	if state_timer <= 0.0:
		# Initiate dive
		dive_direction = (dive_target - global_position).normalized()
		if dive_direction.length_squared() < 0.1:
			dive_direction = Vector2.DOWN
		
		velocity = dive_direction * dive_speed
		swoop_phase = 0
		swoop_timer = 0.55
		
		if hitbox:
			hitbox.activate(dive_direction)
		
		_set_state(EnemyState.ATTACK)
		attack_performed.emit()


func _handle_attack(delta: float) -> void:
	swoop_timer -= delta
	
	if swoop_phase == 0:
		# Diving downward toward player
		velocity = dive_direction * dive_speed
		
		# Check if dive has reached or passed dive target altitude, or timer expired
		var reached_depth: bool = global_position.y >= dive_target.y
		if reached_depth or swoop_timer <= 0.0:
			swoop_phase = 1
			if hitbox:
				hitbox.deactivate()
			swoop_timer = 1.0
	else:
		# Climbing back up toward home altitude
		velocity.x = float(facing_direction) * patrol_speed
		velocity.y = move_toward(velocity.y, -recovery_speed, 500.0 * delta)
		
		if global_position.y <= home_position.y or swoop_timer <= 0.0:
			velocity = Vector2.ZERO
			state_timer = attack_cooldown
			_set_state(EnemyState.IDLE)


func _draw() -> void:
	var base_pos := shake_offset
	var is_flashing := flash_timer > 0.0
	
	if is_dead:
		var ash := PackedVector2Array([
			base_pos + Vector2(-8, 0),
			base_pos + Vector2(0, -6),
			base_pos + Vector2(8, 0)
		])
		draw_colored_polygon(ash, Color(0.2, 0.22, 0.26, 0.5))
		return
	
	var body_color := Color.WHITE if is_flashing else Color(0.14, 0.16, 0.22, 1.0)
	var wing_color := Color(1.0, 0.35, 0.35, 1.0) if is_flashing else Color(0.25, 0.30, 0.40, 1.0)
	var eye_color := Color.WHITE if is_flashing else (Color(1.0, 0.2, 0.2, 1.0) if current_state == EnemyState.ALERT or current_state == EnemyState.ATTACK else Color(0.4, 0.8, 1.0, 1.0))
	
	var wing_flap := sin(hover_time * 2.0) * 8.0
	if current_state == EnemyState.ATTACK:
		wing_flap = -10.0 # Wings pinned back during dive
	
	# Left Wing
	var left_wing := PackedVector2Array([
		base_pos + Vector2(-4, -10),
		base_pos + Vector2(-18, -20 + wing_flap),
		base_pos + Vector2(-12, -4 + wing_flap * 0.5),
		base_pos + Vector2(-4, -6)
	])
	draw_colored_polygon(left_wing, wing_color)
	
	# Right Wing
	var right_wing := PackedVector2Array([
		base_pos + Vector2(4, -10),
		base_pos + Vector2(18, -20 + wing_flap),
		base_pos + Vector2(12, -4 + wing_flap * 0.5),
		base_pos + Vector2(4, -6)
	])
	draw_colored_polygon(right_wing, wing_color)
	
	# Central Body
	var body := PackedVector2Array([
		base_pos + Vector2(0, -22),
		base_pos + Vector2(-7, -12),
		base_pos + Vector2(0, 0),
		base_pos + Vector2(7, -12)
	])
	draw_colored_polygon(body, body_color)
	
	# Eyes
	var facing := float(facing_direction)
	draw_circle(base_pos + Vector2(2 * facing, -14), 2.2, eye_color)
