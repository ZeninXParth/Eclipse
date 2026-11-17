class_name ArenaGate
extends StaticBody2D

## ECLIPSE: Echoes of the Forgotten
## Milestone 4: Arena Confinement Gate
## Heavy stone and iron portcullis that seals boss arenas during combat encounters.
## When closed/locked, enables solid collision to prevent player exit.
## When opened/unlocked, disables collision and retracts portcullis bars.

signal gate_closed()
signal gate_opened()

@export var gate_id: String = ""
@export var is_closed: bool = false
@export var gate_width: float = 28.0
@export var gate_height: float = 140.0
@export var bar_count: int = 5

var collision_shape: CollisionShape2D
var _anim_progress: float = 0.0 # 0.0 = fully open, 1.0 = fully closed
var _is_animating: bool = false
var _target_progress: float = 0.0

const COLOR_STONE_FRAME = Color(0.14, 0.16, 0.22, 1.0)
const COLOR_IRON_BAR = Color(0.28, 0.32, 0.40, 1.0)
const COLOR_RUNIC_RIVET = Color(0.35, 0.90, 1.0, 0.9)
const COLOR_LOCK_RUNE = Color(0.78, 0.25, 0.95, 0.95)


func _ready() -> void:
	collision_layer = 1 # Layer 1: World
	collision_mask = 0
	
	_setup_collision()
	if is_closed:
		_set_closed_state(true, true)
	else:
		_set_closed_state(false, true)


func _setup_collision() -> void:
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(gate_width, gate_height)
		collision_shape.shape = rect
		collision_shape.position = Vector2(0.0, -gate_height * 0.5)
		add_child(collision_shape)
	elif collision_shape.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(gate_width, gate_height)
		collision_shape.shape = rect
		collision_shape.position = Vector2(0.0, -gate_height * 0.5)


func close_gate(instant: bool = false) -> void:
	is_closed = true
	_set_closed_state(true, instant)
	gate_closed.emit()


func open_gate(instant: bool = false) -> void:
	is_closed = false
	_set_closed_state(false, instant)
	gate_opened.emit()


func lock_gate(instant: bool = false) -> void:
	close_gate(instant)


func unlock_gate(instant: bool = false) -> void:
	open_gate(instant)


func is_gate_closed() -> bool:
	return is_closed


func _set_closed_state(closed: bool, instant: bool) -> void:
	if collision_shape:
		collision_shape.disabled = not closed
		collision_shape.set_deferred("disabled", not closed)
	
	_target_progress = 1.0 if closed else 0.0
	if instant:
		_anim_progress = _target_progress
		_is_animating = false
	else:
		_is_animating = true
	queue_redraw()


func _process(delta: float) -> void:
	if _is_animating:
		_anim_progress = move_toward(_anim_progress, _target_progress, delta * 3.5)
		if is_equal_approx(_anim_progress, _target_progress):
			_is_animating = false
		queue_redraw()


func _draw() -> void:
	var half_w := gate_width * 0.5
	var drop_h := gate_height * _anim_progress
	
	# Top arch / lintel housing
	var lintel_rect := Rect2(-half_w - 6.0, -gate_height - 12.0, gate_width + 12.0, 16.0)
	draw_rect(lintel_rect, COLOR_STONE_FRAME)
	draw_rect(lintel_rect, Color(0.4, 0.45, 0.55, 0.8), false, 2.0)
	
	if _anim_progress <= 0.01:
		return # Completely retracted into archway
	
	# Portcullis vertical iron bars dropping down
	var bar_spacing := gate_width / float(bar_count + 1)
	for i in range(bar_count):
		var bar_x := -half_w + (i + 1) * bar_spacing
		var bar_top := -gate_height
		var bar_bot := -gate_height + drop_h
		
		# Draw main vertical bar
		draw_line(Vector2(bar_x, bar_top), Vector2(bar_x, bar_bot), COLOR_IRON_BAR, 4.0)
		
		# Spiked bottom tip if partially or fully dropped
		if _anim_progress > 0.3:
			var tip := PackedVector2Array([
				Vector2(bar_x - 3.0, bar_bot),
				Vector2(bar_x + 3.0, bar_bot),
				Vector2(bar_x, bar_bot + 6.0)
			])
			draw_polygon(tip, [COLOR_IRON_BAR])
	
	# Horizontal crossbeams
	var cross_y_positions = [-gate_height + drop_h * 0.3, -gate_height + drop_h * 0.7]
	for cy in cross_y_positions:
		if cy > -gate_height:
			draw_rect(Rect2(-half_w - 2.0, cy - 3.0, gate_width + 4.0, 6.0), COLOR_STONE_FRAME)
			draw_line(Vector2(-half_w, cy), Vector2(half_w, cy), COLOR_RUNIC_RIVET, 1.5)
	
	# Center occult lock crest
	if _anim_progress > 0.8:
		var center_y := -gate_height + drop_h * 0.5
		draw_circle(Vector2(0.0, center_y), 7.0, COLOR_STONE_FRAME)
		draw_circle(Vector2(0.0, center_y), 5.0, COLOR_LOCK_RUNE)
		draw_arc(Vector2(0.0, center_y), 8.0, 0.0, TAU, 16, COLOR_RUNIC_RIVET, 1.5)
