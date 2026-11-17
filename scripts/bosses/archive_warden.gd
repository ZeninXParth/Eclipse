class_name ArchiveWarden
extends EnemyBase

## ECLIPSE: Echoes of the Forgotten
## Milestone 4: First Boss Encounter ("The Archive Warden / Ancient Sentry")
## Massive ancient occult sentry automaton guarding the Ancient Chamber.
## Features two-phase combat lifecycle, overhead ground shockwave slams,
## sweeping forward thrust charges, enrage sequence with aura flare,
## arena confinement gate integration, and PlayerData persistence.

const GroundShockwaveScript = preload("res://scripts/bosses/ground_shockwave.gd")
const ArenaGateScript = preload("res://scripts/world/arena_gate.gd")
const BossHealthBarScript = preload("res://scripts/ui/boss_health_bar.gd")
const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const GameManagerScript = preload("res://scripts/core/game_manager.gd")

signal slam_initiated()
signal ground_slammed()
signal thrust_initiated()
signal thrust_completed()
signal shockwave_emitted(shockwave: Node)
signal phase_changed(new_phase: int)
signal enrage_started()
signal enrage_completed()
signal boss_defeated()
signal gates_unlocked()
signal screen_shake_requested(intensity: float, duration: float)

enum BossPhase {
	PHASE_1 = 1,
	PHASE_2 = 2
}

enum WardenState {
	DORMANT,
	STALK,
	SLAM_WINDUP,
	SLAM_IMPACT,
	SLAM_RECOVER,
	THRUST_WINDUP,
	THRUST_CHARGE,
	THRUST_RECOVER,
	LEAP_WINDUP,
	LEAP_AIR,
	LEAP_SLAM,
	LEAP_RECOVER,
	ENRAGING,
	DYING,
	DEAD
}

@export_group("Boss Identity & Stats")
@export var boss_name: String = "ARCHIVE WARDEN — Ancient Sentry"
@export var phase_2_threshold: int = 15
@export var stalk_speed: float = 65.0
@export var thrust_charge_speed: float = 340.0
@export var thrust_duration: float = 0.42
@export var slam_windup_duration: float = 0.50
@export var thrust_windup_duration: float = 0.40
@export var p1_recovery_duration: float = 0.85
@export var p2_recovery_duration: float = 0.45
@export var enrage_duration: float = 1.20
@export var leap_speed_x: float = 260.0
@export var leap_velocity_y: float = -520.0

@export_group("Arena Integration")
@export var arena_gate_west: StaticBody2D
@export var arena_gate_east: StaticBody2D
@export var boss_health_bar: CanvasLayer

var warden_state: WardenState = WardenState.DORMANT
var current_phase: BossPhase = BossPhase.PHASE_1
var enraged_aura: bool = false
var aura_pulse: float = 0.0
var attack_decision_timer: float = 0.0
var current_action_timer: float = 0.0
var attack_counter: int = 0
var is_encounter_active: bool = false

# Visuals & Color Palette
const COLOR_STONE_ARMOR = Color(0.14, 0.16, 0.22, 1.0)
const COLOR_BRASS_TRIM = Color(0.78, 0.62, 0.28, 1.0)
const COLOR_CYAN_CORE = Color(0.35, 0.90, 1.0, 1.0)
const COLOR_PURPLE_AURA = Color(0.85, 0.20, 0.95, 0.8)
const COLOR_BLADE_STEEL = Color(0.75, 0.80, 0.90, 1.0)
const COLOR_WHITE_FLASH = Color(1.0, 1.0, 1.0, 1.0)


func _init() -> void:
	max_health = 30
	patrol_speed = stalk_speed
	contact_damage = 2
	contact_knockback_force = 300.0
	knockback_resistance = 0.85 # Heavy automaton, high knockback resistance
	detection_range = 350.0
	lose_interest_range = 800.0
	alert_duration = slam_windup_duration
	hurt_duration = 0.10


func _ready() -> void:
	super._ready()
	
	# Tune collision shape
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape is CapsuleShape2D:
		var cap := col.shape as CapsuleShape2D
		cap.radius = 16.0
		cap.height = 54.0
		col.position = Vector2(0.0, -27.0)
	elif col == null:
		col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var cap := CapsuleShape2D.new()
		cap.radius = 16.0
		cap.height = 54.0
		col.shape = cap
		col.position = Vector2(0.0, -27.0)
		add_child(col)
	
	# Tune hurtbox & hitbox for boss stature
	if hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:
		var h_cap := hurtbox_shape.shape as CapsuleShape2D
		h_cap.radius = 20.0
		h_cap.height = 58.0
		hurtbox_shape.position = Vector2(0.0, -29.0)
	
	if hitbox_shape and hitbox_shape.shape is CapsuleShape2D:
		var hb_cap := hitbox_shape.shape as CapsuleShape2D
		hb_cap.radius = 24.0
		hb_cap.height = 62.0
		hitbox_shape.position = Vector2(0.0, -29.0)
	
	# Initialize health component
	if health_component:
		health_component.max_health = max_health
		health_component.current_health = max_health


func _get_player_data() -> PlayerData:
	if GameManagerScript.instance and GameManagerScript.instance.player_data:
		return GameManagerScript.instance.player_data
	return null


func _request_camera_shake(intensity: float, duration: float) -> void:
	screen_shake_requested.emit(intensity, duration)
	var target := find_player_target()
	if target:
		if target.has_signal("screen_shake_requested"):
			target.call("emit_signal", "screen_shake_requested", intensity, duration)
		var cam := target.get_node_or_null("Camera2D")
		if cam and cam.has_method("apply_shake"):
			cam.call("apply_shake", intensity, duration)


func _handle_idle(delta: float) -> void:
	# Decelerate knockback but do not clobber warden_state with EnemyState.PATROL
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)


func start_encounter() -> void:
	if is_encounter_active or is_dead:
		return
	is_encounter_active = true
	
	# Lock arena gates
	if arena_gate_west and not arena_gate_west.is_gate_closed():
		arena_gate_west.close_gate()
	if arena_gate_east and not arena_gate_east.is_gate_closed():
		arena_gate_east.close_gate()
	
	# Setup & display health bar
	if boss_health_bar:
		boss_health_bar.initialize_bar(boss_name, max_health, health_component.current_health if health_component else max_health)
		boss_health_bar.show_bar()
	
	# Transition to stalking
	_set_warden_state(WardenState.STALK)
	attack_decision_timer = 0.6


func get_warden_state_name() -> String:
	match warden_state:
		WardenState.DORMANT: return "DORMANT"
		WardenState.STALK: return "STALK"
		WardenState.SLAM_WINDUP: return "SLAM_WINDUP"
		WardenState.SLAM_IMPACT: return "SLAM_IMPACT"
		WardenState.SLAM_RECOVER: return "SLAM_RECOVER"
		WardenState.THRUST_WINDUP: return "THRUST_WINDUP"
		WardenState.THRUST_CHARGE: return "THRUST_CHARGE"
		WardenState.THRUST_RECOVER: return "THRUST_RECOVER"
		WardenState.LEAP_WINDUP: return "LEAP_WINDUP"
		WardenState.LEAP_AIR: return "LEAP_AIR"
		WardenState.LEAP_SLAM: return "LEAP_SLAM"
		WardenState.LEAP_RECOVER: return "LEAP_RECOVER"
		WardenState.ENRAGING: return "ENRAGING"
		WardenState.DYING: return "DYING"
		WardenState.DEAD: return "DEAD"
		_: return "UNKNOWN"


func _set_warden_state(new_state: WardenState) -> void:
	warden_state = new_state
	match new_state:
		WardenState.DORMANT:
			_set_state(EnemyState.IDLE)
		WardenState.STALK:
			_set_state(EnemyState.PATROL)
		WardenState.SLAM_WINDUP, WardenState.THRUST_WINDUP, WardenState.LEAP_WINDUP:
			_set_state(EnemyState.ALERT)
		WardenState.SLAM_IMPACT, WardenState.THRUST_CHARGE, WardenState.LEAP_SLAM:
			_set_state(EnemyState.ATTACK)
		WardenState.SLAM_RECOVER, WardenState.THRUST_RECOVER, WardenState.LEAP_RECOVER, WardenState.ENRAGING:
			_set_state(EnemyState.IDLE)
		WardenState.DYING, WardenState.DEAD:
			_set_state(EnemyState.DEAD)


func step_boss(delta: float) -> void:
	if is_dead and warden_state != WardenState.DYING:
		return
	
	if enraged_aura:
		aura_pulse = fmod(aura_pulse + delta * 5.0, TAU)
	
	match warden_state:
		WardenState.DORMANT:
			velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
		
		WardenState.STALK:
			_handle_stalk_state(delta)
		
		WardenState.SLAM_WINDUP:
			_handle_slam_windup(delta)
		
		WardenState.SLAM_IMPACT:
			_handle_slam_impact(delta)
		
		WardenState.SLAM_RECOVER:
			_handle_slam_recover(delta)
		
		WardenState.THRUST_WINDUP:
			_handle_thrust_windup(delta)
		
		WardenState.THRUST_CHARGE:
			_handle_thrust_charge(delta)
		
		WardenState.THRUST_RECOVER:
			_handle_thrust_recover(delta)
		
		WardenState.LEAP_WINDUP:
			_handle_leap_windup(delta)
		
		WardenState.LEAP_AIR:
			_handle_leap_air(delta)
		
		WardenState.LEAP_SLAM:
			_handle_leap_slam(delta)
		
		WardenState.LEAP_RECOVER:
			_handle_leap_recover(delta)
		
		WardenState.ENRAGING:
			_handle_enrage_state(delta)
		
		WardenState.DYING:
			_handle_dying_state(delta)


func _physics_process(delta: float) -> void:
	step_physics(delta)
	step_boss(delta)


func _handle_stalk_state(delta: float) -> void:
	# Track player facing direction
	var target := find_player_target()
	if target != null:
		var dir_x := target.global_position.x - global_position.x
		if absf(dir_x) > 15.0:
			facing_direction = 1 if dir_x > 0.0 else -1
	
	# Menacing stalking pace
	velocity.x = float(facing_direction) * (stalk_speed * (1.25 if current_phase == BossPhase.PHASE_2 else 1.0))
	
	# Decide attack based on distance and cadence
	attack_decision_timer -= delta
	if attack_decision_timer <= 0.0:
		_choose_next_attack()


func _choose_next_attack() -> void:
	velocity.x = 0.0
	attack_counter += 1
	var target := find_player_target()
	var dist := distance_to_target()
	
	# Phase 2 has Leaping Ground Pound option
	if current_phase == BossPhase.PHASE_2 and (attack_counter % 3 == 0 or dist > 260.0):
		start_leap_ground_pound()
		return
	
	# Alternate or distance-based slam vs thrust
	if dist < 150.0:
		# Close range: overhead slam
		start_overhead_slam()
	elif dist > 180.0:
		# Medium-long range: sweeping thrust
		start_sweeping_thrust()
	else:
		# Alternating selection
		if attack_counter % 2 == 1:
			start_overhead_slam()
		else:
			start_sweeping_thrust()


# ----------------------------------------------------
# Overhead Slam Attack Lifecycle
# ----------------------------------------------------

func start_overhead_slam() -> void:
	_set_warden_state(WardenState.SLAM_WINDUP)
	current_action_timer = slam_windup_duration * (0.80 if current_phase == BossPhase.PHASE_2 else 1.0)
	flash_timer = current_action_timer
	telegraph_started.emit(current_action_timer)
	slam_initiated.emit()


func _handle_slam_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		execute_overhead_slam()


func execute_overhead_slam() -> void:
	_set_warden_state(WardenState.SLAM_IMPACT)
	current_action_timer = 0.10
	
	# Melee strike hitbox
	if hitbox:
		hitbox.activate(Vector2(float(facing_direction), 0.5).normalized(), false)
	
	# Slam impact signals
	ground_slammed.emit()
	attack_performed.emit()
	_request_camera_shake(5.0, 0.20)
	
	# Spawn traveling GroundShockwave along floor
	var shockwave = spawn_shockwave(float(facing_direction))
	shockwave_emitted.emit(shockwave)
	
	# Phase 2 bonus: double shockwave (left & right)
	if current_phase == BossPhase.PHASE_2:
		var reverse_shockwave = spawn_shockwave(-float(facing_direction))
		shockwave_emitted.emit(reverse_shockwave)


func _handle_slam_impact(delta: float) -> void:
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		if hitbox:
			hitbox.deactivate()
		_set_warden_state(WardenState.SLAM_RECOVER)
		current_action_timer = p2_recovery_duration if current_phase == BossPhase.PHASE_2 else p1_recovery_duration


func _handle_slam_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		_set_warden_state(WardenState.STALK)
		attack_decision_timer = 0.35 if current_phase == BossPhase.PHASE_2 else 0.70


# ----------------------------------------------------
# Sweeping Thrust Attack Lifecycle
# ----------------------------------------------------

func start_sweeping_thrust() -> void:
	_set_warden_state(WardenState.THRUST_WINDUP)
	current_action_timer = thrust_windup_duration * (0.80 if current_phase == BossPhase.PHASE_2 else 1.0)
	flash_timer = current_action_timer
	telegraph_started.emit(current_action_timer)
	thrust_initiated.emit()


func _handle_thrust_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		execute_sweeping_thrust()


func execute_sweeping_thrust() -> void:
	_set_warden_state(WardenState.THRUST_CHARGE)
	current_action_timer = thrust_duration
	velocity.x = float(facing_direction) * (thrust_charge_speed * (1.15 if current_phase == BossPhase.PHASE_2 else 1.0))
	if hitbox:
		hitbox.knockback_force = 360.0
		hitbox.activate(Vector2(float(facing_direction), -0.2).normalized(), false)
	attack_performed.emit()


func _handle_thrust_charge(delta: float) -> void:
	current_action_timer -= delta
	if current_action_timer <= 0.0 or has_wall_ahead():
		if hitbox:
			hitbox.deactivate()
			hitbox.knockback_force = contact_knockback_force
		thrust_completed.emit()
		_set_warden_state(WardenState.THRUST_RECOVER)
		current_action_timer = p2_recovery_duration if current_phase == BossPhase.PHASE_2 else p1_recovery_duration


func _handle_thrust_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		_set_warden_state(WardenState.STALK)
		attack_decision_timer = 0.35 if current_phase == BossPhase.PHASE_2 else 0.70


# ----------------------------------------------------
# Phase 2 Leaping Ground Pound Lifecycle
# ----------------------------------------------------

func start_leap_ground_pound() -> void:
	_set_warden_state(WardenState.LEAP_WINDUP)
	current_action_timer = 0.35
	flash_timer = current_action_timer
	telegraph_started.emit(current_action_timer)


func _handle_leap_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		_execute_leap()


func _execute_leap() -> void:
	_set_warden_state(WardenState.LEAP_AIR)
	var target := find_player_target()
	if target:
		facing_direction = 1 if target.global_position.x > global_position.x else -1
	velocity.x = float(facing_direction) * leap_speed_x
	velocity.y = leap_velocity_y


func _handle_leap_air(_delta: float) -> void:
	# Fall down and detect impact
	if velocity.y > 0.0 and is_on_floor():
		_execute_leap_impact()


func _execute_leap_impact() -> void:
	_set_warden_state(WardenState.LEAP_SLAM)
	velocity.x = 0.0
	current_action_timer = 0.12
	ground_slammed.emit()
	_request_camera_shake(6.0, 0.25)
	
	# Dual shockwaves
	var s_right = spawn_shockwave(1.0)
	var s_left = spawn_shockwave(-1.0)
	shockwave_emitted.emit(s_right)
	shockwave_emitted.emit(s_left)


func _handle_leap_slam(delta: float) -> void:
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		_set_warden_state(WardenState.LEAP_RECOVER)
		current_action_timer = p2_recovery_duration + 0.10


func _handle_leap_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		_set_warden_state(WardenState.STALK)
		attack_decision_timer = 0.35


# ----------------------------------------------------
# Shockwave Spawner
# ----------------------------------------------------

func spawn_shockwave(dir: float) -> Area2D:
	var sw: Area2D = null
	if ResourceLoader.exists("res://scenes/bosses/ground_shockwave.tscn"):
		var scn := ResourceLoader.load("res://scenes/bosses/ground_shockwave.tscn") as PackedScene
		if scn:
			sw = scn.instantiate() as Area2D
	
	if sw == null:
		sw = GroundShockwaveScript.new()
		sw.name = "GroundShockwave"
	
	sw.direction = dir
	sw.speed = 260.0
	
	# Spawn at ground level in front of feet
	var spawn_x := global_position.x + dir * 28.0
	var spawn_y := global_position.y
	sw.global_position = Vector2(spawn_x, spawn_y)
	
	if get_parent():
		get_parent().add_child(sw)
	else:
		add_child(sw)
	
	return sw


# ----------------------------------------------------
# Enrage Phase Transition Lifecycle
# ----------------------------------------------------

func _on_health_damaged(amount: int) -> void:
	super._on_health_damaged(amount)
	
	if boss_health_bar and health_component:
		boss_health_bar.update_health(health_component.current_health, max_health)
	
	# Check for Phase 2 Enrage trigger
	if current_phase == BossPhase.PHASE_1 and health_component and health_component.current_health <= phase_2_threshold and health_component.current_health > 0:
		trigger_enrage()


func trigger_enrage() -> void:
	current_phase = BossPhase.PHASE_2
	_set_warden_state(WardenState.ENRAGING)
	current_action_timer = enrage_duration
	enraged_aura = true
	flash_timer = enrage_duration
	
	if hitbox:
		hitbox.deactivate()
	if hurtbox:
		hurtbox.set_manual_invulnerable(true) # Roar invulnerability
	
	phase_changed.emit(int(current_phase))
	enrage_started.emit()
	_request_camera_shake(8.0, 0.80)


func _handle_enrage_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		if hurtbox:
			hurtbox.set_manual_invulnerable(false)
		enrage_completed.emit()
		_set_warden_state(WardenState.STALK)
		attack_decision_timer = 0.25


# ----------------------------------------------------
# Defeat Sequence & Persistence
# ----------------------------------------------------

func _on_died() -> void:
	is_dead = true
	_set_warden_state(WardenState.DYING)
	current_action_timer = 1.0
	velocity = Vector2.ZERO
	
	if hitbox:
		hitbox.deactivate()
	if hurtbox:
		hurtbox.set_manual_invulnerable(true)
	
	# Emit boss defeat signal
	boss_defeated.emit()
	died.emit()
	
	# Unlock arena confinement gates permanently
	if arena_gate_west:
		arena_gate_west.unlock_gate()
	if arena_gate_east:
		arena_gate_east.unlock_gate()
	gates_unlocked.emit()
	
	# Award Soul reward to player
	var target := find_player_target()
	if target and target.has_method("add_soul"):
		target.call("add_soul", 33)
	
	# Persist defeat flag in PlayerData
	var pd := _get_player_data()
	if pd:
		pd.set_story_flag("boss_warden_defeated", true)
		if GameManagerScript.instance:
			GameManagerScript.instance.save_game()
	
	# Fade out cinematic health bar
	if boss_health_bar:
		boss_health_bar.fade_out()


func _handle_dying_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	current_action_timer -= delta
	if current_action_timer <= 0.0:
		_set_warden_state(WardenState.DEAD)


func _on_hurtbox_hit_received(hit_data: RefCounted) -> void:
	if is_dead:
		return
	
	# Wake up if attacked while dormant
	if warden_state == WardenState.DORMANT:
		start_encounter()
	
	var kb_dir: Vector2 = hit_data.get("knockback_direction") if hit_data.get("knockback_direction") != null else Vector2.RIGHT
	var kb_force: float = hit_data.get("knockback_force") if hit_data.get("knockback_force") != null else contact_knockback_force
	var effective_force := kb_force * (1.0 - clampf(knockback_resistance, 0.0, 1.0))
	velocity.x += kb_dir.x * effective_force
	flash_timer = 0.15
	
	# Boss poise: Preserve active attack hitboxes and state machine during strike execution
	var is_in_attack_action := warden_state in [
		WardenState.SLAM_WINDUP, WardenState.SLAM_IMPACT,
		WardenState.THRUST_WINDUP, WardenState.THRUST_CHARGE,
		WardenState.LEAP_WINDUP, WardenState.LEAP_AIR, WardenState.LEAP_SLAM,
		WardenState.ENRAGING, WardenState.DYING, WardenState.DEAD
	]
	
	if not is_in_attack_action and hitbox:
		hitbox.deactivate()


func respawn() -> void:
	var pd := _get_player_data()
	if (pd and pd.get_flag("boss_warden_defeated", false)) or is_dead:
		is_dead = true
		hide()
		set_physics_process(false)
		if hitbox:
			hitbox.deactivate()
		if hurtbox:
			hurtbox.set_manual_invulnerable(true)
		return
	super.respawn()


# ----------------------------------------------------
# Custom Visual Rendering
# ----------------------------------------------------

func _draw() -> void:
	var base_pos := shake_offset
	var dir_sign := float(facing_direction)
	var is_flashing := flash_timer > 0.0
	
	if warden_state == WardenState.DEAD:
		# Draw fallen stone husk debris
		draw_rect(Rect2(-24.0, -12.0, 48.0, 12.0), COLOR_STONE_ARMOR)
		draw_line(Vector2(-24.0, -6.0), Vector2(24.0, -6.0), COLOR_BRASS_TRIM, 2.0)
		return
	
	# Phase 2 Enraged Occult Aura
	if enraged_aura:
		var aura_radius := 34.0 + sin(aura_pulse) * 4.0
		draw_arc(base_pos + Vector2(0.0, -28.0), aura_radius, 0.0, TAU, 24, COLOR_PURPLE_AURA, 3.0)
		draw_arc(base_pos + Vector2(0.0, -28.0), aura_radius * 0.75, 0.0, TAU, 18, COLOR_CYAN_CORE, 2.0)
	
	# Main Armored Torso
	var armor_color := COLOR_WHITE_FLASH if is_flashing else COLOR_STONE_ARMOR
	var trim_color := COLOR_CYAN_CORE if is_flashing else COLOR_BRASS_TRIM
	
	# Lower legs / tread
	draw_rect(Rect2(base_pos.x - 14.0, base_pos.y - 14.0, 10.0, 14.0), armor_color)
	draw_rect(Rect2(base_pos.x + 4.0, base_pos.y - 14.0, 10.0, 14.0), armor_color)
	draw_line(Vector2(base_pos.x - 14.0, base_pos.y - 1.0), Vector2(base_pos.x - 4.0, base_pos.y - 1.0), trim_color, 2.0)
	draw_line(Vector2(base_pos.x + 4.0, base_pos.y - 1.0), Vector2(base_pos.x + 14.0, base_pos.y - 1.0), trim_color, 2.0)
	
	# Heavy Basalt Cuirass
	var torso_poly := PackedVector2Array([
		base_pos + Vector2(-16.0, -14.0),
		base_pos + Vector2(16.0, -14.0),
		base_pos + Vector2(20.0, -42.0),
		base_pos + Vector2(-20.0, -42.0)
	])
	draw_polygon(torso_poly, [armor_color])
	draw_polyline(torso_poly, trim_color, 2.0)
	
	# Pauldrons
	draw_circle(base_pos + Vector2(-19.0, -38.0), 7.0, armor_color)
	draw_circle(base_pos + Vector2(19.0, -38.0), 7.0, armor_color)
	draw_arc(base_pos + Vector2(-19.0, -38.0), 7.0, 0.0, TAU, 12, trim_color, 1.5)
	draw_arc(base_pos + Vector2(19.0, -38.0), 7.0, 0.0, TAU, 12, trim_color, 1.5)
	
	# Sentry Crested Helm
	var helm_poly := PackedVector2Array([
		base_pos + Vector2(-12.0, -42.0),
		base_pos + Vector2(12.0, -42.0),
		base_pos + Vector2(10.0, -58.0),
		base_pos + Vector2(0.0, -64.0),
		base_pos + Vector2(-10.0, -58.0)
	])
	draw_polygon(helm_poly, [armor_color])
	draw_polyline(helm_poly, trim_color, 2.0)
	
	# Piercing Cyan Visor Slit
	var visor_start := base_pos + Vector2(dir_sign * 2.0, -50.0)
	var visor_end := base_pos + Vector2(dir_sign * 9.0, -50.0)
	draw_line(visor_start, visor_end, COLOR_CYAN_CORE, 3.0)
	
	# Chest Core Occult Eye
	draw_circle(base_pos + Vector2(0.0, -28.0), 5.0, COLOR_CYAN_CORE)
	draw_arc(base_pos + Vector2(0.0, -28.0), 7.0, 0.0, TAU, 12, trim_color, 1.5)
	
	# Great Mace / Executioner Blade Rendering
	_draw_weapon(base_pos, dir_sign)


func _draw_weapon(base_pos: Vector2, dir_sign: float) -> void:
	match warden_state:
		WardenState.SLAM_WINDUP:
			# Raised high overhead
			var hilt := base_pos + Vector2(dir_sign * 8.0, -46.0)
			var tip := base_pos + Vector2(dir_sign * 12.0, -82.0)
			draw_line(hilt, tip, COLOR_BLADE_STEEL, 5.0)
			draw_circle(tip, 9.0, COLOR_BRASS_TRIM)
			draw_circle(tip, 6.0, COLOR_CYAN_CORE)
		
		WardenState.SLAM_IMPACT, WardenState.SLAM_RECOVER:
			# Slammed down into the floor
			var hilt := base_pos + Vector2(dir_sign * 16.0, -24.0)
			var tip := base_pos + Vector2(dir_sign * 32.0, 0.0)
			draw_line(hilt, tip, COLOR_BLADE_STEEL, 6.0)
			draw_circle(tip, 8.0, COLOR_BRASS_TRIM)
			draw_line(tip + Vector2(-10.0, 0.0), tip + Vector2(10.0, 0.0), COLOR_CYAN_CORE, 3.0)
		
		WardenState.THRUST_CHARGE, WardenState.THRUST_WINDUP:
			# Thrust straight forward
			var hilt := base_pos + Vector2(dir_sign * 8.0, -28.0)
			var tip := base_pos + Vector2(dir_sign * 42.0, -28.0)
			draw_line(hilt, tip, COLOR_BLADE_STEEL, 5.0)
			draw_line(tip + Vector2(-8.0 * dir_sign, -6.0), tip, COLOR_CYAN_CORE, 2.5)
			draw_line(tip + Vector2(-8.0 * dir_sign, 6.0), tip, COLOR_CYAN_CORE, 2.5)
		
		_:
			# Resting stance
			var hilt := base_pos + Vector2(dir_sign * 12.0, -26.0)
			var tip := base_pos + Vector2(dir_sign * 16.0, -4.0)
			draw_line(hilt, tip, COLOR_BLADE_STEEL, 4.0)
			draw_circle(tip, 6.0, COLOR_BRASS_TRIM)
