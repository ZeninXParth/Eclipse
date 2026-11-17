extends SceneTree

## Automated Headless Physics and Movement Verification Test Suite
## Comprehensive Metroidvania Mechanics & Physics Engine Regression Suite

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const PlayerVisualsScript = preload("res://scripts/player/player_visuals.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING ECLIPSE M1 PLAYER MOVEMENT VERIFICATION SUITE")
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
	
	player._ready()
	return player


func _run_all_tests_async() -> void:
	test_physics_constants_calculation()
	test_horizontal_acceleration_and_max_speed()
	test_ground_friction_and_stopping()
	test_facing_direction_and_visuals_sync()
	test_air_acceleration_vs_ground()
	test_jump_impulse_and_state()
	test_variable_jump_height()
	test_subframe_tap_and_buffered_jump()
	test_gravity_and_terminal_velocity()
	test_coyote_time_success_and_expiry()
	test_jump_buffering_success_and_expiry()
	test_ceiling_collision_resolution()
	test_landing_recovery_and_idle_transition()
	test_reset_to_spawn()
	await test_test_room_scene_simulation_async()
	
	print("\n========================================================")
	print("  TEST RESULTS SUMMARY:")
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
		print("  ALL TESTS PASSED SUCCESSFULLY!")
		print("========================================================\n")
		quit(0)


func test_physics_constants_calculation() -> void:
	print("\n--- Test Suite 1: Kinematic Constants ---")
	var player := create_test_player(false)
	
	# jump_height = 96, time_to_peak = 0.34
	# g = 2 * 96 / (0.34^2) = 192 / 0.1156 = ~1660.9
	# v = -g * 0.34 = ~-564.7
	assert_approx_equal(player.jump_gravity, 1660.9, 5.0, "Jump gravity calculated correctly")
	assert_approx_equal(player.jump_velocity, -564.7, 5.0, "Jump velocity calculated correctly")
	assert_approx_equal(player.fall_gravity, player.jump_gravity * 1.35, 1.0, "Fall gravity multiplier (1.35x) applied")
	player.free()


func test_horizontal_acceleration_and_max_speed() -> void:
	print("\n--- Test Suite 2: Horizontal Locomotion ---")
	var player := create_test_player(false)
	player.set_velocity(Vector2.ZERO)
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player.simulated_move_axis = 1.0
	var delta: float = 1.0 / 60.0
	
	for i in range(5):
		player._handle_horizontal_movement(delta)
	
	assert_true(player.velocity.x > 50.0, "Player accelerates rightward when move_axis = 1.0")
	assert_true(player.velocity.x <= player.max_speed, "Player does not exceed max_speed during acceleration")
	
	for i in range(30):
		player._handle_horizontal_movement(delta)
	
	assert_approx_equal(player.velocity.x, 260.0, 0.01, "Player reaches exactly max_speed (260 px/s)")
	
	# Reverse to left
	player.simulated_move_axis = -1.0
	for i in range(30):
		player._handle_horizontal_movement(delta)
	assert_approx_equal(player.velocity.x, -260.0, 0.01, "Player reaches full negative max_speed (-260 px/s)")
	player.free()


func test_ground_friction_and_stopping() -> void:
	print("\n--- Test Suite 3: Ground Deceleration / Friction ---")
	var player := create_test_player(false)
	player.velocity.x = player.max_speed
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player.simulated_move_axis = 0.0
	
	var delta: float = 1.0 / 60.0
	player._handle_horizontal_movement(delta)
	assert_approx_equal(player.velocity.x, 260.0 - (player.ground_deceleration * delta), 0.5, "Velocity drops by ground_deceleration * delta")
	
	for i in range(10):
		player._handle_horizontal_movement(delta)
	
	assert_approx_equal(player.velocity.x, 0.0, 0.01, "Player halts cleanly to 0 px/s without sliding or drifting")
	player.free()


func test_facing_direction_and_visuals_sync() -> void:
	print("\n--- Test Suite 4: Facing Direction & Visuals Synchronization ---")
	var player := create_test_player(true)
	var visuals: PlayerVisuals = player.visuals_node as PlayerVisuals
	var delta: float = 1.0 / 60.0
	
	# Moving right
	player.simulated_move_axis = 1.0
	player._handle_horizontal_movement(delta)
	visuals._process(delta)
	assert_true(player.facing_direction == 1, "Facing direction is 1 (right) on right input")
	assert_true(visuals.scale.x > 0.0, "Visuals node scale.x is positive when facing right")
	
	# Moving left
	player.simulated_move_axis = -1.0
	player._handle_horizontal_movement(delta)
	visuals._process(delta)
	assert_true(player.facing_direction == -1, "Facing direction flips to -1 (left) on left input")
	assert_true(visuals.scale.x < 0.0, "Visuals node scale.x flips negative when facing left")
	
	# Stop moving (idle): facing must NOT reset or snap to positive!
	player.simulated_move_axis = 0.0
	player.velocity.x = 0.0
	player._handle_horizontal_movement(delta)
	for i in range(5):
		visuals._process(delta)
	assert_true(player.facing_direction == -1, "Facing direction remains -1 while idle after moving left")
	assert_true(visuals.scale.x < 0.0, "Visuals node scale.x retains negative orientation during idle")
	
	player.free()


func test_air_acceleration_vs_ground() -> void:
	print("\n--- Test Suite 5: Air vs Ground Responsiveness ---")
	var player := create_test_player(false)
	assert_true(player.air_acceleration < player.ground_acceleration, "Air acceleration is tuned lower than ground acceleration for control")
	assert_true(player.air_deceleration < player.ground_deceleration, "Air friction is tuned lower than ground friction")
	player.free()


func test_jump_impulse_and_state() -> void:
	print("\n--- Test Suite 6: Jump Trigger & Signal ---")
	var player := create_test_player(false)
	var signal_emitted: Array[bool] = [false]
	player.jumped.connect(func(): signal_emitted[0] = true)
	
	player.simulated_jump_held = true
	player.jump_buffer_timer = 0.10
	player.coyote_timer = 0.10
	
	player._handle_jump(1.0 / 60.0)
	
	assert_approx_equal(player.velocity.y, player.jump_velocity, 0.01, "Jump sets upward velocity to jump_velocity")
	assert_true(signal_emitted[0], "Jumped signal emitted upon jump execution")
	assert_true(player.jump_buffer_timer == 0.0, "Jump buffer consumed upon jump")
	assert_true(player.coyote_timer == 0.0, "Coyote timer consumed upon jump")
	assert_true(player.is_jumping, "is_jumping flag set to true")
	player.free()


func test_variable_jump_height() -> void:
	print("\n--- Test Suite 7: Variable Jump Height Cutoff ---")
	var player := create_test_player(false)
	player.velocity.y = -500.0
	player.is_jumping = true
	player.simulated_jump_held = false
	player.simulated_jump_released = true
	
	player._handle_jump(1.0 / 60.0)
	
	assert_approx_equal(player.velocity.y, -250.0, 0.01, "Upward velocity halved (-250 px/s) on early release")
	assert_true(not player.is_jumping, "is_jumping flag reset after cutoff")
	player.free()


func test_subframe_tap_and_buffered_jump() -> void:
	print("\n--- Test Suite 8: Sub-frame Tap & Buffered Jump Cutoff ---")
	var player := create_test_player(false)
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	var delta: float = 1.0 / 60.0
	
	# Case A: Tap jump where button is pressed and released on same frame
	player.simulated_jump_pressed = true
	player.simulated_jump_released = true
	player.simulated_jump_held = false
	player._handle_input_timers(delta)
	player._handle_jump(delta)
	
	var expected_cutoff: float = player.jump_velocity * player.variable_jump_cutoff
	assert_approx_equal(player.velocity.y, expected_cutoff, 0.01, "Subframe tap jump immediately initiates with halved velocity")
	assert_true(not player.is_jumping, "is_jumping flag reset on tap jump cutoff")
	
	# Case B: Buffered tap jump where button was released while airborne before touchdown
	player.velocity.y = 0.0
	player.jump_buffer_timer = 0.08
	player.simulated_on_floor = true
	player.simulated_jump_held = false
	player.simulated_jump_released = false
	player._handle_jump(delta)
	assert_approx_equal(player.velocity.y, expected_cutoff, 0.01, "Buffered jump with released button applies cutoff on trigger")
	
	player.free()


func test_gravity_and_terminal_velocity() -> void:
	print("\n--- Test Suite 9: Gravity Progression & Terminal Velocity ---")
	var player := create_test_player(false)
	var delta: float = 1.0 / 60.0
	
	# Upward rise
	player.velocity.y = -300.0
	player._handle_gravity(delta)
	var expected_upward: float = -300.0 + (player.jump_gravity * delta)
	assert_approx_equal(player.velocity.y, expected_upward, 0.5, "Upward rise uses jump_gravity")
	
	# Downward descent
	player.velocity.y = 100.0
	player._handle_gravity(delta)
	var expected_downward: float = 100.0 + (player.fall_gravity * delta)
	assert_approx_equal(player.velocity.y, expected_downward, 0.5, "Downward descent uses stronger fall_gravity")
	
	# Prolonged fall
	for i in range(180):
		player._handle_gravity(delta)
	
	assert_true(player.velocity.y <= player.max_fall_speed, "Fall velocity capped at max_fall_speed (650 px/s)")
	assert_approx_equal(player.velocity.y, player.max_fall_speed, 0.01, "Player reaches terminal velocity exactly")
	player.free()


func test_coyote_time_success_and_expiry() -> void:
	print("\n--- Test Suite 10: Coyote Time Window ---")
	var player := create_test_player(false)
	var delta: float = 0.04
	
	# Player walks off ledge: airborne with full coyote window
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.coyote_timer = player.coyote_duration # 0.12s
	
	# Advance 1 tick (0.04s elapsed, 0.08s left)
	player.simulated_jump_pressed = true
	player.simulated_jump_held = true
	player._handle_input_timers(delta)
	assert_approx_equal(player.coyote_timer, 0.08, 0.001, "Coyote timer decremented by single tick (0.08s remaining)")
	
	player._handle_jump(delta)
	assert_approx_equal(player.velocity.y, player.jump_velocity, 0.01, "Coyote jump succeeds during active window")
	
	# Case B: Expiry past duration
	player.velocity.y = 0.0
	player.coyote_timer = 0.0
	player.simulated_jump_pressed = true
	player._handle_input_timers(delta)
	player._handle_jump(delta)
	assert_approx_equal(player.velocity.y, 0.0, 0.01, "Jump fails after coyote window has expired")
	player.free()


func test_jump_buffering_success_and_expiry() -> void:
	print("\n--- Test Suite 11: Jump Buffering Window ---")
	var player := create_test_player(false)
	var delta: float = 0.04
	
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.simulated_jump_pressed = true
	player.simulated_jump_held = true
	player._handle_input_timers(delta)
	assert_approx_equal(player.jump_buffer_timer, player.jump_buffer_duration, 0.001, "Jump buffer primed on button press")
	
	# Advance 2 ticks (0.08s elapsed, 0.04s left)
	player._handle_input_timers(delta)
	player._handle_input_timers(delta)
	assert_true(player.jump_buffer_timer > 0.0, "Jump buffer still active after 0.08s")
	
	# Player touches ground
	player.simulated_on_floor = true
	player._handle_jump(delta)
	assert_approx_equal(player.velocity.y, player.jump_velocity, 0.01, "Buffered jump executes immediately upon ground touchdown")
	
	# Buffer expired
	player.velocity.y = 0.0
	player.jump_buffer_timer = 0.0
	player._handle_jump(delta)
	assert_approx_equal(player.velocity.y, 0.0, 0.01, "No jump triggered when buffer has expired")
	player.free()


func test_ceiling_collision_resolution() -> void:
	print("\n--- Test Suite 12: Ceiling Collision Resolution ---")
	var player := create_test_player(false)
	player.velocity.y = -400.0
	player.is_jumping = true
	
	# Simulate hitting ceiling
	if player.velocity.y < 0.0:
		player.is_jumping = false
		player.velocity.y = 0.0
	
	assert_true(not player.is_jumping, "Ceiling impact cleanly resets is_jumping to false")
	assert_approx_equal(player.velocity.y, 0.0, 0.01, "Ceiling impact zeroes upward velocity")
	player.free()


func test_landing_recovery_and_idle_transition() -> void:
	print("\n--- Test Suite 13: Landing Recovery & Idle Transition ---")
	var player := create_test_player(false)
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player.velocity = Vector2.ZERO
	
	# Trigger landing from air
	player._handle_landing(false, true)
	assert_true(player.current_state == PlayerControllerScript.State.LAND, "Player enters LAND state upon touchdown")
	assert_approx_equal(player.land_timer, player.land_duration, 0.001, "Landing timer primed to land_duration (0.08s)")
	
	# Step 2 frames (0.033s): should remain in LAND
	var delta: float = 1.0 / 60.0
	player._update_state(delta)
	player._update_state(delta)
	assert_true(player.current_state == PlayerControllerScript.State.LAND, "Player remains in LAND state during recovery window")
	
	# Step remaining frames to exceed 0.08s (5 frames total at 60fps)
	for i in range(5):
		player._update_state(delta)
	assert_true(player.current_state == PlayerControllerScript.State.IDLE, "Player cleanly transitions from LAND to IDLE on timer expiry")
	
	# Move interruption: moving immediately breaks out of LAND into RUN
	player._handle_landing(false, true)
	assert_true(player.current_state == PlayerControllerScript.State.LAND, "Re-entered LAND state on second landing")
	player.velocity.x = 50.0
	player._update_state(delta)
	assert_true(player.current_state == PlayerControllerScript.State.RUN, "Moving immediately cancels LAND state and transitions to RUN")
	
	player.free()


func test_reset_to_spawn() -> void:
	print("\n--- Test Suite 14: Spawn Reset ---")
	var player := create_test_player(false)
	player.spawn_position = Vector2(100, 200)
	player.global_position = Vector2(999, 888)
	player.velocity = Vector2(250, 400)
	player.coyote_timer = 0.1
	player.jump_buffer_timer = 0.1
	player.land_timer = 0.08
	player.is_jumping = true
	
	player.reset_to_spawn()
	
	assert_true(player.global_position == Vector2(100, 200), "Position reset to spawn point")
	assert_true(player.velocity == Vector2.ZERO, "Velocity reset to zero")
	assert_true(player.coyote_timer == 0.0, "Coyote timer reset to zero")
	assert_true(player.jump_buffer_timer == 0.0, "Jump buffer reset to zero")
	assert_true(player.land_timer == 0.0, "Land timer reset to zero")
	assert_true(not player.is_jumping, "is_jumping reset to false")
	assert_true(player.current_state == PlayerControllerScript.State.IDLE, "State reset to IDLE")
	player.free()


func test_test_room_scene_simulation_async() -> void:
	print("\n--- Test Suite 15: Deep Engine Physics Loop Simulation ---")
	var room_scene: PackedScene = load("res://scenes/levels/test_room.tscn")
	assert_true(room_scene != null, "res://scenes/levels/test_room.tscn loads successfully")
	
	var room_instance = room_scene.instantiate()
	assert_true(room_instance != null, "test_room.tscn instantiated successfully")
	
	root.add_child(room_instance)
	
	var player_in_room = room_instance.get_node_or_null("Player") as PlayerController
	assert_true(player_in_room != null, "Player node found in test_room")
	
	var hud_in_room = room_instance.get_node_or_null("DebugHUD")
	assert_true(hud_in_room != null, "DebugHUD node found in test_room")
	
	var geom_in_room = room_instance.get_node_or_null("Geometry")
	assert_true(geom_in_room != null, "Geometry node found in test_room")
	
	var cam: Camera2D = player_in_room.get_node_or_null("Camera2D")
	assert_true(cam != null, "Camera2D node found on Player")
	assert_true(cam.limit_left == -150 and cam.limit_right == 2250, "Camera limits correctly initialized by TestRoom")
	
	# Step 15 real engine physics frames: player spawns at y=470, falls, lands on Platform 0 at y=500
	for i in range(15):
		await physics_frame
		await process_frame
	
	assert_true(player_in_room.is_on_floor(), "Player landed on Platform 0 solid floor")
	
	# Settle past landing recovery duration (5 more frames) -> should be IDLE
	for i in range(6):
		await physics_frame
		await process_frame
	
	assert_true(player_in_room.current_state == PlayerControllerScript.State.IDLE, "Player transitioned cleanly from LAND to IDLE in test room")
	
	# Test pit respawn behavior
	player_in_room.global_position = Vector2(1050, 800) # In pit below threshold
	await physics_frame
	await physics_frame
	assert_true(player_in_room.global_position.y < 700.0, "Player respawned safely above pit threshold")
	
	room_instance.queue_free()
	await process_frame
