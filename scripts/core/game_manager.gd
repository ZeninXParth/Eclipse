extends Node

## ECLIPSE: Echoes of the Forgotten
## Milestone 3: Game Manager & Room Streaming Autoload
## Orchestrates seamless room streaming, player persistence, input locking,
## fade-to-black screen transitions, camera bounds snapping, and save/load cycles.

const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const RoomBaseScript = preload("res://scripts/world/room_base.gd")

signal transition_started(from_room: String, to_room: String)
signal transition_completed(to_room: String, target_gate_id: String)
signal game_saved(slot_path: String)
signal game_loaded(slot_path: String)

static var instance: GameManager = null

var player_data = null
var is_transitioning: bool = false
var transition_fade_duration: float = 0.20

# UI Overlay for smooth screen fade
var _fade_canvas: CanvasLayer
var _fade_rect: ColorRect
var _current_player: CharacterBody2D
var _current_room = null


func _init() -> void:
	instance = self
	if player_data == null:
		player_data = PlayerDataScript.new()


func _ready() -> void:
	instance = self
	_setup_fade_overlay()
	call_deferred("_locate_active_room_and_player")


func _exit_tree() -> void:
	if instance == self:
		instance = null
	is_transitioning = false


static func get_instance() -> GameManager:
	return instance


func _setup_fade_overlay() -> void:
	_fade_canvas = CanvasLayer.new()
	_fade_canvas.name = "TransitionFadeCanvas"
	_fade_canvas.layer = 100
	
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_fade_canvas.add_child(_fade_rect)
	add_child(_fade_canvas)


func _locate_active_room_and_player() -> void:
	var tree := get_tree()
	if tree == null:
		return
	
	if tree.current_scene is RoomBaseScript:
		_current_room = tree.current_scene
	elif tree.current_scene:
		_current_room = tree.current_scene
	
	if _current_room and "player" in _current_room and _current_room.player:
		_current_player = _current_room.player
	elif tree.current_scene:
		_current_player = tree.current_scene.get_node_or_null("Player") as CharacterBody2D
	
	if _current_player and not _current_player.player_died.is_connected(respawn_at_last_bench):
		_current_player.player_died.connect(respawn_at_last_bench)


func change_room(target_room_path: String, target_gate_id: String, travel_direction: Vector2 = Vector2.ZERO, instant: bool = false, sync_stats: bool = true) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	_locate_active_room_and_player()
	
	var from_path: String = ""
	if _current_room:
		from_path = _current_room.scene_file_path
	elif get_tree() and get_tree().current_scene:
		from_path = get_tree().current_scene.scene_file_path
	
	transition_started.emit(from_path, target_room_path)
	
	# 1. Lock player input
	lock_player(_current_player)
	
	if instant or not is_inside_tree() or get_tree() == null:
		_perform_scene_swap(target_room_path, target_gate_id, travel_direction, sync_stats)
		unlock_player(_current_player)
		is_transitioning = false
		transition_completed.emit(target_room_path, target_gate_id)
		return
	
	# 2. Fade to black
	var tween := create_tween()
	if tween and _fade_rect:
		tween.tween_property(_fade_rect, "color:a", 1.0, transition_fade_duration)
		await tween.finished
	
	# 3. Swap scenes
	_perform_scene_swap(target_room_path, target_gate_id, travel_direction, sync_stats)
	
	# 4. Fade in
	var in_tween := create_tween()
	if in_tween and _fade_rect:
		in_tween.tween_property(_fade_rect, "color:a", 0.0, transition_fade_duration)
		await in_tween.finished
	
	# 5. Restore player input
	unlock_player(_current_player)
	is_transitioning = false
	transition_completed.emit(target_room_path, target_gate_id)


func _perform_scene_swap(target_room_path: String, target_gate_id: String, travel_direction: Vector2, sync_stats: bool = true) -> void:
	var tree := get_tree()
	if tree == null:
		return
	
	# Synchronize state from current player
	if sync_stats and _current_player and player_data:
		player_data.sync_from_player(_current_player)
	
	if not ResourceLoader.exists(target_room_path):
		push_error("Target room path does not exist: %s" % target_room_path)
		return
	
	var scene_res := ResourceLoader.load(target_room_path) as PackedScene
	if scene_res == null:
		push_error("Failed to load scene: %s" % target_room_path)
		return
	
	# Unload previous room
	var old_scene = tree.current_scene
	if old_scene:
		if old_scene.get_parent():
			old_scene.get_parent().remove_child(old_scene)
		old_scene.queue_free()
	
	# Instantiate target room
	var new_room_node = scene_res.instantiate()
	tree.root.add_child(new_room_node)
	tree.current_scene = new_room_node
	_current_room = new_room_node
	
	# Mark room visited
	if player_data:
		player_data.mark_room_visited(target_room_path)
	
	# Locate player in new room
	var new_player: CharacterBody2D = null
	if _current_room and "player" in _current_room and _current_room.player:
		new_player = _current_room.player
	elif new_room_node:
		new_player = new_room_node.get_node_or_null("Player") as CharacterBody2D
	_current_player = new_player
	
	# Immediately lock player input on incoming player so they cannot move in the dark
	lock_player(new_player)
	
	if new_player and not new_player.player_died.is_connected(respawn_at_last_bench):
		new_player.player_died.connect(respawn_at_last_bench)
	
	# Anchor player at target gate
	var spawn_pos := Vector2.ZERO
	if _current_room and _current_room.has_method("get_gate_position"):
		spawn_pos = _current_room.get_gate_position(target_gate_id)
	elif new_room_node and new_room_node.has_method("get_gate_position"):
		spawn_pos = new_room_node.call("get_gate_position", target_gate_id)
	
	if new_player:
		new_player.global_position = spawn_pos
		new_player.set("spawn_position", spawn_pos)
		
		# Preserved direction and entry velocity
		if travel_direction.x != 0.0:
			new_player.set("facing_direction", int(signf(travel_direction.x)))
			if new_player.has_method("_update_visual_facing"):
				new_player.call("_update_visual_facing")
			new_player.velocity = travel_direction * 120.0
		else:
			new_player.velocity = Vector2.ZERO
		
		# Synchronize stats
		if player_data:
			player_data.sync_to_player(new_player)
		
		# Snap camera bounds to prevent frame tearing
		var cam: Camera2D = new_player.get_node_or_null("Camera2D")
		if cam:
			if _current_room and _current_room.has_method("apply_camera_limits"):
				_current_room.apply_camera_limits(cam)
			cam.global_position = new_player.global_position
			if cam.has_method("reset_smoothing"):
				cam.call("reset_smoothing")


func lock_player(p: CharacterBody2D) -> void:
	if p == null:
		return
	if "input_locked" in p:
		p.set("input_locked", true)
	if p.has_method("interrupt_focus"):
		p.call("interrupt_focus")
	p.velocity = Vector2.ZERO


func unlock_player(p: CharacterBody2D) -> void:
	if p == null:
		return
	if "input_locked" in p:
		p.set("input_locked", false)


func save_game(slot_path: String = "user://save_slot_1.res") -> Error:
	if _current_player and player_data:
		player_data.sync_from_player(_current_player)
	if player_data:
		var err: Error = player_data.save_to_file(slot_path)
		if err == OK:
			game_saved.emit(slot_path)
		return err
	return FAILED


func load_game(slot_path: String = "user://save_slot_1.res") -> bool:
	var loaded = PlayerDataScript.load_from_file(slot_path)
	if loaded:
		player_data = loaded
		if _current_player:
			player_data.sync_to_player(_current_player)
		game_loaded.emit(slot_path)
		return true
	return false


func respawn_at_last_bench(instant: bool = false) -> void:
	if player_data and not player_data.respawn_room_path.is_empty():
		player_data.current_health = player_data.max_health
		player_data.soul = 0
		change_room(player_data.respawn_room_path, player_data.respawn_gate_id, Vector2.ZERO, instant, false)
	elif _current_player and _current_player.has_method("reset_to_spawn"):
		_current_player.call("reset_to_spawn")
