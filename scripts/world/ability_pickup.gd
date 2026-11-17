class_name AbilityPickup
extends Area2D

## ECLIPSE: Echoes of the Forgotten
## Milestone 5: Ability Pickup & Collectible Altar
## Interconnected world interactable that permanently grants abilities,
## mask shards, currency caches, or relics with persistence tracking.

const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const GameManagerScript = preload("res://scripts/core/game_manager.gd")

signal collected(pickup_id: String, pickup_type: PickupType)

enum PickupType {
	ABILITY,
	MASK_SHARD,
	CURRENCY,
	RELIC
}

@export_group("Pickup Identity")
@export var pickup_id: String = "ability_double_jump"
@export var pickup_type: PickupType = PickupType.ABILITY
@export var ability_name: String = "double_jump"
@export var display_name: String = "Wings of the Lunar Eclipse"
@export_multiline var description_text: String = "Press Jump while airborne to unfurl spectral lunar wings and ascend anew."
@export var currency_value: int = 50
@export var auto_collect_on_touch: bool = true

@export_group("Visuals & Audio")
@export var altar_color: Color = Color(0.12, 0.13, 0.18, 1.0)
@export var rune_color: Color = Color(0.38, 0.90, 1.0, 1.0)
@export var glow_color: Color = Color(0.65, 0.25, 0.95, 0.85)

var is_collected: bool = false
var anim_time: float = 0.0
var collection_fade: float = 1.0
var is_fading: bool = false


func _init() -> void:
	collision_layer = 256 # Layer 9 = Interactables
	collision_mask = 2   # Layer 2 = Player


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_READY:
		_check_initial_persistence()


func _ready() -> void:
	collision_layer = 256 # Layer 9 = Interactables
	collision_mask = 2   # Layer 2 = Player
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Check if already collected in persistent story flags or abilities
	_check_initial_persistence()


func _check_initial_persistence() -> void:
	var pd := _get_player_data()
	if pd:
		var flag_key := "collected_" + pickup_id
		if pd.has_story_flag(flag_key) and bool(pd.get_story_flag(flag_key)):
			_mark_already_collected()
		elif pickup_type == PickupType.ABILITY and pd.has_ability(ability_name):
			_mark_already_collected()


func _mark_already_collected() -> void:
	is_collected = true
	monitoring = false
	monitorable = false
	hide()


func _get_player_data() -> PlayerData:
	if GameManagerScript.instance and GameManagerScript.instance.player_data:
		return GameManagerScript.instance.player_data
	return null


func _process(delta: float) -> void:
	if is_collected and not is_fading:
		return
	
	anim_time += delta
	
	if is_fading:
		collection_fade = maxf(0.0, collection_fade - delta * 3.0)
		if collection_fade <= 0.0:
			is_fading = false
			hide()
			monitoring = false
			monitorable = false
	
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if is_collected or is_fading:
		return
	
	if body is CharacterBody2D and (body.is_in_group("player") or body.get("name") == "Player" or body.has_method("reset_to_spawn")):
		if auto_collect_on_touch:
			execute_collection(body)


func execute_collection(player_node: CharacterBody2D = null) -> void:
	if is_collected:
		return
	
	is_collected = true
	is_fading = true
	
	var pd := _get_player_data()
	
	# Process reward based on type
	match pickup_type:
		PickupType.ABILITY:
			if pd:
				pd.unlock_ability(ability_name)
			if player_node:
				if ability_name == "double_jump" and "double_jump_unlocked" in player_node:
					player_node.set("double_jump_unlocked", true)
				elif ability_name == "mantle" and "mantle_unlocked" in player_node:
					player_node.set("mantle_unlocked", true)
				elif ability_name == "dash" and "dash_unlocked" in player_node:
					player_node.set("dash_unlocked", true)
				elif ability_name == "wall_jump" and "wall_jump_unlocked" in player_node:
					player_node.set("wall_jump_unlocked", true)
		
		PickupType.MASK_SHARD:
			if pd:
				var upgraded = pd.add_mask_shard()
				if upgraded and player_node and player_node.has_method("restore_health"):
					player_node.call("restore_health", -1)
		
		PickupType.CURRENCY:
			if pd:
				pd.add_currency(currency_value)
		
		PickupType.RELIC:
			if pd:
				pd.add_collectible(pickup_id)
	
	# Record persistent story flag
	if pd:
		pd.set_story_flag("collected_" + pickup_id, true)
	
	# Dispatch signals and hit stop
	collected.emit(pickup_id, pickup_type)
	if player_node and player_node.has_method("trigger_hit_stop"):
		player_node.call("trigger_hit_stop", 0.12)


func _draw() -> void:
	if is_collected and not is_fading:
		return
	
	var alpha: float = collection_fade
	
	# 1. Altar Pedestal
	var ped_color := Color(altar_color.r, altar_color.g, altar_color.b, alpha)
	var ped_trim := Color(0.35, 0.38, 0.48, alpha)
	
	# Base steps
	draw_rect(Rect2(-24, 0, 48, 14), ped_color)
	draw_rect(Rect2(-24, 0, 48, 3), ped_trim)
	draw_rect(Rect2(-18, -12, 36, 12), ped_color)
	draw_rect(Rect2(-18, -12, 36, 3), ped_trim)
	
	# Glowing runic carvings on pedestal
	var runic_pulse := 0.6 + 0.4 * sin(anim_time * 2.5)
	var rune_col := Color(rune_color.r, rune_color.g, rune_color.b, alpha * runic_pulse)
	draw_line(Vector2(-12, -6), Vector2(12, -6), rune_col, 1.5)
	draw_circle(Vector2(0, -6), 2.5, rune_col)
	
	# 2. Hovering Sigil / Relic
	var bob_y: float = -28.0 + sin(anim_time * 3.0) * 4.0
	var sigil_center := Vector2(0.0, bob_y)
	
	# Radial aura
	var aura_pulse := 0.7 + 0.3 * cos(anim_time * 3.5)
	var cur_glow := Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * alpha * aura_pulse)
	draw_circle(sigil_center, 16.0, Color(cur_glow.r, cur_glow.g, cur_glow.b, 0.15 * alpha))
	draw_circle(sigil_center, 10.0, Color(cur_glow.r, cur_glow.g, cur_glow.b, 0.30 * alpha))
	
	# Distinct symbol based on pickup type
	match pickup_type:
		PickupType.ABILITY:
			# Lunar Crescent Wings Emblem
			var c_points := PackedVector2Array([
				sigil_center + Vector2(-12, -6),
				sigil_center + Vector2(-6, -14),
				sigil_center + Vector2(0, -8),
				sigil_center + Vector2(6, -14),
				sigil_center + Vector2(12, -6),
				sigil_center + Vector2(6, 4),
				sigil_center + Vector2(0, 10),
				sigil_center + Vector2(-6, 4)
			])
			draw_polyline(c_points, rune_col, 2.0)
			draw_circle(sigil_center, 3.5, Color(1.0, 1.0, 1.0, alpha))
		
		PickupType.MASK_SHARD:
			# Ancient Mask Fragment Diamond
			var d_points := PackedVector2Array([
				sigil_center + Vector2(0, -12),
				sigil_center + Vector2(10, 0),
				sigil_center + Vector2(0, 12),
				sigil_center + Vector2(-10, 0),
				sigil_center + Vector2(0, -12)
			])
			draw_polyline(d_points, Color(0.95, 0.85, 0.40, alpha), 2.0)
			draw_circle(sigil_center, 2.0, Color(1.0, 1.0, 1.0, alpha))
		
		PickupType.CURRENCY:
			# Stygian Shard Crystal
			var s_points := PackedVector2Array([
				sigil_center + Vector2(0, -10),
				sigil_center + Vector2(6, -3),
				sigil_center + Vector2(4, 9),
				sigil_center + Vector2(-4, 9),
				sigil_center + Vector2(-6, -3),
				sigil_center + Vector2(0, -10)
			])
			draw_polyline(s_points, Color(0.40, 0.85, 1.0, alpha), 2.0)
		
		PickupType.RELIC:
			# Occult Sigil Ring
			draw_arc(sigil_center, 9.0, 0.0, TAU, 16, rune_col, 2.0)
			draw_line(sigil_center - Vector2(6, 0), sigil_center + Vector2(6, 0), rune_col, 1.5)
			draw_line(sigil_center - Vector2(0, 6), sigil_center + Vector2(0, 6), rune_col, 1.5)
