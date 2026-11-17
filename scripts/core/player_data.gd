class_name PlayerData
extends Resource

## ECLIPSE: Echoes of the Forgotten
## Milestone 3: Player Data Ledger & Serialization System (Hollow Knight Architecture)
## Flat serializable save data tracking health, soul, unlocked abilities,
## visited rooms, story flags, and respawn anchors.

@export var max_health: int = 5
@export var current_health: int = 5
@export var soul: int = 0
@export var max_soul: int = 99
@export var currency: int = 0
@export var mask_shards: int = 0
@export var unlocked_abilities: Array[String] = []
@export var collected_items: Array[String] = []
@export var visited_rooms: Array[String] = []
@export var story_flags: Dictionary = {}
@export var respawn_room_path: String = "res://scenes/levels/forgotten_entrance.tscn"
@export var respawn_gate_id: String = "Bench_Entrance"
@export var last_bench_id: String = "Bench_Entrance"

const DEFAULT_SAVE_PATH: String = "user://save_slot_1.res"


func _init() -> void:
	if unlocked_abilities == null:
		unlocked_abilities = []
	if collected_items == null:
		collected_items = []
	if visited_rooms == null:
		visited_rooms = []
	if story_flags == null:
		story_flags = {}


func save_to_file(path: String = DEFAULT_SAVE_PATH) -> Error:
	var dir := path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	if path.ends_with(".json"):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		var json_str := JSON.stringify(to_dict(), "\t")
		file.store_string(json_str)
		file.close()
		return OK
	var err := ResourceSaver.save(self, path)
	return err


static func load_from_file(path: String = DEFAULT_SAVE_PATH) -> Resource:
	var script: GDScript = load("res://scripts/core/player_data.gd")
	var instance = script.new()
	if path.ends_with(".json"):
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var json_str := file.get_as_text()
				file.close()
				var parsed = JSON.parse_string(json_str)
				if parsed is Dictionary:
					instance.from_dict(parsed)
					return instance
		return instance
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res != null and (res is PlayerData or res.get_script() == script):
			return res
	return instance


func has_ability(ability: String) -> bool:
	return unlocked_abilities.has(ability)


func unlock_ability(ability: String) -> void:
	if not unlocked_abilities.has(ability):
		unlocked_abilities.append(ability)


func add_currency(amount: int) -> void:
	currency = clampi(currency + amount, 0, 999999)


func spend_currency(amount: int) -> bool:
	if amount <= 0:
		return true
	if currency >= amount:
		currency -= amount
		return true
	return false


func add_mask_shard() -> bool:
	mask_shards += 1
	if mask_shards >= 4:
		mask_shards = 0
		max_health += 1
		current_health = max_health
		return true
	return false


func add_collectible(item_id: String) -> void:
	if not collected_items.has(item_id):
		collected_items.append(item_id)


func has_collectible(item_id: String) -> bool:
	return collected_items.has(item_id)


func mark_room_visited(room_path: String) -> void:
	if not visited_rooms.has(room_path):
		visited_rooms.append(room_path)


func is_room_visited(room_path: String) -> bool:
	return visited_rooms.has(room_path)


func set_flag(key: String, value: Variant) -> void:
	story_flags[key] = value


func get_flag(key: String, default_value: Variant = null) -> Variant:
	return story_flags.get(key, default_value)


func set_story_flag(key: String, value: Variant) -> void:
	set_flag(key, value)


func get_story_flag(key: String, default_value: Variant = null) -> Variant:
	return get_flag(key, default_value)


func has_story_flag(key: String) -> bool:
	return story_flags.has(key)


func set_bench_checkpoint(bench_id: String, room_path: String) -> void:
	last_bench_id = bench_id
	respawn_gate_id = bench_id
	if not room_path.is_empty():
		respawn_room_path = room_path


func sync_from_player(player: CharacterBody2D) -> void:
	if player == null:
		return
	if player.has_method("get_max_health"):
		max_health = player.call("get_max_health")
	if player.has_method("get_current_health"):
		current_health = player.call("get_current_health")
	if player.has_method("get_current_soul"):
		soul = player.call("get_current_soul")
	if player.has_method("get_max_soul"):
		max_soul = player.call("get_max_soul")


func sync_to_player(player: CharacterBody2D) -> void:
	if player == null:
		return
	if player.get("health_component") != null:
		var hc = player.get("health_component")
		hc.max_health = max_health
		hc.current_health = current_health
	if "current_soul" in player:
		player.set("current_soul", soul)
		if player.has_signal("soul_changed"):
			player.emit_signal("soul_changed", soul, max_soul)
	if "double_jump_unlocked" in player:
		player.set("double_jump_unlocked", has_ability("double_jump"))
	if "mantle_unlocked" in player:
		player.set("mantle_unlocked", has_ability("mantle"))


func to_dict() -> Dictionary:
	return {
		"max_health": max_health,
		"current_health": current_health,
		"soul": soul,
		"max_soul": max_soul,
		"currency": currency,
		"mask_shards": mask_shards,
		"unlocked_abilities": unlocked_abilities.duplicate(),
		"collected_items": collected_items.duplicate(),
		"visited_rooms": visited_rooms.duplicate(),
		"story_flags": story_flags.duplicate(),
		"respawn_room_path": respawn_room_path,
		"respawn_gate_id": respawn_gate_id,
		"last_bench_id": last_bench_id
	}


func from_dict(data: Dictionary) -> void:
	if data.has("max_health"):
		var mh = data["max_health"]
		if mh is int or mh is float:
			max_health = clampi(int(mh), 1, 99)
		elif mh is String and (mh as String).is_valid_int():
			max_health = clampi((mh as String).to_int(), 1, 99)
		else:
			max_health = 5
	else:
		max_health = 5

	if data.has("current_health"):
		var ch = data["current_health"]
		if ch is int or ch is float:
			current_health = clampi(int(ch), 0, max_health)
		elif ch is String and (ch as String).is_valid_int():
			current_health = clampi((ch as String).to_int(), 0, max_health)
		else:
			current_health = max_health
	else:
		current_health = max_health

	if data.has("max_soul"):
		var ms = data["max_soul"]
		if ms is int or ms is float:
			max_soul = clampi(int(ms), 1, 999)
		elif ms is String and (ms as String).is_valid_int():
			max_soul = clampi((ms as String).to_int(), 1, 999)
		else:
			max_soul = 99
	else:
		max_soul = 99

	if data.has("soul"):
		var s = data["soul"]
		if s is int or s is float:
			soul = clampi(int(s), 0, max_soul)
		elif s is String and (s as String).is_valid_int():
			soul = clampi((s as String).to_int(), 0, max_soul)
		else:
			soul = 0
	else:
		soul = 0

	if data.has("currency"):
		var cur = data["currency"]
		if cur is int or cur is float:
			currency = clampi(int(cur), 0, 999999)
		elif cur is String and (cur as String).is_valid_int():
			currency = clampi((cur as String).to_int(), 0, 999999)
		else:
			currency = 0
	else:
		currency = 0

	if data.has("mask_shards"):
		var ms_shards = data["mask_shards"]
		if ms_shards is int or ms_shards is float:
			mask_shards = clampi(int(ms_shards), 0, 3)
		elif ms_shards is String and (ms_shards as String).is_valid_int():
			mask_shards = clampi((ms_shards as String).to_int(), 0, 3)
		else:
			mask_shards = 0
	else:
		mask_shards = 0

	unlocked_abilities.clear()
	var raw_abilities = data.get("unlocked_abilities", [])
	if raw_abilities is Array:
		for a in raw_abilities:
			var s_ab := str(a).strip_edges()
			if not s_ab.is_empty() and not unlocked_abilities.has(s_ab):
				unlocked_abilities.append(s_ab)

	collected_items.clear()
	var raw_items = data.get("collected_items", [])
	if raw_items is Array:
		for it in raw_items:
			var s_it := str(it).strip_edges()
			if not s_it.is_empty() and not collected_items.has(s_it):
				collected_items.append(s_it)

	visited_rooms.clear()
	var raw_rooms = data.get("visited_rooms", [])
	if raw_rooms is Array:
		for r in raw_rooms:
			var s_rm := str(r).strip_edges()
			if not s_rm.is_empty() and not visited_rooms.has(s_rm):
				visited_rooms.append(s_rm)

	var raw_flags = data.get("story_flags", {})
	if raw_flags is Dictionary:
		story_flags = raw_flags.duplicate()
	else:
		story_flags = {}

	var raw_room_path = str(data.get("respawn_room_path", "")).strip_edges()
	respawn_room_path = raw_room_path if not raw_room_path.is_empty() else "res://scenes/levels/forgotten_entrance.tscn"

	var raw_gate_id = str(data.get("respawn_gate_id", "")).strip_edges()
	respawn_gate_id = raw_gate_id if not raw_gate_id.is_empty() else "Bench_Entrance"

	var raw_bench_id = str(data.get("last_bench_id", "")).strip_edges()
	last_bench_id = raw_bench_id if not raw_bench_id.is_empty() else "Bench_Entrance"
