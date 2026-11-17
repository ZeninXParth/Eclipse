extends SceneTree

## ECLIPSE: Echoes of the Forgotten
## Milestone 2 Verification Suite (Soul / Focus Healing System & Mobile Enemy Framework)
## Verifies that Soul accumulation, Focus vulnerable channel healing, interruption guards,
## and Walker / Flyer / Charger enemy archetypes execute with deterministic precision.

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const PlayerVisualsScript = preload("res://scripts/player/player_visuals.gd")
const PlayerConfigScript = preload("res://scripts/player/player_config.gd")
const HealthComponentScript = preload("res://scripts/combat/health_component.gd")
const HurtboxScript = preload("res://scripts/combat/hurtbox.gd")
const HitboxScript = preload("res://scripts/combat/hitbox.gd")
const HitDataScript = preload("res://scripts/combat/hit_data.gd")
const EnemyBaseScript = preload("res://scripts/enemies/enemy_base.gd")
const WalkerEnemyScript = preload("res://scripts/enemies/walker_enemy.gd")
const FlyerEnemyScript = preload("res://scripts/enemies/flyer_enemy.gd")
const ChargerEnemyScript = preload("res://scripts/enemies/charger_enemy.gd")
const TrainingDummyScript = preload("res://scripts/enemies/training_dummy.gd")
const HazardZoneScript = preload("res://scripts/combat/hazard_zone.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING ECLIPSE M2 COMBAT CORE & ENEMY TEST SUITE")
	print("  Godot Engine: ", Engine.get_version_info().string)
	print("========================================================\n")
	
	call_deferred("_run_all_tests_async")


func assert_true(condition: bool, test_name: String, details: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		var msg := "%s : %s" % [test_name, details]
		failures.append(msg)
		print("  [FAIL] %s" % msg)


func assert_approx_equal(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	var diff := absf(actual - expected)
	var cond := diff <= tolerance
	assert_true(cond, test_name, "Expected ~%f, got %f (diff: %f > %f)" % [expected, actual, diff, tolerance])


func create_test_player() -> PlayerController:
	var player := PlayerControllerScript.new()
	player.input_override_enabled = true
	
	var col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 10.0
	cap.height = 40.0
	col.shape = cap
	player.add_child(col)
	player.collision_shape = col
	
	var visuals := PlayerVisualsScript.new()
	visuals.controller = player
	player.add_child(visuals)
	player.visuals_node = visuals
	
	player._ready()
	player.recalculate_physics_constants()
	return player


func create_test_dummy() -> TrainingDummy:
	var dummy := TrainingDummyScript.new()
	
	var col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 12.0
	cap.height = 44.0
	col.shape = cap
	dummy.add_child(col)
	
	var health := HealthComponentScript.new()
	health.name = "HealthComponent"
	health.max_health = 4
	health.default_invulnerability_duration = 0.15
	dummy.add_child(health)
	dummy.health_component = health
	
	var hurt := HurtboxScript.new()
	hurt.name = "Hurtbox"
	hurt.health_component = health
	var h_col := CollisionShape2D.new()
	var h_cap := CapsuleShape2D.new()
	h_cap.radius = 14.0
	h_cap.height = 46.0
	h_col.shape = h_cap
	hurt.add_child(h_col)
	dummy.add_child(hurt)
	dummy.hurtbox = hurt
	
	dummy._ready()
	return dummy


func _run_all_tests_async() -> void:
	await _test_soul_resource_accumulation()
	await _test_focus_channel_prerequisites()
	await _test_focus_interruption_safeguards()
	await _test_focus_completion_and_healing()
	await _test_enemy_base_framework()
	await _test_walker_enemy_archetype()
	await _test_flyer_enemy_archetype()
	await _test_charger_enemy_archetype()
	await _test_combat_arena_scene_integration()
	
	print("\n========================================================")
	print("  M2 COMBAT CORE & ENEMY TEST RESULTS SUMMARY:")
	print("  Total Tests:  %d" % total_tests)
	print("  Passed:       %d" % passed_tests)
	print("  Failed:       %d" % failed_tests)
	if failed_tests == 0:
		print("  ALL M2 COMBAT CORE TESTS PASSED SUCCESSFULLY!")
	else:
		print("  FAILURES DETECTED (%d):" % failed_tests)
		for f in failures:
			print("    - %s" % f)
	print("========================================================\n")
	
	quit(0 if failed_tests == 0 else 1)


func _test_soul_resource_accumulation() -> void:
	print("\n--- Test Suite 1: Soul / Aether Resource Pool & Accumulation ---")
	var player := create_test_player()
	var dummy := create_test_dummy()
	root.add_child(player)
	root.add_child(dummy)
	
	assert_true(player.get_current_soul() == 0, "Player starts with 0 soul by default")
	assert_true(player.get_max_soul() == 99, "Max soul capacity defaults to 99")
	assert_true(player.soul_per_hit == 11, "Soul per hit defaults to 11")
	assert_true(player.get_soul_heal_cost() == 33, "Soul heal cost defaults to 33 (1 charge)")
	
	var soul_signal_record: Array[int] = [0]
	player.soul_changed.connect(func(cur: int, _max_s: int):
		soul_signal_record[0] = cur
	)
	
	# Land a melee hit on dummy
	dummy.global_position = Vector2(24, 0)
	player.hitbox.activate(Vector2.RIGHT, false)
	player.hitbox._on_area_entered(dummy.hurtbox)
	
	assert_true(player.get_current_soul() == 11, "Landing melee hit adds exactly 11 soul", "Got: %d" % player.get_current_soul())
	assert_true(soul_signal_record[0] == 11, "soul_changed signal emitted with 11 soul")
	
	# Confirm i-frames reject rapid sub-tick hits before expiration
	player.hitbox.deactivate()
	player.hitbox.activate(Vector2.RIGHT, false)
	player.hitbox._on_area_entered(dummy.hurtbox)
	assert_true(player.get_current_soul() == 11, "Hit rejected during active i-frames without awarding soul")
	
	# Naturally tick dummy invulnerability to expiry (0.15s + margin)
	dummy.health_component._tick_invulnerability(0.20)
	assert_true(not dummy.health_component.is_invulnerable, "Dummy i-frames naturally expired after tick")
	
	# Consecutive hit once i-frames expire
	player.hitbox.deactivate()
	player.hitbox.activate(Vector2.RIGHT, false)
	player.hitbox._on_area_entered(dummy.hurtbox)
	assert_true(player.get_current_soul() == 22, "Second hit accumulates to 22 soul once i-frames expire")
	
	# Third hit brings soul to 33 (full heal charge)
	dummy.health_component._tick_invulnerability(0.20)
	player.hitbox.deactivate()
	player.hitbox.activate(Vector2.RIGHT, false)
	player.hitbox._on_area_entered(dummy.hurtbox)
	assert_true(player.get_current_soul() == 33, "Third hit accumulates to 33 soul (1 full heal charge)")
	
	# Accumulate up to max soul (99)
	for i in range(10):
		player.add_soul(11)
	
	assert_true(player.get_current_soul() == 99, "Soul caps cleanly at max_soul (99) without overflowing", "Got: %d" % player.get_current_soul())
	
	# Extra hit does not exceed 99
	player.add_soul(11)
	assert_true(player.get_current_soul() == 99, "Subsequent hits clamped at 99")
	
	# Pogoing an enemy adds soul
	player.current_soul = 0
	dummy.health_component.current_health = 4
	dummy.health_component._tick_invulnerability(0.20)
	player.hitbox.deactivate()
	player.hitbox.activate(Vector2.DOWN, true)
	player.hitbox._on_area_entered(dummy.hurtbox)
	assert_true(player.get_current_soul() == 11, "Down-slash pogo on enemy adds 11 soul")
	
	# Down-slashing a pogo hazard does NOT award soul
	var hazard := HazardZoneScript.new()
	root.add_child(hazard)
	player.current_soul = 0
	player.hitbox.deactivate()
	player.hitbox.activate(Vector2.DOWN, true)
	player.hitbox._on_area_entered(hazard)
	assert_true(player.get_current_soul() == 0, "Down-slash on pogo hazard awards 0 soul (no farming)")
	hazard.queue_free()
	
	# Clean up
	player.queue_free()
	dummy.queue_free()
	await process_frame


func _test_focus_channel_prerequisites() -> void:
	print("\n--- Test Suite 2: Focus Healing Prerequisites & Permissions ---")
	var player := create_test_player()
	root.add_child(player)
	
	# Setup grounded stationary player
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player.velocity = Vector2.ZERO
	player.current_state = PlayerControllerScript.State.IDLE
	
	# 1. At full health (5/5)
	player.current_soul = 99
	assert_true(player.get_current_health() == 5, "Player at full health")
	assert_true(not player.can_focus(), "Cannot focus while at full health (5/5)")
	
	# Damage player to 4/5
	player.health_component.current_health = 4
	assert_true(player.can_focus(), "Can focus when damaged (4/5) and possessing sufficient soul (99)")
	
	# 2. Insufficient soul (< 33)
	player.current_soul = 32
	assert_true(not player.can_focus(), "Cannot focus with insufficient soul (32 < 33)")
	
	player.current_soul = 33
	assert_true(player.can_focus(), "Can focus with exactly 33 soul")
	
	# 3. Airborne prohibition
	player.simulated_on_floor = false
	assert_true(not player.can_focus(), "Cannot focus while airborne")
	player.simulated_on_floor = true
	
	# 4. Moving horizontally prohibition
	player.velocity.x = 80.0
	assert_true(not player.can_focus(), "Cannot focus while moving with horizontal velocity")
	player.velocity.x = 0.0
	
	player.simulated_move_axis = 1.0
	assert_true(not player.can_focus(), "Cannot focus while pressing horizontal directional input")
	player.simulated_move_axis = 0.0
	
	# 5. Dash state prohibition
	player.current_state = PlayerControllerScript.State.DASH
	assert_true(not player.can_focus(), "Cannot focus while in DASH state")
	player.current_state = PlayerControllerScript.State.IDLE
	
	# 6. Knockback stun prohibition
	player.knockback_timer = 0.15
	assert_true(not player.can_focus(), "Cannot focus while in knockback stun")
	player.knockback_timer = 0.0
	
	# 7. Attack state prohibition
	player.current_attack_state = PlayerControllerScript.AttackState.ACTIVE
	assert_true(not player.can_focus(), "Cannot focus while actively attacking")
	player.current_attack_state = PlayerControllerScript.AttackState.NONE
	
	# Successful initiation
	var focus_started_record: Array[bool] = [false]
	player.focus_started.connect(func(): focus_started_record[0] = true)
	
	player.simulated_focus_pressed = true
	player.simulated_focus_held = true
	player._physics_process(0.016)
	
	assert_true(player.current_state == PlayerControllerScript.State.FOCUS, "Player entered State.FOCUS")
	assert_true(player.is_focusing(), "is_focusing() returns true")
	assert_true(focus_started_record[0], "focus_started signal was emitted")
	assert_true(player.velocity.x == 0.0, "Horizontal velocity clamped to 0 while focusing")
	
	player.queue_free()
	await process_frame


func _test_focus_interruption_safeguards() -> void:
	print("\n--- Test Suite 3: Focus Interruption Safeguards ---")
	var player := create_test_player()
	root.add_child(player)
	
	# 1. Early release interruption
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player.health_component.current_health = 3
	player.current_soul = 66
	player.start_focus()
	
	var interrupted_record: Array[bool] = [false]
	player.focus_interrupted.connect(func(): interrupted_record[0] = true)
	
	# Channel for half duration
	player.simulated_focus_held = true
	player._physics_process(0.30)
	assert_true(player.focus_timer > 0.25, "Focus timer advanced during held channel")
	assert_true(player.get_current_soul() == 66, "Soul not consumed during channeling")
	
	# Release focus early
	player.simulated_focus_held = false
	player._physics_process(0.016)
	
	assert_true(player.current_state == PlayerControllerScript.State.IDLE, "Player returned to State.IDLE on early release")
	assert_true(interrupted_record[0], "focus_interrupted signal emitted on early release")
	assert_true(player.get_current_soul() == 66, "Soul NOT consumed on early release (remains 66)")
	assert_true(player.get_current_health() == 3, "Health NOT healed on early release (remains 3)")
	assert_true(player.focus_timer == 0.0, "Focus timer reset to 0.0")
	
	# 2. Movement interruption
	interrupted_record[0] = false
	player.start_focus()
	player.simulated_focus_held = true
	player.simulated_move_axis = 1.0 # Press right
	player._physics_process(0.016)
	assert_true(not player.is_focusing(), "Pressing move direction interrupted focus")
	assert_true(interrupted_record[0], "focus_interrupted emitted on move input")
	player.simulated_move_axis = 0.0
	
	# 3. Jump interruption
	interrupted_record[0] = false
	player.start_focus()
	player.simulated_focus_held = true
	player.simulated_jump_pressed = true
	player._physics_process(0.016)
	assert_true(not player.is_focusing(), "Pressing jump interrupted focus")
	assert_true(interrupted_record[0], "focus_interrupted emitted on jump input")
	player.simulated_jump_pressed = false
	
	# 4. Dash interruption
	interrupted_record[0] = false
	player.start_focus()
	player.simulated_focus_held = true
	player.simulated_dash_pressed = true
	player._physics_process(0.016)
	assert_true(not player.is_focusing(), "Pressing dash interrupted focus")
	assert_true(interrupted_record[0], "focus_interrupted emitted on dash input")
	player.simulated_dash_pressed = false
	
	# 5. Loss of ground contact interruption
	interrupted_record[0] = false
	player.start_focus()
	player.simulated_focus_held = true
	player.simulated_on_floor = false # Ground drops out
	player._physics_process(0.016)
	assert_true(player.current_state == PlayerControllerScript.State.FALL, "Losing ground contact interrupted focus and entered FALL")
	assert_true(interrupted_record[0], "focus_interrupted emitted on ground loss")
	player.simulated_on_floor = true
	
	# 6. Damage interruption
	interrupted_record[0] = false
	player.start_focus()
	player.simulated_focus_held = true
	player._physics_process(0.20)
	
	# Enemy strikes player
	var hit := HitDataScript.new(1, Vector2.LEFT, 200.0)
	player.hurtbox.receive_hit(hit)
	
	assert_true(player.current_state == PlayerControllerScript.State.FALL, "Taking damage transitions focus to FALL state with knockback")
	assert_true(interrupted_record[0], "focus_interrupted emitted upon taking damage")
	assert_true(player.get_current_soul() == 66, "Soul preserved without loss on damage interruption")
	assert_true(player.get_current_health() == 2, "Player took 1 damage (HP dropped from 3 to 2)")
	assert_true(player.knockback_timer > 0.0, "Knockback stun active")
	
	# 7. Fatal damage interruption
	interrupted_record[0] = false
	player.knockback_timer = 0.0
	player.health_component._tick_invulnerability(1.10)
	player.health_component.current_health = 1
	player.simulated_on_floor = true
	player.current_state = PlayerControllerScript.State.IDLE
	player.start_focus()
	player.simulated_focus_held = true
	var fatal_hit := HitDataScript.new(1, Vector2.LEFT, 100.0)
	player.hurtbox.receive_hit(fatal_hit)
	assert_true(interrupted_record[0], "focus_interrupted emitted upon taking fatal damage")
	assert_true(player.current_state == PlayerControllerScript.State.IDLE, "Player cleanly respawned to IDLE after fatal interruption")
	
	player.queue_free()
	await process_frame


func _test_focus_completion_and_healing() -> void:
	print("\n--- Test Suite 4: Focus Channel Completion, Healing & Chaining ---")
	var player := create_test_player()
	root.add_child(player)
	
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player.health_component.current_health = 3
	player.current_soul = 66 # Exactly 2 charges
	
	var completed_record: Array[bool] = [false]
	var soul_reduced_record: Array[bool] = [false]
	var health_healed_record: Array[bool] = [false]
	
	player.focus_completed.connect(func(): completed_record[0] = true)
	player.soul_changed.connect(func(_c, _m): soul_reduced_record[0] = true)
	player.health_component.healed.connect(func(_amt): health_healed_record[0] = true)
	
	player.start_focus()
	player.simulated_focus_held = true
	
	# Tick through focus_charge_duration (0.85s)
	var steps := int(ceil(player.focus_charge_duration / 0.016)) + 2
	for i in range(steps):
		player._physics_process(0.016)
		if completed_record[0]:
			break
	
	assert_true(completed_record[0], "focus_completed signal emitted upon reaching full duration")
	assert_true(player.get_current_soul() == 33, "Exactly 33 soul consumed (66 -> 33)", "Got: %d" % player.get_current_soul())
	assert_true(player.get_current_health() == 4, "Exactly 1 health mask healed (3 -> 4)", "Got: %d" % player.get_current_health())
	assert_true(soul_reduced_record[0], "soul_changed signal emitted on consumption")
	assert_true(health_healed_record[0], "healed signal emitted on health restoration")
	
	# Released button exits to IDLE
	player.simulated_focus_held = false
	player._physics_process(0.016)
	assert_true(player.current_state == PlayerControllerScript.State.IDLE, "Player transitioned to IDLE after releasing focus")
	
	# Chained Focus: Hold button continuously to heal second mask
	completed_record[0] = false
	player.start_focus()
	player.simulated_focus_held = true
	
	for i in range(steps):
		player._physics_process(0.016)
		if completed_record[0]:
			break
	
	assert_true(completed_record[0], "Second consecutive focus heal completed")
	assert_true(player.get_current_soul() == 0, "Second 33 soul consumed (33 -> 0)")
	assert_true(player.get_current_health() == 5, "Second mask healed to full (4 -> 5)")
	
	# At full health (5/5), focus automatically terminates even if button is held
	player._physics_process(0.016)
	assert_true(player.current_state == PlayerControllerScript.State.IDLE, "Focus cleanly terminates when full health is reached")
	
	player.queue_free()
	await process_frame


func _test_enemy_base_framework() -> void:
	print("\n--- Test Suite 5: Reusable Enemy Framework Base & Architecture ---")
	var enemy := EnemyBaseScript.new()
	root.add_child(enemy)
	enemy._ready()
	
	assert_true(enemy.health_component != null, "EnemyBase instantiates HealthComponent")
	assert_true(enemy.hurtbox != null, "EnemyBase instantiates Hurtbox")
	assert_true(enemy.hitbox != null, "EnemyBase instantiates Hitbox")
	assert_true(enemy.collision_layer == 4, "EnemyBase on Layer 3 (Enemies = 4)")
	assert_true(enemy.hurtbox.collision_layer == 64, "Hurtbox on Layer 7 (EnemyHurtbox = 64)")
	assert_true(enemy.hurtbox.collision_mask == 8, "Hurtbox listens to Layer 4 (PlayerHitbox = 8)")
	assert_true(enemy.hitbox.collision_layer == 32, "Hitbox on Layer 6 (EnemyHitbox = 32)")
	assert_true(enemy.hitbox.collision_mask == 16, "Hitbox listens to Layer 5 (PlayerHurtbox = 16)")
	assert_true(enemy.current_state == EnemyBaseScript.EnemyState.PATROL, "Enemy starts in PATROL state")
	
	# Damage resolution & knockback
	var enemy_damaged_record: Array[bool] = [false]
	enemy.damaged.connect(func(_amt, _rem): enemy_damaged_record[0] = true)
	
	var hit := HitDataScript.new(1, Vector2.RIGHT, 200.0)
	enemy.hurtbox.receive_hit(hit)
	
	assert_true(enemy.health_component.current_health == 2, "Enemy took 1 damage (HP: 2/3)")
	assert_true(enemy_damaged_record[0], "damaged signal emitted")
	assert_true(enemy.velocity.x == 200.0, "Full directional knockback velocity applied")
	assert_true(enemy.flash_timer == 0.15, "Hit flash timer initialized")
	assert_true(enemy.current_state == EnemyBaseScript.EnemyState.HURT, "Enemy entered HURT state")
	
	# Knockback friction
	enemy.step_physics(0.10)
	assert_true(enemy.velocity.x < 200.0, "Knockback friction decelerates velocity")
	
	# Hurt timer expires back to PATROL and i-frames expire
	enemy.step_physics(0.15)
	assert_true(enemy.current_state == EnemyBaseScript.EnemyState.PATROL, "Enemy returns to PATROL after hurt duration")
	
	# Knockback resistance test
	enemy.knockback_resistance = 0.5 # 50% resistance
	var hit2 := HitDataScript.new(1, Vector2.RIGHT, 200.0)
	enemy.hurtbox.receive_hit(hit2)
	assert_approx_equal(enemy.velocity.x, 100.0, 1.0, "Knockback resistance reduces knockback velocity to 50% (100 px/s)")
	
	# Step through remaining hurt
	enemy.step_physics(0.25)
	
	# Fatal blow & death state
	var died_record: Array[bool] = [false]
	enemy.died.connect(func(): died_record[0] = true)
	var fatal_hit := HitDataScript.new(5, Vector2.RIGHT, 100.0)
	enemy.hurtbox.receive_hit(fatal_hit)
	
	assert_true(enemy.is_dead, "Enemy marked is_dead")
	assert_true(enemy.current_state == EnemyBaseScript.EnemyState.DEAD, "Enemy entered DEAD state")
	assert_true(died_record[0], "died signal emitted on 0 HP")
	assert_true(not enemy.hurtbox.can_receive_hit(), "Dead enemy hurtbox rejects subsequent hits")
	assert_true(not enemy.hitbox.is_active, "Dead enemy hitbox deactivated")
	
	# Hitbox deactivation on hurt test
	var enemy2 := EnemyBaseScript.new()
	root.add_child(enemy2)
	enemy2._ready()
	enemy2.current_state = EnemyBaseScript.EnemyState.ATTACK
	enemy2.hitbox.activate(Vector2.RIGHT)
	assert_true(enemy2.hitbox.is_active, "Enemy hitbox is active during ATTACK")
	var disrupt_hit := HitDataScript.new(1, Vector2.LEFT, 100.0)
	enemy2.hurtbox.receive_hit(disrupt_hit)
	assert_true(not enemy2.hitbox.is_active, "Enemy hitbox immediately deactivated upon taking damage")
	enemy2.step_physics(0.25)
	assert_true(enemy2.current_state == EnemyBaseScript.EnemyState.PATROL, "Enemy returned to PATROL")
	assert_true(not enemy2.hitbox.is_active, "Enemy hitbox remains deactivated throughout PATROL")
	enemy2.queue_free()
	
	enemy.queue_free()
	await process_frame


func _test_walker_enemy_archetype() -> void:
	print("\n--- Test Suite 6: Walker Archetype (Scavenger Husk) ---")
	var walker := WalkerEnemyScript.new()
	walker.test_override_enabled = true
	root.add_child(walker)
	walker._ready()
	
	assert_true(walker.patrol_speed == 50.0, "Walker patrol speed is 50 px/s")
	assert_true(walker.lunge_speed == 180.0, "Walker lunge speed is 180 px/s")
	assert_true(walker.facing_direction == 1, "Starts facing right")
	
	# 1. Patrol movement
	walker.step_physics(0.016)
	assert_approx_equal(walker.velocity.x, 50.0, 1.0, "Walker moves rightward in PATROL state")
	
	# 2. Edge / Ledge Turnaround
	walker.simulated_edge_detected = true
	walker.step_physics(0.016)
	assert_true(walker.facing_direction == -1, "Walker turns around when edge/ledge detected ahead")
	assert_approx_equal(walker.velocity.x, -50.0, 1.0, "Walker velocity flips to leftward (-50 px/s)")
	walker.simulated_edge_detected = false
	
	# 3. Wall Turnaround
	walker.simulated_wall_detected = true
	walker.step_physics(0.016)
	assert_true(walker.facing_direction == 1, "Walker turns around when wall detected ahead")
	assert_approx_equal(walker.velocity.x, 50.0, 1.0, "Walker velocity flips back to rightward (+50 px/s)")
	walker.simulated_wall_detected = false
	
	# 4. Player Detection & Alert Telegraph
	var mock_player := Node2D.new()
	mock_player.global_position = walker.global_position + Vector2(100, 0)
	root.add_child(mock_player)
	walker.target_player = mock_player
	
	var telegraph_record: Array[bool] = [false]
	walker.telegraph_started.connect(func(_dur): telegraph_record[0] = true)
	
	walker.step_physics(0.016)
	assert_true(walker.current_state == EnemyBaseScript.EnemyState.ALERT, "Walker entered ALERT state on spotting player")
	assert_true(telegraph_record[0], "telegraph_started signal emitted")
	assert_true(walker.velocity.x == 0.0, "Walker stops moving during alert telegraph")
	
	# 5. Alert completes and unleashes lunge attack
	var attack_performed_record: Array[bool] = [false]
	walker.attack_performed.connect(func(): attack_performed_record[0] = true)
	
	walker.step_physics(walker.alert_duration + 0.01)
	assert_true(walker.current_state == EnemyBaseScript.EnemyState.ATTACK, "Walker entered ATTACK state")
	assert_true(attack_performed_record[0], "attack_performed signal emitted")
	assert_approx_equal(walker.velocity.x, 180.0, 2.0, "Walker lunges forward at lunge_speed (180 px/s)")
	assert_true(walker.hitbox.is_active, "Hitbox is active during lunge")
	
	# 6. Lunge completes and enters recovery
	walker.step_physics(walker.lunge_duration + 0.01)
	assert_true(not walker.hitbox.is_active, "Hitbox deactivated after lunge")
	assert_true(walker.current_state == EnemyBaseScript.EnemyState.IDLE, "Walker entered IDLE recovery")
	
	# 7. Player Pogo Rebound on Walker
	var player := create_test_player()
	root.add_child(player)
	player.global_position = walker.global_position + Vector2(0, -30)
	
	var pogo_record: Array[bool] = [false]
	player.pogo_bounced.connect(func(): pogo_record[0] = true)
	
	walker.health_component.is_invulnerable = false
	player.current_attack_direction = PlayerControllerScript.AttackDirection.DOWN
	player.hitbox.activate(Vector2.DOWN, true)
	player.hitbox._on_area_entered(walker.hurtbox)
	
	assert_true(pogo_record[0], "Player down-slash on Walker triggers pogo_bounced signal")
	assert_approx_equal(player.velocity.y, player.pogo_bounce_velocity, 1.0, "Player upward pogo bounce (-460 px/s) applied")
	assert_true(player.get_current_soul() == 11, "Player gains 11 soul from striking Walker")
	
	player.queue_free()
	mock_player.queue_free()
	walker.queue_free()
	await process_frame


func _test_flyer_enemy_archetype() -> void:
	print("\n--- Test Suite 7: Flyer Archetype (Gloom Bat / Swooper) ---")
	var flyer := FlyerEnemyScript.new()
	flyer.test_override_enabled = true
	root.add_child(flyer)
	flyer._ready()
	
	assert_true(flyer.gravity == 0.0, "Flyer has 0 gravity (aerial hovering)")
	assert_true(flyer.patrol_speed == 40.0, "Flyer patrol drift speed is 40 px/s")
	assert_true(flyer.dive_speed == 220.0, "Flyer dive speed is 220 px/s")
	
	# 1. Sinusoidal hover bobbing
	flyer.step_physics(0.10)
	assert_true(flyer.velocity.y != 0.0, "Flyer executes vertical sinusoidal hover bobbing")
	assert_approx_equal(flyer.velocity.x, 40.0, 1.0, "Flyer drifts horizontally in patrol")
	
	# 2. Player detection below triggers ALERT
	var mock_player := Node2D.new()
	mock_player.global_position = flyer.global_position + Vector2(60, 100) # Below and forward
	root.add_child(mock_player)
	flyer.target_player = mock_player
	
	var alert_record: Array[bool] = [false]
	flyer.telegraph_started.connect(func(_dur): alert_record[0] = true)
	flyer.step_physics(0.016)
	
	assert_true(flyer.current_state == EnemyBaseScript.EnemyState.ALERT, "Flyer entered ALERT state on spotting player below")
	assert_true(alert_record[0], "telegraph_started signal emitted")
	
	# 3. Transition to ATTACK (Downward dive swoop)
	var attack_record: Array[bool] = [false]
	flyer.attack_performed.connect(func(): attack_record[0] = true)
	
	flyer.step_physics(flyer.alert_duration + 0.01)
	assert_true(flyer.current_state == EnemyBaseScript.EnemyState.ATTACK, "Flyer entered ATTACK state (Swoop)")
	assert_true(attack_record[0], "attack_performed signal emitted")
	assert_true(flyer.velocity.y > 100.0, "Flyer diving rapidly downward (velocity.y > 100)")
	assert_true(flyer.hitbox.is_active, "Hitbox is active during dive swoop")
	
	# 4. Passing dive depth initiates climb recovery
	flyer.global_position.y = mock_player.global_position.y + 10.0
	flyer.step_physics(0.016)
	assert_true(flyer.swoop_phase == 1, "Flyer transitioned to climb recovery phase")
	assert_true(not flyer.hitbox.is_active, "Hitbox deactivated during climb recovery")
	
	# 5. Aerial Pogo Rebound on Flyer
	var player := create_test_player()
	root.add_child(player)
	player.global_position = flyer.global_position + Vector2(0, -25)
	
	var pogo_record: Array[bool] = [false]
	player.pogo_bounced.connect(func(): pogo_record[0] = true)
	
	flyer.health_component.is_invulnerable = false
	player.current_attack_direction = PlayerControllerScript.AttackDirection.DOWN
	player.hitbox.activate(Vector2.DOWN, true)
	player.hitbox._on_area_entered(flyer.hurtbox)
	
	assert_true(pogo_record[0], "Player down-slash on Flyer triggers pogo bounce")
	assert_approx_equal(player.velocity.y, player.pogo_bounce_velocity, 1.0, "Upward pogo bounce velocity (-460 px/s) applied")
	assert_true(player.get_current_soul() == 11, "Player gains 11 soul from aerial pogo hit")
	
	player.queue_free()
	mock_player.queue_free()
	await process_frame
	
	# 6. Flyer roost altitude recovery after downward disruption
	flyer.target_player = null
	flyer.velocity = Vector2.ZERO
	flyer.hurt_timer = 0.0
	flyer.global_position = flyer.home_position + Vector2(0, 80) # Disrupted 80px below roost
	flyer.current_state = EnemyBaseScript.EnemyState.PATROL
	for s in range(60):
		flyer.step_physics(0.016)
		flyer.global_position += flyer.velocity * 0.016
	assert_true(flyer.global_position.y < flyer.home_position.y + 25.0, "Flyer steered upward back toward roost altitude")
	
	flyer.queue_free()
	await process_frame


func _test_charger_enemy_archetype() -> void:
	print("\n--- Test Suite 8: Charger Archetype (Armored Beetle) ---")
	var charger := ChargerEnemyScript.new()
	charger.test_override_enabled = true
	root.add_child(charger)
	charger._ready()
	
	assert_true(charger.max_health == 6, "Charger has 6 health (heavy armor)")
	assert_true(charger.knockback_resistance == 0.50, "Charger has 50% knockback resistance")
	assert_true(charger.charge_speed == 280.0, "Charger charge speed is 280 px/s")
	
	# 1. Knockback absorption
	var hit := HitDataScript.new(1, Vector2.RIGHT, 240.0)
	charger.hurtbox.receive_hit(hit)
	assert_approx_equal(charger.velocity.x, 120.0, 1.0, "Charger absorbs 50% knockback force (120 px/s)")
	charger.step_physics(0.20)
	
	# 2. Player detection triggers ALERT roar telegraph
	var mock_player := Node2D.new()
	mock_player.global_position = charger.global_position + Vector2(120, 0)
	root.add_child(mock_player)
	charger.target_player = mock_player
	
	var alert_record: Array[bool] = [false]
	charger.telegraph_started.connect(func(_dur): alert_record[0] = true)
	charger.step_physics(0.016)
	
	assert_true(charger.current_state == EnemyBaseScript.EnemyState.ALERT, "Charger entered ALERT wind-up state")
	assert_true(alert_record[0], "telegraph_started signal emitted")
	assert_true(charger.velocity.x == 0.0, "Charger pauses in place during wind-up")
	
	# 3. Alert completes and accelerates into rapid charge
	var attack_record: Array[bool] = [false]
	charger.attack_performed.connect(func(): attack_record[0] = true)
	charger.step_physics(charger.alert_duration + 0.01)
	
	assert_true(charger.current_state == EnemyBaseScript.EnemyState.ATTACK, "Charger entered ATTACK state (Charge!)")
	assert_true(attack_record[0], "attack_performed emitted")
	assert_approx_equal(charger.velocity.x, 280.0, 2.0, "Charger velocity equals charge_speed (280 px/s)")
	assert_true(charger.hitbox.is_active, "Hitbox is active with high contact damage")
	
	# 4. Wall Impact triggers Wall Slam Stun
	var wall_slam_record: Array[bool] = [false]
	charger.wall_slammed.connect(func(): wall_slam_record[0] = true)
	
	charger.simulated_wall_detected = true
	charger.step_physics(0.016)
	
	assert_true(wall_slam_record[0], "wall_slammed signal emitted on wall impact")
	assert_true(charger.is_wall_stunned, "Charger enters is_wall_stunned state")
	assert_true(not charger.hitbox.is_active, "Hitbox deactivated upon wall slam")
	assert_true(charger.current_state == EnemyBaseScript.EnemyState.IDLE, "Charger entered IDLE stun opening")
	assert_true(charger.facing_direction == -1, "Charger turned around away from wall")
	
	# 5. Player down-slash pogo bounce over Charger
	var player := create_test_player()
	root.add_child(player)
	player.global_position = charger.global_position + Vector2(0, -25)
	
	var pogo_record: Array[bool] = [false]
	player.pogo_bounced.connect(func(): pogo_record[0] = true)
	
	charger.health_component.is_invulnerable = false
	player.current_attack_direction = PlayerControllerScript.AttackDirection.DOWN
	player.hitbox.activate(Vector2.DOWN, true)
	player.hitbox._on_area_entered(charger.hurtbox)
	
	assert_true(pogo_record[0], "Player down-slash pogos off Charger carapace")
	assert_approx_equal(player.velocity.y, player.pogo_bounce_velocity, 1.0, "Player bounces upward (-460 px/s)")
	assert_true(player.get_current_soul() == 11, "Player gains 11 soul from striking Charger")
	
	# 6. Charger respawn clears wall-stun flag
	charger.is_wall_stunned = true
	charger.health_component._tick_invulnerability(0.25)
	var fatal_charger_hit := HitDataScript.new(10, Vector2.RIGHT, 100.0)
	charger.hurtbox.receive_hit(fatal_charger_hit)
	assert_true(charger.is_dead, "Charger killed while wall-stunned")
	charger.respawn()
	assert_true(not charger.is_wall_stunned, "Charger wall-stun flag cleared upon respawn")
	
	player.queue_free()
	mock_player.queue_free()
	charger.queue_free()
	await process_frame


func _test_combat_arena_scene_integration() -> void:
	print("\n--- Test Suite 9: Combat Arena Scene Deep Integration ---")
	var scene_res := load("res://scenes/levels/combat_room.tscn") as PackedScene
	assert_true(scene_res != null, "combat_room.tscn loads successfully")
	
	var combat_room := scene_res.instantiate() as Node2D
	assert_true(combat_room != null, "combat_room.tscn instantiates cleanly")
	root.add_child(combat_room)
	await process_frame
	
	var player: PlayerController = combat_room.get_node_or_null("Player") as PlayerController
	var dummy: TrainingDummy = combat_room.get_node_or_null("TrainingDummy") as TrainingDummy
	var walker: WalkerEnemy = combat_room.get_node_or_null("WalkerEnemy") as WalkerEnemy
	var flyer: FlyerEnemy = combat_room.get_node_or_null("FlyerEnemy") as FlyerEnemy
	var charger: ChargerEnemy = combat_room.get_node_or_null("ChargerEnemy") as ChargerEnemy
	var hud: DebugHUD = combat_room.get_node_or_null("DebugHUD") as DebugHUD
	
	assert_true(player != null, "Player node present in CombatRoom")
	assert_true(dummy != null, "TrainingDummy node present in CombatRoom")
	assert_true(walker != null, "WalkerEnemy node present in CombatRoom")
	assert_true(flyer != null, "FlyerEnemy node present in CombatRoom")
	assert_true(charger != null, "ChargerEnemy node present in CombatRoom")
	assert_true(hud != null, "DebugHUD node present in CombatRoom")
	
	# Simulate player melee attack hitting walker in live scene
	player.input_override_enabled = true
	player.global_position = walker.global_position + Vector2(-24, 0)
	player.facing_direction = 1
	player.current_soul = 0
	
	player.hitbox.activate(Vector2.RIGHT, false)
	player.hitbox._on_area_entered(walker.hurtbox)
	
	assert_true(walker.health_component.current_health == 2, "Walker took damage from player forward melee swing in live scene")
	assert_true(player.get_current_soul() == 11, "Player gained 11 soul from live combat hit")
	
	# Reset attack state so player is ready to focus
	player.hitbox.deactivate()
	player.current_attack_state = PlayerControllerScript.AttackState.NONE
	
	# Simulate player taking damage, then using focus heal to recover
	player.health_component.current_health = 3
	player.current_soul = 66
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player.velocity = Vector2.ZERO
	player.current_state = PlayerControllerScript.State.IDLE
	
	player.simulated_focus_pressed = true
	player.simulated_focus_held = true
	player._physics_process(0.016)
	
	assert_true(player.current_state == PlayerControllerScript.State.FOCUS, "Player entered FOCUS in live combat arena")
	
	# Advance focus to completion
	var steps := int(ceil(player.focus_charge_duration / 0.016)) + 2
	for i in range(steps):
		player._physics_process(0.016)
	
	assert_true(player.get_current_health() == 4, "Player healed 1 mask in live combat arena (3 -> 4)")
	assert_true(player.get_current_soul() == 33, "Player soul consumed properly in live combat arena (66 -> 33)")
	
	combat_room.queue_free()
	await process_frame
