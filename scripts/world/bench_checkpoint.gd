class_name BenchCheckpoint
extends Area2D

## ECLIPSE: Echoes of the Forgotten
## Milestone 3: Bench Checkpoint System (Hollow Knight Architecture)
## Gothic iron bench with an archival lamp. Resting at the bench restores health masks,
## refills Soul, records PlayerData checkpoint to disk, and respawns room enemies.

const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const RoomBaseScript = preload("res://scripts/world/room_base.gd")
const GameManagerScript = preload("res://scripts/core/game_manager.gd")

@export var bench_id: String = "Bench_Entrance"
@export var bench_name: String = "Sanctum Archival Bench"
@export var is_active: bool = true

signal bench_rested(bench_id: String)
signal player_approached()
signal player_departed()

var _player_in_range: CharacterBody2D = null
var _rest_flare_timer: float = 0.0
const REST_FLARE_DURATION: float = 0.6


func _ready() -> void:
	collision_layer = 256 # Layer 9: Interactables
	collision_mask = 2 # Layer 2: Player
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func get_gate_id() -> String:
	return bench_id


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = body as CharacterBody2D
		player_approached.emit()


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		player_departed.emit()


func _get_game_manager() -> Node:
	if Engine.has_singleton("GameManager"):
		return Engine.get_singleton("GameManager")
	elif Engine.get_main_loop() and Engine.get_main_loop().root.has_node("GameManager"):
		return Engine.get_main_loop().root.get_node("GameManager")
	elif GameManagerScript.instance != null:
		return GameManagerScript.instance
	return null


func _process(delta: float) -> void:
	if _rest_flare_timer > 0.0:
		_rest_flare_timer = maxf(0.0, _rest_flare_timer - delta)
	
	if _player_in_range and is_active:
		var can_sit := true
		if _player_in_range.has_method("_is_grounded"):
			can_sit = _player_in_range.call("_is_grounded")
		elif _player_in_range.is_on_floor():
			can_sit = true
		else:
			can_sit = false
		
		if _player_in_range.get("knockback_timer") != null and _player_in_range.get("knockback_timer") > 0.0:
			can_sit = false
		if _player_in_range.get("input_locked") == true:
			can_sit = false
		
		if can_sit:
			var wants_rest: bool = Input.is_action_just_pressed("move_up")
			if not wants_rest and _player_in_range.get("input_override_enabled") == true:
				wants_rest = _player_in_range.get("simulated_move_up")
			if wants_rest:
				rest(_player_in_range)
	
	queue_redraw()


func rest(p: CharacterBody2D) -> void:
	if p == null or not is_active:
		return
	
	# 1. Restore health masks
	if p.has_method("restore_health"):
		p.call("restore_health")
	else:
		var hc = p.get_node_or_null("HealthComponent")
		if hc and hc.has_method("reset_health"):
			hc.call("reset_health")
		elif p.has_method("get_max_health"):
			var mh: int = p.call("get_max_health")
			if "current_health" in p:
				p.set("current_health", mh)
	
	# 2. Refill Soul
	if p.has_method("refill_soul"):
		p.call("refill_soul")
	elif "current_soul" in p and "max_soul" in p:
		var max_s: int = p.get("max_soul")
		p.set("current_soul", max_s)
		if p.has_signal("soul_changed"):
			p.emit_signal("soul_changed", max_s, max_s)
	
	# 3. Reset player velocity & state to idle
	if p.has_method("interrupt_focus"):
		p.call("interrupt_focus")
	p.velocity = Vector2.ZERO
	if p.has_method("_set_state") and "State" in p:
		p.call("_set_state", 0) # IDLE
	
	# 4. Update PlayerData and write to disk
	var gm = _get_game_manager()
	var pdata = null
	if gm and "player_data" in gm and gm.player_data:
		pdata = gm.player_data
	else:
		pdata = PlayerDataScript.new()
	
	var current_room_path: String = ""
	var room = _find_enclosing_room()
	if room:
		current_room_path = room.scene_file_path
	
	if pdata:
		pdata.sync_from_player(p)
		pdata.set_bench_checkpoint(bench_id, current_room_path)
		if gm and gm.has_method("save_game"):
			gm.call("save_game", "user://save_slot_1.res")
		else:
			pdata.save_to_file("user://save_slot_1.res")
	
	# 5. Respawn room enemies
	if room and room.has_method("respawn_enemies"):
		room.call("respawn_enemies")
	
	_rest_flare_timer = REST_FLARE_DURATION
	bench_rested.emit(bench_id)


func _find_enclosing_room() -> Node:
	var curr: Node = get_parent()
	while curr:
		if curr is RoomBaseScript or curr.has_method("respawn_enemies"):
			return curr
		curr = curr.get_parent()
	return null


func _draw() -> void:
	# Gothic iron bench silhouette
	var seat_col := Color(0.20, 0.22, 0.26, 1.0)
	var iron_highlight := Color(0.35, 0.38, 0.44, 1.0)
	var brass_col := Color(0.85, 0.72, 0.38, 1.0)
	
	# Bench legs & ornate frame
	draw_line(Vector2(-24, 0), Vector2(-22, -10), seat_col, 3.0)
	draw_line(Vector2(24, 0), Vector2(22, -10), seat_col, 3.0)
	draw_line(Vector2(0, 0), Vector2(0, -10), seat_col, 2.0)
	
	# Seat slat
	draw_rect(Rect2(-26, -14, 52, 6), seat_col)
	draw_line(Vector2(-26, -14), Vector2(26, -14), iron_highlight, 1.5)
	
	# Gothic curved backrest with arches
	draw_line(Vector2(-24, -14), Vector2(-22, -32), seat_col, 2.5)
	draw_line(Vector2(24, -14), Vector2(22, -32), seat_col, 2.5)
	draw_line(Vector2(-22, -32), Vector2(22, -32), seat_col, 2.0)
	draw_arc(Vector2(-11, -26), 7.0, PI, TAU, 12, iron_highlight, 1.5)
	draw_arc(Vector2(11, -26), 7.0, PI, TAU, 12, iron_highlight, 1.5)
	draw_arc(Vector2(0, -28), 9.0, PI, TAU, 14, brass_col, 1.5)
	
	# Archival Post Lamp
	var lamp_x: float = 30.0
	draw_line(Vector2(lamp_x, 0), Vector2(lamp_x, -44), seat_col, 3.0)
	draw_circle(Vector2(lamp_x, -44), 4.0, iron_highlight)
	draw_line(Vector2(lamp_x, -44), Vector2(lamp_x - 6, -50), seat_col, 2.0)
	
	# Lantern housing
	var lantern_pos := Vector2(lamp_x - 6, -54)
	draw_rect(Rect2(lantern_pos.x - 4, lantern_pos.y - 6, 8, 10), Color(0.15, 0.15, 0.18, 0.9))
	
	# Glowing flame
	var pulse: float = sin(Time.get_ticks_msec() * 0.005) * 1.5
	var flare_extra: float = (_rest_flare_timer / REST_FLARE_DURATION) * 12.0
	var flame_r: float = 3.5 + pulse + flare_extra
	
	# Outer purple flame halo
	draw_circle(lantern_pos, flame_r * 2.2, Color(0.65, 0.25, 0.90, 0.35 + (0.4 if _rest_flare_timer > 0.0 else 0.0)))
	# Inner warm celestial flame
	draw_circle(lantern_pos, flame_r, Color(0.98, 0.88, 0.50, 0.9))
	draw_circle(lantern_pos, flame_r * 0.5, Color.WHITE)
