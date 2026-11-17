class_name PlayerVisuals
extends Node2D

## ECLIPSE: Echoes of the Forgotten
## Visual representation for the Aristocratic Occult Detective protagonist.
## Renders a silhouette featuring a silk top hat with purple band,
## tiered coachman's capelet with animated inner purple silk lining,
## tailored waistcoat, pocket watch chain, laced boots,
## drawn silver cane-sword with electric cyan/lunar light trails,
## and floating ethereal tarot cards with glowing runic aura during Focus Healing.

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")

@export var controller: CharacterBody2D

# --- Occult Detective Thematic Palette ---
const COLOR_HAT_SILK: Color = Color(0.10, 0.11, 0.14, 1.0) # Obsidian silk top hat
const COLOR_HAT_BAND: Color = Color(0.58, 0.16, 0.84, 1.0) # Royal purple silk band
const COLOR_HAT_BUCKLE: Color = Color(0.92, 0.82, 0.42, 1.0) # Antique brass clasp
const COLOR_FACE_SHADOW: Color = Color(0.12, 0.13, 0.16, 1.0) # Shadowed visage under brim
const COLOR_CRAVAT: Color = Color(0.88, 0.90, 0.95, 1.0) # Fine silver-white cravat
const COLOR_WAISTCOAT: Color = Color(0.16, 0.15, 0.22, 1.0) # Tailored plum/charcoal vest
const COLOR_WATCH_CHAIN: Color = Color(0.94, 0.84, 0.45, 0.95) # Gold pocket watch chain
const COLOR_CAPELET_OUTER: Color = Color(0.12, 0.13, 0.17, 1.0) # Tiered coachman's capelet
const COLOR_CAPELET_LINING: Color = Color(0.68, 0.20, 0.92, 1.0) # Rich purple silk lining
const COLOR_TROUSERS: Color = Color(0.13, 0.14, 0.17, 1.0) # Dark tailored trousers
const COLOR_BOOTS: Color = Color(0.08, 0.08, 0.10, 1.0) # Laced Victorian boots
const COLOR_BOOT_LACES: Color = Color(0.35, 0.38, 0.45, 0.9)
const COLOR_EYE_GLOW: Color = Color(0.38, 0.90, 1.0, 1.0) # Electric cyan occult gaze
const COLOR_CANE_SHAFT: Color = Color(0.11, 0.11, 0.13, 1.0) # Polished ebony cane shaft
const COLOR_CANE_SILVER: Color = Color(0.88, 0.92, 0.98, 1.0) # Ornate silver handle & ferrule
const COLOR_SLASH_BLADE: Color = Color(0.98, 1.0, 1.0, 0.95) # Engraved rapier blade
const COLOR_SLASH_GLOW: Color = Color(0.35, 0.85, 1.0, 0.8) # Electric cyan lunar light trail
const COLOR_SLASH_OCCULT: Color = Color(0.72, 0.25, 0.98, 0.65) # Celestial purple occult fringe
const COLOR_TAROT_CARD: Color = Color(0.14, 0.10, 0.22, 0.85) # Ethereal card backing
const COLOR_TAROT_GLOW: Color = Color(0.75, 0.35, 1.0, 0.9) # Purple card flame
const COLOR_TAROT_RUNE: Color = Color(0.40, 0.92, 1.0, 0.95) # Celestial cyan runes
const COLOR_DASH_GHOST: Color = Color(0.45, 0.82, 1.0, 0.45)
const COLOR_DASH_STREAK: Color = Color(0.85, 0.95, 1.0, 0.8)
const COLOR_WALL_DUST: Color = Color(0.65, 0.72, 0.90, 0.6)

# Backward-compatibility aliases for existing test suites
const COLOR_CLOAK: Color = COLOR_CAPELET_OUTER
const COLOR_CLOAK_INNER: Color = COLOR_CAPELET_LINING
const COLOR_MASK: Color = COLOR_CRAVAT

var current_scale: Vector2 = Vector2.ONE
var target_scale: Vector2 = Vector2.ONE
var lean_angle: float = 0.0
var walk_cycle_time: float = 0.0

var slash_timer: float = 0.0
var slash_direction: int = 0 # 0: Forward, 1: Up, 2: Down
var slash_facing: float = 1.0

var damage_flash_timer: float = 0.0
const DAMAGE_FLASH_DURATION: float = 0.14
var heal_pulse_timer: float = 0.0
const HEAL_PULSE_DURATION: float = 0.25
var lunar_wings_timer: float = 0.0
const LUNAR_WINGS_DURATION: float = 0.32

# Dash ghost recording
var dash_ghosts: Array[Dictionary] = []
var tarot_charge_sparks: Array[Dictionary] = []
var _last_soul: int = 0


func _ready() -> void:
	if controller:
		if controller.has_signal("jumped") and not controller.jumped.is_connected(_on_jumped):
			controller.jumped.connect(_on_jumped)
		if controller.has_signal("double_jumped") and not controller.double_jumped.is_connected(_on_double_jumped):
			controller.double_jumped.connect(_on_double_jumped)
		if controller.has_signal("mantled") and not controller.mantled.is_connected(_on_mantled):
			controller.mantled.connect(_on_mantled)
		if controller.has_signal("landed") and not controller.landed.is_connected(_on_landed):
			controller.landed.connect(_on_landed)
		if controller.has_signal("wall_jumped") and not controller.wall_jumped.is_connected(_on_wall_jumped):
			controller.wall_jumped.connect(_on_wall_jumped)
		if controller.has_signal("dashed") and not controller.dashed.is_connected(_on_dashed):
			controller.dashed.connect(_on_dashed)
		if controller.has_signal("player_damaged") and not controller.player_damaged.is_connected(_on_player_damaged):
			controller.player_damaged.connect(_on_player_damaged)
		if controller.has_signal("soul_changed") and not controller.soul_changed.is_connected(_on_soul_changed):
			controller.soul_changed.connect(_on_soul_changed)
		if controller.has_signal("focus_started") and not controller.focus_started.is_connected(_on_focus_started):
			controller.focus_started.connect(_on_focus_started)
		if controller.has_signal("focus_completed") and not controller.focus_completed.is_connected(_on_focus_completed):
			controller.focus_completed.connect(_on_focus_completed)
		if controller.has_signal("focus_interrupted") and not controller.focus_interrupted.is_connected(_on_focus_interrupted):
			controller.focus_interrupted.connect(_on_focus_interrupted)
		if controller.has_method("get_current_soul"):
			_last_soul = controller.call("get_current_soul")


func _on_soul_changed(new_soul: int, _max_soul: int) -> void:
	if new_soul > _last_soul:
		for k in range(5):
			tarot_charge_sparks.append({
				"pos": Vector2(randf_range(-14.0, 14.0), randf_range(-25.0, 5.0)),
				"vel": Vector2(randf_range(-20.0, 20.0), randf_range(-40.0, -15.0)),
				"life": 0.45,
				"max_life": 0.45
			})
		queue_redraw()
	_last_soul = new_soul


func _on_player_damaged(_damage: int, _remaining_health: int) -> void:
	damage_flash_timer = DAMAGE_FLASH_DURATION
	queue_redraw()


func _on_focus_started() -> void:
	target_scale = Vector2(0.9, 0.95)
	queue_redraw()


func _on_focus_completed() -> void:
	target_scale = Vector2(1.15, 1.15)
	heal_pulse_timer = HEAL_PULSE_DURATION
	queue_redraw()


func _on_focus_interrupted() -> void:
	target_scale = Vector2.ONE
	queue_redraw()


func _on_double_jumped() -> void:
	target_scale = Vector2(0.80, 1.25)
	lunar_wings_timer = LUNAR_WINGS_DURATION
	queue_redraw()


func _on_mantled() -> void:
	target_scale = Vector2(1.05, 0.95)
	lean_angle = 0.15
	queue_redraw()


func _process(delta: float) -> void:
	if controller:
		_update_animations(delta)
	
	if slash_timer > 0.0:
		slash_timer = maxf(0.0, slash_timer - delta)
	
	if damage_flash_timer > 0.0:
		damage_flash_timer = maxf(0.0, damage_flash_timer - delta)
	
	if heal_pulse_timer > 0.0:
		heal_pulse_timer = maxf(0.0, heal_pulse_timer - delta)
	
	if lunar_wings_timer > 0.0:
		lunar_wings_timer = maxf(0.0, lunar_wings_timer - delta)
	
	# Update dash ghosts
	var i := 0
	while i < dash_ghosts.size():
		dash_ghosts[i]["life"] -= delta * 5.0
		if dash_ghosts[i]["life"] <= 0.0:
			dash_ghosts.remove_at(i)
		else:
			i += 1
	
	# Update tarot card charge sparks
	var j := 0
	while j < tarot_charge_sparks.size():
		tarot_charge_sparks[j]["life"] -= delta
		tarot_charge_sparks[j]["pos"] += tarot_charge_sparks[j]["vel"] * delta
		if tarot_charge_sparks[j]["life"] <= 0.0:
			tarot_charge_sparks.remove_at(j)
		else:
			j += 1
	
	queue_redraw()


func play_slash(direction: int, facing: int) -> void:
	slash_direction = direction
	slash_facing = float(facing)
	slash_timer = 0.12
	if direction == 0:
		current_scale = Vector2(1.2, 0.9)
	elif direction == 1:
		current_scale = Vector2(0.85, 1.25)
	elif direction == 2:
		current_scale = Vector2(0.9, 1.15)
	queue_redraw()


func on_pogo_bounce() -> void:
	current_scale = Vector2(0.65, 1.45)
	queue_redraw()


func _on_dashed(_direction: Vector2) -> void:
	current_scale = Vector2(1.5, 0.65)
	var facing: float = float(controller.facing_direction if controller else 1)
	dash_ghosts.append({
		"global_pos": global_position,
		"life": 1.0,
		"scale": Vector2(1.3, 0.7),
		"facing": facing
	})
	queue_redraw()


func _on_wall_jumped() -> void:
	current_scale = Vector2(0.7, 1.4)
	queue_redraw()


func _on_jumped() -> void:
	current_scale = Vector2(0.75, 1.3)


func _on_landed() -> void:
	current_scale = Vector2(1.35, 0.65)


func _update_animations(delta: float) -> void:
	target_scale = Vector2.ONE
	var facing: float = float(controller.facing_direction) if controller else 1.0
	var state = controller.current_state if controller else 0
	
	match state:
		PlayerControllerScript.State.RUN:
			walk_cycle_time += delta * 14.0
			var bob: float = sin(walk_cycle_time) * 0.06
			target_scale = Vector2(1.0 + bob, 1.0 - bob)
			lean_angle = lerpf(lean_angle, 0.12 * facing, delta * 12.0)
		
		PlayerControllerScript.State.DASH:
			target_scale = Vector2(1.4, 0.7)
			lean_angle = 0.15 * facing
			if randf() < 0.4:
				dash_ghosts.append({
					"global_pos": global_position,
					"life": 0.8,
					"scale": current_scale,
					"facing": facing
				})
		
		PlayerControllerScript.State.WALL_SLIDE:
			target_scale = Vector2(0.85, 1.12)
			lean_angle = 0.05 * facing
			walk_cycle_time = 0.0
		
		PlayerControllerScript.State.WALL_JUMP, PlayerControllerScript.State.JUMP:
			target_scale = Vector2(0.85, 1.2)
			lean_angle = lerpf(lean_angle, 0.0, delta * 10.0)
			walk_cycle_time = 0.0
		
		PlayerControllerScript.State.FALL:
			target_scale = Vector2(0.92, 1.08)
			lean_angle = lerpf(lean_angle, 0.0, delta * 10.0)
			walk_cycle_time = 0.0
		
		_:
			walk_cycle_time = 0.0
			lean_angle = lerpf(lean_angle, 0.0, delta * 10.0)
	
	current_scale = current_scale.lerp(target_scale, delta * 14.0)
	scale = Vector2(current_scale.x * facing, current_scale.y)
	rotation = lean_angle


func _draw() -> void:
	# 1. Dash ghost silhouettes
	for ghost in dash_ghosts:
		var ghost_alpha: float = clampf(ghost["life"], 0.0, 1.0) * 0.4
		var g_color := Color(COLOR_DASH_GHOST.r, COLOR_DASH_GHOST.g, COLOR_DASH_GHOST.b, ghost_alpha)
		var off: Vector2 = Vector2.ZERO
		if ghost.has("global_pos"):
			off = to_local(ghost["global_pos"])
		elif ghost.has("offset"):
			off = ghost["offset"]
		
		_draw_detective_silhouette(off, g_color)
	
	# 2. Damage i-frame visual feedback
	var is_invulnerable: bool = false
	if controller and controller.has_method("is_invulnerable"):
		is_invulnerable = controller.call("is_invulnerable")
	
	var is_flicker_invisible: bool = false
	if is_invulnerable and damage_flash_timer <= 0.0:
		is_flicker_invisible = (int(Time.get_ticks_msec() / 60.0) % 2) == 0
	
	if damage_flash_timer > 0.0:
		_draw_character(true)
	elif not is_flicker_invisible:
		_draw_character(false)
	
	# 3. Wall slide friction sparks
	if controller and controller.get("current_state") == PlayerControllerScript.State.WALL_SLIDE:
		var wall_x: float = 11.0
		for k in range(3):
			var spark_y: float = -randf_range(5.0, 25.0)
			draw_circle(Vector2(wall_x, spark_y), randf_range(1.0, 2.0), COLOR_WALL_DUST)
	
	# 4. Dash speed streaks
	if controller and controller.get("current_state") == PlayerControllerScript.State.DASH:
		for k in range(3):
			var streak_y: float = -randf_range(8.0, 32.0)
			var streak_len: float = randf_range(20.0, 36.0)
			draw_line(Vector2(-streak_len, streak_y), Vector2(0.0, streak_y), COLOR_DASH_STREAK, 1.5)
	
	# 5. Cane sword slash visual effects
	if slash_timer > 0.0:
		_draw_slash_effect()
	
	# 6. Ethereal Tarot Cards Focus Channeling
	if controller and controller.has_method("is_focusing") and controller.call("is_focusing"):
		_draw_tarot_focus()
	
	# 7. Tarot card energy charge sparks (accumulated from striking enemies)
	for spark in tarot_charge_sparks:
		var spark_alpha: float = clampf(spark["life"] / spark["max_life"], 0.0, 1.0)
		draw_circle(spark["pos"], 2.0, Color(COLOR_TAROT_RUNE.r, COLOR_TAROT_RUNE.g, COLOR_TAROT_RUNE.b, spark_alpha))
		draw_line(spark["pos"] - Vector2(0, 2), spark["pos"] + Vector2(0, 2), Color(1.0, 1.0, 1.0, spark_alpha), 1.0)
	
	# 8. Heal completion burst
	if heal_pulse_timer > 0.0:
		_draw_heal_burst()
	
	# 9. Lunar Eclipse Wings (Double Jump)
	if lunar_wings_timer > 0.0:
		_draw_lunar_wings()


func _draw_lunar_wings() -> void:
	var alpha: float = clampf(lunar_wings_timer / LUNAR_WINGS_DURATION, 0.0, 1.0)
	var wing_purple := Color(COLOR_SLASH_OCCULT.r, COLOR_SLASH_OCCULT.g, COLOR_SLASH_OCCULT.b, alpha * 0.8)
	var wing_cyan := Color(COLOR_SLASH_GLOW.r, COLOR_SLASH_GLOW.g, COLOR_SLASH_GLOW.b, alpha * 0.95)
	var wing_white := Color(1.0, 1.0, 1.0, alpha * 0.9)
	
	# Left Wing (arc back)
	var left_wing_pts := PackedVector2Array([
		Vector2(-4, -22),
		Vector2(-26, -38),
		Vector2(-36, -26),
		Vector2(-24, -14),
		Vector2(-6, -18)
	])
	draw_colored_polygon(left_wing_pts, wing_purple)
	draw_polyline(left_wing_pts, wing_cyan, 1.5)
	draw_line(Vector2(-4, -22), Vector2(-30, -32), wing_white, 1.5)
	
	# Right Wing (arc forward/high)
	var right_wing_pts := PackedVector2Array([
		Vector2(2, -22),
		Vector2(24, -38),
		Vector2(34, -26),
		Vector2(22, -14),
		Vector2(4, -18)
	])
	draw_colored_polygon(right_wing_pts, wing_purple)
	draw_polyline(right_wing_pts, wing_cyan, 1.5)
	draw_line(Vector2(2, -22), Vector2(28, -32), wing_white, 1.5)


func _draw_detective_silhouette(off: Vector2, color: Color) -> void:
	# Silhouette polygon incorporating top hat, capelet, and stance
	var pts := PackedVector2Array([
		off + Vector2(-10, 0),
		off + Vector2(-12, -26),
		off + Vector2(-8, -38),
		off + Vector2(-11, -38), # Hat brim left
		off + Vector2(-8, -43),  # Crown base
		off + Vector2(-7, -58),  # Crown top left
		off + Vector2(7, -58),   # Crown top right
		off + Vector2(8, -43),   # Crown base
		off + Vector2(11, -38),  # Hat brim right
		off + Vector2(8, -38),
		off + Vector2(12, -26),
		off + Vector2(10, 0),
		off + Vector2(0, -3)
	])
	draw_colored_polygon(pts, color)


func _draw_character(is_flashing: bool = false) -> void:
	if is_flashing:
		_draw_detective_silhouette(Vector2.ZERO, Color.WHITE)
		return
	
	var state = controller.current_state if controller else 0
	
	# --- 1. Laced Victorian Boots & Trousers ---
	# Trousers
	draw_line(Vector2(-4, -14), Vector2(-4, -4), COLOR_TROUSERS, 4.0)
	draw_line(Vector2(4, -14), Vector2(4, -4), COLOR_TROUSERS, 4.0)
	# Laced Boots
	draw_rect(Rect2(-7, -5, 6, 5), COLOR_BOOTS)
	draw_rect(Rect2(1, -5, 6, 5), COLOR_BOOTS)
	draw_line(Vector2(-6, -3), Vector2(-2, -3), COLOR_BOOT_LACES, 1.0)
	draw_line(Vector2(2, -3), Vector2(6, -3), COLOR_BOOT_LACES, 1.0)
	
	# --- 2. Tiered Coachman's Capelet with Animated Purple Silk Lining ---
	# Calculate flutter based on locomotion
	var cape_flutter: float = 0.0
	if state == PlayerControllerScript.State.RUN:
		cape_flutter = sin(walk_cycle_time) * 4.0 - 5.0 # Flutter backwards
	elif state == PlayerControllerScript.State.JUMP or state == PlayerControllerScript.State.FALL:
		var vy: float = controller.velocity.y if controller else 0.0
		cape_flutter = clampf(-vy * 0.015, -4.0, 7.0)
	elif state == PlayerControllerScript.State.DASH:
		cape_flutter = -9.0
	
	# A) Inner Purple Silk Lining (billowing behind when moving)
	if absf(cape_flutter) > 1.5 or state == PlayerControllerScript.State.RUN or state == PlayerControllerScript.State.DASH:
		var lining_pts := PackedVector2Array([
			Vector2(-10, -26),
			Vector2(-14 + cape_flutter * 0.8, -12),
			Vector2(-13 + cape_flutter, 0),
			Vector2(-6, -2),
			Vector2(-6, -20)
		])
		draw_colored_polygon(lining_pts, COLOR_CAPELET_LINING)
		# Silk sheen line
		draw_line(Vector2(-10, -26), Vector2(-13 + cape_flutter, 0), Color(0.85, 0.40, 1.0, 0.8), 1.0)
	
	# B) Main Capelet Body (Outer obsidian fabric)
	var cape_pts := PackedVector2Array([
		Vector2(-10, 0 + (cape_flutter * 0.2)),
		Vector2(-13, -24),
		Vector2(-9, -36),
		Vector2(0, -38),
		Vector2(9, -36),
		Vector2(12, -24),
		Vector2(9, 0),
		Vector2(0, -2)
	])
	draw_colored_polygon(cape_pts, COLOR_CAPELET_OUTER)
	
	# Subtle purple trim along capelet hem
	draw_line(Vector2(-10, 0 + (cape_flutter * 0.2)), Vector2(0, -2), COLOR_CAPELET_LINING, 1.5)
	draw_line(Vector2(0, -2), Vector2(9, 0), COLOR_CAPELET_LINING, 1.5)
	
	# Upper Tier Shoulder Capelet (Mantlet)
	var shoulder_tier := PackedVector2Array([
		Vector2(-11, -22),
		Vector2(-8, -36),
		Vector2(0, -38),
		Vector2(8, -36),
		Vector2(11, -22),
		Vector2(0, -18)
	])
	draw_colored_polygon(shoulder_tier, Color(0.14, 0.15, 0.19, 1.0))
	draw_line(Vector2(-11, -22), Vector2(0, -18), COLOR_CAPELET_LINING, 1.0)
	draw_line(Vector2(0, -18), Vector2(11, -22), COLOR_CAPELET_LINING, 1.0)
	
	# --- 3. Tailored Waistcoat & Gold Pocket Watch Chain ---
	var vest_pts := PackedVector2Array([
		Vector2(-5, -20),
		Vector2(0, -32),
		Vector2(5, -20),
		Vector2(0, -12)
	])
	draw_colored_polygon(vest_pts, COLOR_WAISTCOAT)
	
	# Fine silver cravat / neckwear
	var cravat_pts := PackedVector2Array([
		Vector2(-3, -28),
		Vector2(0, -34),
		Vector2(3, -28),
		Vector2(0, -23)
	])
	draw_colored_polygon(cravat_pts, COLOR_CRAVAT)
	
	# Gold Pocket Watch Chain (draped across vest pocket)
	var chain_pts := PackedVector2Array([
		Vector2(-2, -18),
		Vector2(0, -15),
		Vector2(3, -16)
	])
	draw_polyline(chain_pts, COLOR_WATCH_CHAIN, 1.2)
	draw_circle(Vector2(3, -16), 1.2, COLOR_WATCH_CHAIN) # Watch fob
	
	# --- 4. Occult Detective Visage & Top Hat ---
	# Shadowed face
	draw_rect(Rect2(-4, -36, 8, 8), COLOR_FACE_SHADOW)
	
	# Keen electric cyan / lunar eye
	draw_circle(Vector2(2.5, -32), 1.8, COLOR_EYE_GLOW)
	draw_circle(Vector2(2.5, -32), 0.8, Color.WHITE)
	
	# Wide Top Hat Brim
	var brim_pts := PackedVector2Array([
		Vector2(-12, -37),
		Vector2(12, -37),
		Vector2(10, -39),
		Vector2(-10, -39)
	])
	draw_colored_polygon(brim_pts, COLOR_HAT_SILK)
	draw_line(Vector2(-12, -37), Vector2(12, -37), Color(0.25, 0.26, 0.32, 0.8), 1.0) # Brim highlight
	
	# Tall Top Hat Crown
	var crown_pts := PackedVector2Array([
		Vector2(-7, -39),
		Vector2(-6, -56),
		Vector2(6, -56),
		Vector2(7, -39)
	])
	draw_colored_polygon(crown_pts, COLOR_HAT_SILK)
	# Crown silk highlight
	draw_line(Vector2(-5, -56), Vector2(5, -56), Color(0.3, 0.32, 0.4, 0.9), 1.5)
	
	# Royal Purple Silk Ribbon / Band around Hat Base
	var band_pts := PackedVector2Array([
		Vector2(-7.2, -40),
		Vector2(-6.8, -44),
		Vector2(6.8, -44),
		Vector2(7.2, -40)
	])
	draw_colored_polygon(band_pts, COLOR_HAT_BAND)
	
	# Antique Brass Hat Buckle
	draw_rect(Rect2(1.5, -43.5, 3.5, 3.0), COLOR_HAT_BUCKLE, false, 1.0)
	
	# --- 5. Cane Sword (Sheathed / Resting) ---
	if slash_timer <= 0.0:
		# Resting cane by side
		draw_line(Vector2(-7, -18), Vector2(-7, -2), COLOR_CANE_SHAFT, 2.0)
		draw_circle(Vector2(-7, -20), 2.2, COLOR_CANE_SILVER) # Ornate silver curved handle
		draw_circle(Vector2(-7, -2), 1.2, COLOR_CANE_SILVER)  # Silver ferrule tip


func _draw_slash_effect() -> void:
	var alpha_factor: float = clampf(slash_timer / 0.12, 0.0, 1.0)
	var occult_color: Color = Color(COLOR_SLASH_OCCULT.r, COLOR_SLASH_OCCULT.g, COLOR_SLASH_OCCULT.b, COLOR_SLASH_OCCULT.a * alpha_factor)
	var glow_color: Color = Color(COLOR_SLASH_GLOW.r, COLOR_SLASH_GLOW.g, COLOR_SLASH_GLOW.b, COLOR_SLASH_GLOW.a * alpha_factor)
	var blade_color: Color = Color(COLOR_SLASH_BLADE.r, COLOR_SLASH_BLADE.g, COLOR_SLASH_BLADE.b, COLOR_SLASH_BLADE.a * alpha_factor)
	
	# Draw drawn silver cane-sword rapier
	var hilt_pos := Vector2(4.0, -22.0)
	if slash_direction == 1:
		hilt_pos = Vector2(0.0, -32.0)
	elif slash_direction == 2:
		hilt_pos = Vector2(0.0, -10.0)
	
	# Silver rapier hilt & drawn blade line
	draw_circle(hilt_pos, 2.4, COLOR_CANE_SILVER)
	
	var outer_pts := PackedVector2Array()
	var mid_pts := PackedVector2Array()
	var inner_pts := PackedVector2Array()
	
	match slash_direction:
		0: # FORWARD slash arc
			var center := Vector2(10.0, -20.0)
			var r_out := 35.0
			var r_mid := 28.0
			var r_in := 16.0
			var start_ang := -PI * 0.38
			var end_ang := PI * 0.38
			var steps := 10
			for i in range(steps + 1):
				var t: float = float(i) / float(steps)
				var ang: float = lerpf(start_ang, end_ang, t)
				outer_pts.append(center + Vector2(cos(ang) * r_out, sin(ang) * r_out))
				mid_pts.append(center + Vector2(cos(ang) * r_mid, sin(ang) * r_mid))
			for i in range(steps, -1, -1):
				var t: float = float(i) / float(steps)
				var ang: float = lerpf(start_ang, end_ang, t)
				inner_pts.append(center + Vector2(cos(ang) * r_in, sin(ang) * r_in))
		
		1: # UPWARD slash arc
			var center := Vector2(0.0, -34.0)
			var r_out := 36.0
			var r_mid := 28.0
			var r_in := 16.0
			var start_ang := -PI * 0.88
			var end_ang := -PI * 0.12
			var steps := 10
			for i in range(steps + 1):
				var t: float = float(i) / float(steps)
				var ang: float = lerpf(start_ang, end_ang, t)
				outer_pts.append(center + Vector2(cos(ang) * r_out, sin(ang) * r_out))
				mid_pts.append(center + Vector2(cos(ang) * r_mid, sin(ang) * r_mid))
			for i in range(steps, -1, -1):
				var t: float = float(i) / float(steps)
				var ang: float = lerpf(start_ang, end_ang, t)
				inner_pts.append(center + Vector2(cos(ang) * r_in, sin(ang) * r_in))
		
		2: # DOWNWARD pogo slash arc
			var center := Vector2(0.0, -6.0)
			var r_out := 32.0
			var r_mid := 24.0
			var r_in := 14.0
			var start_ang := PI * 0.12
			var end_ang := PI * 0.88
			var steps := 10
			for i in range(steps + 1):
				var t: float = float(i) / float(steps)
				var ang: float = lerpf(start_ang, end_ang, t)
				outer_pts.append(center + Vector2(cos(ang) * r_out, sin(ang) * r_out))
				mid_pts.append(center + Vector2(cos(ang) * r_mid, sin(ang) * r_mid))
			for i in range(steps, -1, -1):
				var t: float = float(i) / float(steps)
				var ang: float = lerpf(start_ang, end_ang, t)
				inner_pts.append(center + Vector2(cos(ang) * r_in, sin(ang) * r_in))
	
	if outer_pts.size() > 2 and inner_pts.size() > 2:
		# Outer purple occult trail
		var occult_poly := PackedVector2Array()
		occult_poly.append_array(outer_pts)
		occult_poly.append_array(inner_pts)
		draw_colored_polygon(occult_poly, occult_color)
		
		# Inner electric cyan lunar core
		draw_polyline(mid_pts, glow_color, 4.0)
		# Gleaming engraved rapier blade edge
		draw_polyline(outer_pts, blade_color, 2.2)
		
		# Celestial runic sparkle along the slash tip
		if outer_pts.size() > 4:
			draw_circle(outer_pts[outer_pts.size() / 2], 2.5, Color.WHITE)
			draw_circle(outer_pts[outer_pts.size() - 2], 1.8, COLOR_SLASH_GLOW)


func _draw_tarot_focus() -> void:
	var prog: float = controller.call("get_focus_progress") if controller.has_method("get_focus_progress") else 0.0
	var time_ms: float = float(Time.get_ticks_msec())
	var center := Vector2(0.0, -22.0)
	
	# Spiraling Runic Circle on Ground & Around Detective
	var rune_r: float = lerpf(34.0, 16.0, prog)
	var rune_alpha: float = 0.4 + 0.6 * prog
	var ring_col := Color(COLOR_TAROT_GLOW.r, COLOR_TAROT_GLOW.g, COLOR_TAROT_GLOW.b, rune_alpha)
	draw_arc(center, rune_r, 0.0, TAU, 32, ring_col, 2.0)
	
	# Inner glowing celestial aura
	var core_pulse: float = 4.0 + sin(time_ms * 0.015) * 2.0 + prog * 6.0
	draw_circle(center, core_pulse, Color(0.65, 0.35, 1.0, 0.25 + 0.5 * prog))
	draw_circle(center, core_pulse * 0.5, Color(0.4, 0.9, 1.0, 0.3 + 0.5 * prog))
	
	# 4 Orbiting Ethereal Tarot Cards
	var orbit_speed: float = time_ms * 0.003
	var card_orbit_rx: float = lerpf(32.0, 20.0, prog)
	var card_orbit_ry: float = lerpf(18.0, 10.0, prog)
	
	for c in range(4):
		var ang: float = orbit_speed + float(c) * (TAU / 4.0)
		var card_center: Vector2 = center + Vector2(cos(ang) * card_orbit_rx, sin(ang) * card_orbit_ry)
		
		# Draw ethereal tarot card (rotated to follow orbit)
		_draw_ethereal_tarot_card(card_center, ang, prog)


func _draw_ethereal_tarot_card(pos: Vector2, angle: float, prog: float) -> void:
	var cw: float = 9.0
	var ch: float = 14.0
	var ca: float = angle * 0.4
	var cos_a: float = cos(ca)
	var sin_a: float = sin(ca)
	
	# 4 corners of the card
	var p1 := pos + Vector2(-cw * 0.5 * cos_a + ch * 0.5 * sin_a, -cw * 0.5 * sin_a - ch * 0.5 * cos_a)
	var p2 := pos + Vector2(cw * 0.5 * cos_a + ch * 0.5 * sin_a, cw * 0.5 * sin_a - ch * 0.5 * cos_a)
	var p3 := pos + Vector2(cw * 0.5 * cos_a - ch * 0.5 * sin_a, cw * 0.5 * sin_a + ch * 0.5 * cos_a)
	var p4 := pos + Vector2(-cw * 0.5 * cos_a - ch * 0.5 * sin_a, -cw * 0.5 * sin_a + ch * 0.5 * cos_a)
	
	var card_pts := PackedVector2Array([p1, p2, p3, p4])
	
	# Card backing (dark obsidian ethereal parchment)
	draw_colored_polygon(card_pts, COLOR_TAROT_CARD)
	
	# Glowing celestial flame border
	var border_alpha: float = 0.7 + 0.3 * prog
	var border_col := Color(COLOR_TAROT_GLOW.r, COLOR_TAROT_GLOW.g, COLOR_TAROT_GLOW.b, border_alpha)
	draw_polyline(PackedVector2Array([p1, p2, p3, p4, p1]), border_col, 1.2)
	
	# Celestial occult rune glyph inside card
	var rune_col := Color(COLOR_TAROT_RUNE.r, COLOR_TAROT_RUNE.g, COLOR_TAROT_RUNE.b, 0.85 + 0.15 * prog)
	draw_circle(pos, 1.6, rune_col)
	draw_line(pos - Vector2(0, 3), pos + Vector2(0, 3), rune_col, 1.0)
	draw_line(pos - Vector2(2, 0), pos + Vector2(2, 0), rune_col, 1.0)


func _draw_heal_burst() -> void:
	var burst_t: float = 1.0 - (heal_pulse_timer / HEAL_PULSE_DURATION)
	var burst_r: float = lerpf(14.0, 52.0, burst_t)
	var burst_alpha: float = (1.0 - burst_t) * 0.85
	var center := Vector2(0.0, -22.0)
	
	# Radiant celestial shockwave
	draw_arc(center, burst_r, 0.0, TAU, 36, Color(0.7, 0.35, 1.0, burst_alpha), 3.0)
	draw_arc(center, burst_r * 0.7, 0.0, TAU, 28, Color(0.4, 0.9, 1.0, burst_alpha * 0.8), 2.0)
	
	# Dissipating tarot card energy rays
	for i in range(8):
		var ray_ang: float = float(i) * (TAU / 8.0) + (burst_t * 0.5)
		var p_start := center + Vector2(cos(ray_ang) * (burst_r * 0.4), sin(ray_ang) * (burst_r * 0.4))
		var p_end := center + Vector2(cos(ray_ang) * burst_r, sin(ray_ang) * burst_r)
		draw_line(p_start, p_end, Color(0.9, 0.7, 1.0, burst_alpha), 1.5)
