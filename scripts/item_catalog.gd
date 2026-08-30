class_name ItemCatalog
extends Resource

const EquipmentItemData = preload("res://scripts/equipment_item_data.gd")

@export var items: Array[EquipmentItemData] = []
@export var default_equipment_drop_pool: Array[EquipmentItemData] = []

var _items_by_id: Dictionary = {}
var _valid_items: Array[EquipmentItemData] = []
var _valid_default_drop_pool: Array[EquipmentItemData] = []
var _validation_errors: PackedStringArray = PackedStringArray()
var _index_built: bool = false
var _errors_reported: bool = false


func get_item_by_id(item_id: StringName) -> EquipmentItemData:
	if item_id.is_empty():
		return null

	_ensure_index()
	return _items_by_id.get(item_id) as EquipmentItemData


func get_all_items() -> Array[EquipmentItemData]:
	_ensure_index()
	return _valid_items.duplicate()


func get_default_equipment_drop_pool() -> Array[EquipmentItemData]:
	_ensure_index()
	return _valid_default_drop_pool.duplicate()


func get_validation_errors() -> PackedStringArray:
	_ensure_index()
	return _validation_errors.duplicate()


func is_valid_catalog() -> bool:
	return get_validation_errors().is_empty()


func report_validation_errors() -> void:
	_ensure_index()

	if _errors_reported:
		return

	_errors_reported = true

	for validation_error in _validation_errors:
		push_error("ItemCatalog: %s" % validation_error)


func _ensure_index() -> void:
	if _index_built:
		return

	_index_built = true
	_items_by_id.clear()
	_valid_items.clear()
	_valid_default_drop_pool.clear()
	_validation_errors.clear()

	for item in items:
		if item == null:
			_validation_errors.append("Catalog contains an empty item entry.")
			continue

		if not item.is_valid_item():
			_validation_errors.append("Catalog contains an invalid item definition.")
			continue

		if _items_by_id.has(item.item_id):
			_validation_errors.append(
				"Duplicate item ID '%s'; the first definition is kept." % item.item_id
			)
			continue

		_items_by_id[item.item_id] = item
		_valid_items.append(item)

	var default_pool_ids: Dictionary = {}

	for pool_item in default_equipment_drop_pool:
		if pool_item == null or not pool_item.is_valid_item():
			_validation_errors.append("Default drop pool contains an invalid item.")
			continue

		var authoritative_item := _items_by_id.get(pool_item.item_id) as EquipmentItemData

		if authoritative_item == null:
			_validation_errors.append(
				"Default drop pool contains unknown item ID '%s'." % pool_item.item_id
			)
			continue

		if default_pool_ids.has(pool_item.item_id):
			_validation_errors.append(
				"Default drop pool contains duplicate item ID '%s'." % pool_item.item_id
			)
			continue

		default_pool_ids[pool_item.item_id] = true
		_valid_default_drop_pool.append(authoritative_item)
