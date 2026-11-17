extends SceneTree

## ECLIPSE: Echoes of the Forgotten
## Milestone 1 Verification Suite (Wall Slide, Wall Jump, Dash, Hit-Stop, Screen Shake, Config)
## Verifies that all newly introduced M1 platforming, forgiveness, and feedback systems
## execute with deterministic precision.

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const PlayerVisualsScript = preload("res://scripts/player/player_visuals.gd")
const PlayerConfigScript = preload("res://scripts/player/player_config.gd")
const HitDataScript = preload("res://scripts/combat/hit_data.gd")
const CameraControllerScript = preload("res://scripts/camera/camera_controller.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING ECLIPSE M1 ADVANCED MOVEMENT TEST SUITE")
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


func create_test_player(attach_visuals: bool = true) -> PlayerController:
	var player := PlayerControllerScript.new()
	player.input_override_enabled = true
	
	var col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 10.0
	cap.height = 40.0
	col.shape = cap
	player.add_child(col)
	player.collision_shape = col
	
	if attach_visuals:
		var visuals := PlayerVisualsScript.new()
		visuals.controller = player
		player.add_child(visuals)
		player.visuals_node = visuals
		visuals._ready()
	
	player._ready()
	return player


func _run_all_tests_async() -> void:
	test_player_config_resource_binding()
	test_dash_locomotion_and_gravity_suspension()
	test_dash_cooldown_and_single_air_dash_limit()
	test_dash_air_dash_refresh_on_touchdown_and_wall()
	test_wall_slide_speed_clamping()
	test_wall_slide_cancellation()
	test_wall_jump_impulse_and_facing()
	test_wall_jump_coyote_window()
	test_wall_jump_input_lockout()
	test_hit_stop_physics_freeze()
	test_screen_shake_events()
	test_dash_concurrency_and_stun_lockout()
	test_camera_trauma_and_truncation_immunity()
	test_player_damage_flash_and_visuals()
	
	print("\n========================================================")
	print("  M1 ADVANCED MOVEMENT TEST RESULTS SUMMARY:")
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
		print("  ALL M1 ADVANCED MOVEMENT TESTS PASSED SUCCESSFULLY!")
		print("========================================================\n")
		quit(0)


func test_player_config_resource_binding() -> void:
	print("\n--- Test Suite 1: PlayerConfig Resource & Data-Driven Tuning ---")
	var player := create_test_player(false)
	
	assert_true(player.config != null, "PlayerConfig resource is instantiated by default")
	assert_approx_equal(player.max_speed, 260.0, 0.01, "Config default max_speed correctly propagated")
	assert_approx_equal(player.dash_speed, 550.0, 0.01, "Config default dash_speed correctly propagated")
	assert_approx_equal(player.wall_slide_speed, 120.0, 0.01, "Config default wall_slide_speed correctly propagated")
	
	# Test live tuning via property forwarding
	player.max_speed = 320.0
	assert_approx_equal(player.config.get("max_speed"), 320.0, 0.01, "Mutating player.max_speed updates config resource")
	assert_approx_equal(player.max_speed, 320.0, 0.01, "Property getter reflects mutated config")
	
	# Load external .tres resource
	var custom_config: Resource = load("res://resources/player/default_player_config.tres")
	assert_true(custom_config != null, "default_player_config.tres loaded successfully")
	player.config = custom_config
	assert_approx_equal(player.dash_speed, 550.0, 0.01, "Assigned external config resource properties read accurately")
	
	player.free()


func test_dash_locomotion_and_gravity_suspension() -> void:
	print("\n--- Test Suite 2: Dash Locomotion & Physics Suspension ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player.facing_direction = 1
	player.simulated_dash_pressed = true
	
	var dashed_signal_emitted: Array[bool] = [false]
	var dashed_dir: Array[Vector2] = [Vector2.ZERO]
	player.dashed.connect(func(dir: Vector2):
		dashed_signal_emitted[0] = true
		dashed_dir[0] = dir
	)
	
	player._physics_process(delta)
	
	assert_true(dashed_signal_emitted[0], "dashed signal emitted upon dash execution")
	assert_true(dashed_dir[0] == Vector2(1, 0), "dashed direction corresponds to player facing")
	assert_true(player.current_state == PlayerControllerScript.State.DASH, "Player entered State.DASH")
	assert_approx_equal(player.velocity.x, player.dash_speed, 0.01, "Horizontal velocity set to dash_speed (550 px/s)")
	assert_approx_equal(player.velocity.y, 0.0, 0.01, "Vertical velocity zeroed during dash")
	
	# Step mid-dash frames: gravity must remain suspended
	player.velocity.y = 100.0 # attempt external vertical shift
	player._physics_process(delta)
	assert_approx_equal(player.velocity.y, 0.0, 0.01, "Gravity remains suspended (velocity.y clamped to 0) during dash")
	assert_approx_equal(player.velocity.x, player.dash_speed, 0.01, "Horizontal velocity stays locked to dash_speed")
	
	# Step through remaining frames until dash completes (0.16s = ~10 frames)
	for i in range(12):
		player._physics_process(delta)
	
	assert_true(player.current_state != PlayerControllerScript.State.DASH, "Player cleanly exited DASH state upon timer expiry")
	assert_true(player.current_state == PlayerControllerScript.State.RUN or player.current_state == PlayerControllerScript.State.IDLE, "Player transitioned to grounded state")
	assert_true(player.velocity.x <= player.max_speed, "Velocity normalized back to max_speed upon dash exit")
	
	player.free()


func test_dash_cooldown_and_single_air_dash_limit() -> void:
	print("\n--- Test Suite 3: Dash Cooldown & Airborne Single-Use Limit ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false # In air
	player.velocity = Vector2.ZERO
	player.air_dashes_remaining = 1
	
	# 1st air dash: should succeed
	player.simulated_dash_pressed = true
	player._physics_process(delta)
	assert_true(player.current_state == PlayerControllerScript.State.DASH, "First air dash succeeds")
	assert_true(player.air_dashes_remaining == 0, "air_dashes_remaining decremented to 0")
	assert_true(player.dash_cooldown_timer > 0.0, "Dash cooldown primed")
	
	# Wait for dash to finish while remaining airborne
	for i in range(12):
		player._physics_process(delta)
	assert_true(player.current_state == PlayerControllerScript.State.FALL, "Player in FALL state after air dash completes")
	
	# Expire cooldown artificially while remaining airborne
	player.dash_cooldown_timer = 0.0
	
	# Attempt 2nd air dash before touching ground or wall: must FAIL
	player.simulated_dash_pressed = true
	player._physics_process(delta)
	assert_true(player.current_state != PlayerControllerScript.State.DASH, "Second consecutive air dash rejected without ground/wall touch")
	
	player.free()


func test_dash_air_dash_refresh_on_touchdown_and_wall() -> void:
	print("\n--- Test Suite 4: Air Dash Refresh Mechanics ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	# Consume air dash
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.air_dashes_remaining = 0
	
	# Touch floor
	player.simulated_on_floor = true
	player._handle_landing(false, true)
	player._handle_input_timers(delta)
	assert_true(player.air_dashes_remaining == player.max_air_dashes, "Air dash replenished upon ground touchdown")
	
	# Consume air dash again
	player.air_dashes_remaining = 0
	player.simulated_on_floor = false
	
	# Engage wall slide
	player.simulated_on_wall_override = true
	player.simulated_on_wall = true
	player.simulated_wall_normal = Vector2.LEFT
	player.velocity.y = 100.0
	player.simulated_move_axis = 1.0 # push right into wall
	player._handle_wall_mechanics(delta)
	assert_true(player.air_dashes_remaining == player.max_air_dashes, "Air dash replenished upon wall slide contact")
	
	player.free()


func test_wall_slide_speed_clamping() -> void:
	print("\n--- Test Suite 5: Wall Slide Physics & Descent Speed Clamping ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.simulated_on_wall_override = true
	player.simulated_on_wall = true
	player.simulated_wall_normal = Vector2.LEFT # Wall is to the right
	player.velocity = Vector2(0.0, 450.0) # High downward velocity
	player.simulated_move_axis = 1.0 # Pushing right into wall
	
	var wall_slid_emitted: Array[bool] = [false]
	player.wall_slid.connect(func(): wall_slid_emitted[0] = true)
	
	player._handle_wall_mechanics(delta)
	
	assert_true(wall_slid_emitted[0], "wall_slid signal emitted upon engaging wall")
	assert_true(player.current_state == PlayerControllerScript.State.WALL_SLIDE, "Player entered State.WALL_SLIDE")
	assert_approx_equal(player.velocity.y, player.wall_slide_speed, 0.01, "Downward descent clamped to wall_slide_speed (120 px/s)")
	assert_true(player.is_wall_sliding(), "is_wall_sliding() returns true")
	assert_true(player.wall_coyote_timer > 0.0, "Wall coyote timer primed")
	
	player.free()


func test_wall_slide_cancellation() -> void:
	print("\n--- Test Suite 6: Wall Slide Cancellation ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.simulated_on_wall_override = true
	player.simulated_on_wall = true
	player.simulated_wall_normal = Vector2.LEFT
	player.velocity.y = 100.0
	player.simulated_move_axis = 1.0
	player._handle_wall_mechanics(delta)
	assert_true(player.current_state == PlayerControllerScript.State.WALL_SLIDE, "In wall slide")
	
	# Case A: Pull away from wall (move_axis = -1.0)
	player.simulated_move_axis = -1.0
	player.facing_direction = -1
	player._handle_wall_mechanics(delta)
	assert_true(player.current_state != PlayerControllerScript.State.WALL_SLIDE, "Pulling away from wall cancels wall slide")
	assert_true(player.current_state == PlayerControllerScript.State.FALL, "Player returns to FALL state")
	
	# Case B: Ground touchdown
	player.simulated_move_axis = 1.0
	player._handle_wall_mechanics(delta)
	assert_true(player.current_state == PlayerControllerScript.State.WALL_SLIDE, "Re-entered wall slide")
	player.simulated_on_floor = true
	player._handle_landing(false, true)
	player._update_state(delta)
	assert_true(player.current_state == PlayerControllerScript.State.LAND or player.current_state == PlayerControllerScript.State.RUN, "Touching ground transitions from WALL_SLIDE to landing/run")
	
	player.free()


func test_wall_jump_impulse_and_facing() -> void:
	print("\n--- Test Suite 7: Wall Jump Impulse & Trajectory ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.simulated_on_wall_override = true
	player.simulated_on_wall = true
	player.simulated_wall_normal = Vector2.LEFT # Wall is on the right
	player.velocity = Vector2(0.0, 100.0)
	player.simulated_move_axis = 1.0
	player._handle_wall_mechanics(delta)
	
	var wall_jumped_emitted: Array[bool] = [false]
	var jumped_emitted: Array[bool] = [false]
	player.wall_jumped.connect(func(): wall_jumped_emitted[0] = true)
	player.jumped.connect(func(): jumped_emitted[0] = true)
	
	# Trigger jump from wall
	player.simulated_jump_pressed = true
	player.simulated_jump_held = true
	player._handle_input_timers(delta)
	player._handle_jump(delta)
	
	assert_true(wall_jumped_emitted[0], "wall_jumped signal emitted")
	assert_true(jumped_emitted[0], "jumped signal emitted")
	assert_true(player.current_state == PlayerControllerScript.State.WALL_JUMP, "Player entered State.WALL_JUMP")
	assert_approx_equal(player.velocity.x, -player.wall_jump_velocity.x, 0.01, "Outward horizontal impulse applied away from wall (-300 px/s)")
	assert_approx_equal(player.velocity.y, player.wall_jump_velocity.y, 0.01, "Upward lift impulse applied (-480 px/s)")
	assert_true(player.facing_direction == -1, "Player facing flipped to face away from the wall")
	assert_true(player.wall_input_lock_timer > 0.0, "Wall jump input lockout timer primed")
	
	player.free()


func test_wall_jump_coyote_window() -> void:
	print("\n--- Test Suite 8: Wall Jump Coyote Window ---")
	var player := create_test_player(false)
	var delta: float = 0.04
	
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.simulated_on_wall_override = true
	player.simulated_on_wall = true
	player.simulated_wall_normal = Vector2.RIGHT # Wall on the left
	player.last_wall_normal = Vector2.RIGHT
	player.wall_coyote_timer = player.wall_jump_coyote_duration # 0.12s
	
	# Player leaves wall
	player.simulated_on_wall = false
	player._handle_wall_mechanics(delta)
	assert_approx_equal(player.wall_coyote_timer, 0.08, 0.001, "Wall coyote timer decremented by tick (0.08s left)")
	
	# Jump during active coyote window
	player.simulated_jump_pressed = true
	player.simulated_jump_held = true
	player._handle_input_timers(delta)
	player._handle_jump(delta)
	
	assert_true(player.current_state == PlayerControllerScript.State.WALL_JUMP, "Wall jump executed successfully within wall coyote window")
	assert_approx_equal(player.velocity.x, player.wall_jump_velocity.x, 0.01, "Outward velocity applied away from wall")
	
	# Expired coyote window
	player.wall_coyote_timer = 0.0
	player.simulated_jump_pressed = true
	player._handle_input_timers(delta)
	player.velocity = Vector2.ZERO
	player._handle_jump(delta)
	assert_approx_equal(player.velocity.y, 0.0, 0.01, "Wall jump rejected after wall coyote window expired")
	
	player.free()


func test_wall_jump_input_lockout() -> void:
	print("\n--- Test Suite 9: Wall Jump Directional Input Lockout ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.facing_direction = -1
	player.last_wall_normal = Vector2.LEFT
	player.velocity = Vector2(-300.0, -480.0)
	player.wall_input_lock_timer = player.wall_jump_input_lock_duration # 0.12s
	
	# Player immediately tries to push back right towards the wall (move_axis = 1.0)
	player.simulated_move_axis = 1.0
	player._handle_horizontal_movement(delta)
	
	# Velocity.x should still maintain negative outward movement, NOT snap to positive rightward speed!
	assert_true(player.velocity.x < -200.0, "Horizontal velocity preserved outward despite opposite input during lock window")
	
	player.free()


func test_hit_stop_physics_freeze() -> void:
	print("\n--- Test Suite 10: Hit-Stop Frame Freeze ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	player.velocity = Vector2(200.0, -300.0)
	player.trigger_hit_stop(0.06)
	
	assert_approx_equal(player.hit_stop_timer, 0.06, 0.001, "Hit stop timer set to 0.06s")
	
	# Process physics step: should be skipped/frozen by hit-stop
	player._physics_process(delta)
	
	assert_approx_equal(player.hit_stop_timer, 0.06 - delta, 0.001, "Hit stop timer decremented")
	assert_approx_equal(player.velocity.x, 200.0, 0.01, "Velocity remains frozen during hit-stop frame")
	
	# Advance remaining hit-stop frames
	player._physics_process(delta)
	player._physics_process(delta)
	player._physics_process(delta)
	
	assert_approx_equal(player.hit_stop_timer, 0.0, 0.001, "Hit stop completed cleanly")
	
	player.free()


func test_screen_shake_events() -> void:
	print("\n--- Test Suite 11: Screen Shake Signals ---")
	var player := create_test_player(false)
	
	var shake_intensities: Array[float] = []
	var shake_durations: Array[float] = []
	player.screen_shake_requested.connect(func(intensity: float, duration: float):
		shake_intensities.append(intensity)
		shake_durations.append(duration)
	)
	
	# Pogo bounce shake
	player.current_attack_direction = PlayerControllerScript.AttackDirection.DOWN
	player._on_pogo_triggered(null)
	assert_true(shake_intensities.size() > 0, "Screen shake emitted on pogo bounce")
	assert_true(shake_intensities[0] > 0.0, "Screen shake intensity > 0")
	
	# Dash shake
	player._execute_dash()
	assert_true(shake_intensities.size() > 1, "Screen shake emitted on dash execution")
	
	# Wall jump shake
	player.last_wall_normal = Vector2.LEFT
	player._execute_wall_jump()
	assert_true(shake_intensities.size() > 2, "Screen shake emitted on wall jump")
	
	player.free()


func test_dash_concurrency_and_stun_lockout() -> void:
	print("\n--- Test Suite 12: Dash Interruption & Stun Lockout ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	# 1. Downward pogo during dash cancels dash and initiates upward bounce
	player._execute_dash()
	assert_true(player.current_state == PlayerControllerScript.State.DASH, "Player in DASH state")
	player.current_attack_direction = PlayerControllerScript.AttackDirection.DOWN
	player._on_pogo_triggered(null)
	assert_true(player.current_state == PlayerControllerScript.State.JUMP, "Pogo bounce cancels DASH and sets State.JUMP")
	assert_approx_equal(player.velocity.y, player.pogo_bounce_velocity, 0.01, "Pogo bounce velocity set to -460 px/s")
	# Step next physics frame: bounce must not be erased
	player.hit_stop_timer = 0.0
	player._physics_process(delta)
	assert_true(player.velocity.y < -300.0, "Upward pogo momentum preserved on subsequent physics frame")
	
	# 2. Damage received during dash cancels dash and applies knockback
	player._execute_dash()
	assert_true(player.current_state == PlayerControllerScript.State.DASH, "Player re-entered DASH state")
	var hit := HitDataScript.new(1, Vector2.LEFT, 220.0, null, Vector2.LEFT, false)
	player.hurtbox.receive_hit(hit)
	assert_true(player.current_state != PlayerControllerScript.State.DASH, "Damage hit cancels DASH state")
	assert_true(player.velocity.x < 0.0, "Knockback direction preserved away from hit")
	# Step next frame past hit stop
	player.hit_stop_timer = 0.0
	player._physics_process(delta)
	assert_true(player.velocity.x < 0.0, "Knockback velocity not overwritten by dash speed")
	
	# 3. Dash input is rejected during knockback stun
	assert_true(player.knockback_timer > 0.0, "Player still in knockback stun")
	player.simulated_dash_pressed = true
	player._handle_dash(delta)
	assert_true(player.current_state != PlayerControllerScript.State.DASH, "Dash rejected during knockback stun")
	
	# 4. Jump input is rejected during knockback stun
	player.simulated_jump_pressed = true
	player.simulated_jump_held = true
	player._handle_jump(delta)
	assert_true(not player.is_jumping, "Jump rejected during knockback stun")
	
	player.free()


func test_camera_trauma_and_truncation_immunity() -> void:
	print("\n--- Test Suite 13: Trauma-Decay Screen Shake & Truncation Immunity ---")
	var cam := CameraControllerScript.new()
	
	# Initial major shake: 10 intensity, 0.50s duration
	cam.apply_shake(10.0, 0.50)
	assert_approx_equal(cam._shake_timer, 0.50, 0.001, "Initial major shake timer initialized")
	assert_approx_equal(cam._trauma, 1.0, 0.01, "Trauma clamped to 1.0 max")
	
	# Step 0.1s
	cam._process(0.10)
	assert_approx_equal(cam._shake_timer, 0.40, 0.001, "Shake timer decremented to 0.40s")
	assert_true(cam._trauma < 1.0 and cam._trauma > 0.0, "Trauma decayed over time")
	assert_true(cam.offset.length() > 0.0, "Non-zero camera shake offset applied")
	
	# Fire tiny, short shake (1.0 intensity, 0.05s duration): must NOT truncate running 0.40s shake timer
	cam.apply_shake(1.0, 0.05)
	assert_approx_equal(cam._shake_timer, 0.40, 0.001, "Running shake timer not truncated by shorter shake")
	
	# Step past remaining duration until full decay (60 frames * 0.02s = 1.2s)
	for i in range(60):
		cam._process(0.02)
	assert_approx_equal(cam.offset.x, 0.0, 0.001, "Camera offset returned cleanly to zero")
	assert_approx_equal(cam.rotation, 0.0, 0.001, "Camera rotation roll returned cleanly to zero")
	
	cam.free()


func test_player_damage_flash_and_visuals() -> void:
	print("\n--- Test Suite 14: Damage Flash & Dash Ghost Positioning ---")
	var player := create_test_player(true)
	var visuals: PlayerVisuals = player.visuals_node as PlayerVisuals
	var delta: float = 1.0 / 60.0
	
	# Verify player_damaged primes damage flash timer on visuals
	assert_approx_equal(visuals.damage_flash_timer, 0.0, 0.001, "Damage flash timer starts at 0")
	var hit := HitDataScript.new(1, Vector2.LEFT, 100.0, null, Vector2.LEFT, false)
	player.hurtbox.receive_hit(hit)
	assert_true(visuals.damage_flash_timer > 0.10, "Damage flash timer primed upon taking damage")
	
	# Verify dash ghost recorded with global position
	player.global_position = Vector2(250.0, 400.0)
	player._execute_dash()
	assert_true(visuals.dash_ghosts.size() > 0, "Dash ghost recorded on dash execution")
	var first_ghost: Dictionary = visuals.dash_ghosts[0]
	assert_true(first_ghost.has("global_pos"), "Dash ghost stores world-space global_pos")
	assert_approx_equal(first_ghost["global_pos"].x, 250.0, 0.01, "Ghost anchored to world position at dash origin")
	
	player.free()
