class_name HealthComponent
extends Node

## ECLIPSE: Echoes of the Forgotten
## Modular health tracking, damage resolution, and invulnerability frame (i-frame) management.

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died()
signal invulnerability_started()
signal invulnerability_ended()

@export var max_health: int = 5
@export var current_health: int = 5
@export var default_invulnerability_duration: float = 1.0

var is_invulnerable: bool = false
var invulnerability_timer: float = 0.0


func _ready() -> void:
	current_health = max_health


func _physics_process(delta: float) -> void:
	_tick_invulnerability(delta)


func _process(delta: float) -> void:
	# Support manual test stepping when node is not inside scene tree
	if not is_inside_tree():
		_tick_invulnerability(delta)


func _tick_invulnerability(delta: float) -> void:
	if is_invulnerable:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0:
			is_invulnerable = false
			invulnerability_timer = 0.0
			invulnerability_ended.emit()


func take_damage(amount: int, trigger_iframes: bool = true) -> bool:
	if is_invulnerable or current_health <= 0:
		return false
	
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	damaged.emit(amount)
	
	if trigger_iframes and default_invulnerability_duration > 0.0 and current_health > 0:
		start_invulnerability(default_invulnerability_duration)
	
	if current_health <= 0:
		died.emit()
	
	return true


func heal(amount: int) -> void:
	if current_health <= 0:
		return
	var previous_hp := current_health
	current_health = mini(max_health, current_health + amount)
	if current_health != previous_hp:
		health_changed.emit(current_health, max_health)
		healed.emit(current_health - previous_hp)


func start_invulnerability(duration: float) -> void:
	is_invulnerable = true
	invulnerability_timer = duration
	invulnerability_started.emit()


func reset_health() -> void:
	current_health = max_health
	is_invulnerable = false
	invulnerability_timer = 0.0
	health_changed.emit(current_health, max_health)
