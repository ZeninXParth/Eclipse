extends SceneTree

## ECLIPSE: Echoes of the Forgotten
## Milestone 4 Verification Suite: The Ancient Chamber & First Boss Encounter
## Verifies Archive Warden boss state machine, telegraph windows, shockwave hazards,
## pogo rebound support, enrage phase transition, defeat sequence, arena confinement gates,
## cinematic boss health bar HUD, level layout with 960px runway and 64px platforms,
## two-way transition linking (Archive <-> Chamber), and PlayerData save/load persistence.

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const GameManagerScript = preload("res://scripts/core/game_manager.gd")
const RoomBaseScript = preload("res://scripts/world/room_base.gd")
const AncientChamberScript = preload("res://scripts/world/ancient_chamber.gd")
const TransitionPointScript = preload("res://scripts/world/transition_point.gd")
const ArenaGateScript = preload("res://scripts/world/arena_gate.gd")
const ArchiveWardenScript = preload("res://scripts/bosses/archive_warden.gd")
const GroundShockwaveScript = preload("res://scripts/bosses/ground_shockwave.gd")
const BossHealthBarScript = preload("res://scripts/ui/boss_health_bar.gd")
const EnemyBaseScript = preload("res://scripts/enemies/enemy_base.gd")
const HealthComponentScript = preload("res://scripts/combat/health_component.gd")
const HurtboxScript = preload("res://scripts/combat/hurtbox.gd")
const HitboxScript = preload("res://scripts/combat/hitbox.gd")
const HitDataScript = preload("res://scripts/combat/hit_data.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _init() -> void:
	print("\n========================================================")
	print("  RUNNING ECLIPSE M4 ANCIENT CHAMBER & FIRST BOSS SUITE")
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
	cap.height = 36.0
	col.shape = cap
	col.position = Vector2(0.0, -18.0)
	player.add_child(col)
	
	return player


func _run_all_tests_async() -> void:
	await _test_boss_initialization_and_architecture()
	await _test_boss_phase_1_attacks_and_telegraphs()
	await _test_ground_shockwave_hazard_and_pogo()
	await _test_boss_phase_2_enrage_transition()
	await _test_boss_phase_2_upgrades_and_leaping_pound()
	await _test_boss_defeat_sequence_and_rewards()
	await _test_arena_confinement_gates()
	await _test_boss_health_bar_hud()
	await _test_ancient_chamber_arena_layout_and_platforms()
	await _test_two_way_room_transitions()
	await _test_player_data_boss_persistence()
	
	print("\n========================================================")
	print("  M4 ANCIENT CHAMBER & FIRST BOSS TEST RESULTS SUMMARY:")
	print("  Total Tests:  %d" % total_tests)
	print("  Passed:       %d" % passed_tests)
	print("  Failed:       %d" % failed_tests)
	if failed_tests == 0:
		print("  ALL M4 BOSS & ARENA TESTS PASSED SUCCESSFULLY!")
		print("========================================================\n")
		quit(0)
	else:
		print("  FAILURES DETECTED:")
		for f in failures:
			print("    - %s" % f)
		print("========================================================\n")
		quit(1)


# ------------------------------------------------------------------------------
# Test Suite 1: Boss Initialization & Architecture
# ------------------------------------------------------------------------------

func _test_boss_initialization_and_architecture() -> void:
	print("--- Test Suite 1: Boss Initialization & Architecture ---")
	var warden = ArchiveWardenScript.new()
	warden.name = "ArchiveWarden"
	root.add_child(warden)
	warden._ready()
	
	assert_true(warden is EnemyBaseScript, "ArchiveWarden inherits from EnemyBase")
	assert_true(warden is CharacterBody2D, "ArchiveWarden is a CharacterBody2D")
	assert_true(warden.max_health == 30, "ArchiveWarden max health is 30 HP")
	assert_true(warden.health_component != null, "ArchiveWarden has HealthComponent attached")
	assert_true(warden.health_component.current_health == 30, "ArchiveWarden initializes with 30 HP")
	assert_true(warden.hurtbox != null, "ArchiveWarden has Hurtbox attached")
	assert_true(warden.hitbox != null, "ArchiveWarden has Hitbox attached")
	assert_true(warden.collision_layer == 4, "ArchiveWarden collision_layer is on Layer 3 (Enemies = 4)")
	assert_true(warden.collision_mask == 1, "ArchiveWarden collision_mask is on Layer 1 (World = 1)")
	assert_approx_equal(warden.knockback_resistance, 0.85, 0.01, "ArchiveWarden has 85% knockback resistance")
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.DORMANT, "ArchiveWarden starts in DORMANT state")
	assert_true(warden.current_phase == ArchiveWardenScript.BossPhase.PHASE_1, "ArchiveWarden starts in PHASE_1")
	assert_true(not warden.enraged_aura, "Enraged aura is initially inactive")
	
	# Start encounter
	warden.start_encounter()
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.STALK, "Starting encounter sets state to STALK")
	assert_true(warden.is_encounter_active, "Encounter is marked active")
	
	warden.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 2: Phase 1 Attacks & Telegraph Windows
# ------------------------------------------------------------------------------

func _test_boss_phase_1_attacks_and_telegraphs() -> void:
	print("\n--- Test Suite 2: Phase 1 Attacks & Telegraph Windows ---")
	var warden = ArchiveWardenScript.new()
	warden.name = "ArchiveWarden"
	root.add_child(warden)
	warden._ready()
	warden.start_encounter()
	
	# 1. Stalking approach
	var player = create_test_player()
	player.global_position = Vector2(400.0, 560.0)
	warden.global_position = Vector2(600.0, 560.0)
	root.add_child(player)
	player._ready()
	
	warden.step_boss(0.1)
	assert_true(warden.facing_direction == -1, "Warden faces left toward player")
	assert_true(warden.velocity.x < 0.0, "Warden stalks leftward toward player")
	
	# 2. Overhead Slam Wind-up & Telegraph
	var telegraph_logged: Array[float] = [0.0]
	warden.telegraph_started.connect(func(d): telegraph_logged[0] = d)
	warden.start_overhead_slam()
	
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.SLAM_WINDUP, "State entered SLAM_WINDUP")
	assert_approx_equal(telegraph_logged[0], 0.50, 0.01, "Telegraph signal emitted with 0.50s windup duration")
	assert_approx_equal(warden.current_action_timer, 0.50, 0.01, "Action timer set to 0.50s windup")
	assert_true(warden.flash_timer > 0.0, "Flash timer active during telegraph")
	
	# Step through wind-up
	warden.step_boss(0.30)
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.SLAM_WINDUP, "Still in SLAM_WINDUP at 0.3s")
	
	# Complete windup to impact
	var slammed: Array[bool] = [false]
	warden.ground_slammed.connect(func(): slammed[0] = true)
	warden.step_boss(0.25) # Reaches impact
	
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.SLAM_IMPACT, "State transitioned to SLAM_IMPACT")
	assert_true(slammed[0], "ground_slammed signal emitted on impact")
	assert_true(warden.hitbox.is_active, "Melee hitbox active during slam impact")
	
	# Step impact into recovery window
	warden.step_boss(0.15)
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.SLAM_RECOVER, "State transitioned to SLAM_RECOVER")
	assert_true(not warden.hitbox.is_active, "Hitbox deactivated during recovery")
	assert_approx_equal(warden.current_action_timer, 0.85, 0.05, "Generous P1 recovery window of ~0.85s")
	
	# Verify EnemyBase._handle_idle does not clobber recovery state to PATROL
	warden.step_physics(0.016)
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.SLAM_RECOVER, "Warden recovery state not corrupted by physics tick")
	assert_true(warden.current_state == EnemyBaseScript.EnemyState.IDLE, "Idle state preserved across recovery ticks")
	
	# Step through recovery back to stalk
	warden.step_boss(0.90)
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.STALK, "Warden returns to STALK after recovery")
	
	# 3. Sweeping Thrust Attack
	var thrust_started: Array[bool] = [false]
	warden.thrust_initiated.connect(func(): thrust_started[0] = true)
	warden.start_sweeping_thrust()
	
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.THRUST_WINDUP, "State entered THRUST_WINDUP")
	assert_true(thrust_started[0], "thrust_initiated emitted")
	assert_approx_equal(warden.current_action_timer, 0.40, 0.01, "Thrust telegraph windup is 0.40s")
	
	# Complete thrust wind-up into charge
	warden.step_boss(0.45)
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.THRUST_CHARGE, "State entered THRUST_CHARGE")
	assert_true(warden.velocity.x != 0.0, "Velocity applied during thrust charge")
	assert_true(warden.hitbox.is_active, "Hitbox active during thrust charge")
	assert_approx_equal(warden.hitbox.knockback_force, 360.0, 1.0, "Heavy knockback force applied (360 px/s)")
	
	# Test Boss Poise: player attacks boss during charge; hitbox must remain active
	var test_hit = HitDataScript.new(1, Vector2.LEFT, 120.0, player, Vector2.ZERO, false)
	warden._on_hurtbox_hit_received(test_hit)
	assert_true(warden.hitbox.is_active, "Hitbox remains active when attacked during thrust charge (Boss Poise)")
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.THRUST_CHARGE, "State machine does not get stunned out of charge")
	
	# Complete thrust charge into recovery
	warden.step_boss(0.50)
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.THRUST_RECOVER, "State transitioned to THRUST_RECOVER")
	assert_true(not warden.hitbox.is_active, "Hitbox deactivated during thrust recovery")
	assert_approx_equal(warden.current_action_timer, 0.85, 0.05, "P1 thrust recovery window of ~0.85s")
	
	warden.queue_free()
	player.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 3: Ground Shockwave Hazard & Pogo Rebound Support
# ------------------------------------------------------------------------------

func _test_ground_shockwave_hazard_and_pogo() -> void:
	print("\n--- Test Suite 3: Ground Shockwave Hazard & Pogo Rebound ---")
	var shockwave = GroundShockwaveScript.new()
	shockwave.name = "GroundShockwave"
	shockwave.direction = 1.0
	shockwave.speed = 260.0
	shockwave.global_position = Vector2(200.0, 560.0)
	root.add_child(shockwave)
	shockwave._ready()
	
	assert_true(shockwave.is_in_group("pogo_hazard"), "Shockwave is in group 'pogo_hazard'")
	assert_true(shockwave.is_pogo_hazard(), "is_pogo_hazard() returns true")
	assert_true(shockwave.collision_layer == 128, "Shockwave is on Layer 8 (Hazards = 128)")
	assert_approx_equal(shockwave.speed, 260.0, 1.0, "Shockwave travel speed is 260 px/s")
	
	# Horizontal travel stepping
	var initial_x: float = shockwave.global_position.x
	shockwave.step_shockwave(0.5)
	assert_approx_equal(shockwave.global_position.x, initial_x + 130.0, 1.0, "Shockwave traveled 130px in 0.5s")
	assert_approx_equal(shockwave.distance_traveled, 130.0, 1.0, "distance_traveled tracked accurately")
	
	# Test Player Pogo Rebound off Ground Shockwave
	var player = create_test_player()
	root.add_child(player)
	player._ready()
	player.global_position = shockwave.global_position + Vector2(0.0, -25.0)
	
	# Execute downward attack (pogo)
	var pogo_signal_received: Array[bool] = [false]
	player.pogo_bounced.connect(func(): pogo_signal_received[0] = true)
	
	player.current_attack_direction = PlayerControllerScript.AttackDirection.DOWN
	player.has_pogo_bounced = false
	player.hitbox.activate(Vector2.DOWN, true)
	assert_true(player.hitbox.is_active, "Player attack hitbox activated")
	assert_true(player.hitbox.is_pogo, "Attack marked as pogo attack")
	
	# Simulate hitbox hitting shockwave
	player.hitbox._on_area_entered(shockwave)
	
	assert_true(pogo_signal_received[0], "pogo_bounced signal emitted on hitting shockwave")
	assert_approx_equal(player.velocity.y, -460.0, 1.0, "Player received upward pogo bounce velocity (-460 px/s)")
	
	# Clean up
	shockwave.queue_free()
	player.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 4: Phase 2 Enrage Transition (< 50% HP)
# ------------------------------------------------------------------------------

func _test_boss_phase_2_enrage_transition() -> void:
	print("\n--- Test Suite 4: Phase 2 Enrage Transition (< 50% HP) ---")
	var warden = ArchiveWardenScript.new()
	warden.name = "ArchiveWarden"
	root.add_child(warden)
	warden._ready()
	warden.start_encounter()
	
	var health_bar = BossHealthBarScript.new()
	root.add_child(health_bar)
	health_bar._ready()
	warden.boss_health_bar = health_bar
	
	var phase_changed_logged: Array[int] = [0]
	var enrage_started_logged: Array[bool] = [false]
	var shake_intensity_logged: Array[float] = [0.0]
	warden.phase_changed.connect(func(p): phase_changed_logged[0] = p)
	warden.enrage_started.connect(func(): enrage_started_logged[0] = true)
	warden.screen_shake_requested.connect(func(i, _d): shake_intensity_logged[0] = i)
	
	# Deal damage in Phase 1 down to 16 HP (just above 50% threshold of 15)
	warden.health_component.take_damage(14)
	assert_true(warden.health_component.current_health == 16, "Warden health reduced to 16 HP")
	assert_true(warden.current_phase == ArchiveWardenScript.BossPhase.PHASE_1, "Still in Phase 1 at 16 HP")
	assert_true(not warden.enraged_aura, "Enraged aura still inactive at 16 HP")
	
	# Take 1 more damage: drops to 15 HP (<= 50% threshold)
	warden.health_component._tick_invulnerability(0.20)
	warden.health_component.take_damage(1)
	assert_true(warden.health_component.current_health == 15, "Warden health reduced to 15 HP (50%)")
	assert_true(warden.current_phase == ArchiveWardenScript.BossPhase.PHASE_2, "Transitioned to PHASE_2")
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.ENRAGING, "State entered ENRAGING")
	assert_true(phase_changed_logged[0] == 2, "phase_changed signal emitted with 2")
	assert_true(enrage_started_logged[0], "enrage_started signal emitted")
	assert_true(shake_intensity_logged[0] >= 8.0, "Screen shake requested on enrage roar (>= 8.0 intensity)")
	assert_true(warden.enraged_aura, "Enraged aura enabled")
	assert_true(warden.hurtbox.is_invulnerable, "Hurtbox is invulnerable during enrage roar")
	assert_approx_equal(warden.current_action_timer, 1.20, 0.01, "Enrage roar duration is 1.20s")
	
	# Step through enrage roar
	var enrage_completed_logged: Array[bool] = [false]
	warden.enrage_completed.connect(func(): enrage_completed_logged[0] = true)
	warden.step_physics(1.25)
	warden.step_boss(1.25)
	
	assert_true(enrage_completed_logged[0], "enrage_completed signal emitted")
	assert_true(not warden.hurtbox.is_invulnerable, "Invulnerability removed after enrage completes")
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.STALK, "Returns to STALK after enrage")
	
	warden.queue_free()
	health_bar.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 5: Phase 2 Upgrades & Leaping Ground Pound
# ------------------------------------------------------------------------------

func _test_boss_phase_2_upgrades_and_leaping_pound() -> void:
	print("\n--- Test Suite 5: Phase 2 Upgrades & Leaping Ground Pound ---")
	var warden = ArchiveWardenScript.new()
	warden.name = "ArchiveWarden"
	root.add_child(warden)
	warden._ready()
	warden.start_encounter()
	
	# Fast forward to Phase 2
	warden.health_component.current_health = 14
	warden.trigger_enrage()
	warden.step_boss(1.25)
	
	assert_true(warden.current_phase == ArchiveWardenScript.BossPhase.PHASE_2, "Confirmed Phase 2 active")
	
	# 1. Faster recovery in Phase 2
	warden.start_overhead_slam()
	assert_approx_equal(warden.current_action_timer, 0.40, 0.01, "Phase 2 slam windup accelerated to 0.40s")
	warden.step_boss(0.42) # Reaches impact
	warden.step_boss(0.12) # Reaches recovery
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.SLAM_RECOVER, "Entered slam recovery")
	assert_approx_equal(warden.current_action_timer, 0.45, 0.05, "Phase 2 recovery window accelerated to ~0.45s")
	warden.step_boss(0.50)
	
	# 2. Leaping Ground Pound
	warden.start_leap_ground_pound()
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.LEAP_WINDUP, "State entered LEAP_WINDUP")
	assert_approx_equal(warden.current_action_timer, 0.35, 0.01, "Leap windup duration is 0.35s")
	
	warden.step_boss(0.40)
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.LEAP_AIR, "State transitioned to LEAP_AIR")
	assert_approx_equal(warden.velocity.y, -520.0, 1.0, "Upward leap launch velocity is -520 px/s")
	
	# Simulate landing impact
	var shockwaves_emitted: Array[Node] = []
	var leap_shake_logged: Array[float] = [0.0]
	warden.shockwave_emitted.connect(func(sw): shockwaves_emitted.append(sw))
	warden.screen_shake_requested.connect(func(i, _d): leap_shake_logged[0] = i)
	warden._execute_leap_impact()
	
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.LEAP_SLAM, "State transitioned to LEAP_SLAM")
	assert_true(leap_shake_logged[0] >= 6.0, "Screen shake requested on leap slam impact (>= 6.0 intensity)")
	assert_true(shockwaves_emitted.size() >= 2, "Dual ground shockwaves emitted on leap impact")
	var dir1: float = shockwaves_emitted[0].direction
	var dir2: float = shockwaves_emitted[1].direction
	assert_true(dir1 != dir2, "Dual shockwaves travel in opposing directions (left and right)")
	
	for sw in shockwaves_emitted:
		if is_instance_valid(sw):
			sw.queue_free()
	warden.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 6: Boss Defeat Sequence & Rewards
# ------------------------------------------------------------------------------

func _test_boss_defeat_sequence_and_rewards() -> void:
	print("\n--- Test Suite 6: Boss Defeat Sequence & Rewards ---")
	var warden = ArchiveWardenScript.new()
	warden.name = "ArchiveWarden"
	root.add_child(warden)
	warden._ready()
	warden.start_encounter()
	
	var gate_west = ArenaGateScript.new()
	var gate_east = ArenaGateScript.new()
	root.add_child(gate_west)
	root.add_child(gate_east)
	gate_west._ready()
	gate_east._ready()
	gate_west.close_gate(true)
	gate_east.close_gate(true)
	warden.arena_gate_west = gate_west
	warden.arena_gate_east = gate_east
	
	var player = create_test_player()
	player.current_soul = 10
	root.add_child(player)
	player._ready()
	
	var defeat_emitted: Array[bool] = [false]
	var gates_unlocked_emitted: Array[bool] = [false]
	warden.boss_defeated.connect(func(): defeat_emitted[0] = true)
	warden.gates_unlocked.connect(func(): gates_unlocked_emitted[0] = true)
	
	# Kill the boss (30 damage)
	warden.health_component.take_damage(30)
	
	assert_true(warden.is_dead, "Warden is marked dead")
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.DYING, "State transitioned to DYING")
	assert_true(defeat_emitted[0], "boss_defeated signal emitted")
	assert_true(gates_unlocked_emitted[0], "gates_unlocked signal emitted")
	assert_true(not gate_west.is_gate_closed(), "West arena gate unlocked upon boss defeat")
	assert_true(not gate_east.is_gate_closed(), "East arena gate unlocked upon boss defeat")
	assert_true(player.current_soul > 10, "Soul reward awarded to player upon boss defeat")
	
	# Step through death state
	warden.step_boss(1.1)
	assert_true(warden.warden_state == ArchiveWardenScript.WardenState.DEAD, "State reached DEAD")
	
	warden.queue_free()
	gate_west.queue_free()
	gate_east.queue_free()
	player.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 7: Arena Confinement Gates
# ------------------------------------------------------------------------------

func _test_arena_confinement_gates() -> void:
	print("\n--- Test Suite 7: Arena Confinement Gates ---")
	var gate = ArenaGateScript.new()
	gate.name = "ArenaGate_West"
	gate.gate_id = "ArenaGate_West"
	gate.is_closed = false
	root.add_child(gate)
	gate._ready()
	
	assert_true(gate.collision_layer == 1, "ArenaGate collision_layer is on Layer 1 (World)")
	assert_true(gate.collision_shape != null, "ArenaGate has CollisionShape2D attached")
	assert_true(gate.collision_shape.disabled, "CollisionShape disabled when gate is open")
	assert_true(not gate.is_gate_closed(), "is_gate_closed() returns false when open")
	
	# Close gate
	var closed_emitted: Array[bool] = [false]
	gate.gate_closed.connect(func(): closed_emitted[0] = true)
	gate.close_gate(true)
	
	assert_true(gate.is_gate_closed(), "is_gate_closed() returns true when closed")
	assert_true(not gate.collision_shape.disabled, "CollisionShape enabled when gate is closed")
	assert_true(closed_emitted[0], "gate_closed signal emitted")
	
	# Open gate
	var opened_emitted: Array[bool] = [false]
	gate.gate_opened.connect(func(): opened_emitted[0] = true)
	gate.open_gate(true)
	
	assert_true(not gate.is_gate_closed(), "is_gate_closed() returns false after opening")
	assert_true(gate.collision_shape.disabled, "CollisionShape disabled after opening")
	assert_true(opened_emitted[0], "gate_opened signal emitted")
	
	gate.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 8: Cinematic Boss Health Bar HUD
# ------------------------------------------------------------------------------

func _test_boss_health_bar_hud() -> void:
	print("\n--- Test Suite 8: Cinematic Boss Health Bar HUD ---")
	var hud = BossHealthBarScript.new()
	root.add_child(hud)
	hud._ready()
	
	assert_true(hud.boss_title == "ARCHIVE WARDEN — Ancient Sentry", "HUD title matches requirement")
	assert_true(hud.title_label != null, "Title label created")
	assert_true(hud.title_label.text == "ARCHIVE WARDEN — Ancient Sentry", "Title label displays correctly")
	assert_true(hud.current_fill != null, "Primary health fill rect created")
	assert_true(hud.lag_fill != null, "Damage lag fill rect created")
	
	# Show bar
	var shown_emitted: Array[bool] = [false]
	hud.bar_shown.connect(func(): shown_emitted[0] = true)
	hud.show_bar(false) # instant
	assert_true(hud.is_active, "Health bar is active")
	assert_true(shown_emitted[0], "bar_shown signal emitted")
	assert_approx_equal(hud.current_alpha, 1.0, 0.01, "Alpha is 1.0 when shown")
	
	# Update health: take 10 damage (30 -> 20)
	var health_updated_emitted: Array[bool] = [false]
	hud.health_updated.connect(func(_c, _m): health_updated_emitted[0] = true)
	hud.update_health(20, 30)
	
	assert_true(health_updated_emitted[0], "health_updated signal emitted")
	assert_true(hud.current_health == 20, "Current health updated to 20")
	assert_true(hud.lag_health == 30.0, "Lag health remains at 30 before stepping")
	
	# Step UI: lag health catches up smoothly
	hud.step_ui(0.4)
	assert_true(hud.lag_health < 30.0, "Lag health is catching up to current health")
	hud.step_ui(1.0)
	assert_approx_equal(hud.lag_health, 20.0, 0.1, "Lag health reaches current health (20)")
	
	# Fade out on defeat
	var hidden_emitted: Array[bool] = [false]
	hud.bar_hidden.connect(func(): hidden_emitted[0] = true)
	hud.fade_out()
	assert_approx_equal(hud.target_alpha, 0.0, 0.01, "Target alpha is 0.0 on fade_out")
	hud.step_ui(1.0)
	assert_approx_equal(hud.current_alpha, 0.0, 0.05, "Alpha smoothly faded to 0.0")
	assert_true(not hud.is_active, "Health bar is inactive after fade out completes")
	assert_true(hidden_emitted[0], "bar_hidden emitted on fade out completion")
	
	hud.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 9: Ancient Chamber Arena Layout & Elevated Platforms
# ------------------------------------------------------------------------------

func _test_ancient_chamber_arena_layout_and_platforms() -> void:
	print("\n--- Test Suite 9: Ancient Chamber Arena Layout & Platforms ---")
	var chamber_scene = ResourceLoader.load("res://scenes/levels/ancient_chamber.tscn") as PackedScene
	assert_true(chamber_scene != null, "res://scenes/levels/ancient_chamber.tscn loads successfully")
	
	var chamber = chamber_scene.instantiate()
	assert_true(chamber != null, "ancient_chamber.tscn instantiates cleanly")
	assert_true(chamber is RoomBaseScript, "AncientChamber inherits from RoomBase")
	assert_true(chamber.room_id == "ancient_chamber", "Room ID is 'ancient_chamber'")
	
	# Camera limits
	assert_true(chamber.limit_left == -100, "Camera limit_left is -100")
	assert_true(chamber.limit_right == 1850, "Camera limit_right is 1850")
	assert_true(chamber.limit_top == -250, "Camera limit_top is -250")
	assert_true(chamber.limit_bottom == 850, "Camera limit_bottom is 850")
	
	# Key nodes present
	var warden = chamber.get_node_or_null("ArchiveWarden")
	var gate_west = chamber.get_node_or_null("ArenaGate_West")
	var gate_east = chamber.get_node_or_null("ArenaGate_East")
	var trigger = chamber.get_node_or_null("EncounterTrigger") as Area2D
	var health_bar = chamber.get_node_or_null("BossHealthBar")
	var transition_west = chamber.get_node_or_null("Gate_West")
	
	assert_true(warden != null, "ArchiveWarden boss present in chamber")
	assert_true(gate_west != null, "ArenaGate_West present in chamber")
	assert_true(gate_east != null, "ArenaGate_East present in chamber")
	assert_true(trigger != null, "EncounterTrigger present in chamber")
	assert_true(health_bar != null, "BossHealthBar HUD present in chamber")
	assert_true(transition_west != null, "Gate_West transition trigger present in chamber")
	
	# Verify Platforms & 960px runway
	var geom = chamber.get_node_or_null("Geometry") as StaticBody2D
	var left_plat = geom.get_node_or_null("LeftElevatedPlatform") as CollisionShape2D
	var right_plat = geom.get_node_or_null("RightElevatedPlatform") as CollisionShape2D
	var main_floor = geom.get_node_or_null("MainFloor") as CollisionShape2D
	
	assert_true(left_plat != null, "LeftElevatedPlatform present in geometry")
	assert_true(right_plat != null, "RightElevatedPlatform present in geometry")
	assert_true(main_floor != null, "MainFloor runway present in geometry")
	
	# Runway width between elevated platforms:
	# Left platform edge is at x = 360, Right platform edge is at x = 1360 -> Runway width = 1000px >= 960px!
	var left_plat_rect := left_plat.shape as RectangleShape2D
	var right_plat_rect := right_plat.shape as RectangleShape2D
	var left_edge: float = left_plat.position.x + left_plat_rect.size.x * 0.5
	var right_edge: float = right_plat.position.x - right_plat_rect.size.x * 0.5
	var runway_span: float = right_edge - left_edge
	assert_true(runway_span >= 960.0, "Runway span between platforms is %fpx (>= 960px required)" % runway_span)
	
	# Platform elevation: Floor surface is at y = 560, platform surface is at y = 496 -> exactly 64px elevation!
	var floor_surface_y: float = main_floor.position.y - (main_floor.shape as RectangleShape2D).size.y * 0.5
	var plat_surface_y: float = left_plat.position.y - left_plat_rect.size.y * 0.5
	var elevation: float = floor_surface_y - plat_surface_y
	assert_approx_equal(elevation, 64.0, 1.0, "Elevated platforms are exactly 64px higher than the floor")
	assert_true(left_plat.one_way_collision, "Left elevated platform has one_way_collision enabled")
	assert_true(right_plat.one_way_collision, "Right elevated platform has one_way_collision enabled")
	
	chamber.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 10: Two-Way Room Transitions (Sunken Archive <-> Ancient Chamber)
# ------------------------------------------------------------------------------

func _test_two_way_room_transitions() -> void:
	print("\n--- Test Suite 10: Two-Way Transitions (Archive <-> Chamber) ---")
	var archive_scene = ResourceLoader.load("res://scenes/levels/sunken_archive.tscn") as PackedScene
	var chamber_scene = ResourceLoader.load("res://scenes/levels/ancient_chamber.tscn") as PackedScene
	
	var archive = archive_scene.instantiate() as RoomBaseScript
	var chamber = chamber_scene.instantiate() as RoomBaseScript
	
	root.add_child(archive)
	archive._ready()
	
	# Check Archive_East gate
	var archive_east_gate = archive.get_node_or_null("Gate_East")
	assert_true(archive_east_gate != null, "Gate_East transition trigger found in sunken_archive")
	assert_true(archive_east_gate.gate_id == "Archive_East", "Gate_East has gate_id 'Archive_East'")
	assert_true(archive_east_gate.target_room_path == "res://scenes/levels/ancient_chamber.tscn", "Gate_East points to ancient_chamber.tscn")
	assert_true(archive_east_gate.target_gate_id == "Chamber_West", "Gate_East targets Chamber_West gate")
	
	# Check Chamber_West gate
	root.remove_child(archive)
	root.add_child(chamber)
	chamber._ready()
	
	var chamber_west_gate = chamber.get_node_or_null("Gate_West")
	assert_true(chamber_west_gate != null, "Gate_West transition trigger found in ancient_chamber")
	assert_true(chamber_west_gate.gate_id == "Chamber_West", "Gate_West has gate_id 'Chamber_West'")
	assert_true(chamber_west_gate.target_room_path == "res://scenes/levels/sunken_archive.tscn", "Gate_West points to sunken_archive.tscn")
	assert_true(chamber_west_gate.target_gate_id == "Archive_East", "Gate_West targets Archive_East gate")
	
	# Verify spawn point markers
	var chamber_spawn = chamber.get_gate_position("Chamber_West")
	assert_true(chamber_spawn == Vector2(120, 520), "Chamber_West resolves to Chamber_West_Spawn marker coords (120, 520)")
	
	var archive_spawn = archive.get_gate_position("Archive_East")
	assert_true(archive_spawn == Vector2(2070, 630), "Archive_East resolves to Archive_East_Spawn marker coords (2070, 630)")
	
	archive.queue_free()
	chamber.queue_free()
	await process_frame


# ------------------------------------------------------------------------------
# Test Suite 11: PlayerData Boss Persistence & Re-entry Logic
# ------------------------------------------------------------------------------

func _test_player_data_boss_persistence() -> void:
	print("\n--- Test Suite 11: PlayerData Boss Persistence & Re-entry ---")
	var pd = PlayerDataScript.new()
	assert_true(not pd.get_flag("boss_warden_defeated", false), "boss_warden_defeated flag initially false")
	assert_true(not pd.get_story_flag("boss_warden_defeated", false), "get_story_flag returns false initially")
	
	# Set story flag
	pd.set_story_flag("boss_warden_defeated", true)
	assert_true(pd.get_story_flag("boss_warden_defeated", false), "set_story_flag successfully records defeat")
	assert_true(pd.has_story_flag("boss_warden_defeated"), "has_story_flag returns true")
	
	# Verify save/load disk persistence
	var test_save_path := "user://test_boss_save.res"
	var err := pd.save_to_file(test_save_path)
	assert_true(err == OK, "Saved PlayerData with boss defeat flag to disk")
	
	var loaded_pd = PlayerDataScript.load_from_file(test_save_path)
	assert_true(loaded_pd != null, "Loaded PlayerData from disk")
	assert_true(loaded_pd.get_story_flag("boss_warden_defeated", false) == true, "Loaded data preserves boss_warden_defeated flag as true")
	
	# Reset GameManager flag if present to test fresh un-defeated entry first
	if GameManagerScript.instance and GameManagerScript.instance.player_data:
		GameManagerScript.instance.player_data.set_story_flag("boss_warden_defeated", false)
	
	# Test AncientChamber fresh entry (boss undefeated)
	var chamber_scene = ResourceLoader.load("res://scenes/levels/ancient_chamber.tscn") as PackedScene
	var chamber = chamber_scene.instantiate()
	root.add_child(chamber)
	chamber._ready()
	
	assert_true(not chamber.is_boss_cleared, "Chamber is not cleared initially")
	assert_true(chamber.warden_boss != null and is_instance_valid(chamber.warden_boss), "Boss is present and valid")
	assert_true(not chamber.warden_boss.is_dead, "Boss is alive and ready")
	
	# Clean up first chamber instance
	chamber.queue_free()
	await process_frame
	
	# Set GameManager story flag to defeated to test true re-entry persistence
	if GameManagerScript.instance and GameManagerScript.instance.player_data:
		GameManagerScript.instance.player_data.set_story_flag("boss_warden_defeated", true)
	
	var reentered_chamber = chamber_scene.instantiate()
	root.add_child(reentered_chamber)
	reentered_chamber._ready()
	
	assert_true(reentered_chamber.is_boss_cleared, "Re-entered chamber automatically recognizes boss_warden_defeated")
	assert_true(not reentered_chamber.arena_gate_west.is_gate_closed(), "West arena gate remains open on re-entry")
	assert_true(not reentered_chamber.arena_gate_east.is_gate_closed(), "East arena gate remains open on re-entry")
	assert_true(reentered_chamber.warden_boss.is_dead, "Boss is dead on re-entry and does not respawn")
	
	# Verify that room enemy respawn cycles (e.g. resting at a bench) never revive the defeated boss
	reentered_chamber.respawn_enemies()
	assert_true(reentered_chamber.warden_boss.is_dead, "Boss remains dead after respawn_enemies() call")
	assert_true(not reentered_chamber.arena_gate_west.is_gate_closed(), "West arena gate remains open after respawn_enemies()")
	assert_true(not reentered_chamber.arena_gate_east.is_gate_closed(), "East arena gate remains open after respawn_enemies()")
	
	# Clean up save file & scene
	if DirAccess.dir_exists_absolute("user://"):
		DirAccess.remove_absolute(test_save_path)
	reentered_chamber.queue_free()
	await process_frame
