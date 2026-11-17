class_name CameraController
extends Camera2D

## ECLIPSE: Echoes of the Forgotten
## Smooth Camera Controller with Dynamic Screen Shake & Trauma Decay

@export var trauma_decay: float = 1.0
@export var max_offset: Vector2 = Vector2(16.0, 12.0)
@export var max_roll: float = 0.05

var _trauma: float = 0.0
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0


func _ready() -> void:
	var player = get_parent()
	if player and player.has_signal("screen_shake_requested"):
		player.connect("screen_shake_requested", _on_screen_shake_requested)


func _process(delta: float) -> void:
	if _trauma > 0.0 or _shake_timer > 0.0:
		_trauma = maxf(0.0, _trauma - trauma_decay * delta)
		_shake_timer = maxf(0.0, _shake_timer - delta)
		var shake: float = _trauma * _trauma
		var time_factor: float = (_shake_timer / _shake_duration) if _shake_duration > 0.0 else 0.0
		var effective_shake: float = maxf(shake, time_factor * clampf(_shake_intensity / 10.0, 0.0, 1.0))
		offset = Vector2(
			randf_range(-max_offset.x, max_offset.x) * effective_shake,
			randf_range(-max_offset.y, max_offset.y) * effective_shake
		)
		rotation = randf_range(-max_roll, max_roll) * effective_shake
	else:
		offset = Vector2.ZERO
		rotation = 0.0


func _on_screen_shake_requested(intensity: float, duration: float) -> void:
	apply_shake(intensity, duration)


func apply_shake(intensity: float, duration: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_timer = maxf(_shake_timer, duration)
	var trauma_add: float = clampf(intensity / 10.0, 0.15, 1.0)
	_trauma = clampf(_trauma + trauma_add, 0.0, 1.0)

