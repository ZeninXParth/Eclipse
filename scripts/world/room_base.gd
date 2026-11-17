class_name RoomBase
extends Node2D

## ECLIPSE: Echoes of the Forgotten
## Milestone 3: Base Room Controller (Hollow Knight Scene Linking Architecture)
## Provides camera boundaries, spawn gate registry, dynamic enemy respawn management,
## and player positioning.

@export var room_id: String = ""
@export var room_name: String = ""

@export_group("Camera Boundaries")
@export var limit_left: int = -200
@export var limit_right: int = 2400
@export var limit_top: int = -300
@export var limit_bottom: int = 900

@export_group("Room Settings")
@export var respawn_y_threshold: float = 950.0
@export var default_spawn_point: Vector2 = Vector2(100.0, 450.0)
@export var player: CharacterBody2D

var _gates: Dictionary = {} # gate_id -> Node2D
var _spawn_points: Dictionary = {} # gate_id -> Marker2D / Node2D
var _initial_enemies: Array[Dictionary] = [] # snapshots of initial enemies for respawn
var _registered_enemies: Array[Node] = []

signal enemy_respawn_triggered()


func _ready() -> void:
	_scan_and_register_gates()
	_snapshot_initial_enemies()
	_initialize_player()


func _scan_and_register_gates() -> void:
	_gates.clear()
	_spawn_points.clear()
	_scan_node_for_gates(self)


func _scan_node_for_gates(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("get_gate_id"):
			var gid: String = child.call("get_gate_id")
			if not gid.is_empty():
				_gates[gid] = child
		elif "gate_id" in child:
			var gid: String = str(child.get("gate_id"))
			if not gid.is_empty():
				_gates[gid] = child
		
		# Register Marker2D or Node2D
		if child is Marker2D:
			_gates[child.name] = child
			if child.name.ends_with("_Spawn"):
				var target_id := child.name.trim_suffix("_Spawn")
				_spawn_points[target_id] = child
			elif child.name.begins_with("Spawn_"):
				var target_id := child.name.trim_prefix("Spawn_")
				_spawn_points[target_id] = child
		elif child is Node2D:
			if child.name.begins_with("Gate_") or child.name.begins_with("Door_") or child.name.begins_with("Bench_") or child.name.begins_with("Door"):
				if not _gates.has(child.name):
					_gates[child.name] = child
		
		if child.get_child_count() > 0:
			_scan_node_for_gates(child)


func register_gate(gate_id: String, gate_node: Node2D) -> void:
	_gates[gate_id] = gate_node


func has_gate(gate_id: String) -> bool:
	if _gates.has(gate_id) or _spawn_points.has(gate_id):
		return true
	return get_node_or_null(gate_id) != null


func get_gate(gate_id: String) -> Node2D:
	if _gates.has(gate_id):
		return _gates[gate_id]
	var n = get_node_or_null(gate_id)
	if n is Node2D:
		return n
	return null


func get_gate_position(gate_id: String) -> Vector2:
	# 1. Dedicated spawn point marker: <gate_id>_Spawn or Spawn_<gate_id>
	if _spawn_points.has(gate_id):
		return _spawn_points[gate_id].global_position
	if _gates.has(gate_id + "_Spawn"):
		return _gates[gate_id + "_Spawn"].global_position
	if _gates.has("Spawn_" + gate_id):
		return _gates["Spawn_" + gate_id].global_position
	var direct_spawn = get_node_or_null(gate_id + "_Spawn")
	if direct_spawn is Node2D:
		return direct_spawn.global_position
	
	# 2. Gate node itself or child spawn marker
	var g := get_gate(gate_id)
	if g:
		if g.has_node("SpawnPoint"):
			return (g.get_node("SpawnPoint") as Node2D).global_position
		if g.has_node("Spawn"):
			return (g.get_node("Spawn") as Node2D).global_position
		if g.has_method("get_spawn_position"):
			return g.call("get_spawn_position")
		if "spawn_offset" in g and g.get("spawn_offset") != Vector2.ZERO:
			return g.global_position + g.get("spawn_offset")
		return g.global_position
	
	return default_spawn_point


func _snapshot_initial_enemies() -> void:
	_initial_enemies.clear()
	_registered_enemies.clear()
	_scan_for_enemies(self)


func _scan_for_enemies(node: Node) -> void:
	for child in node.get_children():
		if child.is_in_group("enemies") or child.has_method("take_damage") or child.get_node_or_null("HealthComponent") != null:
			if child is CharacterBody2D and child != player:
				_registered_enemies.append(child)
				var info := {
					"node": child,
					"name": child.name,
					"parent": node,
					"scene_file_path": child.scene_file_path,
					"global_position": child.global_position,
					"facing": child.get("facing_direction") if "facing_direction" in child else 1
				}
				_initial_enemies.append(info)
		if child.get_child_count() > 0:
			_scan_for_enemies(child)


func respawn_enemies() -> void:
	for info in _initial_enemies:
		var node: Node = info.get("node")
		if is_instance_valid(node):
			if node.has_method("respawn"):
				node.call("respawn")
			elif node.has_method("reset_to_spawn"):
				node.call("reset_to_spawn")
			else:
				# Generic enemy reset
				node.global_position = info["global_position"]
				if "velocity" in node:
					node.velocity = Vector2.ZERO
				if "is_dead" in node:
					node.set("is_dead", false)
				if "current_state" in node and "State" in node:
					node.set("current_state", 1) # PATROL
				var hc = node.get_node_or_null("HealthComponent")
				if hc and hc.has_method("reset_health"):
					hc.call("reset_health")
				var hurt = node.get_node_or_null("Hurtbox")
				if hurt and "is_active" in hurt:
					hurt.set("is_active", true)
				var hit = node.get_node_or_null("Hitbox")
				if hit and hit.has_method("deactivate"):
					hit.call("deactivate")
		else:
			# If node was freed, recreate from packed scene
			var scene_path: String = info.get("scene_file_path", "")
			if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
				var scn = ResourceLoader.load(scene_path) as PackedScene
				if scn:
					var new_inst = scn.instantiate() as CharacterBody2D
					new_inst.name = info["name"]
					info["parent"].add_child(new_inst)
					new_inst.global_position = info["global_position"]
					info["node"] = new_inst
	
	enemy_respawn_triggered.emit()


func _initialize_player() -> void:
	if player == null:
		player = get_node_or_null("Player") as CharacterBody2D
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			apply_camera_limits(cam)


func apply_camera_limits(cam: Camera2D) -> void:
	if cam == null:
		return
	cam.limit_left = limit_left
	cam.limit_right = limit_right
	cam.limit_top = limit_top
	cam.limit_bottom = limit_bottom
	if cam.has_method("reset_smoothing"):
		cam.call("reset_smoothing")


func _physics_process(_delta: float) -> void:
	if player and player.global_position.y > respawn_y_threshold:
		if player.has_method("reset_to_spawn"):
			player.call("reset_to_spawn")
		else:
			player.global_position = default_spawn_point
			player.velocity = Vector2.ZERO
