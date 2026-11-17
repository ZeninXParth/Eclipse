class_name AncientChamber
extends RoomBase

## ECLIPSE: Echoes of the Forgotten
## Milestone 4: The Ancient Chamber Room Controller
## Manages the first boss encounter arena ("Archive Warden / Ancient Sentry"),
## encounter trigger detection, arena confinement gates (ArenaGate_West & ArenaGate_East),
## boss health bar HUD overlay, and PlayerData defeat persistence.

const ArchiveWardenScript = preload("res://scripts/bosses/archive_warden.gd")
const ArenaGateScript = preload("res://scripts/world/arena_gate.gd")
const BossHealthBarScript = preload("res://scripts/ui/boss_health_bar.gd")
const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const GameManagerScript = preload("res://scripts/core/game_manager.gd")

signal encounter_started()
signal boss_encounter_cleared()

@export_group("Encounter Arena Components")
@export var warden_boss: CharacterBody2D
@export var arena_gate_west: StaticBody2D
@export var arena_gate_east: StaticBody2D
@export var boss_health_bar: CanvasLayer
@export var encounter_trigger: Area2D

var is_boss_cleared: bool = false
var encounter_in_progress: bool = false


func _ready() -> void:
	room_id = "ancient_chamber"
	room_name = "The Ancient Chamber"
	
	super._ready()
	_setup_encounter_components()
	_check_persistence_state()


func _setup_encounter_components() -> void:
	if warden_boss == null:
		warden_boss = get_node_or_null("ArchiveWarden") as CharacterBody2D
	if arena_gate_west == null:
		arena_gate_west = get_node_or_null("ArenaGate_West") as StaticBody2D
	if arena_gate_east == null:
		arena_gate_east = get_node_or_null("ArenaGate_East") as StaticBody2D
	if boss_health_bar == null:
		boss_health_bar = get_node_or_null("BossHealthBar") as CanvasLayer
	if encounter_trigger == null:
		encounter_trigger = get_node_or_null("EncounterTrigger") as Area2D
	
	# Wire boss references to gates and health bar
	if warden_boss:
		warden_boss.arena_gate_west = arena_gate_west
		warden_boss.arena_gate_east = arena_gate_east
		warden_boss.boss_health_bar = boss_health_bar
		if not warden_boss.boss_defeated.is_connected(_on_boss_defeated):
			warden_boss.boss_defeated.connect(_on_boss_defeated)
	
	# Wire encounter trigger
	if encounter_trigger and not encounter_trigger.body_entered.is_connected(_on_encounter_trigger_body_entered):
		encounter_trigger.body_entered.connect(_on_encounter_trigger_body_entered)


func _get_player_data() -> PlayerData:
	if GameManagerScript.instance and GameManagerScript.instance.player_data:
		return GameManagerScript.instance.player_data
	return null


func _check_persistence_state() -> void:
	var pd := _get_player_data()
	var defeated := false
	if pd:
		defeated = bool(pd.get_flag("boss_warden_defeated", false))
	
	if defeated:
		mark_encounter_cleared_immediate()


func mark_encounter_cleared_immediate() -> void:
	is_boss_cleared = true
	encounter_in_progress = false
	
	# Ensure gates are open
	if arena_gate_west:
		arena_gate_west.open_gate(true)
	if arena_gate_east:
		arena_gate_east.open_gate(true)
	
	# Deactivate trigger
	if encounter_trigger:
		encounter_trigger.set_deferred("monitoring", false)
	
	# Deactivate / remove boss
	if warden_boss and is_instance_valid(warden_boss):
		warden_boss.is_dead = true
		warden_boss.hide()
		warden_boss.set_physics_process(false)
		if warden_boss.hitbox:
			warden_boss.hitbox.deactivate()
		if warden_boss.hurtbox:
			warden_boss.hurtbox.set_manual_invulnerable(true)


func _on_encounter_trigger_body_entered(body: Node2D) -> void:
	if is_boss_cleared or encounter_in_progress:
		return
	
	if body is CharacterBody2D and (body == player or body.is_in_group("player")):
		start_boss_encounter()


func start_boss_encounter() -> void:
	if is_boss_cleared or encounter_in_progress:
		return
	
	encounter_in_progress = true
	
	# Lock arena confinement gates
	if arena_gate_west:
		arena_gate_west.close_gate()
	if arena_gate_east:
		arena_gate_east.close_gate()
	
	# Start boss combat
	if warden_boss and is_instance_valid(warden_boss):
		warden_boss.start_encounter()
	
	encounter_started.emit()


func _on_boss_defeated() -> void:
	is_boss_cleared = true
	encounter_in_progress = false
	
	# Unlock arena confinement gates permanently
	if arena_gate_west:
		arena_gate_west.open_gate()
	if arena_gate_east:
		arena_gate_east.open_gate()
	
	if encounter_trigger:
		encounter_trigger.set_deferred("monitoring", false)
	
	# Persist flag
	var pd := _get_player_data()
	if pd:
		pd.set_story_flag("boss_warden_defeated", true)
		if GameManagerScript.instance:
			GameManagerScript.instance.save_game()
	
	boss_encounter_cleared.emit()


func respawn_enemies() -> void:
	super.respawn_enemies()
	if is_boss_cleared and warden_boss and is_instance_valid(warden_boss):
		warden_boss.is_dead = true
		warden_boss.hide()
		warden_boss.set_physics_process(false)
		if warden_boss.hitbox:
			warden_boss.hitbox.deactivate()
		if warden_boss.hurtbox:
			warden_boss.hurtbox.set_manual_invulnerable(true)
