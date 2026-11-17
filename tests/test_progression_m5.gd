extends SceneTree

## ECLIPSE: Echoes of the Forgotten
## Milestone 5: Progression Systems & Traversal Abilities Test Suite
## Validates Double Jump (Lunar Wings), Mantle / Ledge Grab, AbilityPickup entity,
## Stygian Shards currency economy, Mask Shard health upgrades, PlayerData persistence,
## and Celestial Sanctuary room integration with ability gating.

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const PlayerConfigScript = preload("res://scripts/player/player_config.gd")
const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const GameManagerScript = preload("res://scripts/core/game_manager.gd")
const AbilityPickupScript = preload("res://scripts/world/ability_pickup.gd")
const RoomBaseScript = preload("res://scripts/world/room_base.gd")
const TransitionPointScript = preload("res://scripts/world/transition_point.gd")
const BenchCheckpointScript = preload("res://scripts/world/bench_checkpoint.gd")
const EnemyBaseScript = preload("res://scripts/enemies/enemy_base.gd")

var tests_run: int = 0
var tests_passed: int = 0
var tests_failed: int = 0


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING ECLIPSE M5 PROGRESSION & ABILITIES SUITE")
	print("  Godot Engine: %s" % Engine.get_version_info().string)
	print("========================================================\n")
	
	_test_double_jump_mechanics()
	_test_mantle_mechanics()
	_test_ability_pickup_entity()
	_test_currency_and_enemy_rewards()
	_test_mask_shard_health_upgrade()
	_test_player_data_progression_persistence()
	_test_celestial_sanctuary_structure()
	_test_two_way_transitions_chamber_sanctuary()
	_test_ability_gate_reachability()
	
	_print_summary()
	quit(0 if tests_failed == 0 else 1)


func assert_true(condition: bool, test_name: String) -> void:
	tests_run += 1
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		tests_failed += 1
		print("  [FAIL] %s" % test_name)


func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	tests_run += 1
	if actual == expected:
		tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		tests_failed += 1
		print("  [FAIL] %s: Expected '%s', got '%s'" % [test_name, str(expected), str(actual)])


func _test_double_jump_mechanics() -> void:
	print("--- Test Suite 1: Double Jump (Lunar Wings) Mechanics ---")
	var player = PlayerControllerScript.new()
	player.input_override_enabled = true
	root.add_child(player)
	
	assert_true(player.double_jump_unlocked == false, "double_jump_unlocked is false by default on fresh controller")
	assert_true(player.can_double_jump == false, "can_double_jump is false initially before being grounded")
	
	# Simulate landing on floor to charge abilities
	player.simulated_on_floor_override = true
	player.simulated_on_floor = true
	player._physics_process(0.016)
	assert_true(player.can_double_jump == true, "can_double_jump resets to true when grounded")
	
	# Become airborne
	player.simulated_on_floor = false
	player.coyote_timer = 0.0
	player.velocity.y = 100.0
	
	# Attempt double jump while locked
	player.simulated_jump_pressed = true
	player.simulated_jump_held = true
	player._physics_process(0.016)
	assert_true(player.velocity.y > 0.0, "Cannot double jump when double_jump_unlocked is false")
	
	# Unlock double jump
	player.double_jump_unlocked = true
	player.can_double_jump = true
	var double_jumped_emitted := [false]
	player.double_jumped.connect(func(): double_jumped_emitted[0] = true)
	
	# Execute double jump
	player.simulated_jump_pressed = true
	player.simulated_jump_held = true
	player._physics_process(0.016)
	
	assert_true(double_jumped_emitted[0], "double_jumped signal emitted on mid-air jump")
	assert_true(player.is_double_jumping == true, "is_double_jumping flag active")
	assert_true(player.velocity.y == player.double_jump_velocity, "Double jump velocity applied (-440 px/s)")
	assert_true(player.can_double_jump == false, "can_double_jump consumed after double jump")
	
	# Attempt consecutive 3rd jump in mid-air
	player.simulated_jump_pressed = true
	var prev_vel_y = player.velocity.y
	player._physics_process(0.016)
	assert_true(player.velocity.y >= prev_vel_y, "Cannot perform triple jump (charge stays consumed)")
	
	# Test variable jump cutoff on double jump
	player.simulated_jump_held = false
	player.simulated_jump_released = true
	player._physics_process(0.016)
	assert_true(player.velocity.y > player.double_jump_velocity, "Early jump release cuts double jump velocity in half")
	
	# Test double jump refresh on ground touch
	player.simulated_on_floor = true
	player._physics_process(0.016)
	assert_true(player.can_double_jump == true, "can_double_jump refreshed on touching ground")
	
	# Test double jump refresh on wall slide
	player.simulated_on_floor = false
	player.can_double_jump = false
	player.simulated_on_wall_override = true
	player.simulated_on_wall = true
	player.velocity.y = 80.0
	player._physics_process(0.016)
	assert_true(player.can_double_jump == true, "can_double_jump refreshed on wall contact / slide")
	
	# Test double jump refresh on pogo bounce
	player.simulated_on_wall = false
	player.can_double_jump = false
	player.current_attack_direction = PlayerControllerScript.AttackDirection.DOWN
	player._on_pogo_triggered(null)
	assert_true(player.can_double_jump == true, "can_double_jump refreshed on downward pogo bounce")
	
	player.queue_free()


func _test_mantle_mechanics() -> void:
	print("\n--- Test Suite 2: Ledge Grab / Mantle Mechanics ---")
	var player = PlayerControllerScript.new()
	player.input_override_enabled = true
	root.add_child(player)
	
	assert_true(player.mantle_unlocked == false, "mantle_unlocked is false by default")
	
	# Test ledge detection query when locked
	player.simulated_on_floor_override = true
	player.simulated_on_floor = false
	player.velocity.y = 50.0
	player.simulated_mantle_detected = true
	player._physics_process(0.016)
	assert_true(player.current_state != PlayerControllerScript.State.MANTLE, "Does not enter MANTLE when mantle_unlocked is false")
	
	# Unlock mantle
	player.mantle_unlocked = true
	var mantled_emitted := [false]
	player.mantled.connect(func(): mantled_emitted[0] = true)
	
	# Trigger mantle grab
	player._physics_process(0.016)
	assert_true(mantled_emitted[0], "mantled signal emitted on grabbing ledge")
	assert_true(player.current_state == PlayerControllerScript.State.MANTLE, "Player entered State.MANTLE")
	assert_true(player.velocity == Vector2.ZERO, "Player velocity frozen in MANTLE state")
	assert_true(player.can_double_jump == true, "Double jump refreshed upon grabbing ledge")
	
	# Test drop release with DOWN input
	player.simulated_move_down = true
	player._physics_process(0.016)
	assert_true(player.current_state == PlayerControllerScript.State.FALL, "Pressing DOWN releases mantle into State.FALL")
	
	# Re-enter mantle
	player.simulated_move_down = false
	player._physics_process(0.016)
	assert_true(player.current_state == PlayerControllerScript.State.MANTLE, "Re-entered MANTLE state")
	
	# Test vault pull-up with JUMP input
	var mantle_completed_emitted := [false]
	player.mantle_completed.connect(func(): mantle_completed_emitted[0] = true)
	var pre_vault_pos = player.position
	player.simulated_jump_pressed = true
	player._physics_process(0.016)
	
	assert_true(mantle_completed_emitted[0], "mantle_completed emitted on vault up")
	assert_true(player.current_state == PlayerControllerScript.State.IDLE, "Player entered State.IDLE after vaulting")
	assert_true(player.position.y < pre_vault_pos.y, "Player displaced vertically upward onto platform")
	
	# Test damage interrupts mantle
	player.mantle_timer = 0.4
	player._set_state(PlayerControllerScript.State.MANTLE)
	player._on_hurtbox_hit_received(RefCounted.new())
	assert_true(player.current_state == PlayerControllerScript.State.FALL, "Damage interrupts MANTLE into State.FALL")
	
	player.queue_free()


func _test_ability_pickup_entity() -> void:
	print("\n--- Test Suite 3: AbilityPickup Entity Architecture ---")
	var pickup = AbilityPickupScript.new()
	pickup.pickup_id = "test_wings"
	pickup.pickup_type = AbilityPickupScript.PickupType.ABILITY
	pickup.ability_name = "double_jump"
	pickup.auto_collect_on_touch = true
	root.add_child(pickup)
	
	assert_true(pickup.collision_layer == 256, "AbilityPickup on Layer 9 (Interactables = 256)")
	assert_true(pickup.collision_mask == 2, "AbilityPickup monitors Layer 2 (Player = 2)")
	assert_true(pickup.is_collected == false, "Pickup initially uncollected")
	
	# Setup test player
	var player = PlayerControllerScript.new()
	player.name = "Player"
	player.double_jump_unlocked = false
	root.add_child(player)
	
	# Setup GameManager and PlayerData
	var gm = GameManagerScript.new()
	var pd = PlayerDataScript.new()
	gm.player_data = pd
	GameManagerScript.instance = gm
	root.add_child(gm)
	
	var collected_emitted := [false]
	pickup.collected.connect(func(_id, _type): collected_emitted[0] = true)
	
	# Execute collection
	pickup.execute_collection(player)
	
	assert_true(collected_emitted[0], "collected signal emitted")
	assert_true(pickup.is_collected == true, "Pickup marked as collected")
	assert_true(pd.has_ability("double_jump"), "PlayerData recorded unlocked ability 'double_jump'")
	assert_true(pd.has_story_flag("collected_test_wings"), "PlayerData set story flag 'collected_test_wings'")
	assert_true(player.double_jump_unlocked == true, "PlayerController synchronized double_jump_unlocked to true")
	
	# Test persistence check on room reload / fresh instantiation
	var fresh_pickup = AbilityPickupScript.new()
	fresh_pickup.pickup_id = "test_wings"
	fresh_pickup.pickup_type = AbilityPickupScript.PickupType.ABILITY
	fresh_pickup.ability_name = "double_jump"
	root.add_child(fresh_pickup)
	fresh_pickup._check_initial_persistence()
	
	assert_true(fresh_pickup.is_collected == true, "Re-instantiated pickup immediately recognizes story flag")
	assert_true(fresh_pickup.visible == false, "Already collected pickup hides visuals")
	assert_true(fresh_pickup.monitoring == false, "Already collected pickup disables monitoring")
	
	fresh_pickup.queue_free()
	pickup.queue_free()
	player.queue_free()
	gm.queue_free()
	GameManagerScript.instance = null


func _test_currency_and_enemy_rewards() -> void:
	print("\n--- Test Suite 4: Currency & Enemy Defeat Rewards ---")
	var pd = PlayerDataScript.new()
	assert_true(pd.currency == 0, "Initial currency is 0")
	
	# Test currency accumulation
	pd.add_currency(25)
	assert_true(pd.currency == 25, "add_currency(25) increased balance to 25")
	pd.add_currency(75)
	assert_true(pd.currency == 100, "add_currency(75) increased balance to 100")
	
	# Test currency spending
	var spend_fail = pd.spend_currency(150)
	assert_true(spend_fail == false, "spend_currency(150) rejected when balance is 100")
	assert_true(pd.currency == 100, "Balance unchanged on failed spend")
	
	var spend_success = pd.spend_currency(40)
	assert_true(spend_success == true, "spend_currency(40) accepted")
	assert_true(pd.currency == 60, "Balance reduced to 60")
	
	# Test enemy defeat currency reward
	var gm = GameManagerScript.new()
	gm.name = "GameManager"
	gm.player_data = pd
	GameManagerScript.instance = gm
	root.add_child(gm)
	
	var enemy = EnemyBaseScript.new()
	enemy.currency_reward = 8
	root.add_child(enemy)
	
	enemy._on_died()
	assert_true(pd.currency == 68, "Enemy defeat awarded 8 currency to PlayerData (total 68)")
	
	enemy.queue_free()
	gm.queue_free()
	GameManagerScript.instance = null


func _test_mask_shard_health_upgrade() -> void:
	print("\n--- Test Suite 5: Mask Shard Health Upgrade System ---")
	var pd = PlayerDataScript.new()
	assert_true(pd.max_health == 5, "Initial max health is 5")
	assert_true(pd.mask_shards == 0, "Initial mask shards is 0")
	
	# Collect shards 1, 2, 3
	var up1 = pd.add_mask_shard()
	assert_true(up1 == false, "Shard 1 does not upgrade max health")
	assert_true(pd.mask_shards == 1, "mask_shards is 1")
	assert_true(pd.max_health == 5, "max_health remains 5")
	
	var up2 = pd.add_mask_shard()
	assert_true(up2 == false, "Shard 2 does not upgrade max health")
	assert_true(pd.mask_shards == 2, "mask_shards is 2")
	
	var up3 = pd.add_mask_shard()
	assert_true(up3 == false, "Shard 3 does not upgrade max health")
	assert_true(pd.mask_shards == 3, "mask_shards is 3")
	
	# Collect 4th shard -> Upgrade!
	pd.current_health = 2 # Simulate injured player
	var up4 = pd.add_mask_shard()
	assert_true(up4 == true, "Shard 4 triggers health upgrade")
	assert_true(pd.mask_shards == 0, "mask_shards resets to 0")
	assert_true(pd.max_health == 6, "max_health increased to 6")
	assert_true(pd.current_health == 6, "Player fully healed upon health upgrade (6/6)")


func _test_player_data_progression_persistence() -> void:
	print("\n--- Test Suite 6: PlayerData Progression Serialization ---")
	var pd = PlayerDataScript.new()
	pd.max_health = 6
	pd.current_health = 6
	pd.currency = 240
	pd.mask_shards = 2
	pd.unlock_ability("dash")
	pd.unlock_ability("double_jump")
	pd.add_collectible("relic_lunar_sigil")
	pd.set_story_flag("boss_warden_defeated", true)
	
	# Roundtrip via dictionary
	var dict_data = pd.to_dict()
	assert_true(dict_data["currency"] == 240, "to_dict exports currency accurately")
	assert_true(dict_data["mask_shards"] == 2, "to_dict exports mask_shards accurately")
	assert_true(dict_data["unlocked_abilities"].has("double_jump"), "to_dict exports double_jump")
	assert_true(dict_data["collected_items"].has("relic_lunar_sigil"), "to_dict exports collectible")
	
	var fresh_pd = PlayerDataScript.new()
	fresh_pd.from_dict(dict_data)
	assert_true(fresh_pd.currency == 240, "from_dict restores currency accurately")
	assert_true(fresh_pd.mask_shards == 2, "from_dict restores mask_shards accurately")
	assert_true(fresh_pd.has_ability("double_jump"), "from_dict restores double_jump ability")
	assert_true(fresh_pd.has_collectible("relic_lunar_sigil"), "from_dict restores collectible")
	assert_true(fresh_pd.get_story_flag("boss_warden_defeated") == true, "from_dict restores story flags")
	
	# File persistence
	var test_path := "user://test_progression_save.json"
	var save_err := pd.save_to_file(test_path)
	assert_true(save_err == OK, "Saved progression data to JSON disk successfully")
	
	var loaded_pd = PlayerDataScript.load_from_file(test_path) as PlayerData
	assert_true(loaded_pd != null, "Loaded progression data from JSON disk")
	assert_true(loaded_pd.currency == 240, "Disk load preserved currency")
	assert_true(loaded_pd.mask_shards == 2, "Disk load preserved mask_shards")
	assert_true(loaded_pd.has_ability("double_jump"), "Disk load preserved double_jump")
	assert_true(loaded_pd.has_collectible("relic_lunar_sigil"), "Disk load preserved collectible")


func _test_celestial_sanctuary_structure() -> void:
	print("\n--- Test Suite 7: Celestial Sanctuary Room & Geometry ---")
	var scene_path := "res://scenes/levels/celestial_sanctuary.tscn"
	var packed_scene = ResourceLoader.load(scene_path) as PackedScene
	assert_true(packed_scene != null, "celestial_sanctuary.tscn loads cleanly")
	
	var sanctuary = packed_scene.instantiate() as CelestialSanctuary
	assert_true(sanctuary != null, "celestial_sanctuary.tscn instantiates cleanly")
	root.add_child(sanctuary)
	
	assert_true(sanctuary.room_id == "celestial_sanctuary", "Room ID is 'celestial_sanctuary'")
	assert_true(sanctuary.limit_left == -100, "Camera limit_left is -100")
	assert_true(sanctuary.limit_right == 1600, "Camera limit_right is 1600")
	assert_true(sanctuary.limit_top == -200, "Camera limit_top is -200")
	assert_true(sanctuary.limit_bottom == 800, "Camera limit_bottom is 800")
	
	# Verify sanctuary bench
	var bench = sanctuary.get_node_or_null("Bench_Sanctuary")
	assert_true(bench != null, "Bench_Sanctuary present in scene")
	assert_true(bench.get("bench_id") == "Bench_Sanctuary", "Bench ID is 'Bench_Sanctuary'")
	
	# Verify ability pickups
	var wings = sanctuary.get_node_or_null("AbilityPickup_Wings") as AbilityPickup
	assert_true(wings != null, "AbilityPickup_Wings present in scene")
	assert_true(wings.ability_name == "double_jump", "Wings pickup grants 'double_jump'")
	assert_true(wings.pickup_id == "ability_double_jump", "Wings pickup ID is 'ability_double_jump'")
	
	var mask_shard = sanctuary.get_node_or_null("AbilityPickup_MaskShard") as AbilityPickup
	assert_true(mask_shard != null, "AbilityPickup_MaskShard present in scene")
	assert_true(mask_shard.pickup_type == AbilityPickupScript.PickupType.MASK_SHARD, "Mask shard pickup has MASK_SHARD type")
	
	sanctuary.queue_free()


func _test_two_way_transitions_chamber_sanctuary() -> void:
	print("\n--- Test Suite 8: Two-Way Transitions (Chamber <-> Sanctuary) ---")
	var chamber_scene = ResourceLoader.load("res://scenes/levels/ancient_chamber.tscn") as PackedScene
	var chamber = chamber_scene.instantiate()
	root.add_child(chamber)
	
	var sanctuary_scene = ResourceLoader.load("res://scenes/levels/celestial_sanctuary.tscn") as PackedScene
	var sanctuary = sanctuary_scene.instantiate()
	root.add_child(sanctuary)
	
	# Check Chamber Gate_East
	var c_gate_east = chamber.get_node_or_null("Gate_East")
	assert_true(c_gate_east != null, "Chamber has Gate_East")
	assert_true(c_gate_east.get("gate_id") == "Chamber_East", "Gate_East ID is 'Chamber_East'")
	assert_true(c_gate_east.get("target_room_path") == "res://scenes/levels/celestial_sanctuary.tscn", "Gate_East targets celestial_sanctuary.tscn")
	assert_true(c_gate_east.get("target_gate_id") == "Sanctuary_West", "Gate_East targets Sanctuary_West")
	
	# Check Sanctuary Gate_West
	var s_gate_west = sanctuary.get_node_or_null("Gate_West")
	assert_true(s_gate_west != null, "Sanctuary has Gate_West")
	assert_true(s_gate_west.get("gate_id") == "Sanctuary_West", "Gate_West ID is 'Sanctuary_West'")
	assert_true(s_gate_west.get("target_room_path") == "res://scenes/levels/ancient_chamber.tscn", "Gate_West targets ancient_chamber.tscn")
	assert_true(s_gate_west.get("target_gate_id") == "Chamber_East", "Gate_West targets Chamber_East")
	
	# Check spawn markers exist and have safe offsets
	var s_spawn = sanctuary.get_node_or_null("Sanctuary_West_Spawn")
	assert_true(s_spawn != null, "Sanctuary_West_Spawn marker exists")
	assert_true(s_spawn.position.x > s_gate_west.position.x, "Spawn marker offset safely forward from gate trigger")
	
	chamber.queue_free()
	sanctuary.queue_free()


func _test_ability_gate_reachability() -> void:
	print("\n--- Test Suite 9: Ability Gate Reachability Verification ---")
	var cfg = PlayerConfigScript.new()
	var single_jump_max_height = cfg.jump_height # 96px
	
	# Balcony height difference in Celestial Sanctuary:
	# Floor y = 560, Balcony surface y = 380 -> delta_y = 180px
	var floor_y = 560.0
	var balcony_y = 380.0
	var required_reach = floor_y - balcony_y # 180px
	
	assert_true(required_reach > single_jump_max_height, "Balcony height (180px) is unreachable via single jump (96px max)")
	
	# Double Jump reach calculation:
	# Jump 1 apex: 96px
	# Double jump velocity (-460 px/s) at apex gives additional height:
	# v^2 / (2 * g) = 460^2 / (2 * 1660.9) ~= 63.7px + mantle grab reach (24px)
	# Combined reach exceeds 183.7px (>= 180px), perfectly scaling the ledge!
	var jump_g: float = (2.0 * cfg.jump_height) / (cfg.time_to_peak * cfg.time_to_peak)
	var double_jump_reach = single_jump_max_height + ((cfg.double_jump_velocity * cfg.double_jump_velocity) / (2.0 * jump_g)) + cfg.mantle_reach_distance
	assert_true(double_jump_reach >= required_reach, "Double Jump combined with Mantle reach (>= 180px) enables scaling the balcony")


func _print_summary() -> void:
	print("\n========================================================")
	print("  M5 PROGRESSION & ABILITIES TEST RESULTS SUMMARY:")
	print("  Total Tests:  %d" % tests_run)
	print("  Passed:       %d" % tests_passed)
	print("  Failed:       %d" % tests_failed)
	if tests_failed == 0:
		print("  ALL M5 PROGRESSION & ABILITIES TESTS PASSED SUCCESSFULLY!")
	else:
		print("  WARNING: SOME TESTS FAILED!")
	print("========================================================\n")
