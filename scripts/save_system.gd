extends Node

const CURRENT_SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://savegame.json"

@export var save_path: String = DEFAULT_SAVE_PATH


func save_game(player_data: Dictionary) -> Dictionary:
	if not _is_valid_player_data(player_data):
		return _failure("Save Failed: Invalid Progression")

	var save_data := {
		"save_version": CURRENT_SAVE_VERSION,
		"player": player_data,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		return _failure("Save Failed")

	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()

	if write_error != OK:
		return _failure("Save Failed")

	return {
		"success": true,
		"message": "Game Saved",
	}


func load_game() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return _failure("No Save Found")

	var file := FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		return _failure("Load Failed")

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()

	if json.parse(json_text) != OK:
		return _failure("Load Failed: Invalid Save")

	var save_data: Variant = json.data

	if typeof(save_data) != TYPE_DICTIONARY:
		return _failure("Load Failed: Invalid Save")

	if not save_data.has("save_version") or not _is_number(save_data["save_version"]):
		return _failure("Load Failed: Invalid Save")

	if int(save_data["save_version"]) != CURRENT_SAVE_VERSION:
		return _failure("Load Failed: Unsupported Save")

	if not save_data.has("player") or not _is_valid_player_data(save_data["player"]):
		return _failure("Load Failed: Invalid Save")

	return {
		"success": true,
		"message": "Game Loaded",
		"player_data": save_data["player"],
	}


func get_absolute_save_path() -> String:
	return ProjectSettings.globalize_path(save_path)


func _is_valid_player_data(player_data: Variant) -> bool:
	if typeof(player_data) != TYPE_DICTIONARY:
		return false

	for key in ["level", "current_xp", "gold"]:
		if not player_data.has(key) or not _is_number(player_data[key]):
			return false

	if int(player_data["level"]) < 1:
		return false

	if int(player_data["current_xp"]) < 0 or int(player_data["gold"]) < 0:
		return false

	if not player_data.has("attributes"):
		return false

	var attribute_data: Variant = player_data["attributes"]

	if typeof(attribute_data) != TYPE_DICTIONARY:
		return false

	for key in [
		"strength",
		"dexterity",
		"intelligence",
		"vitality",
		"unspent_points",
	]:
		if not attribute_data.has(key) or not _is_number(attribute_data[key]):
			return false

		if int(attribute_data[key]) < 0:
			return false

	if player_data.has("equipment"):
		var equipment_data: Variant = player_data["equipment"]

		if typeof(equipment_data) != TYPE_DICTIONARY:
			return false

		for slot_key in equipment_data:
			if (
				typeof(slot_key) != TYPE_STRING
				and typeof(slot_key) != TYPE_STRING_NAME
			):
				return false

			var item_id: Variant = equipment_data[slot_key]

			if typeof(item_id) != TYPE_STRING and typeof(item_id) != TYPE_STRING_NAME:
				return false

	return true


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"message": message,
	}
