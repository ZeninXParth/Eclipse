extends SceneTree

## ECLIPSE: Echoes of the Forgotten
## Milestone 3 Verification Suite (World Structure & Room Transitions)
## Verifies PlayerData save/load serialization, RoomBase camera limits & gate registry,
## TransitionPoint gate triggering, BenchCheckpoint healing & persistence,
## GameManager room streaming pipeline, and two-way connected level scenes.

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const PlayerVisualsScript = preload("res://scripts/player/player_visuals.gd")
const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const RoomBaseScript = preload("res://scripts/world/room_base.gd")
const TransitionPointScript = preload("res://scripts/world/transition_point.gd")
const BenchCheckpointScript = preload("res://scripts/world/bench_checkpoint.gd")
const GameManagerScript = preload("res://scripts/core/game_manager.gd")
const WalkerEnemyScript = preload("res://scripts/enemies/walker_enemy.gd")
const FlyerEnemyScript = preload("res://scripts/enemies/flyer_enemy.gd")
const HealthComponentScript = preload("res://scripts/combat/health_component.gd")
const HurtboxScript = preload("res://scripts/combat/hurtbox.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING ECLIPSE M3 WORLD & ROOM TRANSITIONS SUITE")
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


func create_test_player() -> CharacterBody2D:
	var player = PlayerControllerScript.new()
	player.name = "Player"
	player.add_to_group("player")
	player.input_override_enabled = true
	
	var col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 10.0
	cap.height = 40.0
	col.shape = cap
	player.add_child(col)
	player.collision_shape = col
	
	var visuals = PlayerVisualsScript.new()
	visuals.controller = player
	player.add_child(visuals)
	player.visuals_node = visuals
	
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	player.add_child(cam)
	
	player._ready()
	player.recalculate_physics_constants()
	return player


func _run_all_tests_async() -> void:
	await _test_player_data_ledger()
	await _test_player_data_serialization()
	await _test_room_base_architecture()
	await _test_transition_point_trigger()
	await _test_bench_checkpoint_mechanics()
	await _test_dynamic_enemy_respawn()
	await _test_game_manager_streaming()
	await _test_connected_level_scenes()
	await _test_occult_detective_thematics()
	
	print("\n========================================================")
	print("  M3 WORLD & ROOM TRANSITIONS TEST RESULTS SUMMARY:")
	print("  Total Tests:  %d" % total_tests)
	print("  Passed:       %d" % passed_tests)
	print("  Failed:       %d" % failed_tests)
	if failed_tests == 0:
		print("  ALL M3 WORLD & ROOM TRANSITION TESTS PASSED SUCCESSFULLY!")
	else:
		print("  FAILURES DETECTED (%d):" % failed_tests)
		for f in failures:
			print("    - %s" % f)
	print("========================================================\n")
	
	quit(0 if failed_tests == 0 else 1)


func _test_player_data_ledger() -> void:
	print("\n--- Test Suite 1: PlayerData Ledger & State Tracking ---")
	var data = PlayerDataScript.new()
	
	assert_true(data.max_health == 5, "Default max_health is 5")
	assert_true(data.current_health == 5, "Default current_health is 5")
	assert_true(data.soul == 0, "Default soul is 0")
	assert_true(data.max_soul == 99, "Default max_soul is 99")
	assert_true(data.unlocked_abilities.size() == 0, "Default unlocked_abilities is empty")
	assert_true(data.visited_rooms.size() == 0, "Default visited_rooms is empty")
	assert_true(data.respawn_room_path == "res://scenes/levels/forgotten_entrance.tscn", "Default respawn room is forgotten_entrance")
	assert_true(data.respawn_gate_id == "Bench_Entrance", "Default respawn gate is Bench_Entrance")
	
	# Ability unlocking
	data.unlock_ability("dash")
	data.unlock_ability("wall_jump")
	assert_true(data.has_ability("dash"), "Player has unlocked dash")
	assert_true(data.has_ability("wall_jump"), "Player has unlocked wall_jump")
	assert_true(not data.has_ability("double_jump"), "Player does not have double_jump")
	
	# Unlocking again does not duplicate
	data.unlock_ability("dash")
	assert_true(data.unlocked_abilities.size() == 2, "Unlocking already learned ability does not duplicate")
	
	# Visited rooms
	data.mark_room_visited("res://scenes/levels/forgotten_entrance.tscn")
	assert_true(data.is_room_visited("res://scenes/levels/forgotten_entrance.tscn"), "Room marked visited returns true")
	assert_true(not data.is_room_visited("res://scenes/levels/sunken_archive.tscn"), "Unvisited room returns false")
	
	# Story flags
	data.set_flag("boss_defeated_1", true)
	data.set_flag("relics_collected", 3)
	assert_true(data.get_flag("boss_defeated_1") == true, "Story flag boolean retrieved accurately")
	assert_true(data.get_flag("relics_collected") == 3, "Story flag integer retrieved accurately")
	assert_true(data.get_flag("nonexistent_flag", "default") == "default", "Unset flag returns fallback default")
	
	# Bench checkpoint setting
	data.set_bench_checkpoint("Bench_Archive", "res://scenes/levels/sunken_archive.tscn")
	assert_true(data.last_bench_id == "Bench_Archive", "Bench ID updated on checkpoint set")
	assert_true(data.respawn_gate_id == "Bench_Archive", "Respawn gate ID updated on checkpoint set")
	assert_true(data.respawn_room_path == "res://scenes/levels/sunken_archive.tscn", "Respawn room path updated on checkpoint set")
	
	# Sync to/from player
	var player = create_test_player()
	player.health_component.current_health = 3
	player.current_soul = 66
	
	data.sync_from_player(player)
	assert_true(data.current_health == 3, "PlayerData synced health from player (3)")
	assert_true(data.soul == 66, "PlayerData synced soul from player (66)")
	
	# Modify data and sync back to player
	data.current_health = 4
	data.soul = 99
	data.sync_to_player(player)
	assert_true(player.get_current_health() == 4, "Player health updated via sync_to_player (4)")
	assert_true(player.get_current_soul() == 99, "Player soul updated via sync_to_player (99)")
	
	# Dictionary export and import roundtrip
	var d_dict = data.to_dict()
	assert_true(d_dict["current_health"] == 4, "to_dict exports current_health accurately")
	assert_true(d_dict["soul"] == 99, "to_dict exports soul accurately")
	assert_true(d_dict["unlocked_abilities"].has("dash"), "to_dict exports unlocked abilities")
	
	var fresh_data = PlayerDataScript.new()
	fresh_data.from_dict(d_dict)
	assert_true(fresh_data.current_health == 4, "from_dict imports current_health accurately")
	assert_true(fresh_data.soul == 99, "from_dict imports soul accurately")
	assert_true(fresh_data.has_ability("dash"), "from_dict imports unlocked abilities")
	assert_true(fresh_data.last_bench_id == "Bench_Archive", "from_dict imports last bench ID")
	
	player.queue_free()


func _test_player_data_serialization() -> void:
	print("\n--- Test Suite 2: PlayerData File Persistence (Save / Load) ---")
	var test_save_path := "user://test_save_slot_m3.res"
	
	var save_data = PlayerDataScript.new()
	save_data.current_health = 2
	save_data.soul = 77
	save_data.unlock_ability("dash")
	save_data.unlock_ability("super_pogo")
	save_data.mark_room_visited("res://scenes/levels/test_room.tscn")
	save_data.set_flag("ancient_gate_opened", true)
	save_data.set_bench_checkpoint("Bench_Ancient", "res://scenes/levels/ancient_chamber.tscn")
	
	var err = save_data.save_to_file(test_save_path)
	assert_true(err == OK, "PlayerData saved to disk with status OK")
	assert_true(FileAccess.file_exists(test_save_path), "Save file exists on disk")
	
	# Load back from file
	var loaded_data = PlayerDataScript.load_from_file(test_save_path)
	assert_true(loaded_data != null, "PlayerData loaded from file successfully")
	assert_true(loaded_data.current_health == 2, "Loaded data preserves current_health (2)")
	assert_true(loaded_data.soul == 77, "Loaded data preserves soul (77)")
	assert_true(loaded_data.has_ability("dash"), "Loaded data preserves unlocked ability: dash")
	assert_true(loaded_data.has_ability("super_pogo"), "Loaded data preserves unlocked ability: super_pogo")
	assert_true(loaded_data.is_room_visited("res://scenes/levels/test_room.tscn"), "Loaded data preserves visited room")
	assert_true(loaded_data.get_flag("ancient_gate_opened") == true, "Loaded data preserves story flag")
	assert_true(loaded_data.respawn_gate_id == "Bench_Ancient", "Loaded data preserves respawn gate ID")
	assert_true(loaded_data.respawn_room_path == "res://scenes/levels/ancient_chamber.tscn", "Loaded data preserves respawn room path")
	
	# Nonexistent file returns fresh default
	var nonexistent_data = PlayerDataScript.load_from_file("user://nonexistent_save_file_xyz.res")
	assert_true(nonexistent_data != null, "Loading nonexistent file returns fresh PlayerData instance")
	assert_true(nonexistent_data.max_health == 5, "Fallback data has default max_health (5)")
	assert_true(nonexistent_data.current_health == 5, "Fallback data has default current_health (5)")
	
	# Clean up test save file
	DirAccess.remove_absolute(test_save_path)
	
	# Test JSON disk persistence
	var json_save_path := "user://test_save_slot_1.json"
	var json_err = save_data.save_to_file(json_save_path)
	assert_true(json_err == OK, "PlayerData saved to JSON file with status OK")
	assert_true(FileAccess.file_exists(json_save_path), "JSON save file exists on disk")
	
	var loaded_json = PlayerDataScript.load_from_file(json_save_path)
	assert_true(loaded_json != null, "PlayerData loaded from JSON file successfully")
	assert_true(loaded_json.current_health == 2, "Loaded JSON preserves current_health (2)")
	assert_true(loaded_json.soul == 77, "Loaded JSON preserves soul (77)")
	assert_true(loaded_json.has_ability("dash"), "Loaded JSON preserves unlocked ability: dash")
	assert_true(loaded_json.get_flag("ancient_gate_opened") == true, "Loaded JSON preserves story flag")
	assert_true(loaded_json.respawn_gate_id == "Bench_Ancient", "Loaded JSON preserves respawn gate ID")
	DirAccess.remove_absolute(json_save_path)
	
	# Test corrupted / mismatched types in from_dict
	var corrupted_dict := {
		"max_health": "invalid_num",
		"current_health": "five",
		"soul": -50,
		"max_soul": "150",
		"unlocked_abilities": [123, "dash"],
		"visited_rooms": [999, "res://test.tscn"],
		"story_flags": null,
		"respawn_room_path": "",
		"respawn_gate_id": "",
		"last_bench_id": ""
	}
	var recovery_data = PlayerDataScript.new()
	recovery_data.from_dict(corrupted_dict)
	assert_true(recovery_data.max_health == 5, "Corrupted max_health falls back to 5")
	assert_true(recovery_data.current_health == 5, "Corrupted current_health string falls back to max_health")
	assert_true(recovery_data.soul == 0, "Negative soul clamped to 0")
	assert_true(recovery_data.max_soul == 150, "String-encoded valid int max_soul parsed to 150")
	assert_true(recovery_data.has_ability("dash"), "Corrupted abilities array preserved string entry")
	assert_true(recovery_data.has_ability("123"), "Integer in abilities array safely converted to string")
	assert_true(recovery_data.is_room_visited("res://test.tscn"), "Corrupted visited rooms preserved string entry")
	assert_true(recovery_data.story_flags.is_empty(), "Null story flags safely assigned empty dictionary")
	assert_true(recovery_data.respawn_room_path == "res://scenes/levels/forgotten_entrance.tscn", "Empty respawn room path falls back to default")


func _test_room_base_architecture() -> void:
	print("\n--- Test Suite 3: RoomBase Architecture & Camera Boundaries ---")
	var room = RoomBaseScript.new()
	room.room_id = "test_chamber"
	room.room_name = "Test Archival Chamber"
	room.limit_left = -250
	room.limit_right = 3200
	room.limit_top = -400
	room.limit_bottom = 1000
	room.default_spawn_point = Vector2(200, 500)
	
	# Add mock gates
	var gate1 = Marker2D.new()
	gate1.name = "Gate_North"
	gate1.position = Vector2(400, 100)
	room.add_child(gate1)
	
	var gate2 = TransitionPointScript.new()
	gate2.name = "DoorA_Exit"
	gate2.gate_id = "DoorA_Exit"
	gate2.position = Vector2(1800, 600)
	room.add_child(gate2)
	
	room._ready()
	
	assert_true(room.has_gate("Gate_North"), "Room registers child Marker2D gate Gate_North")
	assert_true(room.has_gate("DoorA_Exit"), "Room registers TransitionPoint gate DoorA_Exit")
	assert_true(room.get_gate_position("Gate_North") == Vector2(400, 100), "get_gate_position returns correct coords for Gate_North")
	assert_true(room.get_gate_position("DoorA_Exit") == Vector2(1800, 600), "get_gate_position returns correct coords for DoorA_Exit")
	assert_true(room.get_gate_position("Nonexistent_Gate") == Vector2(200, 500), "get_gate_position falls back to default_spawn_point")
	
	# Dedicated spawn marker test
	var gate_spawn = Marker2D.new()
	gate_spawn.name = "DoorA_Exit_Spawn"
	gate_spawn.position = Vector2(1720, 600)
	room.add_child(gate_spawn)
	room._scan_and_register_gates()
	assert_true(room.get_gate_position("DoorA_Exit") == Vector2(1720, 600), "get_gate_position prefers dedicated DoorA_Exit_Spawn marker")
	
	# Camera boundary application
	var cam := Camera2D.new()
	room.apply_camera_limits(cam)
	assert_true(cam.limit_left == -250, "Camera limit_left assigned accurately")
	assert_true(cam.limit_right == 3200, "Camera limit_right assigned accurately")
	assert_true(cam.limit_top == -400, "Camera limit_top assigned accurately")
	assert_true(cam.limit_bottom == 1000, "Camera limit_bottom assigned accurately")
	
	room.queue_free()
	cam.queue_free()


func _test_transition_point_trigger() -> void:
	print("\n--- Test Suite 4: TransitionPoint Gateway Trigger & Configuration ---")
	var gate = TransitionPointScript.new()
	gate.gate_id = "Gate_East"
	gate.target_room_path = "res://scenes/levels/sunken_archive.tscn"
	gate.target_gate_id = "Gate_West"
	gate.travel_direction = Vector2.RIGHT
	gate.is_active = true
	gate.spawn_offset = Vector2(-48, 0)
	
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 80)
	col.shape = rect
	gate.add_child(col)
	gate._ready()
	
	assert_true(gate.collision_layer == 1, "TransitionPoint collision_layer is on Layer 1 (World)")
	assert_true((gate.collision_mask & 2) != 0, "TransitionPoint collision_mask listens to Layer 2 (Player)")
	assert_true((gate.collision_mask & 16) != 0, "TransitionPoint collision_mask listens to Layer 5 (PlayerHurtbox)")
	assert_true(gate.get_gate_id() == "Gate_East", "get_gate_id returns Gate_East")
	assert_true(gate.get_spawn_position() == gate.global_position + Vector2(-48, 0), "get_spawn_position includes spawn_offset")
	
	var player = create_test_player()
	
	var triggered_signal_received := [false]
	var sig_room := [""]
	var sig_gate := [""]
	var sig_dir := [Vector2.ZERO]
	gate.transition_triggered.connect(func(target_r: String, target_g: String, dir: Vector2):
		triggered_signal_received[0] = true
		sig_room[0] = target_r
		sig_gate[0] = target_g
		sig_dir[0] = dir
	)
	
	# Trigger via body_entered
	gate._on_body_entered(player)
	assert_true(triggered_signal_received[0], "transition_triggered signal emitted on player body entry")
	assert_true(sig_room[0] == "res://scenes/levels/sunken_archive.tscn", "Signal reports target room accurately")
	assert_true(sig_gate[0] == "Gate_West", "Signal reports target gate accurately")
	assert_true(sig_dir[0] == Vector2.RIGHT, "Signal reports travel direction accurately")
	
	# Guard test: lethal damage rejection
	var dead_triggered := [false]
	var test_gate_dead = TransitionPointScript.new()
	test_gate_dead.target_room_path = "res://scenes/levels/sunken_archive.tscn"
	test_gate_dead.transition_triggered.connect(func(_r, _g, _d): dead_triggered[0] = true)
	player.health_component.current_health = 0
	test_gate_dead._on_body_entered(player)
	assert_true(not dead_triggered[0], "Transition rejected when player has 0 HP (lethal damage)")
	
	# Guard test: input locked rejection
	var locked_triggered := [false]
	player.health_component.current_health = 5
	player.input_locked = true
	test_gate_dead.transition_triggered.connect(func(_r, _g, _d): locked_triggered[0] = true)
	test_gate_dead._on_body_entered(player)
	assert_true(not locked_triggered[0], "Transition rejected when player is input locked")
	player.input_locked = false
	test_gate_dead.queue_free()
	
	# Inactive gate rejection
	var inactive_gate = TransitionPointScript.new()
	inactive_gate.is_active = false
	inactive_gate.target_room_path = "res://scenes/levels/sunken_archive.tscn"
	var inactive_triggered := [false]
	inactive_gate.transition_triggered.connect(func(_r, _g, _d): inactive_triggered[0] = true)
	inactive_gate._on_body_entered(player)
	assert_true(not inactive_triggered[0], "Inactive transition gate ignores player collision")
	
	gate.queue_free()
	inactive_gate.queue_free()
	player.queue_free()


func _test_bench_checkpoint_mechanics() -> void:
	print("\n--- Test Suite 5: BenchCheckpoint Interaction, Healing & Disk Save ---")
	var room = RoomBaseScript.new()
	room.room_id = "sanctuary"
	
	var bench = BenchCheckpointScript.new()
	bench.bench_id = "Bench_Sanctuary"
	bench.bench_name = "Sanctuary Archival Lamp"
	bench.position = Vector2(200, 400)
	
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	col.shape = rect
	bench.add_child(col)
	room.add_child(bench)
	
	var player = create_test_player()
	room.add_child(player)
	
	bench._ready()
	
	assert_true(bench.collision_layer == 256, "BenchCheckpoint is on Layer 9 (Interactables = 256)")
	assert_true(bench.collision_mask == 2, "BenchCheckpoint monitors Layer 2 (Player = 2)")
	assert_true(bench.get_gate_id() == "Bench_Sanctuary", "Bench get_gate_id returns Bench_Sanctuary")
	
	# Player approach & departure signals
	var approached := [false]
	var departed := [false]
	bench.player_approached.connect(func(): approached[0] = true)
	bench.player_departed.connect(func(): departed[0] = true)
	
	bench._on_body_entered(player)
	assert_true(approached[0], "player_approached signal emitted when entering bench area")
	
	bench._on_body_exited(player)
	assert_true(departed[0], "player_departed signal emitted when leaving bench area")
	
	# Damage player and deplete soul
	player.health_component.current_health = 2
	player.current_soul = 15
	player.velocity = Vector2(150, -50)
	player.current_state = PlayerControllerScript.State.RUN
	
	var bench_rested_emitted := [false]
	bench.bench_rested.connect(func(_id: String): bench_rested_emitted[0] = true)
	
	# Sit at bench
	bench.rest(player)
	
	assert_true(bench_rested_emitted[0], "bench_rested signal emitted upon sitting")
	assert_true(player.get_current_health() == player.get_max_health(), "Resting at bench restores player to full health masks (5/5)")
	assert_true(player.get_current_soul() == player.get_max_soul(), "Resting at bench refills player Soul to max capacity (99/99)")
	assert_true(player.velocity == Vector2.ZERO, "Player velocity zeroed upon resting at bench")
	assert_true(player.current_state == PlayerControllerScript.State.IDLE, "Player transitioned to IDLE upon resting at bench")
	assert_true(bench._rest_flare_timer > 0.4, "Visual rest flare timer primed on archival lamp")
	
	# Verify save file written to disk
	assert_true(FileAccess.file_exists("user://save_slot_1.res"), "Save file written to user://save_slot_1.res upon bench rest")
	var loaded = PlayerDataScript.load_from_file("user://save_slot_1.res")
	assert_true(loaded != null, "Saved bench data loads successfully from disk")
	assert_true(loaded.current_health == 5, "Saved bench data records restored health (5)")
	assert_true(loaded.soul == 99, "Saved bench data records restored soul (99)")
	assert_true(loaded.last_bench_id == "Bench_Sanctuary", "Saved bench data records last_bench_id as Bench_Sanctuary")
	
	# Airborne bench sit rejection test
	var airborne_player = create_test_player()
	airborne_player.simulated_on_floor_override = true
	airborne_player.simulated_on_floor = false
	airborne_player.simulated_move_up = true
	bench._player_in_range = airborne_player
	var airborne_rest_emitted := [false]
	bench.bench_rested.connect(func(_id): airborne_rest_emitted[0] = true)
	bench._process(0.016)
	assert_true(not airborne_rest_emitted[0], "Airborne player cannot sit on bench")
	airborne_player.queue_free()
	
	room.queue_free()


func _test_dynamic_enemy_respawn() -> void:
	print("\n--- Test Suite 6: RoomBase Dynamic Enemy Respawn Control ---")
	var room = RoomBaseScript.new()
	room.room_id = "combat_arena"
	
	# Add a Walker enemy
	var walker = WalkerEnemyScript.new()
	walker.name = "PatrolHusk"
	walker.position = Vector2(500, 300)
	
	var w_col := CollisionShape2D.new()
	var w_cap := CapsuleShape2D.new()
	w_cap.radius = 12.0
	w_cap.height = 36.0
	w_col.shape = w_cap
	walker.add_child(w_col)
	
	var hc = HealthComponentScript.new()
	hc.name = "HealthComponent"
	hc.max_health = 3
	hc.current_health = 3
	walker.add_child(hc)
	walker.health_component = hc
	
	var hurt = HurtboxScript.new()
	hurt.name = "Hurtbox"
	hurt.health_component = hc
	walker.add_child(hurt)
	walker.hurtbox = hurt
	
	room.add_child(walker)
	walker._ready()
	room._ready()
	
	assert_true(room._initial_enemies.size() == 1, "RoomBase captured snapshot of initial enemy")
	
	# Simulate damage and movement
	walker.position = Vector2(800, 300)
	walker.health_component.current_health = 1
	walker.velocity = Vector2(100, 0)
	walker.current_state = 3 # ATTACK
	
	var respawn_signal_emitted := [false]
	room.enemy_respawn_triggered.connect(func(): respawn_signal_emitted[0] = true)
	
	# Trigger room enemy respawn
	room.respawn_enemies()
	
	assert_true(respawn_signal_emitted[0], "enemy_respawn_triggered signal was emitted")
	assert_true(walker.position == Vector2(500, 300), "Enemy restored to original spawn coordinates")
	assert_true(walker.health_component.current_health == 3, "Enemy health restored to full (3)")
	assert_true(walker.velocity == Vector2.ZERO, "Enemy velocity zeroed on respawn")
	assert_true(walker.current_state == 1, "Enemy state restored to PATROL")
	
	room.queue_free()


func _test_game_manager_streaming() -> void:
	print("\n--- Test Suite 7: GameManager Room Streaming Pipeline ---")
	var gm = GameManagerScript.new()
	root.add_child(gm)
	gm._ready()
	
	var player = create_test_player()
	player.current_soul = 44
	player.health_component.current_health = 3
	
	# Test input locking
	gm.lock_player(player)
	assert_true(player.input_locked, "lock_player sets player.input_locked = true")
	assert_true(player.velocity.x == 0.0, "lock_player halts player horizontal velocity")
	assert_true(not player.can_focus(), "Player cannot initiate focus while input_locked")
	
	# Test input unlocking
	gm.unlock_player(player)
	assert_true(not player.input_locked, "unlock_player sets player.input_locked = false")
	
	# Save and load game via GameManager
	var gm_save_path := "user://gm_test_save.res"
	gm._current_player = player
	var save_err = gm.save_game(gm_save_path)
	assert_true(save_err == OK, "GameManager.save_game succeeded with OK")
	
	player.health_component.current_health = 1
	player.current_soul = 0
	
	var load_success = gm.load_game(gm_save_path)
	assert_true(load_success, "GameManager.load_game succeeded")
	assert_true(player.get_current_health() == 3, "Loaded state restored player health to 3")
	assert_true(player.get_current_soul() == 44, "Loaded state restored player soul to 44")
	
	# Bench respawn vitals restoration test
	gm.player_data.max_health = 5
	gm.player_data.current_health = 1
	gm.player_data.soul = 88
	gm.player_data.respawn_room_path = "res://scenes/levels/forgotten_entrance.tscn"
	gm.player_data.respawn_gate_id = "Bench_Entrance"
	gm.respawn_at_last_bench(true)
	assert_true(gm.player_data.current_health == 5, "respawn_at_last_bench restores player health to full max_health (5)")
	assert_true(gm.player_data.soul == 0, "respawn_at_last_bench resets soul to 0 on death")
	
	DirAccess.remove_absolute(gm_save_path)
	gm.queue_free()
	player.queue_free()


func _test_connected_level_scenes() -> void:
	print("\n--- Test Suite 8: Two-Way Level Scene Integration (Entrance <-> Archive) ---")
	# 1. Load Forgotten Entrance
	var entrance_scene = ResourceLoader.load("res://scenes/levels/forgotten_entrance.tscn") as PackedScene
	assert_true(entrance_scene != null, "res://scenes/levels/forgotten_entrance.tscn loads successfully")
	
	var entrance_instance = entrance_scene.instantiate()
	assert_true(entrance_instance != null, "forgotten_entrance.tscn instantiates cleanly")
	assert_true(entrance_instance is RoomBaseScript, "forgotten_entrance root node is a RoomBase")
	
	var entrance_player = entrance_instance.get_node_or_null("Player") as CharacterBody2D
	var entrance_bench = entrance_instance.get_node_or_null("Bench_Entrance")
	var entrance_gate = entrance_instance.get_node_or_null("Gate_East")
	
	assert_true(entrance_player != null, "Player node found in forgotten_entrance")
	assert_true(entrance_bench != null, "Bench_Entrance found in forgotten_entrance")
	assert_true(entrance_bench is BenchCheckpointScript, "Bench_Entrance is of type BenchCheckpoint")
	assert_true(entrance_gate != null, "Gate_East transition trigger found in forgotten_entrance")
	assert_true(entrance_gate is TransitionPointScript, "Gate_East is of type TransitionPoint")
	assert_true(entrance_gate.target_room_path == "res://scenes/levels/sunken_archive.tscn", "Gate_East points to sunken_archive.tscn")
	assert_true(entrance_gate.target_gate_id == "Archive_West", "Gate_East targets Archive_West gate")
	
	# 2. Load Sunken Archive
	var archive_scene = ResourceLoader.load("res://scenes/levels/sunken_archive.tscn") as PackedScene
	assert_true(archive_scene != null, "res://scenes/levels/sunken_archive.tscn loads successfully")
	
	var archive_instance = archive_scene.instantiate()
	assert_true(archive_instance != null, "sunken_archive.tscn instantiates cleanly")
	assert_true(archive_instance is RoomBaseScript, "sunken_archive root node is a RoomBase")
	
	var archive_player = archive_instance.get_node_or_null("Player") as CharacterBody2D
	var archive_gate = archive_instance.get_node_or_null("Gate_West")
	var archive_walker = archive_instance.get_node_or_null("WalkerEnemy")
	var archive_flyer = archive_instance.get_node_or_null("FlyerEnemy")
	var archive_spikes = archive_instance.get_node_or_null("HazardSpikes")
	
	assert_true(archive_player != null, "Player node found in sunken_archive")
	assert_true(archive_gate != null, "Gate_West transition trigger found in sunken_archive")
	assert_true(archive_gate is TransitionPointScript, "Gate_West is of type TransitionPoint")
	assert_true(archive_gate.target_room_path == "res://scenes/levels/forgotten_entrance.tscn", "Gate_West points to forgotten_entrance.tscn")
	assert_true(archive_gate.target_gate_id == "Entrance_East", "Gate_West targets Entrance_East gate")
	assert_true(archive_walker != null, "WalkerEnemy encounter present in sunken_archive")
	assert_true(archive_flyer != null, "FlyerEnemy encounter present in sunken_archive")
	assert_true(archive_spikes != null, "HazardSpikes pit present in sunken_archive")
	
	# 3. Simulate Two-Way Transition Walk
	# Simulate entering Entrance_East transition
	root.add_child(entrance_instance)
	entrance_instance._ready()
	
	# Rest at Entrance bench to save checkpoint
	entrance_bench.rest(entrance_player)
	assert_true(entrance_player.get_current_health() == 5, "Rested at entrance bench, health is 5")
	
	# Simulate walking into Gate_East
	var transition_data := { "room": "", "gate": "", "dir": Vector2.ZERO }
	entrance_gate.transition_triggered.connect(func(r, g, d):
		transition_data["room"] = r
		transition_data["gate"] = g
		transition_data["dir"] = d
	)
	entrance_gate._on_body_entered(entrance_player)
	
	assert_true(transition_data["room"] == "res://scenes/levels/sunken_archive.tscn", "Entrance -> Archive transition triggered with target room")
	assert_true(transition_data["gate"] == "Archive_West", "Entrance -> Archive transition targeted Archive_West")
	assert_true(transition_data["dir"] == Vector2(1, 0), "Entrance -> Archive transition preserved forward direction")
	
	# Switch to Archive scene
	root.remove_child(entrance_instance)
	root.add_child(archive_instance)
	archive_instance._ready()
	
	# Anchor player at Archive_West gate
	var archive_spawn = archive_instance.get_gate_position("Archive_West")
	assert_true(archive_spawn == Vector2(120, 470), "Archive_West resolves to Archive_West_Spawn marker coords (120, 470)")
	archive_player.global_position = archive_spawn
	archive_player.velocity = transition_data["dir"] * 120.0
	assert_true(archive_player.velocity.x > 0.0, "Player entered archive with forward velocity")
	
	# Simulate combat in archive: take damage
	archive_player.health_component.current_health = 3
	assert_true(archive_player.get_current_health() == 3, "Player took damage during archive combat")
	
	# Simulate returning through Gate_West back to Entrance
	var return_transition := { "room": "", "gate": "", "dir": Vector2.ZERO }
	archive_gate.transition_triggered.connect(func(r, g, d):
		return_transition["room"] = r
		return_transition["gate"] = g
		return_transition["dir"] = d
	)
	archive_gate._on_body_entered(archive_player)
	
	assert_true(return_transition["room"] == "res://scenes/levels/forgotten_entrance.tscn", "Archive -> Entrance return transition triggered")
	assert_true(return_transition["gate"] == "Entrance_East", "Archive -> Entrance return targeted Entrance_East")
	assert_true(return_transition["dir"] == Vector2(-1, 0), "Archive -> Entrance return preserved leftward direction")
	
	var entrance_spawn = entrance_instance.get_gate_position("Entrance_East")
	assert_true(entrance_spawn == Vector2(1620, 470), "Entrance_East resolves to Entrance_East_Spawn marker coords (1620, 470)")
	
	# Clean up scenes
	entrance_instance.queue_free()
	archive_instance.queue_free()
	await process_frame


func _test_occult_detective_thematics() -> void:
	print("\n--- Test Suite 9: Occult Detective Visuals & Tarot Feedback ---")
	var player = create_test_player()
	root.add_child(player)
	player._ready()
	
	var visuals = player.visuals_node
	assert_true(visuals != null, "PlayerVisuals attached to player")
	assert_true(visuals.COLOR_HAT_SILK == Color(0.10, 0.11, 0.14, 1.0), "Silk top hat obsidian color defined")
	assert_true(visuals.COLOR_HAT_BAND == Color(0.58, 0.16, 0.84, 1.0), "Royal purple top hat band color defined")
	assert_true(visuals.COLOR_CAPELET_LINING == Color(0.68, 0.20, 0.92, 1.0), "Rich purple silk capelet lining color defined")
	assert_true(visuals.COLOR_CANE_SILVER == Color(0.88, 0.92, 0.98, 1.0), "Silver cane sword hilt color defined")
	assert_true(visuals.COLOR_TAROT_RUNE == Color(0.40, 0.92, 1.0, 0.95), "Celestial cyan tarot rune color defined")
	
	# Test Cane Sword attack animation trigger
	visuals.play_slash(0, 1) # Forward slash
	assert_true(visuals.slash_timer > 0.0, "Cane sword slash timer active")
	assert_true(visuals.slash_direction == 0, "Cane sword slash direction forward")
	
	# Test Soul gain triggering Tarot card energy sparks
	player.current_soul = 0
	visuals._last_soul = 0
	player.add_soul(11) # Strike enemy
	assert_true(player.current_soul == 11, "Player accumulated 11 soul from strike")
	assert_true(visuals.tarot_charge_sparks.size() > 0, "Striking enemy spawned celestial tarot card charge sparks")
	
	# Test Tarot focus channeling visual activation
	player.current_state = PlayerControllerScript.State.FOCUS
	assert_true(player.is_focusing(), "Player is focusing")
	
	player.queue_free()
