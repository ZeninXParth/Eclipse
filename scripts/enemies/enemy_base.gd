class_name EnemyBase
extends CharacterBody2D

## ECLIPSE: Echoes of the Forgotten
## Base Enemy Architecture & State Machine (Milestone 2)
## Provides standardized health tracking, hurtbox/hitbox configuration,
## directional knockback with resistance, damage flash, state machine lifecycle,
## telegraphing hooks, and edge/wall detection for mobile enemy archetypes.

const HitDataScript = preload("res://scripts/combat/hit_data.gd")
const HealthComponentScript = preload("res://scripts/combat/health_component.gd")
const HurtboxScript = preload("res://scripts/combat/hurtbox.gd")
const HitboxScript = preload("res://scripts/combat/hitbox.gd")

signal state_changed(new_state: EnemyState, old_state: EnemyState)
signal damaged(amount: int, remaining_health: int)
signal died()
signal respawned()
signal telegraph_started(duration: float)
signal attack_performed()

enum EnemyState {
	IDLE,
	PATROL,
	ALERT,
	ATTACK,
	HURT,
	DEAD
}

@export_group("Stats & Combat")
@export var max_health: int = 3
@export var patrol_speed: float = 50.0
@export var contact_damage: int = 1
@export var contact_knockback_force: float = 220.0
@export var knockback_resistance: float = 0.0 # 0.0 = full knockback, 1.0 = immovable
@export var detection_range: float = 160.0
@export var lose_interest_range: float = 260.0
@export var alert_duration: float = 0.35
@export var hurt_duration: float = 0.20
@export var gravity: float = 1200.0
@export var knockback_friction: float = 1200.0
@export var auto_respawn: bool = false
@export var respawn_delay: float = 2.5
@export var currency_reward: int = 2

@export_group("Components")
@export var health_component: HealthComponent
@export var hurtbox: Hurtbox
@export var hurtbox_shape: CollisionShape2D
@export var hitbox: Hitbox
@export var hitbox_shape: CollisionShape2D

var current_state: EnemyState = EnemyState.PATROL
var facing_direction: int = 1 # 1: right, -1: left
var spawn_position: Vector2 = Vector2.ZERO
var target_player: Node2D = null
var state_timer: float = 0.0
var hurt_timer: float = 0.0
var respawn_timer: float = 0.0
var flash_timer: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var is_dead: bool = false

# Edge & wall test simulation hooks
var simulated_edge_detected: bool = false
var simulated_wall_detected: bool = false
var test_override_enabled: bool = false


func _ready() -> void:
	collision_layer = 4 # Layer 3: Enemies
	collision_mask = 1 # Layer 1: World
	spawn_position = global_position
	
	_setup_components()


func _setup_components() -> void:
	# Ensure HealthComponent is present
	if health_component == null:
		health_component = get_node_or_null("HealthComponent") as HealthComponent
		if health_component == null:
			health_component = HealthComponentScript.new()
			health_component.name = "HealthComponent"
			health_component.max_health = max_health
			health_component.default_invulnerability_duration = 0.15
			add_child(health_component)
	
	health_component.max_health = max_health
	health_component.reset_health()
	if not health_component.damaged.is_connected(_on_health_damaged):
		health_component.damaged.connect(_on_health_damaged)
	if not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)
	
	# Ensure Hurtbox is present (receives player attacks)
	if hurtbox == null:
		hurtbox = get_node_or_null("Hurtbox") as Hurtbox
		if hurtbox == null:
			hurtbox = HurtboxScript.new()
			hurtbox.name = "Hurtbox"
			hurtbox.is_player_hurtbox = false
			var h_col := CollisionShape2D.new()
			var h_capsule := CapsuleShape2D.new()
			h_capsule.radius = 12.0
			h_capsule.height = 36.0
			h_col.shape = h_capsule
			h_col.position = Vector2(0.0, -18.0)
			hurtbox.add_child(h_col)
			hurtbox_shape = h_col
			add_child(hurtbox)
		else:
			hurtbox_shape = hurtbox.get_node_or_null("CollisionShape2D")
	
	hurtbox.health_component = health_component
	hurtbox.is_player_hurtbox = false
	hurtbox.collision_layer = 64 # Layer 7: EnemyHurtbox
	hurtbox.collision_mask = 8 # Layer 4: PlayerHitbox
	if not hurtbox.hit_received.is_connected(_on_hurtbox_hit_received):
		hurtbox.hit_received.connect(_on_hurtbox_hit_received)
	
	# Ensure Hitbox is present (damages player)
	if hitbox == null:
		hitbox = get_node_or_null("Hitbox") as Hitbox
		if hitbox == null:
			hitbox = HitboxScript.new()
			hitbox.name = "Hitbox"
			hitbox.is_player_hitbox = false
			var hb_col := CollisionShape2D.new()
			var hb_capsule := CapsuleShape2D.new()
			hb_capsule.radius = 12.0
			hb_capsule.height = 36.0
			hb_col.shape = hb_capsule
			hb_col.position = Vector2(0.0, -18.0)
			hb_col.disabled = true
			hitbox.add_child(hb_col)
			hitbox_shape = hb_col
			add_child(hitbox)
		else:
			hitbox_shape = hitbox.get_node_or_null("CollisionShape2D")
	
	hitbox.is_player_hitbox = false
	hitbox.attacker = self
	hitbox.damage = contact_damage
	hitbox.knockback_force = contact_knockback_force
	hitbox.collision_layer = 32 # Layer 6: EnemyHitbox
	hitbox.collision_mask = 16 # Layer 5: PlayerHurtbox
	hitbox.deactivate()


func _physics_process(delta: float) -> void:
	step_physics(delta)


func step_physics(delta: float) -> void:
	if health_component:
		health_component._tick_invulnerability(delta)
	
	if is_dead:
		if auto_respawn:
			respawn_timer -= delta
			if respawn_timer <= 0.0:
				respawn()
		return
	
	# Update damage flash & micro-shake feedback
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)
		shake_offset = Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0)) * (flash_timer / 0.15)
	else:
		shake_offset = Vector2.ZERO
	
	# Handle Hurt / Stun state
	if current_state == EnemyState.HURT:
		hurt_timer -= delta
		_apply_knockback_friction(delta)
		_apply_gravity(delta)
		if is_inside_tree():
			move_and_slide()
		if hurt_timer <= 0.0:
			_set_state(EnemyState.PATROL)
		queue_redraw()
		return
	
	# Standard state execution
	match current_state:
		EnemyState.IDLE:
			_handle_idle(delta)
		EnemyState.PATROL:
			_handle_patrol(delta)
		EnemyState.ALERT:
			_handle_alert(delta)
		EnemyState.ATTACK:
			_handle_attack(delta)
	
	_apply_gravity(delta)
	
	if is_inside_tree():
		move_and_slide()
	
	queue_redraw()


func _handle_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	state_timer -= delta
	if state_timer <= 0.0:
		_set_state(EnemyState.PATROL)


func _handle_patrol(_delta: float) -> void:
	# Virtual hook for sub-classes
	pass


func _handle_alert(_delta: float) -> void:
	# Virtual hook for sub-classes
	pass


func _handle_attack(_delta: float) -> void:
	# Virtual hook for sub-classes
	pass


func _apply_gravity(delta: float) -> void:
	if gravity > 0.0 and not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = minf(velocity.y, 700.0)


func _apply_knockback_friction(delta: float) -> void:
	var fric := knockback_friction if is_on_floor() else knockback_friction * 0.5
	velocity.x = move_toward(velocity.x, 0.0, fric * delta)


func _set_state(new_state: EnemyState) -> void:
	if current_state == new_state:
		return
	var old_state := current_state
	current_state = new_state
	if old_state == EnemyState.ATTACK and new_state != EnemyState.ATTACK:
		if hitbox:
			hitbox.deactivate()
	state_changed.emit(new_state, old_state)


func get_state_name() -> String:
	match current_state:
		EnemyState.IDLE: return "IDLE"
		EnemyState.PATROL: return "PATROL"
		EnemyState.ALERT: return "ALERT"
		EnemyState.ATTACK: return "ATTACK"
		EnemyState.HURT: return "HURT"
		EnemyState.DEAD: return "DEAD"
		_: return "UNKNOWN"


func _on_hurtbox_hit_received(hit_data: RefCounted) -> void:
	if is_dead:
		return
	
	if hitbox:
		hitbox.deactivate()
	
	var kb_dir: Vector2 = hit_data.get("knockback_direction") if hit_data.get("knockback_direction") != null else Vector2.RIGHT
	var kb_force: float = hit_data.get("knockback_force") if hit_data.get("knockback_force") != null else contact_knockback_force
	var effective_force := kb_force * (1.0 - clampf(knockback_resistance, 0.0, 1.0))
	velocity = kb_dir * effective_force
	flash_timer = 0.15
	
	if health_component and health_component.current_health > 0:
		hurt_timer = hurt_duration
		_set_state(EnemyState.HURT)


func _on_health_damaged(amount: int) -> void:
	damaged.emit(amount, health_component.current_health if health_component else max_health)


func _on_died() -> void:
	is_dead = true
	_set_state(EnemyState.DEAD)
	velocity = Vector2.ZERO
	if hurtbox:
		hurtbox.set_manual_invulnerable(true)
	if hitbox:
		hitbox.deactivate()
	died.emit()
	
	# Award currency if GameManager/PlayerData is active
	var gm_script = load("res://scripts/core/game_manager.gd")
	if gm_script and gm_script.instance and gm_script.instance.player_data:
		gm_script.instance.player_data.add_currency(currency_reward)
	elif is_inside_tree():
		var tree := get_tree()
		if tree and tree.root:
			var gm = tree.root.get_node_or_null("GameManager")
			if gm and gm.get("player_data") != null and gm.player_data != null:
				gm.player_data.add_currency(currency_reward)
	
	if auto_respawn:
		respawn_timer = respawn_delay
	queue_redraw()


func respawn() -> void:
	is_dead = false
	respawn_timer = 0.0
	flash_timer = 0.0
	global_position = spawn_position
	velocity = Vector2.ZERO
	if health_component:
		health_component.reset_health()
	if hurtbox:
		hurtbox.set_manual_invulnerable(false)
	if hitbox:
		hitbox.deactivate()
	_set_state(EnemyState.PATROL)
	respawned.emit()
	queue_redraw()


func turn_around() -> void:
	facing_direction = -facing_direction


func find_player_target() -> Node2D:
	if target_player != null and is_instance_valid(target_player):
		return target_player
	
	if is_inside_tree():
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0] as Node2D
			return target_player
		
		# Fallback: search root/scene for node named "Player"
		var scene_root := get_tree().current_scene
		if scene_root != null:
			var p := scene_root.get_node_or_null("Player") as Node2D
			if p != null:
				target_player = p
				return target_player
	return null


func distance_to_target() -> float:
	var target := find_player_target()
	if target == null:
		return 999999.0
	return global_position.distance_to(target.global_position)


func has_wall_ahead() -> bool:
	if test_override_enabled:
		return simulated_wall_detected
	return is_on_wall() and (get_wall_normal().x * float(facing_direction) < -0.1)


func has_edge_ahead() -> bool:
	if test_override_enabled:
		return simulated_edge_detected
	
	# Raycast / Physics check ahead of feet
	if is_inside_tree():
		var space_state := get_world_2d().direct_space_state
		var ahead_x := global_position.x + float(facing_direction) * 18.0
		var foot_y := global_position.y + 2.0
		var query := PhysicsRayQueryParameters2D.create(
			Vector2(ahead_x, foot_y),
			Vector2(ahead_x, foot_y + 24.0),
			1 # Layer 1: World
		)
		var result := space_state.intersect_ray(query)
		# If no solid ground detected directly ahead, edge is reached
		return result.is_empty()
	return false
