class_name DebugHUD
extends CanvasLayer

## Diagnostic telemetry overlay for movement tuning and combat verification.
## Displays real-time physics parameters, state machine updates, combat stats, and control hints.

@export var player: CharacterBody2D

var _info_label: Label
var _panel_container: PanelContainer
var _visible_overlay: bool = true


func _ready() -> void:
	layer = 100
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_visible_overlay = not _visible_overlay
			_panel_container.visible = _visible_overlay


func _process(_delta: float) -> void:
	if not _visible_overlay or not player or not _info_label:
		return
	
	var vx: float = player.velocity.x
	var vy: float = player.velocity.y
	var on_floor: bool = player.is_on_floor()
	var state_str: String = player.call("get_state_name") if player.has_method("get_state_name") else "N/A"
	var coyote_rem: float = player.call("get_coyote_time_remaining") if player.has_method("get_coyote_time_remaining") else 0.0
	var buffer_rem: float = player.call("get_jump_buffer_remaining") if player.has_method("get_jump_buffer_remaining") else 0.0
	var coyote_active: bool = player.call("is_coyote_active") if player.has_method("is_coyote_active") else false
	var buffer_active: bool = player.call("is_jump_buffered") if player.has_method("is_jump_buffered") else false
	var atk_buf_rem: float = player.call("get_attack_buffer_remaining") if player.has_method("get_attack_buffer_remaining") else 0.0
	var atk_buf_active: bool = player.call("is_attack_buffered") if player.has_method("is_attack_buffered") else false
	
	var hp: int = player.call("get_current_health") if player.has_method("get_current_health") else 5
	var max_hp: int = player.call("get_max_health") if player.has_method("get_max_health") else 5
	var atk_state: String = player.call("get_attack_state_name") if player.has_method("get_attack_state_name") else "NONE"
	var atk_dir: String = player.call("get_attack_direction_name") if player.has_method("get_attack_direction_name") else "FORWARD"
	var iframe_rem: float = player.call("get_invulnerability_time_remaining") if player.has_method("get_invulnerability_time_remaining") else 0.0
	
	var hp_pips: String = ""
	for i in range(max_hp):
		hp_pips += "[*]" if i < hp else "[ ]"
	
	var soul: int = player.call("get_current_soul") if player.has_method("get_current_soul") else 0
	var max_soul: int = player.call("get_max_soul") if player.has_method("get_max_soul") else 99
	var soul_cost: int = player.call("get_soul_heal_cost") if player.has_method("get_soul_heal_cost") else 33
	var is_focus: bool = player.call("is_focusing") if player.has_method("is_focusing") else false
	var focus_prog: float = player.call("get_focus_progress") if player.has_method("get_focus_progress") else 0.0
	var charges: int = soul / soul_cost if soul_cost > 0 else 0
	var soul_pips: String = ""
	for c in range(max_soul / soul_cost if soul_cost > 0 else 3):
		soul_pips += "[*]" if c < charges else "[ ]"
	
	var fps: int = Engine.get_frames_per_second()
	
	var wall_coyote_rem: float = player.call("get_wall_coyote_remaining") if player.has_method("get_wall_coyote_remaining") else 0.0
	var dash_cd_rem: float = player.call("get_dash_cooldown_remaining") if player.has_method("get_dash_cooldown_remaining") else 0.0
	var air_dashes: int = player.call("get_air_dashes_remaining") if player.has_method("get_air_dashes_remaining") else 1
	var is_wall_slide: bool = player.call("is_wall_sliding") if player.has_method("is_wall_sliding") else false
	var is_dash: bool = player.call("is_dashing") if player.has_method("is_dashing") else false
	
	var text: String = ""
	text += "=== ECLIPSE PROTOTYPE TELEMETRY ===\n"
	text += "FPS: %d\n" % fps
	text += "Health:         %d/%d  %s\n" % [hp, max_hp, hp_pips]
	text += "Soul / Aether:  %d/%d  %s (%d charges)\n" % [soul, max_soul, soul_pips, charges]
	text += "Focus Channel:  %s\n" % ("CHARGING (%.0f%%)" % (focus_prog * 100.0) if is_focus else "READY" if (charges > 0 and hp < max_hp) else "OFF")
	text += "Movement State: %s\n" % state_str
	text += "Attack State:   %s (%s)\n" % [atk_state, atk_dir]
	text += "Velocity: (X: %6.1f, Y: %6.1f) px/s\n" % [vx, vy]
	text += "On Floor: %s | Wall Slide: %s\n" % [("YES" if on_floor else "NO"), ("ACTIVE" if is_wall_slide else "NO")]
	text += "Coyote Window: %s (%.2fs)\n" % [("ACTIVE" if coyote_active else "OFF"), coyote_rem]
	text += "Wall Coyote:   %s (%.2fs)\n" % [("ACTIVE" if wall_coyote_rem > 0.0 else "OFF"), wall_coyote_rem]
	text += "Jump Buffer:   %s (%.2fs)\n" % [("QUEUED" if buffer_active else "OFF"), buffer_rem]
	text += "Dash State:    %s | CD: %.2fs | Air Left: %d\n" % [("DASHING" if is_dash else "READY" if dash_cd_rem <= 0.0 else "COOLDOWN"), dash_cd_rem, air_dashes]
	text += "Attack Buffer: %s (%.2fs)\n" % [("QUEUED" if atk_buf_active else "OFF"), atk_buf_rem]
	text += "I-Frames:      %s (%.2fs)\n" % [("ACTIVE" if iframe_rem > 0.0 else "OFF"), iframe_rem]
	text += "Facing: %s\n" % ("RIGHT" if player.get("facing_direction") == 1 else "LEFT")
	text += "\n--- CONTROLS ---\n"
	text += "[A / D] Move | [Space] Jump\n"
	text += "[C / Shift] Dash | [Wall + Space] Wall Jump\n"
	text += "[J / X] Melee Attack (Forward)\n"
	text += "[W + J/X] Upward Slash\n"
	text += "[Air + S + J/X] Downward Pogo Slash\n"
	text += "[H / Q / Pad B] Focus Heal (Hold, Grounded)\n"
	text += "[R] Reset Position | [F1] Toggle Overlay"
	
	_info_label.text = text


func _build_ui() -> void:
	_panel_container = PanelContainer.new()
	_panel_container.name = "TelemetryPanel"
	_panel_container.offset_left = 16.0
	_panel_container.offset_top = 16.0
	_panel_container.offset_right = 380.0
	_panel_container.offset_bottom = 320.0
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	style.border_color = Color(0.25, 0.35, 0.48, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	_panel_container.add_theme_stylebox_override("panel", style)
	
	_info_label = Label.new()
	_info_label.name = "TelemetryLabel"
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	
	_panel_container.add_child(_info_label)
	add_child(_panel_container)
