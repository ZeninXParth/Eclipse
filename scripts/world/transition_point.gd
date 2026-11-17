class_name TransitionPoint
extends Area2D

const GameManagerScript = preload("res://scripts/core/game_manager.gd")

## ECLIPSE: Echoes of the Forgotten
## Milestone 3: Room Transition Gateway (Hollow Knight Scene Linking Architecture)
## Connects adjacent rooms via spatial triggers. When entered by the player,
## requests seamless room transition via GameManager.

@export var gate_id: String = ""
@export var target_room_path: String = ""
@export var target_gate_id: String = ""
@export var travel_direction: Vector2 = Vector2.RIGHT
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var is_active: bool = true

signal transition_triggered(target_room: String, target_gate: String, travel_dir: Vector2)

var _is_transitioning: bool = false


func _ready() -> void:
	collision_layer = 1 # World Layer
	collision_mask = 2 | 16 # Detect Player (2) and PlayerHurtbox (16)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func get_gate_id() -> String:
	return gate_id


func get_spawn_position() -> Vector2:
	if spawn_offset != Vector2.ZERO:
		return global_position + spawn_offset
	return global_position


func _get_game_manager() -> Node:
	if Engine.has_singleton("GameManager"):
		return Engine.get_singleton("GameManager")
	elif Engine.get_main_loop() and Engine.get_main_loop().root.has_node("GameManager"):
		return Engine.get_main_loop().root.get_node("GameManager")
	elif GameManagerScript.instance != null:
		return GameManagerScript.instance
	return null


func _on_body_entered(body: Node2D) -> void:
	if not is_active or _is_transitioning:
		return
	if body is CharacterBody2D:
		var p := body as CharacterBody2D
		var hc = p.get_node_or_null("HealthComponent")
		if hc and hc.current_health <= 0:
			return
		if "input_locked" in p and p.get("input_locked") == true:
			return
		_execute_transition(p)


func _on_area_entered(area: Area2D) -> void:
	if not is_active or _is_transitioning:
		return
	if area.get("is_player_hurtbox") == true or area.name == "Hurtbox":
		var player_node = area.get_parent()
		if player_node is CharacterBody2D:
			var p := player_node as CharacterBody2D
			var hc = p.get_node_or_null("HealthComponent")
			if hc and hc.current_health <= 0:
				return
			if "input_locked" in p and p.get("input_locked") == true:
				return
			_execute_transition(p)


func _execute_transition(player_node: CharacterBody2D) -> void:
	if target_room_path.is_empty():
		return
	
	_is_transitioning = true
	transition_triggered.emit(target_room_path, target_gate_id, travel_direction)
	
	var gm = _get_game_manager()
	if gm and gm.has_method("change_room"):
		gm.call("change_room", target_room_path, target_gate_id, travel_direction)
