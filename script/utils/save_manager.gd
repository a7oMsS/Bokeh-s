extends Node

const SAVE_PATH := "user://save.dat"

var _current_world_id := ""

func set_current_world(world_id: String) -> void:
	_current_world_id = world_id


func save_game() -> void:
	var save_data := _load_raw()  # partimos de lo existente — no pisamos otros mundos
	save_data["player"] = {}
	if not save_data.has("worlds"):
		save_data["worlds"] = {}

	for node in get_tree().get_nodes_in_group("saveable_player"):
		if node.has_method("get_save_data"):
			save_data["player"][node.name] = node.get_save_data()

	if _current_world_id != "":
		var world_data := {}
		for node in get_tree().get_nodes_in_group("saveable_world"):
			if node.has_method("get_save_data"):
				world_data[node.name] = node.get_save_data()
		save_data["worlds"][_current_world_id] = world_data

	_write_raw(save_data)


func load_game() -> void:
	var save_data := _load_raw()

	var player_data: Dictionary = save_data.get("player", {})
	for node in get_tree().get_nodes_in_group("saveable_player"):
		if player_data.has(node.name) and node.has_method("load_save_data"):
			node.load_save_data(player_data[node.name])

	if _current_world_id != "":
		var world_data: Dictionary = save_data.get("worlds", {}).get(_current_world_id, {})
		for node in get_tree().get_nodes_in_group("saveable_world"):
			if world_data.has(node.name) and node.has_method("load_save_data"):
				node.load_save_data(world_data[node.name])


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _load_raw() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: no se pudo abrir %s para lectura" % SAVE_PATH)
		return {}
	var data = file.get_var()
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _write_raw(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: no se pudo abrir %s para escritura" % SAVE_PATH)
		return
	file.store_var(data)
