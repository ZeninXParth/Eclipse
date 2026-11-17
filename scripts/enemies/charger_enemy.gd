class_name ChargerEnemy
extends EnemyBase

## ECLIPSE: Echoes of the Forgotten
## Charger Archetype ("Armored Beetle") (Milestone 2)
## Heavy ground enemy with 50% knockback resistance.
## Patrols slowly, spots player in forward line of sight,
## telegraphs with a wind-up roar / ground-scrape alert stance,
## and accelerates into a rapid horizontal charge.
## Slamming into a solid wall triggers a vulnerable Wall-Stun state.
## Can be safely leaped over and pogo-bounced on its armored back.

signal wall_slammed()

@export_group("Charger Archetype Tuning")
@export var charge_speed: float = 280.0
@export var charge_max_duration: float = 1.60
@export var wall_stun_duration: float = 0.70
@export var rest_duration: float = 0.50

var charge_timer: float = 0.0
var is_wall_stunned: bool = false
var walk_cycle: float = 0.0


func _init() -> void:
	max_health = 6
	patrol_speed = 35.0
	contact_damage = 2
	contact_knockback_force = 280.0
	knockback_resistance = 0.50 # Absorbs 50% of knockback
	detection_range = 200.0
	lose_interest_range = 300.0
	alert_duration = 0.45
	hurt_duration = 0.15


func _ready() -> void:
	super._ready()
	# Tune hurtbox & hitbox for wide heavy beetle shape
	if hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:
		(hurtbox_shape.shape as CapsuleShape2D).radius = 16.0
		(hurtbox_shape.shape as CapsuleShape2D).height = 44.0
		hurtbox_shape.position = Vector2(0.0, -18.0)
	if hitbox_shape and hitbox_shape.shape is CapsuleShape2D:
		(hitbox_shape.shape as CapsuleShape2D).radius = 18.0
		(hitbox_shape.shape as CapsuleShape2D).height = 46.0
		hitbox_shape.position = Vector2(0.0, -18.0)


func respawn() -> void:
	is_wall_stunned = false
	charge_timer = 0.0
	super.respawn()


func _handle_patrol(delta: float) -> void:
	walk_cycle += delta * 4.0
	is_wall_stunned = false
	
	velocity.x = float(facing_direction) * patrol_speed
	
	# Turn around on edge or wall
	if has_edge_ahead() or has_wall_ahead():
		turn_around()
		velocity.x = float(facing_direction) * patrol_speed
	
	# Player detection in front
	var target := find_player_target()
	if target != null:
		var dist := global_position.distance_to(target.global_position)
		var forward_dot := (target.global_position.x - global_position.x) * float(facing_direction)
		var height_diff := absf(target.global_position.y - global_position.y)
		
		if dist <= detection_range and forward_dot > -10.0 and height_diff < 50.0:
			velocity.x = 0.0
			state_timer = alert_duration
			_set_state(EnemyState.ALERT)
			telegraph_started.emit(alert_duration)


func _handle_alert(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	state_timer -= delta
	
	# Scrape legs and vibrate in place
	walk_cycle += delta * 20.0
	
	# Re-check facing direction before charge
	var target := find_player_target()
	if target != null:
		var dir_x := target.global_position.x - global_position.x
		if absf(dir_x) > 10.0:
			facing_direction = 1 if dir_x > 0 else -1
	
	if state_timer <= 0.0:
		# Unleash furious charge!
		charge_timer = charge_max_duration
		velocity.x = float(facing_direction) * charge_speed
		if hitbox:
			hitbox.activate(Vector2(float(facing_direction), 0.0))
		_set_state(EnemyState.ATTACK)
		attack_performed.emit()


func _handle_attack(delta: float) -> void:
	charge_timer -= delta
	velocity.x = float(facing_direction) * charge_speed
	
	# Check for solid wall impact during charge
	if has_wall_ahead():
		if hitbox:
			hitbox.deactivate()
		# Rebound recoil slightly
		velocity = Vector2(-float(facing_direction) * 90.0, -90.0)
		is_wall_stunned = true
		state_timer = wall_stun_duration
		wall_slammed.emit()
		turn_around() # Face away from wall
		_set_state(EnemyState.IDLE)
		return
	
	# Charge duration expired
	if charge_timer <= 0.0:
		if hitbox:
			hitbox.deactivate()
		state_timer = rest_duration
		_set_state(EnemyState.IDLE)


func _draw() -> void:
	var base_pos := shake_offset
	var is_flashing := flash_timer > 0.0
	
	if is_dead:
		var shell := PackedVector2Array([
			base_pos + Vector2(-16, 0),
			base_pos + Vector2(-10, -12),
			base_pos + Vector2(10, -12),
			base_pos + Vector2(16, 0)
		])
		draw_colored_polygon(shell, Color(0.2, 0.22, 0.25, 0.6))
		return
	
	var shell_color := Color.WHITE if is_flashing else Color(0.12, 0.15, 0.20, 1.0)
	var plate_color := Color(1.0, 0.4, 0.4, 1.0) if is_flashing else Color(0.28, 0.34, 0.44, 1.0)
	var horn_color := Color.WHITE if is_flashing else (Color(1.0, 0.2, 0.2, 1.0) if current_state == EnemyState.ALERT or current_state == EnemyState.ATTACK else Color(0.4, 0.5, 0.65, 1.0))
	var eye_color := Color.WHITE if is_flashing else (Color(1.0, 0.2, 0.2, 1.0) if current_state == EnemyState.ALERT or current_state == EnemyState.ATTACK else Color(0.9, 0.6, 0.2, 1.0))
	
	var facing := float(facing_direction)
	var leg_bob := sin(walk_cycle) * 2.5
	
	# 4 Sturdy Legs
	draw_line(base_pos + Vector2(-12 * facing, -10), base_pos + Vector2(-14 * facing, 0 + leg_bob), plate_color, 3.5)
	draw_line(base_pos + Vector2(-4 * facing, -10), base_pos + Vector2(-6 * facing, 0 - leg_bob), plate_color, 3.5)
	draw_line(base_pos + Vector2(4 * facing, -10), base_pos + Vector2(6 * facing, 0 + leg_bob), plate_color, 3.5)
	draw_line(base_pos + Vector2(12 * facing, -10), base_pos + Vector2(14 * facing, 0 - leg_bob), plate_color, 3.5)
	
	# Heavy Armored Carapace Body
	var carapace := PackedVector2Array([
		base_pos + Vector2(-16 * facing, -6),
		base_pos + Vector2(-18 * facing, -20),
		base_pos + Vector2(-8 * facing, -30),
		base_pos + Vector2(10 * facing, -28),
		base_pos + Vector2(18 * facing, -16),
		base_pos + Vector2(14 * facing, -6)
	])
	draw_colored_polygon(carapace, shell_color)
	
	# Carapace Armor Rim Plate
	var plate_rim := PackedVector2Array([
		base_pos + Vector2(-14 * facing, -18),
		base_pos + Vector2(-6 * facing, -26),
		base_pos + Vector2(8 * facing, -24),
		base_pos + Vector2(14 * facing, -14)
	])
	draw_polyline(plate_rim, plate_color, 2.5)
	
	# Massive Forward Horn
	var horn := PackedVector2Array([
		base_pos + Vector2(12 * facing, -20),
		base_pos + Vector2(24 * facing, -28),
		base_pos + Vector2(22 * facing, -16),
		base_pos + Vector2(14 * facing, -12)
	])
	draw_colored_polygon(horn, horn_color)
	
	# Eye
	draw_circle(base_pos + Vector2(12 * facing, -18), 2.5, eye_color)
	
	# Stun stars if wall stunned
	if is_wall_stunned and current_state == EnemyState.IDLE:
		for k in range(3):
			var star_angle := Time.get_ticks_msec() * 0.005 + (k * TAU / 3.0)
			var star_pos := base_pos + Vector2(cos(star_angle) * 14.0, -38.0 + sin(star_angle) * 4.0)
			draw_circle(star_pos, 2.0, Color(1.0, 0.9, 0.3, 0.9))
