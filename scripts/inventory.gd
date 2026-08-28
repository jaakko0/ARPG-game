extends Node

signal inventory_updated

@export_range(1, 100, 1) var capacity: int = 20

var item_ids: Array[StringName] = []


func add_item(item_id: StringName) -> bool:
	if item_id.is_empty() or is_full():
		return false

	item_ids.append(item_id)
	inventory_updated.emit()
	return true


func remove_item(item_id: StringName) -> bool:
	var item_index := item_ids.find(item_id)

	if item_index < 0:
		return false

	remove_item_at(item_index)
	return true


func remove_item_at(item_index: int) -> StringName:
	if item_index < 0 or item_index >= item_ids.size():
		return &""

	var removed_item_id := item_ids[item_index]
	item_ids.remove_at(item_index)
	inventory_updated.emit()
	return removed_item_id


func get_item_id_at(item_index: int) -> StringName:
	if item_index < 0 or item_index >= item_ids.size():
		return &""

	return item_ids[item_index]


func get_item_ids() -> Array[StringName]:
	return item_ids.duplicate()


func get_item_id_strings() -> Array[String]:
	var saved_item_ids: Array[String] = []

	for item_id in item_ids:
		saved_item_ids.append(String(item_id))

	return saved_item_ids


func get_item_count() -> int:
	return item_ids.size()


func is_full() -> bool:
	return item_ids.size() >= capacity


func restore_item_ids(saved_item_ids: Array[StringName]) -> void:
	item_ids.clear()

	for item_id in saved_item_ids:
		if item_ids.size() >= capacity:
			break

		if not item_id.is_empty():
			item_ids.append(item_id)

	inventory_updated.emit()
