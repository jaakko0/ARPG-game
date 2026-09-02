extends Node

const CURRENT_SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://savegame.json"
const TEMP_FILE_SUFFIX: String = ".tmp"
const BACKUP_FILE_SUFFIX: String = ".bak"

@export var save_path: String = DEFAULT_SAVE_PATH


func save_game(player_data: Dictionary) -> Dictionary:
	if player_data.is_empty():
		return _failure("Save Failed: Invalid Progression")

	var save_data := {
		"save_version": CURRENT_SAVE_VERSION,
		"player": player_data,
	}
	var temp_path := save_path + TEMP_FILE_SUFFIX
	var backup_path := save_path + BACKUP_FILE_SUFFIX

	if not _remove_file_if_present(temp_path):
		return _failure("Save Failed")

	var file := FileAccess.open(temp_path, FileAccess.WRITE)

	if file == null:
		return _failure("Save Failed")

	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()

	if write_error != OK:
		_remove_file_if_present(temp_path)
		return _failure("Save Failed")

	var active_save_existed := FileAccess.file_exists(save_path)

	if active_save_existed:
		if not _remove_file_if_present(backup_path):
			_remove_file_if_present(temp_path)
			return _failure("Save Failed")

		if not _rename_file(save_path, backup_path):
			_remove_file_if_present(temp_path)
			return _failure("Save Failed")

	if not _rename_file(temp_path, save_path):
		if active_save_existed:
			_rename_file(backup_path, save_path)

		_remove_file_if_present(temp_path)
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

	var version_result := _dispatch_save_version(save_data)

	if not version_result.get("success", false):
		return version_result

	var current_save_data: Dictionary = version_result.get("save_data", {})

	if (
		not current_save_data.has("player")
		or typeof(current_save_data["player"]) != TYPE_DICTIONARY
	):
		return _failure("Load Failed: Invalid Save")

	return {
		"success": true,
		"message": "Game Loaded",
		"player_data": current_save_data["player"],
	}


func get_absolute_save_path() -> String:
	return ProjectSettings.globalize_path(save_path)


func _dispatch_save_version(save_data: Dictionary) -> Dictionary:
	var save_version := int(save_data["save_version"])

	match save_version:
		CURRENT_SAVE_VERSION:
			return {
				"success": true,
				"save_data": save_data,
			}
		_:
			return _failure("Load Failed: Unsupported Save")


# When CURRENT_SAVE_VERSION increases, add the real v1 -> v2 migration here and
# call it from _dispatch_save_version. Current version 1 data needs no migration.


func _remove_file_if_present(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true

	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _rename_file(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	) == OK


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"message": message,
	}
