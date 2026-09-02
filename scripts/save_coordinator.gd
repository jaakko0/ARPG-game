extends Node

var player: Node
var save_system: Node
var experience: Node
var attributes: Node
var inventory: Node
var equipment: Node


func setup(
	player_node: Node,
	save_system_component: Node,
	experience_component: Node,
	attribute_component: Node,
	inventory_component: Node,
	equipment_component: Node
) -> void:
	player = player_node
	save_system = save_system_component
	experience = experience_component
	attributes = attribute_component
	inventory = inventory_component
	equipment = equipment_component


func save_progression() -> Dictionary:
	if not _has_dependencies():
		return _failure("Save Failed")

	var player_data := build_current_player_data()

	if not _prepare_player_data(player_data).get("success", false):
		return _failure("Save Failed: Invalid Progression")

	return save_system.call("save_game", player_data)


func load_progression() -> Dictionary:
	if not _has_dependencies():
		return _failure("Load Failed")

	var result: Dictionary = save_system.call("load_game")

	if not result.get("success", false):
		return result

	if not apply_player_data(result.get("player_data", {})):
		return _failure("Load Failed: Invalid Progression")

	return {
		"success": true,
		"message": result.get("message", "Game Loaded"),
	}


func build_current_player_data() -> Dictionary:
	if not _has_dependencies():
		return {}

	return {
		"level": experience.get("current_level"),
		"current_xp": experience.get("current_experience"),
		"gold": player.call("get_gold"),
		"attributes": {
			"strength": attributes.get("strength"),
			"dexterity": attributes.get("dexterity"),
			"intelligence": attributes.get("intelligence"),
			"vitality": attributes.get("vitality"),
			"unspent_points": attributes.get("unspent_points"),
		},
		"equipment": equipment.call("get_equipped_item_ids"),
		"inventory": inventory.call("get_item_id_strings"),
	}


func apply_player_data(player_data: Variant) -> bool:
	if not _has_dependencies():
		return false

	var prepared_data := _prepare_player_data(player_data)

	if not prepared_data.get("success", false):
		return false

	# All sections are validated and normalized before active state is touched.
	player.call("set_progression_restore_active", true)

	if not experience.call(
		"restore_progress",
		prepared_data["level"],
		prepared_data["current_xp"]
	):
		player.call("set_progression_restore_active", false)
		return false

	if not attributes.call(
		"restore_values",
		prepared_data["strength"],
		prepared_data["dexterity"],
		prepared_data["intelligence"],
		prepared_data["vitality"],
		prepared_data["unspent_points"]
	):
		player.call("set_progression_restore_active", false)
		return false

	equipment.call("restore_equipment", prepared_data["equipment"])
	inventory.call("restore_item_ids", prepared_data["inventory"])
	player.call("restore_saved_gold", prepared_data["gold"])
	player.call("complete_progression_restore")
	return true


func _prepare_player_data(player_data: Variant) -> Dictionary:
	if typeof(player_data) != TYPE_DICTIONARY:
		return _invalid_data()

	var level_value: Variant = player_data.get("level")
	var experience_value: Variant = player_data.get("current_xp")
	var gold_value: Variant = player_data.get("gold")

	if (
		not _is_number(level_value)
		or not _is_number(experience_value)
		or not _is_number(gold_value)
	):
		return _invalid_data()

	var saved_level := int(level_value)
	var saved_experience := int(experience_value)
	var saved_gold := int(gold_value)
	var experience_required: int = experience.call(
		"get_experience_required_for_level",
		saved_level
	)

	if (
		saved_level < 1
		or saved_experience < 0
		or saved_experience >= experience_required
		or saved_gold < 0
	):
		return _invalid_data()

	var attribute_data: Variant = player_data.get("attributes")

	if typeof(attribute_data) != TYPE_DICTIONARY:
		return _invalid_data()

	var attribute_keys := [
		"strength",
		"dexterity",
		"intelligence",
		"vitality",
		"unspent_points",
	]
	var normalized_attributes: Dictionary = {}

	for key in attribute_keys:
		var value: Variant = attribute_data.get(key)

		if not _is_number(value) or int(value) < 0:
			return _invalid_data()

		normalized_attributes[key] = int(value)

	var inventory_data: Variant = player_data.get("inventory", [])

	if typeof(inventory_data) != TYPE_ARRAY:
		return _invalid_data()

	var normalized_inventory: Array[StringName] = []

	for item_id_value in inventory_data:
		if not _is_string(item_id_value):
			return _invalid_data()

		var item_id := StringName(item_id_value)

		if equipment.call("get_item_by_id", item_id) != null:
			normalized_inventory.append(item_id)

	var equipment_data: Variant = player_data.get("equipment", {})

	if typeof(equipment_data) != TYPE_DICTIONARY:
		return _invalid_data()

	var normalized_equipment: Dictionary = {}

	for slot_key_value in equipment_data:
		if not _is_string(slot_key_value):
			return _invalid_data()

		var item_id_value: Variant = equipment_data[slot_key_value]

		if not _is_string(item_id_value):
			return _invalid_data()

		var item_id := StringName(item_id_value)

		if equipment.call("get_item_by_id", item_id) != null:
			normalized_equipment[String(slot_key_value)] = String(item_id)

	return {
		"success": true,
		"level": saved_level,
		"current_xp": saved_experience,
		"gold": saved_gold,
		"strength": normalized_attributes["strength"],
		"dexterity": normalized_attributes["dexterity"],
		"intelligence": normalized_attributes["intelligence"],
		"vitality": normalized_attributes["vitality"],
		"unspent_points": normalized_attributes["unspent_points"],
		"inventory": normalized_inventory,
		"equipment": normalized_equipment,
	}


func _has_dependencies() -> bool:
	return (
		is_instance_valid(player)
		and is_instance_valid(save_system)
		and is_instance_valid(experience)
		and is_instance_valid(attributes)
		and is_instance_valid(inventory)
		and is_instance_valid(equipment)
	)


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _is_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME


func _invalid_data() -> Dictionary:
	return {"success": false}


func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"message": message,
	}
