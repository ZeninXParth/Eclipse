class_name TestRoom
extends "res://scripts/world/room_base.gd"

## ECLIPSE: Echoes of the Forgotten
## Movement Prototype Test Chamber (Milestone M1)
## Provides calibrated test terrain for locomotion, jump arcs, coyote time, and buffering.

var _spawn_point: Vector2 = Vector2(120, 470)


func _ready() -> void:
	limit_left = -150
	limit_top = -150
	limit_right = 2250
	limit_bottom = 750
	respawn_y_threshold = 750.0
	default_spawn_point = _spawn_point
	if player:
		player.global_position = _spawn_point
		player.set("spawn_position", _spawn_point)
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
