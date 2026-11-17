class_name CombatRoom
extends "res://scripts/world/room_base.gd"

## ECLIPSE: Echoes of the Forgotten
## Combat Proving Ground (Milestone 2)
## Features dedicated encounter terraces for Walker, Flyer, and Charger enemies,
## aerial pogo chains, hazard spikes, and training dummy.

var _spawn_point: Vector2 = Vector2(120, 470)


func _ready() -> void:
	limit_left = -150
	limit_top = -200
	limit_right = 2400
	limit_bottom = 800
	respawn_y_threshold = 800.0
	default_spawn_point = _spawn_point
	if player:
		player.global_position = _spawn_point
		player.set("spawn_position", _spawn_point)
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
