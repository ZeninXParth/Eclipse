class_name CelestialSanctuary
extends RoomBase

## ECLIPSE: Echoes of the Forgotten
## Milestone 5: The Celestial Sanctuary
## Serene gothic oasis past the Ancient Chamber. Houses the Bench_Sanctuary checkpoint,
## the Altar of the Lunar Wings (Double Jump ability pickup), and an ability-gated
## upper gallery sheltering a secret Mask Shard collectible.

const AbilityPickupScript = preload("res://scripts/world/ability_pickup.gd")
const BenchCheckpointScript = preload("res://scripts/world/bench_checkpoint.gd")

@export_group("Sanctuary Components")
@export var bench: Node2D
@export var wings_pickup: AbilityPickup
@export var mask_shard_pickup: AbilityPickup


func _ready() -> void:
	room_id = "celestial_sanctuary"
	room_name = "The Celestial Sanctuary"
	limit_left = -100
	limit_right = 1600
	limit_top = -200
	limit_bottom = 800
	respawn_y_threshold = 900.0
	default_spawn_point = Vector2(160, 520)
	
	super._ready()
	_setup_sanctuary_references()


func _setup_sanctuary_references() -> void:
	if bench == null:
		bench = get_node_or_null("Bench_Sanctuary")
	if wings_pickup == null:
		wings_pickup = get_node_or_null("AbilityPickup_Wings") as AbilityPickup
	if mask_shard_pickup == null:
		mask_shard_pickup = get_node_or_null("AbilityPickup_MaskShard") as AbilityPickup
