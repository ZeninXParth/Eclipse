class_name BossHealthBar
extends CanvasLayer

## ECLIPSE: Echoes of the Forgotten
## Milestone 4: Boss Cinematic Health Bar HUD
## Displays boss title and animated health bar at the bottom center of the screen.
## Supports smooth damage lag-behind bars, fade in/out transitions, and dynamic health tracking.

signal bar_shown()
signal bar_hidden()
signal health_updated(current_health: int, max_health: int)

@export var boss_title: String = "ARCHIVE WARDEN — Ancient Sentry"
@export var max_health: int = 30
@export var current_health: int = 30
@export var bar_width: float = 560.0
@export var bar_height: float = 16.0

var lag_health: float = 30.0
var target_alpha: float = 0.0
var current_alpha: float = 0.0
var is_active: bool = false

# UI Nodes
var root_control: Control
var title_label: Label
var bar_container: Control
var bg_rect: ColorRect
var lag_fill: ColorRect
var current_fill: ColorRect
var hp_label: Label

const COLOR_BG = Color(0.08, 0.09, 0.12, 0.95)
const COLOR_BORDER = Color(0.35, 0.40, 0.50, 0.9)
const COLOR_LAG_FILL = Color(0.85, 0.45, 0.20, 0.9) # Amber damage flash
const COLOR_CURRENT_FILL = Color(0.75, 0.15, 0.25, 0.95) # Occult crimson
const COLOR_TITLE = Color(0.92, 0.94, 0.98, 1.0)
const COLOR_RUNE_TRIM = Color(0.35, 0.90, 1.0, 0.9)


func _init() -> void:
	layer = 25


func _ready() -> void:
	_build_ui()
	hide_bar(true)


func _build_ui() -> void:
	if root_control != null:
		return
	
	root_control = Control.new()
	root_control.name = "BossHealthBarRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	
	# Bottom center positioning
	var bar_panel := Control.new()
	bar_panel.name = "BarPanel"
	bar_panel.layout_mode = 1
	bar_panel.anchors_preset = Control.PRESET_CENTER_BOTTOM
	bar_panel.anchor_left = 0.5
	bar_panel.anchor_right = 0.5
	bar_panel.anchor_top = 1.0
	bar_panel.anchor_bottom = 1.0
	bar_panel.offset_left = -bar_width * 0.5
	bar_panel.offset_right = bar_width * 0.5
	bar_panel.offset_top = -65.0
	bar_panel.offset_bottom = -25.0
	bar_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root_control.add_child(bar_panel)
	bar_container = bar_panel
	
	# Boss Title Label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = boss_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.offset_left = 0.0
	title_label.offset_right = bar_width
	title_label.offset_top = -22.0
	title_label.offset_bottom = 0.0
	title_label.add_theme_color_override("font_color", COLOR_TITLE)
	title_label.add_theme_font_size_override("font_size", 14)
	bar_panel.add_child(title_label)
	
	# Background Frame
	bg_rect = ColorRect.new()
	bg_rect.name = "Background"
	bg_rect.color = COLOR_BG
	bg_rect.offset_left = 0.0
	bg_rect.offset_right = bar_width
	bg_rect.offset_top = 0.0
	bg_rect.offset_bottom = bar_height
	bar_panel.add_child(bg_rect)
	
	# Damage Lag Fill (Amber)
	lag_fill = ColorRect.new()
	lag_fill.name = "LagFill"
	lag_fill.color = COLOR_LAG_FILL
	lag_fill.offset_left = 1.0
	lag_fill.offset_top = 1.0
	lag_fill.offset_right = bar_width - 1.0
	lag_fill.offset_bottom = bar_height - 1.0
	bar_panel.add_child(lag_fill)
	
	# Primary Health Fill (Crimson)
	current_fill = ColorRect.new()
	current_fill.name = "CurrentFill"
	current_fill.color = COLOR_CURRENT_FILL
	current_fill.offset_left = 1.0
	current_fill.offset_top = 1.0
	current_fill.offset_right = bar_width - 1.0
	current_fill.offset_bottom = bar_height - 1.0
	bar_panel.add_child(current_fill)
	
	# Numeric HP Indicator
	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "%d / %d" % [current_health, max_health]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.offset_left = 0.0
	hp_label.offset_right = bar_width
	hp_label.offset_top = 0.0
	hp_label.offset_bottom = bar_height
	hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	hp_label.add_theme_font_size_override("font_size", 11)
	bar_panel.add_child(hp_label)


func initialize_bar(p_title: String, p_max_hp: int, p_current_hp: int) -> void:
	boss_title = p_title
	max_health = p_max_hp
	current_health = p_current_hp
	lag_health = float(p_current_hp)
	
	if title_label:
		title_label.text = boss_title
	_update_fill_rects()


func show_bar(animate: bool = true) -> void:
	is_active = true
	target_alpha = 1.0
	if not animate:
		current_alpha = 1.0
		_apply_alpha()
	bar_shown.emit()


func hide_bar(instant: bool = true) -> void:
	is_active = false
	target_alpha = 0.0
	if instant:
		current_alpha = 0.0
		_apply_alpha()
	bar_hidden.emit()


func fade_out() -> void:
	target_alpha = 0.0


func update_health(p_current: int, p_max: int = -1) -> void:
	if p_max > 0:
		max_health = p_max
	current_health = clampi(p_current, 0, max_health)
	health_updated.emit(current_health, max_health)
	_update_fill_rects()


func _update_fill_rects() -> void:
	var total_w := bar_width - 2.0
	var health_ratio := clampf(float(current_health) / float(max_health) if max_health > 0 else 0.0, 0.0, 1.0)
	
	if current_fill:
		current_fill.offset_right = 1.0 + total_w * health_ratio
	
	if hp_label:
		hp_label.text = "%d / %d" % [current_health, max_health]


func step_ui(delta: float) -> void:
	# Lerp alpha
	if not is_equal_approx(current_alpha, target_alpha):
		current_alpha = move_toward(current_alpha, target_alpha, delta * 3.0)
		_apply_alpha()
		if is_equal_approx(current_alpha, 0.0) and is_active and target_alpha <= 0.0:
			is_active = false
			bar_hidden.emit()
	
	# Smoothly lag damage bar
	if not is_equal_approx(lag_health, float(current_health)):
		lag_health = move_toward(lag_health, float(current_health), delta * 12.0)
		var total_w := bar_width - 2.0
		var lag_ratio := clampf(lag_health / float(max_health) if max_health > 0 else 0.0, 0.0, 1.0)
		if lag_fill:
			lag_fill.offset_right = 1.0 + total_w * lag_ratio


func _process(delta: float) -> void:
	step_ui(delta)


func _apply_alpha() -> void:
	if root_control:
		root_control.modulate.a = current_alpha
