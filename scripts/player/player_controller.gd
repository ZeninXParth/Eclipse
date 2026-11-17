class_name PlayerController
extends CharacterBody2D

## ECLIPSE: Echoes of the Forgotten
## Player Character Controller (Milestones M1 & M2)
## Handles horizontal locomotion, jump physics, coyote time, jump buffering,
## wall slide, wall jump, horizontal dash, directional melee combat, hitboxes/hurtboxes,
## hit-stop frame freeze, camera shake, i-frames, and pogo rebound mechanics.

const HitDataScript = preload("res://scripts/combat/hit_data.gd")
const HealthComponentScript = preload("res://scripts/combat/health_component.gd")
const HurtboxScript = preload("res://scripts/combat/hurtbox.gd")
const HitboxScript = preload("res://scripts/combat/hitbox.gd")
const PlayerConfigScript = preload("res://scripts/player/player_config.gd")

signal state_changed(new_state: State, previous_state: State)
signal jumped()
signal landed()
signal wall_slid()
signal wall_jumped()
signal dashed(direction: Vector2)
signal hit_stop_triggered(duration: float)
signal screen_shake_requested(intensity: float, duration: float)
signal attack_initiated(direction: AttackDirection)
signal attack_active(direction: AttackDirection)
signal attack_recovered()
signal pogo_bounced()
signal player_damaged(damage: int, remaining_health: int)
signal player_died()
signal soul_changed(current_soul: int, max_soul: int)
signal focus_started()
signal focus_charged(progress: float)
signal focus_completed()
signal focus_interrupted()
signal double_jumped()
signal mantled()
signal mantle_completed()

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	LAND,
	WALL_SLIDE,
	WALL_JUMP,
	DASH,
	FOCUS,
	MANTLE
}

enum AttackState {
	NONE,
	STARTUP,
	ACTIVE,
	RECOVERY
}

enum AttackDirection {
	FORWARD,
	UP,
	DOWN
}

# --- Data Configuration ---
@export var config: Resource

# --- Tunable Movement Parameter Properties (Delegated to PlayerConfig for live tuning) ---
var max_speed: float:
	get: return config.max_speed if config else 260.0
	set(v):
		if config: config.max_speed = v

var ground_acceleration: float:
	get: return config.ground_acceleration if config else 2000.0
	set(v):
		if config: config.ground_acceleration = v

var ground_deceleration: float:
	get: return config.ground_deceleration if config else 2400.0
	set(v):
		if config: config.ground_deceleration = v

var air_acceleration: float:
	get: return config.air_acceleration if config else 1400.0
	set(v):
		if config: config.air_acceleration = v

var air_deceleration: float:
	get: return config.air_deceleration if config else 900.0
	set(v):
		if config: config.air_deceleration = v

var jump_height: float:
	get: return config.jump_height if config else 96.0
	set(v):
		if config: config.jump_height = v

var time_to_peak: float:
	get: return config.time_to_peak if config else 0.34
	set(v):
		if config: config.time_to_peak = v

var fall_gravity_multiplier: float:
	get: return config.fall_gravity_multiplier if config else 1.35
	set(v):
		if config: config.fall_gravity_multiplier = v

var variable_jump_cutoff: float:
	get: return config.variable_jump_cutoff if config else 0.5
	set(v):
		if config: config.variable_jump_cutoff = v

var max_fall_speed: float:
	get: return config.max_fall_speed if config else 650.0
	set(v):
		if config: config.max_fall_speed = v

var coyote_duration: float:
	get: return config.coyote_duration if config else 0.12
	set(v):
		if config: config.coyote_duration = v

var jump_buffer_duration: float:
	get: return config.jump_buffer_duration if config else 0.12
	set(v):
		if config: config.jump_buffer_duration = v

var land_duration: float:
	get: return config.land_duration if config else 0.08
	set(v):
		if config: config.land_duration = v

var wall_slide_speed: float:
	get: return config.wall_slide_speed if config else 120.0
	set(v):
		if config: config.wall_slide_speed = v

var wall_jump_velocity: Vector2:
	get: return config.wall_jump_velocity if config else Vector2(300.0, -480.0)
	set(v):
		if config: config.wall_jump_velocity = v

var wall_jump_coyote_duration: float:
	get: return config.wall_jump_coyote_duration if config else 0.12
	set(v):
		if config: config.wall_jump_coyote_duration = v

var wall_jump_input_lock_duration: float:
	get: return config.wall_jump_input_lock_duration if config else 0.12
	set(v):
		if config: config.wall_jump_input_lock_duration = v

var dash_speed: float:
	get: return config.dash_speed if config else 550.0
	set(v):
		if config: config.dash_speed = v

var dash_duration: float:
	get: return config.dash_duration if config else 0.16
	set(v):
		if config: config.dash_duration = v

var dash_cooldown: float:
	get: return config.dash_cooldown if config else 0.40
	set(v):
		if config: config.dash_cooldown = v

var max_air_dashes: int:
	get: return config.max_air_dashes if config else 1
	set(v):
		if config: config.max_air_dashes = v

var attack_damage: int:
	get: return config.attack_damage if config else 1
	set(v):
		if config: config.attack_damage = v

var attack_knockback_force: float:
	get: return config.attack_knockback_force if config else 240.0
	set(v):
		if config: config.attack_knockback_force = v

var attack_startup_duration: float:
	get: return config.attack_startup_duration if config else 0.05
	set(v):
		if config: config.attack_startup_duration = v

var attack_active_duration: float:
	get: return config.attack_active_duration if config else 0.07
	set(v):
		if config: config.attack_active_duration = v

var attack_recovery_duration: float:
	get: return config.attack_recovery_duration if config else 0.10
	set(v):
		if config: config.attack_recovery_duration = v

var attack_buffer_duration: float:
	get: return config.attack_buffer_duration if config else 0.10
	set(v):
		if config: config.attack_buffer_duration = v

var pogo_bounce_velocity: float:
	get: return config.pogo_bounce_velocity if config else -460.0
	set(v):
		if config: config.pogo_bounce_velocity = v

var max_health: int:
	get: return config.max_health if config else 5
	set(v):
		if config: config.max_health = v

var hurt_knockback_speed: float:
	get: return config.hurt_knockback_speed if config else 220.0
	set(v):
		if config: config.hurt_knockback_speed = v

var knockback_stun_duration: float:
	get: return config.knockback_stun_duration if config else 0.15
	set(v):
		if config: config.knockback_stun_duration = v

var hit_stop_duration: float:
	get: return config.hit_stop_duration if config else 0.06
	set(v):
		if config: config.hit_stop_duration = v

var screen_shake_intensity: float:
	get: return config.screen_shake_intensity if config else 6.0
	set(v):
		if config: config.screen_shake_intensity = v

var screen_shake_duration: float:
	get: return config.screen_shake_duration if config else 0.20
	set(v):
		if config: config.screen_shake_duration = v

var max_soul: int:
	get: return config.max_soul if config else 99
	set(v):
		if config: config.max_soul = v

var soul_per_hit: int:
	get: return config.soul_per_hit if config else 11
	set(v):
		if config: config.soul_per_hit = v

var soul_heal_cost: int:
	get: return config.soul_heal_cost if config else 33
	set(v):
		if config: config.soul_heal_cost = v

var focus_charge_duration: float:
	get: return config.focus_charge_duration if config else 0.85
	set(v):
		if config: config.focus_charge_duration = v

var double_jump_velocity: float:
	get: return config.double_jump_velocity if config else -460.0
	set(v):
		if config: config.double_jump_velocity = v

var mantle_reach_distance: float:
	get: return config.mantle_reach_distance if config else 24.0
	set(v):
		if config: config.mantle_reach_distance = v

var mantle_climb_duration: float:
	get: return config.mantle_climb_duration if config else 0.20
	set(v):
		if config: config.mantle_climb_duration = v

var mantle_pull_offset: Vector2:
	get: return config.mantle_pull_offset if config else Vector2(20.0, -32.0)
	set(v):
		if config: config.mantle_pull_offset = v

# --- Progression & Ability Gating Flags ---
@export_group("Ability Gating")
@export var double_jump_unlocked: bool = false
@export var mantle_unlocked: bool = false
@export var dash_unlocked: bool = true
@export var wall_jump_unlocked: bool = true

# --- Node References ---
@export_group("Internal References")
@export var visuals_node: Node2D
@export var collision_shape: CollisionShape2D
@export var health_component: HealthComponent
@export var hitbox: Hitbox
@export var hitbox_shape: CollisionShape2D
@export var hurtbox: Hurtbox
@export var hurtbox_shape: CollisionShape2D

# --- Runtime Variables ---
var current_state: State = State.IDLE
var current_attack_state: AttackState = AttackState.NONE
var current_attack_direction: AttackDirection = AttackDirection.FORWARD
var facing_direction: int = 1 # 1: right, -1: left
var spawn_position: Vector2 = Vector2.ZERO

var jump_velocity: float = 0.0
var jump_gravity: float = 0.0
var fall_gravity: float = 0.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var attack_buffer_timer: float = 0.0
var land_timer: float = 0.0
var attack_timer: float = 0.0
var knockback_timer: float = 0.0
var is_jumping: bool = false
var has_pogo_bounced: bool = false
var can_double_jump: bool = false
var is_double_jumping: bool = false
var mantle_timer: float = 0.0
var mantle_wall_normal: Vector2 = Vector2.ZERO

# Wall & Dash runtime timers
var wall_coyote_timer: float = 0.0
var wall_input_lock_timer: float = 0.0
var last_wall_normal: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var air_dashes_remaining: int = 1
var dash_direction: Vector2 = Vector2.ZERO
var hit_stop_timer: float = 0.0
var current_soul: int = 0
var focus_timer: float = 0.0
var _last_jump_pressed_this_frame: bool = false
var _last_dash_pressed_this_frame: bool = false
var input_locked: bool = false

# External input override for automated testing
var input_override_enabled: bool = false
var simulated_move_axis: float = 0.0
var simulated_jump_pressed: bool = false
var simulated_jump_released: bool = false
var simulated_jump_held: bool = false
var simulated_attack_pressed: bool = false
var simulated_dash_pressed: bool = false
var simulated_focus_pressed: bool = false
var simulated_focus_held: bool = false
var simulated_move_up: bool = false
var simulated_move_down: bool = false
var simulated_on_floor_override: bool = false
var simulated_on_floor: bool = false
var simulated_on_wall_override: bool = false
var simulated_on_wall: bool = false
var simulated_wall_normal: Vector2 = Vector2.LEFT
var simulated_mantle_detected: bool = false


func _init() -> void:
	if config == null:
		config = PlayerConfigScript.new()


func _is_grounded() -> bool:
	if input_override_enabled and simulated_on_floor_override:
		return simulated_on_floor
	return is_on_floor()


func _is_wall_contact() -> bool:
	if input_override_enabled and simulated_on_wall_override:
		return simulated_on_wall
	return is_on_wall()


func _get_wall_normal_vector() -> Vector2:
	if input_override_enabled and simulated_on_wall_override:
		return simulated_wall_normal
	return get_wall_normal()


func _ready() -> void:
	if config == null:
		config = PlayerConfigScript.new()
	spawn_position = global_position
	recalculate_physics_constants()
	_initialize_combat_nodes()
	_update_visual_facing()


func _initialize_combat_nodes() -> void:
	# Ensure HealthComponent is present
	if health_component == null:
		health_component = get_node_or_null("HealthComponent") as HealthComponent
		if health_component == null:
			health_component = HealthComponentScript.new()
			health_component.name = "HealthComponent"
			health_component.max_health = max_health
			health_component.default_invulnerability_duration = 1.0
			add_child(health_component)
	
	health_component.max_health = max_health
	health_component.default_invulnerability_duration = 1.0
	if not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)
	if not health_component.damaged.is_connected(_on_health_damaged):
		health_component.damaged.connect(_on_health_damaged)
	
	# Ensure Hurtbox is present
	if hurtbox == null:
		hurtbox = get_node_or_null("Hurtbox") as Hurtbox
		if hurtbox == null:
			hurtbox = HurtboxScript.new()
			hurtbox.name = "Hurtbox"
			hurtbox.is_player_hurtbox = true
			var h_col := CollisionShape2D.new()
			var h_cap := CapsuleShape2D.new()
			h_cap.radius = 11.0
			h_cap.height = 40.0
			h_col.shape = h_cap
			h_col.position = Vector2(0, -20)
			hurtbox.add_child(h_col)
			hurtbox_shape = h_col
			add_child(hurtbox)
		else:
			hurtbox_shape = hurtbox.get_node_or_null("CollisionShape2D")
	
	hurtbox.health_component = health_component
	hurtbox.is_player_hurtbox = true
	if not hurtbox.hit_received.is_connected(_on_hurtbox_hit_received):
		hurtbox.hit_received.connect(_on_hurtbox_hit_received)
	
	# Ensure Hitbox is present
	if hitbox == null:
		hitbox = get_node_or_null("Hitbox") as Hitbox
		if hitbox == null:
			hitbox = HitboxScript.new()
			hitbox.name = "Hitbox"
			hitbox.is_player_hitbox = true
			var hb_col := CollisionShape2D.new()
			var hb_rect := RectangleShape2D.new()
			hb_rect.size = Vector2(36.0, 30.0)
			hb_col.shape = hb_rect
			hb_col.position = Vector2(26.0, -20.0)
			hb_col.disabled = true
			hitbox.add_child(hb_col)
			hitbox_shape = hb_col
			add_child(hitbox)
		else:
			hitbox_shape = hitbox.get_node_or_null("CollisionShape2D")
	
	hitbox.is_player_hitbox = true
	hitbox.attacker = self
	hitbox.damage = attack_damage
	hitbox.knockback_force = attack_knockback_force
	if not hitbox.pogo_triggered.is_connected(_on_pogo_triggered):
		hitbox.pogo_triggered.connect(_on_pogo_triggered)
	if not hitbox.hit_landed.is_connected(_on_hit_landed):
		hitbox.hit_landed.connect(_on_hit_landed)
	hitbox.deactivate()


func recalculate_physics_constants() -> void:
	jump_gravity = (2.0 * jump_height) / (time_to_peak * time_to_peak)
	jump_velocity = -jump_gravity * time_to_peak
	fall_gravity = jump_gravity * fall_gravity_multiplier


func _physics_process(delta: float) -> void:
	# Hit-stop freeze frame processing
	if hit_stop_timer > 0.0:
		hit_stop_timer = maxf(0.0, hit_stop_timer - delta)
		return
	
	_handle_input_timers(delta)
	_handle_attack(delta)
	_handle_dash(delta)
	_handle_focus(delta)
	_handle_mantle(delta)
	
	if current_state != State.DASH and current_state != State.MANTLE:
		if current_state != State.FOCUS:
			_handle_wall_mechanics(delta)
			_handle_jump(delta)
			_handle_horizontal_movement(delta)
		_handle_gravity(delta)
	
	var previously_on_floor: bool = _is_grounded()
	if is_inside_tree():
		move_and_slide()
	var currently_on_floor: bool = _is_grounded()
	
	if is_on_ceiling():
		is_jumping = false
		if velocity.y < 0.0:
			velocity.y = 0.0
	
	_handle_landing(previously_on_floor, currently_on_floor)
	_update_state(delta)
	
	# Check reset action
	if not input_override_enabled and Input.is_action_just_pressed("reset"):
		reset_to_spawn()


func _handle_input_timers(delta: float) -> void:
	# Coyote timer update
	if _is_grounded():
		coyote_timer = coyote_duration
		is_jumping = false
		is_double_jumping = false
		can_double_jump = true
		air_dashes_remaining = max_air_dashes
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
	
	if input_locked:
		jump_buffer_timer = 0.0
		attack_buffer_timer = 0.0
		_last_jump_pressed_this_frame = false
		_last_dash_pressed_this_frame = false
		return
	
	# Jump buffer timer update
	var jump_just_pressed: bool = false
	if input_override_enabled:
		jump_just_pressed = simulated_jump_pressed
		simulated_jump_pressed = false
	else:
		jump_just_pressed = Input.is_action_just_pressed("jump")
	
	_last_jump_pressed_this_frame = jump_just_pressed
	
	if jump_just_pressed:
		jump_buffer_timer = jump_buffer_duration
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	
	# Attack buffer timer update
	var attack_just_pressed: bool = false
	if input_override_enabled:
		attack_just_pressed = simulated_attack_pressed
		simulated_attack_pressed = false
	else:
		attack_just_pressed = Input.is_action_just_pressed("attack")
	
	if attack_just_pressed:
		attack_buffer_timer = attack_buffer_duration
	else:
		attack_buffer_timer = maxf(0.0, attack_buffer_timer - delta)


func _handle_dash(delta: float) -> void:
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	
	# If currently dashing, advance timer
	if current_state == State.DASH:
		dash_timer -= delta
		velocity.y = 0.0
		velocity.x = dash_direction.x * dash_speed
		if dash_timer <= 0.0:
			# Dash finished: return to appropriate movement state
			var move_axis: float = simulated_move_axis if input_override_enabled else Input.get_axis("move_left", "move_right")
			if absf(move_axis) > 0.05:
				velocity.x = signf(move_axis) * max_speed
				if _is_grounded():
					_set_state(State.RUN)
				else:
					_set_state(State.FALL)
			else:
				velocity.x = 0.0
				if _is_grounded():
					_set_state(State.IDLE)
				else:
					_set_state(State.FALL)
		return
	
	# Cannot initiate dash while in knockback stun, input locked, or locked ability
	if knockback_timer > 0.0 or input_locked or not dash_unlocked:
		return
	
	# Check dash trigger
	var dash_just_pressed: bool = false
	if input_override_enabled:
		dash_just_pressed = simulated_dash_pressed
		simulated_dash_pressed = false
	else:
		dash_just_pressed = Input.is_action_just_pressed("dash")
	
	if dash_just_pressed:
		_last_dash_pressed_this_frame = true
		if current_state == State.FOCUS:
			interrupt_focus()
	else:
		_last_dash_pressed_this_frame = false
	
	if dash_just_pressed and dash_cooldown_timer <= 0.0:
		var can_dash: bool = false
		if _is_grounded():
			can_dash = true
		elif air_dashes_remaining > 0:
			can_dash = true
			air_dashes_remaining -= 1
		
		if can_dash:
			_execute_dash()


func _execute_dash() -> void:
	var move_axis: float = 0.0
	if input_override_enabled:
		move_axis = simulated_move_axis
	else:
		move_axis = Input.get_axis("move_left", "move_right")
	
	if absf(move_axis) > 0.05:
		facing_direction = int(signf(move_axis))
		_update_visual_facing()
	
	dash_direction = Vector2(float(facing_direction), 0.0)
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	velocity.x = dash_direction.x * dash_speed
	velocity.y = 0.0
	is_jumping = false
	
	_set_state(State.DASH)
	dashed.emit(dash_direction)
	screen_shake_requested.emit(2.5, 0.10)


func _handle_wall_mechanics(delta: float) -> void:
	if not wall_jump_unlocked:
		return
	
	var touching_wall: bool = _is_wall_contact()
	var wall_norm: Vector2 = _get_wall_normal_vector()
	
	if touching_wall:
		if absf(wall_norm.x) > 0.1:
			last_wall_normal = wall_norm
		wall_coyote_timer = wall_jump_coyote_duration
	else:
		wall_coyote_timer = maxf(0.0, wall_coyote_timer - delta)
	
	if wall_input_lock_timer > 0.0:
		wall_input_lock_timer = maxf(0.0, wall_input_lock_timer - delta)
	
	# Check if wall slide applies
	if not _is_grounded() and touching_wall and velocity.y > 0.0:
		var move_axis: float = simulated_move_axis if input_override_enabled else Input.get_axis("move_left", "move_right")
		var pushing_into_wall: bool = (move_axis * wall_norm.x < -0.05) or (absf(move_axis) <= 0.05 and facing_direction * wall_norm.x < 0)
		
		if pushing_into_wall:
			# Clamp slide speed
			velocity.y = minf(velocity.y, wall_slide_speed)
			air_dashes_remaining = max_air_dashes
			can_double_jump = true
			is_double_jumping = false
			if current_state != State.WALL_SLIDE:
				_set_state(State.WALL_SLIDE)
				wall_slid.emit()
			return
	
	if current_state == State.WALL_SLIDE:
		# Exiting wall slide
		if _is_grounded():
			_set_state(State.LAND)
		else:
			_set_state(State.FALL)


func _handle_attack(delta: float) -> void:
	# Query buffered attack trigger if not currently attacking and not in knockback stun or input locked
	if current_attack_state == AttackState.NONE and knockback_timer <= 0.0 and not input_locked:
		var attack_triggered: bool = false
		if attack_buffer_timer > 0.0:
			attack_triggered = true
			attack_buffer_timer = 0.0
		elif input_override_enabled and simulated_attack_pressed:
			attack_triggered = true
			simulated_attack_pressed = false
		elif not input_override_enabled and Input.is_action_just_pressed("attack"):
			attack_triggered = true
		
		if attack_triggered:
			if current_state == State.FOCUS:
				interrupt_focus()
			_start_attack()
			return
	
	# State machine for attack phases
	match current_attack_state:
		AttackState.STARTUP:
			attack_timer -= delta
			if attack_timer <= 0.0:
				current_attack_state = AttackState.ACTIVE
				attack_timer = attack_active_duration
				_activate_hitbox()
				attack_active.emit(current_attack_direction)
		
		AttackState.ACTIVE:
			attack_timer -= delta
			if attack_timer <= 0.0:
				current_attack_state = AttackState.RECOVERY
				attack_timer = attack_recovery_duration
				_deactivate_hitbox()
		
		AttackState.RECOVERY:
			attack_timer -= delta
			if attack_timer <= 0.0:
				current_attack_state = AttackState.NONE
				attack_timer = 0.0
				attack_recovered.emit()
				# If an attack was queued during recovery, launch it immediately
				if attack_buffer_timer > 0.0 and knockback_timer <= 0.0:
					attack_buffer_timer = 0.0
					_start_attack()
		
		AttackState.NONE:
			pass


func _start_attack() -> void:
	var is_up: bool = false
	var is_down: bool = false
	
	if input_override_enabled:
		is_up = simulated_move_up
		is_down = simulated_move_down
	else:
		is_up = Input.is_action_pressed("move_up")
		is_down = Input.is_action_pressed("move_down")
	
	# Priority: Airborne + Down -> Pogo; Up -> Overhead; Else -> Forward
	if not _is_grounded() and is_down:
		current_attack_direction = AttackDirection.DOWN
	elif is_up:
		current_attack_direction = AttackDirection.UP
	else:
		current_attack_direction = AttackDirection.FORWARD
	
	has_pogo_bounced = false
	current_attack_state = AttackState.STARTUP
	attack_timer = attack_startup_duration
	attack_initiated.emit(current_attack_direction)


func _activate_hitbox() -> void:
	if not hitbox:
		return
	
	var dir_vector: Vector2 = Vector2.RIGHT
	var is_pogo: bool = false
	
	match current_attack_direction:
		AttackDirection.FORWARD:
			dir_vector = Vector2(float(facing_direction), 0.0)
			is_pogo = false
			if hitbox_shape:
				hitbox_shape.position = Vector2(facing_direction * 26.0, -20.0)
				if hitbox_shape.shape is RectangleShape2D:
					(hitbox_shape.shape as RectangleShape2D).size = Vector2(36.0, 30.0)
		
		AttackDirection.UP:
			dir_vector = Vector2.UP
			is_pogo = false
			if hitbox_shape:
				hitbox_shape.position = Vector2(0.0, -48.0)
				if hitbox_shape.shape is RectangleShape2D:
					(hitbox_shape.shape as RectangleShape2D).size = Vector2(40.0, 32.0)
		
		AttackDirection.DOWN:
			dir_vector = Vector2.DOWN
			is_pogo = true
			if hitbox_shape:
				hitbox_shape.position = Vector2(0.0, 4.0)
				if hitbox_shape.shape is RectangleShape2D:
					(hitbox_shape.shape as RectangleShape2D).size = Vector2(36.0, 26.0)
	
	hitbox.damage = attack_damage
	hitbox.knockback_force = attack_knockback_force
	hitbox.activate(dir_vector, is_pogo)
	
	if visuals_node and visuals_node.has_method("play_slash"):
		visuals_node.call("play_slash", current_attack_direction, facing_direction)


func _deactivate_hitbox() -> void:
	if hitbox:
		hitbox.deactivate()


func trigger_hit_stop(duration: float = -1.0) -> void:
	var dur: float = duration if duration > 0.0 else hit_stop_duration
	hit_stop_timer = dur
	hit_stop_triggered.emit(dur)


func _on_pogo_triggered(_target: Node) -> void:
	if current_attack_direction == AttackDirection.DOWN and not has_pogo_bounced:
		has_pogo_bounced = true
		velocity.y = pogo_bounce_velocity
		coyote_timer = coyote_duration
		air_dashes_remaining = max_air_dashes
		can_double_jump = true
		is_double_jumping = false
		is_jumping = false
		if current_state == State.DASH:
			dash_timer = 0.0
			_set_state(State.JUMP)
		pogo_bounced.emit()
		trigger_hit_stop(hit_stop_duration)
		screen_shake_requested.emit(screen_shake_intensity * 0.75, 0.15)
		if visuals_node and visuals_node.has_method("on_pogo_bounce"):
			visuals_node.call("on_pogo_bounce")


func _on_health_damaged(amount: int) -> void:
	player_damaged.emit(amount, health_component.current_health if health_component else max_health)


func _on_hurtbox_hit_received(hit_data: RefCounted) -> void:
	if health_component and health_component.current_health <= 0:
		return
	
	var kb_dir: Vector2 = hit_data.get("knockback_direction") if hit_data.get("knockback_direction") != null else Vector2.ZERO
	if kb_dir.length_squared() < 0.01:
		kb_dir = Vector2(-float(facing_direction), -0.4).normalized()
	else:
		kb_dir = (kb_dir + (Vector2.UP * 0.4)).normalized()
	
	velocity = kb_dir * hurt_knockback_speed
	knockback_timer = knockback_stun_duration
	is_jumping = false
	if current_state == State.DASH:
		dash_timer = 0.0
		_set_state(State.FALL)
	elif current_state == State.WALL_SLIDE:
		_set_state(State.FALL)
	elif current_state == State.FOCUS:
		interrupt_focus()
		_set_state(State.FALL)
	elif current_state == State.MANTLE:
		mantle_timer = 0.0
		_set_state(State.FALL)
	trigger_hit_stop(hit_stop_duration * 1.5)
	screen_shake_requested.emit(screen_shake_intensity * 1.25, screen_shake_duration)


func _on_died() -> void:
	if current_state == State.FOCUS:
		interrupt_focus()
	player_died.emit()
	reset_to_spawn()


func _handle_jump(_delta: float) -> void:
	if input_locked:
		return
	# Cannot initiate jump while in knockback stun
	if knockback_timer > 0.0:
		return
	
	var jump_held: bool = false
	var jump_just_released: bool = false
	if input_override_enabled:
		jump_held = simulated_jump_held
		jump_just_released = simulated_jump_released
		simulated_jump_released = false
	else:
		jump_held = Input.is_action_pressed("jump")
		jump_just_released = Input.is_action_just_released("jump")
	
	# Wall Jump Check
	if jump_buffer_timer > 0.0 and not _is_grounded():
		var touching_wall: bool = _is_wall_contact()
		if touching_wall or wall_coyote_timer > 0.0 or current_state == State.WALL_SLIDE:
			if wall_jump_unlocked:
				_execute_wall_jump()
				if not jump_held or jump_just_released:
					velocity.y *= variable_jump_cutoff
					is_jumping = false
				return
	
	# Standard Ground / Coyote Jump Check
	if jump_buffer_timer > 0.0 and (_is_grounded() or coyote_timer > 0.0):
		_execute_jump()
		if not jump_held or jump_just_released:
			velocity.y *= variable_jump_cutoff
			is_jumping = false
		return
	
	# Double Jump Check
	if jump_buffer_timer > 0.0 and not _is_grounded() and coyote_timer <= 0.0:
		if double_jump_unlocked and can_double_jump and current_state != State.WALL_SLIDE:
			_execute_double_jump()
			if not jump_held or jump_just_released:
				velocity.y *= variable_jump_cutoff
				is_jumping = false
				is_double_jumping = false
			return
	
	# Variable jump height cut-off during upward rise
	if (jump_just_released or not jump_held) and velocity.y < 0.0 and (is_jumping or is_double_jumping):
		velocity.y *= variable_jump_cutoff
		is_jumping = false
		is_double_jumping = false


func _execute_jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	is_jumping = true
	jumped.emit()
	_set_state(State.JUMP)


func _execute_double_jump() -> void:
	velocity.y = double_jump_velocity
	jump_buffer_timer = 0.0
	can_double_jump = false
	is_jumping = true
	is_double_jumping = true
	double_jumped.emit()
	jumped.emit()
	_set_state(State.JUMP)
	screen_shake_requested.emit(2.5, 0.10)


func _execute_wall_jump() -> void:
	var outward_x: float = last_wall_normal.x
	if absf(outward_x) < 0.1:
		outward_x = -float(facing_direction)
	
	velocity.x = outward_x * wall_jump_velocity.x
	velocity.y = wall_jump_velocity.y # negative
	facing_direction = int(signf(outward_x))
	_update_visual_facing()
	
	wall_input_lock_timer = wall_jump_input_lock_duration
	wall_coyote_timer = 0.0
	jump_buffer_timer = 0.0
	is_jumping = true
	is_double_jumping = false
	can_double_jump = true
	air_dashes_remaining = max_air_dashes
	
	_set_state(State.WALL_JUMP)
	wall_jumped.emit()
	jumped.emit()
	screen_shake_requested.emit(3.0, 0.12)


func _handle_gravity(delta: float) -> void:
	if not _is_grounded() and current_state != State.WALL_SLIDE and current_state != State.DASH:
		var active_gravity: float = fall_gravity if velocity.y > 0.0 else jump_gravity
		velocity.y += active_gravity * delta
		velocity.y = minf(velocity.y, max_fall_speed)


func _handle_horizontal_movement(delta: float) -> void:
	# Knockback attenuation
	if knockback_timer > 0.0:
		knockback_timer -= delta
		var decel := ground_deceleration if _is_grounded() else air_deceleration
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		return
	
	# Wall jump input lockout preservation
	if wall_input_lock_timer > 0.0:
		velocity.x = move_toward(velocity.x, facing_direction * max_speed, air_deceleration * delta)
		return
	
	var move_axis: float = 0.0
	if not input_locked:
		if input_override_enabled:
			move_axis = simulated_move_axis
		else:
			move_axis = Input.get_axis("move_left", "move_right")
	
	var target_speed: float = move_axis * max_speed
	var accel_rate: float = 0.0
	if _is_grounded():
		accel_rate = ground_acceleration if absf(move_axis) > 0.01 else ground_deceleration
	else:
		accel_rate = air_acceleration if absf(move_axis) > 0.01 else air_deceleration
	
	velocity.x = move_toward(velocity.x, target_speed, accel_rate * delta)
	
	if current_attack_state == AttackState.NONE or current_attack_state == AttackState.RECOVERY or current_attack_direction != AttackDirection.FORWARD:
		if move_axis > 0.05:
			facing_direction = 1
			_update_visual_facing()
		elif move_axis < -0.05:
			facing_direction = -1
			_update_visual_facing()


func _handle_landing(previously_on_floor: bool, currently_on_floor: bool) -> void:
	if not previously_on_floor and currently_on_floor:
		is_jumping = false
		is_double_jumping = false
		can_double_jump = true
		air_dashes_remaining = max_air_dashes
		landed.emit()
		land_timer = land_duration
		if current_state != State.FOCUS:
			if absf(velocity.x) > 10.0:
				_set_state(State.RUN)
			else:
				_set_state(State.LAND)


func _update_state(delta: float = 0.0) -> void:
	if current_state == State.DASH or current_state == State.FOCUS or current_state == State.MANTLE:
		return
	
	if _is_grounded():
		if current_state == State.LAND:
			land_timer = maxf(0.0, land_timer - delta)
			if absf(velocity.x) > 10.0:
				land_timer = 0.0
				_set_state(State.RUN)
			elif land_timer <= 0.0:
				_set_state(State.IDLE)
		elif absf(velocity.x) > 10.0:
			_set_state(State.RUN)
		else:
			_set_state(State.IDLE)
	else:
		land_timer = 0.0
		if current_state == State.WALL_SLIDE:
			return
		elif current_state == State.WALL_JUMP and velocity.y < 0.0:
			return
		
		if velocity.y < 0.0:
			_set_state(State.JUMP)
		else:
			_set_state(State.FALL)


func _set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	var previous_state: State = current_state
	current_state = new_state
	state_changed.emit(new_state, previous_state)


func _update_visual_facing() -> void:
	if visuals_node:
		visuals_node.scale.x = float(facing_direction)


func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	attack_buffer_timer = 0.0
	land_timer = 0.0
	is_jumping = false
	is_double_jumping = false
	can_double_jump = false
	mantle_timer = 0.0
	has_pogo_bounced = false
	current_attack_state = AttackState.NONE
	attack_timer = 0.0
	knockback_timer = 0.0
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	air_dashes_remaining = max_air_dashes
	wall_coyote_timer = 0.0
	wall_input_lock_timer = 0.0
	hit_stop_timer = 0.0
	focus_timer = 0.0
	current_soul = 0
	soul_changed.emit(0, max_soul)
	_deactivate_hitbox()
	if health_component:
		health_component.reset_health()
	_set_state(State.IDLE)


# --- Helper Query Methods for UI & Testing ---

func get_state_name() -> String:
	match current_state:
		State.IDLE: return "IDLE"
		State.RUN: return "RUN"
		State.JUMP: return "JUMP"
		State.FALL: return "FALL"
		State.LAND: return "LAND"
		State.WALL_SLIDE: return "WALL_SLIDE"
		State.WALL_JUMP: return "WALL_JUMP"
		State.DASH: return "DASH"
		State.FOCUS: return "FOCUS"
		_: return "UNKNOWN"


func get_attack_state_name() -> String:
	match current_attack_state:
		AttackState.NONE: return "NONE"
		AttackState.STARTUP: return "STARTUP"
		AttackState.ACTIVE: return "ACTIVE"
		AttackState.RECOVERY: return "RECOVERY"
		_: return "UNKNOWN"


func get_attack_direction_name() -> String:
	match current_attack_direction:
		AttackDirection.FORWARD: return "FORWARD"
		AttackDirection.UP: return "UP"
		AttackDirection.DOWN: return "DOWN"
		_: return "UNKNOWN"


func is_attacking() -> bool:
	return current_attack_state != AttackState.NONE


func is_attack_active() -> bool:
	return current_attack_state == AttackState.ACTIVE


func get_current_health() -> int:
	return health_component.current_health if health_component else max_health


func get_max_health() -> int:
	return health_component.max_health if health_component else max_health


func is_invulnerable() -> bool:
	return health_component.is_invulnerable if health_component else false


func get_invulnerability_time_remaining() -> float:
	return health_component.invulnerability_timer if health_component else 0.0


func get_coyote_time_remaining() -> float:
	return coyote_timer


func get_jump_buffer_remaining() -> float:
	return jump_buffer_timer


func is_coyote_active() -> bool:
	return coyote_timer > 0.0 and not is_on_floor()


func is_jump_buffered() -> bool:
	return jump_buffer_timer > 0.0


func is_attack_buffered() -> bool:
	return attack_buffer_timer > 0.0


func get_attack_buffer_remaining() -> float:
	return attack_buffer_timer


func is_dashing() -> bool:
	return current_state == State.DASH


func is_wall_sliding() -> bool:
	return current_state == State.WALL_SLIDE


func get_dash_cooldown_remaining() -> float:
	return dash_cooldown_timer


func get_wall_coyote_remaining() -> float:
	return wall_coyote_timer


func get_air_dashes_remaining() -> int:
	return air_dashes_remaining


func _handle_focus(delta: float) -> void:
	var focus_held: bool = simulated_focus_held if input_override_enabled else Input.is_action_pressed("focus")
	var focus_just_pressed: bool = simulated_focus_pressed if input_override_enabled else Input.is_action_just_pressed("focus")
	if input_override_enabled:
		simulated_focus_pressed = false

	if current_state == State.FOCUS:
		# Ground check: must remain grounded
		if not _is_grounded():
			interrupt_focus()
			return
		
		# Movement / action interruption
		var move_axis: float = simulated_move_axis if input_override_enabled else Input.get_axis("move_left", "move_right")
		var jump_just_pressed: bool = _last_jump_pressed_this_frame or (jump_buffer_timer > 0.0)
		var dash_just_pressed: bool = _last_dash_pressed_this_frame
		var attack_just_pressed: bool = attack_buffer_timer > 0.0
		
		if absf(move_axis) > 0.1 or jump_just_pressed or dash_just_pressed or attack_just_pressed:
			interrupt_focus()
			return
		
		# Releasing early cancels without healing or consuming soul
		if not focus_held:
			interrupt_focus()
			return
		
		# Keep player stationary
		velocity.x = 0.0
		
		# Advance charge
		focus_timer += delta
		var progress: float = clampf(focus_timer / focus_charge_duration, 0.0, 1.0)
		focus_charged.emit(progress)
		
		if focus_timer >= focus_charge_duration:
			# Successful completion of 1 heal charge
			consume_soul(soul_heal_cost)
			if health_component:
				health_component.heal(1)
			focus_completed.emit()
			focus_timer = 0.0
			
			# If player continues holding focus, and still has damage and enough soul, continue chaining
			if focus_held and current_soul >= soul_heal_cost and get_current_health() < get_max_health():
				focus_started.emit()
			else:
				_set_state(State.IDLE)
		return

	# If not in FOCUS, check if player wants to start focusing
	var wants_focus: bool = focus_just_pressed or (focus_held and (current_state == State.IDLE or current_state == State.LAND))
	if wants_focus:
		if can_focus():
			start_focus()


func can_focus() -> bool:
	if input_locked:
		return false
	if not _is_grounded():
		return false
	if current_state != State.IDLE and current_state != State.LAND:
		return false
	if current_attack_state != AttackState.NONE:
		return false
	if knockback_timer > 0.0:
		return false
	if current_soul < soul_heal_cost:
		return false
	if get_current_health() >= get_max_health():
		return false
	var move_axis: float = simulated_move_axis if input_override_enabled else Input.get_axis("move_left", "move_right")
	if absf(move_axis) > 0.1:
		return false
	if absf(velocity.x) > 20.0:
		return false
	return true


func start_focus() -> void:
	velocity.x = 0.0
	focus_timer = 0.0
	_set_state(State.FOCUS)
	focus_started.emit()
	focus_charged.emit(0.0)


func interrupt_focus() -> void:
	if current_state == State.FOCUS:
		focus_timer = 0.0
		focus_interrupted.emit()
		if _is_grounded():
			_set_state(State.IDLE)
		else:
			_set_state(State.FALL)


func _on_hit_landed(target: Node, _hit_data: HitData) -> void:
	if target != null and not target.is_in_group("pogo_hazard") and not (target.has_method("is_pogo_hazard") and target.is_pogo_hazard()):
		add_soul(soul_per_hit)


func add_soul(amount: int) -> void:
	var previous_soul := current_soul
	current_soul = clampi(current_soul + amount, 0, max_soul)
	if current_soul != previous_soul:
		soul_changed.emit(current_soul, max_soul)


func consume_soul(amount: int) -> bool:
	if current_soul >= amount:
		current_soul -= amount
		soul_changed.emit(current_soul, max_soul)
		return true
	return false


func is_focusing() -> bool:
	return current_state == State.FOCUS


func get_focus_progress() -> float:
	if current_state == State.FOCUS and focus_charge_duration > 0.0:
		return clampf(focus_timer / focus_charge_duration, 0.0, 1.0)
	return 0.0


func get_current_soul() -> int:
	return current_soul


func get_max_soul() -> int:
	return max_soul


func get_soul_heal_cost() -> int:
	return soul_heal_cost


func restore_health(amount: int = -1) -> void:
	if amount <= 0:
		if health_component:
			health_component.reset_health()
	else:
		if health_component:
			health_component.heal(amount)


func refill_soul() -> void:
	current_soul = max_soul
	soul_changed.emit(current_soul, max_soul)


func _check_mantle_ledge() -> bool:
	if simulated_mantle_detected:
		return true
	if not is_inside_tree() or get_world_2d() == null:
		return false
	
	var space_state = get_world_2d().direct_space_state
	if space_state == null:
		return false
	
	# Ray 1: Forward at chest height (-18px) - must hit solid World
	var chest_origin = global_position + Vector2(0, -18)
	var chest_target = chest_origin + Vector2(float(facing_direction) * mantle_reach_distance, 0)
	var chest_query = PhysicsRayQueryParameters2D.create(chest_origin, chest_target, 1)
	chest_query.exclude = [get_rid()]
	var chest_hit = space_state.intersect_ray(chest_query)
	if chest_hit.is_empty():
		return false
	
	# Ray 2: Forward above head (-42px) - must NOT hit solid World (clearance)
	var head_origin = global_position + Vector2(0, -42)
	var head_target = head_origin + Vector2(float(facing_direction) * mantle_reach_distance, 0)
	var head_query = PhysicsRayQueryParameters2D.create(head_origin, head_target, 1)
	head_query.exclude = [get_rid()]
	var head_hit = space_state.intersect_ray(head_query)
	if not head_hit.is_empty():
		return false
	
	# Ray 3: Downward onto ledge top surface
	var down_origin = chest_hit.position + Vector2(float(facing_direction) * 4.0, -28.0)
	var down_target = down_origin + Vector2(0, 36.0)
	var down_query = PhysicsRayQueryParameters2D.create(down_origin, down_target, 1)
	down_query.exclude = [get_rid()]
	var down_hit = space_state.intersect_ray(down_query)
	if down_hit.is_empty():
		return false
	
	return true


func _handle_mantle(delta: float) -> void:
	if not mantle_unlocked:
		return
	
	if current_state == State.MANTLE:
		velocity = Vector2.ZERO
		mantle_timer -= delta
		
		var jump_pressed: bool = (_last_jump_pressed_this_frame or jump_buffer_timer > 0.0) if input_override_enabled else Input.is_action_just_pressed("jump")
		var up_pressed: bool = simulated_move_up if input_override_enabled else Input.is_action_just_pressed("ui_up")
		var down_pressed: bool = simulated_move_down if input_override_enabled else Input.is_action_just_pressed("ui_down")
		
		if jump_pressed or up_pressed or mantle_timer <= 0.0:
			position += Vector2(float(facing_direction) * mantle_pull_offset.x, mantle_pull_offset.y)
			velocity = Vector2.ZERO
			is_jumping = false
			is_double_jumping = false
			can_double_jump = true
			air_dashes_remaining = max_air_dashes
			jump_buffer_timer = 0.0
			_last_jump_pressed_this_frame = false
			if simulated_on_floor_override:
				simulated_on_floor = true
			_set_state(State.IDLE)
			mantle_completed.emit()
			return
		elif down_pressed:
			_set_state(State.FALL)
			coyote_timer = 0.0
			return
		return
	
	# Check ledge grab entry while airborne and descending or near apex
	if not _is_grounded() and velocity.y >= -120.0 and current_state != State.DASH and current_state != State.FOCUS:
		if _check_mantle_ledge():
			_enter_mantle()


func _enter_mantle() -> void:
	velocity = Vector2.ZERO
	mantle_timer = mantle_climb_duration * 2.0
	mantle_wall_normal = Vector2(-float(facing_direction), 0.0)
	is_jumping = false
	is_double_jumping = false
	can_double_jump = true
	air_dashes_remaining = max_air_dashes
	_set_state(State.MANTLE)
	mantled.emit()

