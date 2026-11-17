class_name HazardZone
extends Area2D

## ECLIPSE: Echoes of the Forgotten
## Environmental hazard (e.g. spikes) dealing damage to players and supporting pogo down-slash bounces.

const HitDataScript = preload("res://scripts/combat/hit_data.gd")
const HurtboxScript = preload("res://scripts/combat/hurtbox.gd")

@export var damage: int = 1
@export var allows_pogo: bool = true
@export var knockback_force: float = 300.0


func _ready() -> void:
	collision_layer = 128 # Layer 8: Hazards
	collision_mask = 16 | 8 # Layer 5: PlayerHurtbox | Layer 4: PlayerHitbox
	add_to_group("pogo_hazard")
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	for area in get_overlapping_areas():
		if area is HurtboxScript and area.is_player_hurtbox:
			if area.can_receive_hit():
				_damage_player_hurtbox(area)


func is_pogo_hazard() -> bool:
	return allows_pogo


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxScript and area.is_player_hurtbox:
		if area.can_receive_hit():
			_damage_player_hurtbox(area)


func _damage_player_hurtbox(area: Area2D) -> void:
	var kb_dir := Vector2.UP
	var hit_data = HitDataScript.new(
		damage,
		kb_dir,
		knockback_force,
		self,
		kb_dir,
		false
	)
	area.receive_hit(hit_data)
