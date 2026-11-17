class_name WalkerEnemy
extends EnemyBase

## ECLIPSE: Echoes of the Forgotten
## Walker Archetype ("Scavenger Husk") (Milestone 2)
## Ground patrol enemy that detects ledges and walls to turn around,
## spots player within forward line of sight, telegraphs an alert stance,
## and executes a forward melee lunge with an active hitbox.

@export_group("Walker Archetype Tuning")
@export var lunge_speed: float = 180.0
@export var lunge_duration: float = 0.35
@export var recovery_duration: float = 0.40
@export var attack_range: float = 120.0

var attack_timer: float = 0.0
var walk_cycle: float = 0.0


func _init() -> void:
	max_health = 3
	patrol_speed = 50.0
	contact_damage = 1
	contact_knockback_force = 220.0
	knockback_resistance = 0.0
	detection_range = 140.0
	lose_interest_range = 220.0
	alert_duration = 0.30
	hurt_duration = 0.20


func respawn() -> void:
	attack_timer = 0.0
	walk_cycle = 0.0
	super.respawn()


func _handle_patrol(delta: float) -> void:
	walk_cycle += delta * 6.0
	
	# Patrol forward
	velocity.x = float(facing_direction) * patrol_speed
	
	# Ledge / wall turnaround
	if has_edge_ahead() or has_wall_ahead():
		turn_around()
		velocity.x = float(facing_direction) * patrol_speed
	
	# Player detection check
	var target := find_player_target()
	if target != null:
		var dist := global_position.distance_to(target.global_position)
		var forward_dot := (target.global_position.x - global_position.x) * float(facing_direction)
		var height_diff := absf(target.global_position.y - global_position.y)
		
		# Detect if player is in front, within range, and roughly same elevation
		if dist <= detection_range and forward_dot > -10.0 and height_diff < 70.0:
			velocity.x = 0.0
			state_timer = alert_duration
			_set_state(EnemyState.ALERT)
			telegraph_started.emit(alert_duration)


func _handle_alert(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	state_timer -= delta
	
	# Track player facing during alert
	var target := find_player_target()
	if target != null:
		var dir_x := target.global_position.x - global_position.x
		if absf(dir_x) > 10.0:
			facing_direction = 1 if dir_x > 0 else -1
	
	if state_timer <= 0.0:
		# Transition to lunge attack
		attack_timer = lunge_duration
		velocity.x = float(facing_direction) * lunge_speed
		if hitbox:
			hitbox.activate(Vector2(float(facing_direction), 0.0))
		_set_state(EnemyState.ATTACK)
		attack_performed.emit()


func _handle_attack(delta: float) -> void:
	attack_timer -= delta
	velocity.x = float(facing_direction) * lunge_speed
	
	if attack_timer <= 0.0:
		if hitbox:
			hitbox.deactivate()
		state_timer = recovery_duration
		_set_state(EnemyState.IDLE)


func _draw() -> void:
	var base_pos := shake_offset
	var is_flashing := flash_timer > 0.0
	
	if is_dead:
		var rubble := PackedVector2Array([
			base_pos + Vector2(-12, 0),
			base_pos + Vector2(-8, -6),
			base_pos + Vector2(2, -4),
			base_pos + Vector2(10, -8),
			base_pos + Vector2(14, 0)
		])
		draw_colored_polygon(rubble, Color(0.2, 0.22, 0.26, 0.6))
		return
	
	var body_color := Color.WHITE if is_flashing else Color(0.16, 0.18, 0.24, 1.0)
	var trim_color := Color(1.0, 0.3, 0.3, 1.0) if is_flashing else Color(0.28, 0.32, 0.42, 1.0)
	var eye_color := Color.WHITE if is_flashing else (Color(1.0, 0.2, 0.2, 1.0) if current_state == EnemyState.ALERT or current_state == EnemyState.ATTACK else Color(0.9, 0.5, 0.3, 1.0))
	
	var facing := float(facing_direction)
	var leg_bob := sin(walk_cycle) * 3.0 if current_state == EnemyState.PATROL else 0.0
	
	# Legs
	draw_line(base_pos + Vector2(-6 * facing, -12), base_pos + Vector2(-8 * facing, 0 + leg_bob), trim_color, 2.5)
	draw_line(base_pos + Vector2(6 * facing, -12), base_pos + Vector2(8 * facing, 0 - leg_bob), trim_color, 2.5)
	
	# Torso / Chitin Husk
	var torso := PackedVector2Array([
		base_pos + Vector2(-10 * facing, -10),
		base_pos + Vector2(-12 * facing, -26),
		base_pos + Vector2(-6 * facing, -36),
		base_pos + Vector2(6 * facing, -36),
		base_pos + Vector2(12 * facing, -24),
		base_pos + Vector2(8 * facing, -10)
	])
	draw_colored_polygon(torso, body_color)
	
	# Claws / Scythe Arms
	var claw_reach := 18.0 if current_state == EnemyState.ATTACK else (10.0 if current_state == EnemyState.ALERT else 4.0)
	var claw_y := -24.0 if current_state == EnemyState.ATTACK else (-30.0 if current_state == EnemyState.ALERT else -20.0)
	draw_line(base_pos + Vector2(4 * facing, -24), base_pos + Vector2((6 + claw_reach) * facing, claw_y), trim_color, 3.0)
	draw_line(base_pos + Vector2((6 + claw_reach) * facing, claw_y), base_pos + Vector2((10 + claw_reach) * facing, claw_y + 10), trim_color, 2.0)
	
	# Glowing Eye
	var eye_pos := base_pos + Vector2(6 * facing, -30)
	draw_circle(eye_pos, 2.5 if current_state == EnemyState.ALERT else 2.0, eye_color)
