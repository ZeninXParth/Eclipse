extends SceneTree

## ECLIPSE: Echoes of the Forgotten
## Automated Headless Combat System Verification Test Suite (Milestone M2)
## Tests player attacks, directional swings, single-hit guarantee, damage resolution,
## invulnerability frames (i-frames), knockback, pogo bounce physics, and enemy dummy respawn.

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const PlayerVisualsScript = preload("res://scripts/player/player_visuals.gd")
const TrainingDummyScript = preload("res://scripts/enemies/training_dummy.gd")
const HitboxScript = preload("res://scripts/combat/hitbox.gd")
const HurtboxScript = preload("res://scripts/combat/hurtbox.gd")
const HealthComponentScript = preload("res://scripts/combat/health_component.gd")
const HazardZoneScript = preload("res://scripts/combat/hazard_zone.gd")
const HitDataScript = preload("res://scripts/combat/hit_data.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING ECLIPSE M2 COMBAT SYSTEM VERIFICATION SUITE")
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
	test_attack_timing_and_phases()
	test_directional_attack_resolution()
	test_single_hit_per_swing_guarantee()
	test_damage_and_knockback_application()
	test_pogo_bounce_physics_and_coyote_reset()
	test_pogo_hazard_interaction()
	test_player_hurt_iframes_and_knockback()
	test_player_death_and_respawn_cycle()
	test_dummy_defeat_and_respawn_cycle()
	test_attack_input_buffering()
	test_directional_lock_and_hitbox_sync()
	test_single_pogo_bounce_per_swing()
	test_hazard_spikes_continuous_damage()
	await test_live_scene_combat_simulation_async()
	
	print("\n========================================================")
	print("  M2 COMBAT TEST RESULTS SUMMARY:")
	print("  Total Tests:  %d" % total_tests)
	print("  Passed:       %d" % passed_tests)
	print("  Failed:       %d" % failed_tests)
	if failed_tests > 0:
		print("\n  FAILURES:")
		for f in failures:
			print("    - ", f)
		print("========================================================\n")
		quit(1)
	else:
		print("  ALL M2 COMBAT TESTS PASSED SUCCESSFULLY!")
		print("========================================================\n")
		quit(0)


func test_attack_timing_and_phases() -> void:
	print("\n--- Test Suite 1: Attack Lifecycle & Timing Phases ---")
	var player := create_test_player()
	var delta: float = 1.0 / 60.0
	
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.NONE, "Player starts in AttackState.NONE")
	assert_true(not player.hitbox.is_active, "Hitbox is_active is false when idle")
	assert_true(not player.hitbox.monitoring, "Hitbox monitoring is disabled when idle")
	
	# Frame 1: Attack pressed -> Enters STARTUP
	player.simulated_attack_pressed = true
	player._handle_attack(delta)
	
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.STARTUP, "Attack enters STARTUP state")
	assert_approx_equal(player.attack_timer, player.attack_startup_duration, 0.001, "Startup timer primed to 0.05s")
	assert_true(not player.hitbox.is_active, "Hitbox remains inactive during STARTUP phase")
	
	# Step through remaining startup frames (0.05s total = ~3 frames)
	player._handle_attack(0.02)
	player._handle_attack(0.02)
	player._handle_attack(0.02) # Exceeds 0.05s -> transitions to ACTIVE
	
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.ACTIVE, "Attack enters ACTIVE state after startup")
	assert_approx_equal(player.attack_timer, player.attack_active_duration, 0.001, "Active timer primed to 0.07s")
	assert_true(player.hitbox.is_active, "Hitbox is_active is true during ACTIVE phase")
	assert_true(player.hitbox.monitoring, "Hitbox monitoring is enabled during ACTIVE phase")
	assert_true(not player.hitbox_shape.disabled, "Hitbox collision shape is enabled during ACTIVE phase")
	
	# Step through active frames (0.07s total = ~4 frames)
	player._handle_attack(0.04)
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.ACTIVE, "Attack stays in ACTIVE phase during duration")
	
	player._handle_attack(0.04) # Exceeds 0.07s -> transitions to RECOVERY
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.RECOVERY, "Attack transitions to RECOVERY after active duration")
	assert_approx_equal(player.attack_timer, player.attack_recovery_duration, 0.001, "Recovery timer primed to 0.10s")
	assert_true(not player.hitbox.is_active, "Hitbox is_active is false during RECOVERY phase")
	assert_true(not player.hitbox.monitoring, "Hitbox monitoring is disabled during RECOVERY phase")
	assert_true(player.hitbox_shape.disabled, "Hitbox collision shape is disabled during RECOVERY phase")
	
	# Step through recovery (0.10s)
	player._handle_attack(0.05)
	player._handle_attack(0.06)
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.NONE, "Attack cleanly returns to NONE after recovery completes")
	
	player.free()


func test_directional_attack_resolution() -> void:
	print("\n--- Test Suite 2: Directional Attack Parsing ---")
	var player := create_test_player()
	var delta: float = 1.0 / 60.0
	
	# 1. Neutral Ground Forward Attack
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player.facing_direction = 1
	player.simulated_attack_pressed = true
	player._handle_attack(delta)
	
	assert_true(player.current_attack_direction == PlayerControllerScript.AttackDirection.FORWARD, "Neutral attack resolves to FORWARD")
	player._handle_attack(0.06)
	assert_approx_equal(player.hitbox_shape.position.x, 26.0, 0.1, "Forward right hitbox offset is positive x (+26px)")
	assert_true(player.hitbox.attack_direction == Vector2.RIGHT, "Hitbox direction vector is Vector2.RIGHT")
	assert_true(not player.hitbox.is_pogo, "Forward attack is not a pogo attack")
	
	player._handle_attack(0.08)
	player._handle_attack(0.12)
	
	# 2. Left Facing Ground Forward Attack
	player.facing_direction = -1
	player.simulated_attack_pressed = true
	player._handle_attack(delta)
	player._handle_attack(0.06)
	assert_approx_equal(player.hitbox_shape.position.x, -26.0, 0.1, "Forward left hitbox offset is negative x (-26px)")
	assert_true(player.hitbox.attack_direction == Vector2.LEFT, "Hitbox direction vector is Vector2.LEFT")
	
	player._handle_attack(0.08)
	player._handle_attack(0.12)
	
	# 3. Upward Slash (Holding UP)
	player.simulated_move_up = true
	player.simulated_attack_pressed = true
	player._handle_attack(delta)
	player._handle_attack(0.06)
	assert_true(player.current_attack_direction == PlayerControllerScript.AttackDirection.UP, "Holding UP resolves to UP attack")
	assert_approx_equal(player.hitbox_shape.position.y, -48.0, 0.1, "Upward attack hitbox is offset above player (-48px)")
	assert_true(player.hitbox.attack_direction == Vector2.UP, "Hitbox direction vector is Vector2.UP")
	assert_true(not player.hitbox.is_pogo, "Upward attack is not a pogo attack")
	
	player.simulated_move_up = false
	player._handle_attack(0.08)
	player._handle_attack(0.12)
	
	# 4. Downward Slash while Grounded (Holding DOWN on ground must NOT pogo)
	player.simulated_on_floor = true
	player.simulated_move_down = true
	player.simulated_attack_pressed = true
	player._handle_attack(delta)
	player._handle_attack(0.06)
	assert_true(player.current_attack_direction == PlayerControllerScript.AttackDirection.FORWARD, "Grounded attack holding DOWN defaults to FORWARD (crouch slash)")
	
	player._handle_attack(0.08)
	player._handle_attack(0.12)
	
	# 5. Downward Slash while Airborne (Holding DOWN while airborne -> Pogo)
	player.simulated_on_floor = false
	player.simulated_move_down = true
	player.simulated_attack_pressed = true
	player._handle_attack(delta)
	player._handle_attack(0.06)
	assert_true(player.current_attack_direction == PlayerControllerScript.AttackDirection.DOWN, "Airborne holding DOWN resolves to DOWN pogo attack")
	assert_approx_equal(player.hitbox_shape.position.y, 4.0, 0.1, "Downward attack hitbox is offset below player (+4px)")
	assert_true(player.hitbox.attack_direction == Vector2.DOWN, "Hitbox direction vector is Vector2.DOWN")
	assert_true(player.hitbox.is_pogo, "Downward airborne attack is marked is_pogo = true")
	
	player.free()


func test_single_hit_per_swing_guarantee() -> void:
	print("\n--- Test Suite 3: Single-Hit Guarantee Per Swing ---")
	var hitbox := HitboxScript.new()
	hitbox.is_player_hitbox = true
	hitbox.damage = 1
	var hb_col := CollisionShape2D.new()
	var hb_rect := RectangleShape2D.new()
	hb_rect.size = Vector2(40, 40)
	hb_col.shape = hb_rect
	hitbox.add_child(hb_col)
	hitbox._ready()
	
	var health := HealthComponentScript.new()
	health.max_health = 10
	health.current_health = 10
	health.default_invulnerability_duration = 0.0 # No iframes so we isolate single-hit tracking
	
	var hurtbox := HurtboxScript.new()
	hurtbox.health_component = health
	hurtbox.is_player_hurtbox = false
	var hurt_col := CollisionShape2D.new()
	hurt_col.shape = hb_rect
	hurtbox.add_child(hurt_col)
	hurtbox._ready()
	
	var hits_landed: Array[int] = [0]
	hitbox.hit_landed.connect(func(_target, _data): hits_landed[0] += 1)
	
	# Activate swing 1
	hitbox.activate(Vector2.RIGHT, false)
	
	# Simulate frame 1: area enters
	hitbox._on_area_entered(hurtbox)
	assert_true(hits_landed[0] == 1, "First frame overlap registers 1 hit")
	assert_true(health.current_health == 9, "Target health reduced by 1")
	
	# Simulate frame 2: area still inside hitbox during SAME swing
	hitbox._on_area_entered(hurtbox)
	assert_true(hits_landed[0] == 1, "Second frame overlap during SAME swing does NOT hit again")
	assert_true(health.current_health == 9, "Target health remains 9 (no multi-hit bug)")
	
	# Simulate frame 3: area still inside
	hitbox._on_area_entered(hurtbox)
	assert_true(hits_landed[0] == 1, "Third frame overlap during SAME swing does NOT hit again")
	
	# Swing completes and deactivates
	hitbox.deactivate()
	
	# New swing begins (Swing 2)
	hitbox.activate(Vector2.RIGHT, false)
	hitbox._on_area_entered(hurtbox)
	assert_true(hits_landed[0] == 2, "Second swing cleanly hits the target again")
	assert_true(health.current_health == 8, "Target health reduced by 1 on new swing")
	
	hitbox.free()
	hurtbox.free()
	health.free()


func test_damage_and_knockback_application() -> void:
	print("\n--- Test Suite 4: Damage & Directional Knockback ---")
	var dummy := create_test_dummy()
	root.add_child(dummy)
	dummy.global_position = Vector2(200, 500)
	dummy.velocity = Vector2.ZERO
	
	var hit_data = HitDataScript.new(
		2,
		Vector2.RIGHT,
		250.0,
		null,
		Vector2.RIGHT,
		false
	)
	
	var success := dummy.hurtbox.receive_hit(hit_data)
	assert_true(success, "Dummy successfully receives hit")
	assert_true(dummy.health_component.current_health == 2, "Dummy HP drops from 4 to 2 (2 damage taken)")
	assert_approx_equal(dummy.velocity.x, 250.0, 0.01, "Dummy receives positive rightward knockback velocity (250 px/s)")
	assert_true(dummy.flash_timer > 0.0, "Dummy flash timer primed for visual damage feedback")
	
	# Simulate 10 physics ticks with friction
	var delta: float = 1.0 / 60.0
	for i in range(10):
		dummy._physics_process(delta)
	
	assert_true(dummy.velocity.x < 250.0, "Dummy velocity decelerates due to ground friction")
	
	for i in range(25):
		dummy._physics_process(delta)
	assert_approx_equal(dummy.velocity.x, 0.0, 0.01, "Dummy halts cleanly back to 0 px/s")
	
	dummy.queue_free()


func test_pogo_bounce_physics_and_coyote_reset() -> void:
	print("\n--- Test Suite 5: Downward Pogo Bounce & Coyote Refresh ---")
	var player := create_test_player()
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false # Airborne
	player.velocity = Vector2(0, 200.0) # Falling downward
	player.coyote_timer = 0.0 # Coyote expired
	
	# Start airborne down attack
	player.simulated_move_down = true
	player.simulated_attack_pressed = true
	player._handle_attack(1.0 / 60.0)
	player._handle_attack(0.06) # Enters ACTIVE
	
	assert_true(player.current_attack_direction == PlayerControllerScript.AttackDirection.DOWN, "Attack is DOWN")
	assert_true(player.hitbox.is_pogo, "Hitbox is_pogo is true")
	
	var pogo_emitted: Array[bool] = [false]
	player.pogo_bounced.connect(func(): pogo_emitted[0] = true)
	
	# Simulate hit on enemy hurtbox
	var dummy := create_test_dummy()
	player.hitbox._on_area_entered(dummy.hurtbox)
	
	assert_true(pogo_emitted[0], "pogo_bounced signal was emitted")
	assert_approx_equal(player.velocity.y, player.pogo_bounce_velocity, 0.01, "Player upward velocity set to pogo_bounce_velocity (-460 px/s)")
	assert_approx_equal(player.coyote_timer, player.coyote_duration, 0.001, "Coyote timer refreshed to full duration on pogo hit")
	assert_true(not player.is_jumping, "is_jumping remains false so variable jump cutoff does not truncate pogo bounce")
	
	# Verify that subsequent physics frames with jump NOT held do NOT truncate velocity
	player.simulated_jump_held = false
	player.simulated_jump_released = false
	player._handle_jump(1.0 / 60.0)
	assert_approx_equal(player.velocity.y, player.pogo_bounce_velocity, 0.01, "Pogo bounce velocity is NOT truncated when jump button is unheld")
	
	# Verify that pressing and holding jump during refreshed coyote window initiates a full aerial jump
	player.simulated_jump_pressed = true
	player.simulated_jump_held = true
	player._handle_input_timers(1.0 / 60.0)
	player._handle_jump(1.0 / 60.0)
	assert_true(player.is_jumping, "Aerial jump initiated during refreshed coyote window")
	assert_approx_equal(player.velocity.y, player.jump_velocity, 0.01, "Full jump velocity applied from coyote jump")
	
	dummy.free()
	player.free()


func test_pogo_hazard_interaction() -> void:
	print("\n--- Test Suite 6: Hazard Zone Pogo Bounce ---")
	var player := create_test_player()
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.velocity = Vector2(0, 150.0)
	player.coyote_timer = 0.0
	
	var hazard := HazardZoneScript.new()
	hazard.damage = 1
	hazard.allows_pogo = true
	hazard._ready()
	
	# Start down attack
	player.simulated_move_down = true
	player.simulated_attack_pressed = true
	player._handle_attack(1.0 / 60.0)
	player._handle_attack(0.06)
	
	player.hitbox._on_area_entered(hazard)
	
	assert_approx_equal(player.velocity.y, player.pogo_bounce_velocity, 0.01, "Hazard pogo bounces player upward (-460 px/s)")
	assert_approx_equal(player.coyote_timer, player.coyote_duration, 0.001, "Hazard pogo refreshes coyote timer")
	
	hazard.free()
	player.free()


func test_player_hurt_iframes_and_knockback() -> void:
	print("\n--- Test Suite 7: Player Hurtbox, I-Frames & Knockback Stun ---")
	var player := create_test_player()
	player.global_position = Vector2(100, 200)
	player.velocity = Vector2.ZERO
	player.facing_direction = 1
	
	assert_true(player.get_current_health() == 5, "Player starts with 5 health")
	assert_true(not player.is_invulnerable(), "Player starts with no i-frames")
	
	var damaged_emitted: Array[bool] = [false]
	player.player_damaged.connect(func(_dmg, _hp): damaged_emitted[0] = true)
	
	# Apply 1 damage with leftward hit (knocking player left)
	var hit := HitDataScript.new(1, Vector2.LEFT, 220.0, null, Vector2.LEFT, false)
	var success := player.hurtbox.receive_hit(hit)
	
	assert_true(success, "Player hurtbox accepts incoming hit")
	assert_true(damaged_emitted[0], "player_damaged signal emitted")
	assert_true(player.get_current_health() == 4, "Player health reduced from 5 to 4")
	assert_true(player.is_invulnerable(), "Player enters invulnerable i-frame state")
	assert_approx_equal(player.get_invulnerability_time_remaining(), 1.0, 0.01, "I-frame timer initialized to 1.0s")
	assert_true(player.velocity.x < 0.0, "Player knocked backward horizontally")
	assert_true(player.knockback_timer > 0.0, "Player control attenuated during knockback stun")
	
	# Attempt second hit immediately during active i-frames
	var hit2 := HitDataScript.new(1, Vector2.LEFT, 220.0, null, Vector2.LEFT, false)
	var hit2_success := player.hurtbox.receive_hit(hit2)
	assert_true(not hit2_success, "Second hit is REJECTED during active i-frames")
	assert_true(player.get_current_health() == 4, "Player health remains 4 (i-frame immunity works)")
	
	# Advance timers by 1.05s to expire i-frames
	player.health_component._process(1.05)
	assert_true(not player.is_invulnerable(), "I-frames expired after 1.0s")
	
	# Attempt third hit after i-frames expire
	var hit3_success := player.hurtbox.receive_hit(hit2)
	assert_true(hit3_success, "Hit accepted again once i-frames expire")
	assert_true(player.get_current_health() == 3, "Player health reduced to 3")
	
	player.free()


func test_player_death_and_respawn_cycle() -> void:
	print("\n--- Test Suite 8: Player Death & Respawn Cycle ---")
	var player := create_test_player()
	player.spawn_position = Vector2(100, 200)
	player.global_position = Vector2(800, 500)
	player.velocity = Vector2(150, -200)
	
	var died_emitted: Array[bool] = [false]
	var damaged_hp: Array[int] = [-1]
	player.player_died.connect(func(): died_emitted[0] = true)
	player.player_damaged.connect(func(_dmg, rem): damaged_hp[0] = rem)
	
	# Deliver lethal blow via hurtbox to test full pipeline
	var hit := HitDataScript.new(5, Vector2.RIGHT, 300.0, null, Vector2.RIGHT, false)
	player.hurtbox.receive_hit(hit)
	
	assert_true(died_emitted[0], "player_died signal emitted on 0 HP")
	assert_true(damaged_hp[0] == 0, "player_damaged accurately reported 0 HP on fatal blow")
	assert_true(player.global_position == Vector2(100, 200), "Player position reset to spawn coordinates")
	assert_true(player.velocity == Vector2.ZERO, "Player velocity zeroed on respawn without lingering knockback")
	assert_approx_equal(player.knockback_timer, 0.0, 0.001, "Knockback stun timer zeroed on respawn")
	assert_true(player.get_current_health() == 5, "Player health fully restored to 5 masks")
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.NONE, "Attack state reset to NONE")
	assert_true(player.current_state == PlayerControllerScript.State.IDLE, "Movement state reset to IDLE")
	
	player.free()


func test_dummy_defeat_and_respawn_cycle() -> void:
	print("\n--- Test Suite 9: Dummy Defeat & Auto-Respawn Cycle ---")
	var dummy := create_test_dummy()
	dummy.spawn_position = Vector2(300, 500)
	dummy.global_position = Vector2(350, 500)
	
	var defeated_emitted: Array[bool] = [false]
	var respawned_emitted: Array[bool] = [false]
	dummy.dummy_defeated.connect(func(): defeated_emitted[0] = true)
	dummy.dummy_respawned.connect(func(): respawned_emitted[0] = true)
	
	# Deal 4 damage to kill dummy
	var hit := HitDataScript.new(4, Vector2.RIGHT, 250.0, null, Vector2.RIGHT, false)
	dummy.hurtbox.receive_hit(hit)
	
	assert_true(dummy.is_defeated, "Dummy enters is_defeated state")
	assert_true(defeated_emitted[0], "dummy_defeated signal emitted")
	assert_true(dummy.velocity == Vector2.ZERO, "Defeated dummy velocity is zeroed without lingering knockback slide")
	assert_true(not dummy.hurtbox.can_receive_hit(), "Hurtbox cannot receive hits while defeated")
	
	# Advance respawn timer
	dummy._physics_process(dummy.respawn_delay + 0.1)
	
	assert_true(not dummy.is_defeated, "Dummy is_defeated flag cleared upon respawn")
	assert_true(respawned_emitted[0], "dummy_respawned signal emitted")
	assert_true(dummy.health_component.current_health == 4, "Dummy HP restored to max (4)")
	assert_true(dummy.global_position == Vector2(300, 500), "Dummy position reset to spawn point")
	assert_true(dummy.hurtbox.can_receive_hit(), "Hurtbox re-enabled for future hits")
	
	dummy.free()


func test_attack_input_buffering() -> void:
	print("\n--- Test Suite 11: Attack Input Buffering ---")
	var player := create_test_player()
	var delta: float = 1.0 / 60.0
	
	# Start initial attack
	player.simulated_attack_pressed = true
	player._handle_input_timers(delta)
	player._handle_attack(delta)
	
	# Advance past startup into active
	player._handle_attack(player.attack_startup_duration + 0.01)
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.ACTIVE, "In ACTIVE state")
	
	# Advance into recovery
	player._handle_attack(player.attack_active_duration + 0.01)
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.RECOVERY, "In RECOVERY state")
	
	# Press attack during recovery window
	player.simulated_attack_pressed = true
	player._handle_input_timers(delta)
	assert_true(player.is_attack_buffered(), "Attack input buffered during recovery")
	
	# Advance past recovery - buffered attack should immediately trigger next swing
	player._handle_attack(player.attack_recovery_duration + 0.01)
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.STARTUP, "Buffered attack immediately started next swing")
	assert_true(not player.is_attack_buffered(), "Attack buffer consumed")
	
	player.free()


func test_directional_lock_and_hitbox_sync() -> void:
	print("\n--- Test Suite 12: Direction Lock & Hitbox Sync ---")
	var player := create_test_player()
	player.facing_direction = 1
	var delta: float = 1.0 / 60.0
	
	player.simulated_attack_pressed = true
	player._handle_input_timers(delta)
	player._handle_attack(delta)
	player._handle_attack(player.attack_startup_duration + 0.01) # Enters ACTIVE
	
	assert_true(player.current_attack_state == PlayerControllerScript.AttackState.ACTIVE, "Attack is ACTIVE")
	assert_approx_equal(player.hitbox_shape.position.x, 26.0, 0.1, "Hitbox facing right")
	
	# Player attempts to steer left during active swing
	player.simulated_move_axis = -1.0
	player._handle_horizontal_movement(delta)
	
	assert_true(player.facing_direction == 1, "Facing direction locked forward during active swing")
	assert_approx_equal(player.hitbox_shape.position.x, 26.0, 0.1, "Hitbox shape position remained synchronized forward")
	assert_true(player.hitbox.attack_direction == Vector2.RIGHT, "Hitbox attack_direction remained Vector2.RIGHT")
	
	player.free()


func test_single_pogo_bounce_per_swing() -> void:
	print("\n--- Test Suite 13: Single Pogo Bounce Guarantee Across Multiple Targets ---")
	var player := create_test_player()
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.simulated_move_down = true
	player.simulated_attack_pressed = true
	player._handle_input_timers(1.0 / 60.0)
	player._handle_attack(1.0 / 60.0)
	player._handle_attack(player.attack_startup_duration + 0.01) # ACTIVE
	
	var bounce_count: Array[int] = [0]
	player.pogo_bounced.connect(func(): bounce_count[0] += 1)
	
	# Simulate hitting two targets simultaneously in the same swing
	var dummy1 := create_test_dummy()
	var dummy2 := create_test_dummy()
	
	player.hitbox._on_area_entered(dummy1.hurtbox)
	player.hitbox._on_area_entered(dummy2.hurtbox)
	
	assert_true(bounce_count[0] == 1, "Only single pogo bounce emitted even when hitting multiple targets")
	assert_approx_equal(player.velocity.y, player.pogo_bounce_velocity, 0.01, "Bounce velocity not stacked")
	
	dummy1.free()
	dummy2.free()
	player.free()


func test_hazard_spikes_continuous_damage() -> void:
	print("\n--- Test Suite 14: Overlapping Hazard Spikes Continuous Damage ---")
	var player := create_test_player()
	player._ready()
	
	var hazard := HazardZoneScript.new()
	hazard.damage = 1
	hazard._ready()
	
	# First contact
	hazard._on_area_entered(player.hurtbox)
	assert_true(player.get_current_health() == 4, "Initial contact dealt 1 damage")
	assert_true(player.is_invulnerable(), "Player in i-frames")
	
	# While remaining overlapping, i-frames expire
	player.health_component._tick_invulnerability(1.05)
	assert_true(not player.is_invulnerable(), "I-frames expired")
	
	# Hazard delivers damage again
	hazard._damage_player_hurtbox(player.hurtbox)
	assert_true(player.get_current_health() == 3, "Continuous contact dealt damage again once i-frames expired")
	
	hazard.free()
	player.free()


func test_live_scene_combat_simulation_async() -> void:
	print("\n--- Test Suite 10: Deep Scene Integration Simulation ---")
	var room_scene: PackedScene = load("res://scenes/levels/test_room.tscn")
	assert_true(room_scene != null, "test_room.tscn loads successfully")
	
	var room_instance = room_scene.instantiate()
	assert_true(room_instance != null, "test_room.tscn instantiates cleanly")
	
	root.add_child(room_instance)
	
	var player = room_instance.get_node_or_null("Player") as PlayerController
	assert_true(player != null, "Player node found in test_room")
	
	var dummy = room_instance.get_node_or_null("TrainingDummy") as TrainingDummy
	assert_true(dummy != null, "TrainingDummy node found in test_room")
	
	var spikes = room_instance.get_node_or_null("HazardSpikes") as HazardZone
	assert_true(spikes != null, "HazardSpikes node found in test_room")
	
	# Step 15 frames for physics to settle on floor
	for i in range(15):
		await physics_frame
		await process_frame
	
	assert_true(player.is_on_floor(), "Player grounded on Platform 0")
	assert_true(dummy.is_on_floor(), "TrainingDummy grounded on Platform 0")
	
	# Position player 20px to the left of dummy facing right (within 36px reach)
	player.global_position = dummy.global_position - Vector2(20.0, 0.0)
	player.facing_direction = 1
	player.input_override_enabled = true
	
	var initial_dummy_hp: int = dummy.health_component.current_health
	
	# Trigger attack via simulated input
	player.simulated_attack_pressed = true
	
	# Step 10 physics frames to execute startup, enter active, and resolve area collisions
	for i in range(10):
		await physics_frame
		await process_frame
	
	assert_true(dummy.health_component.current_health < initial_dummy_hp, "Dummy took damage from player forward melee swing in live scene")
	assert_true(dummy.velocity.x > 0.0, "Dummy received rightward knockback in live scene")
	
	room_instance.queue_free()
	await process_frame
