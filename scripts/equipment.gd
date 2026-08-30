extends Node

const EquipmentItemData = preload("res://scripts/equipment_item_data.gd")
const EquipmentSlots = preload("res://scripts/equipment_slots.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")

signal equipment_updated

@export var item_catalog: ItemCatalog

var equipped_items: Dictionary = {}


func _ready() -> void:
	if item_catalog == null:
		push_error("Equipment requires an ItemCatalog resource.")
		return

	item_catalog.report_validation_errors()


func equip(item: EquipmentItemData) -> bool:
	if item == null or not item.is_valid_item():
		return false

	equipped_items[item.slot] = item
	equipment_updated.emit()
	return true


func equip_by_id(item_id: StringName) -> bool:
	return equip(get_item_by_id(item_id))


func unequip(slot: StringName) -> EquipmentItemData:
	if not EquipmentSlots.is_valid(slot):
		return null

	var previous_item := get_equipped_item(slot)

	if previous_item == null:
		return null

	equipped_items.erase(slot)
	equipment_updated.emit()
	return previous_item


func get_equipped_item(slot: StringName) -> EquipmentItemData:
	return equipped_items.get(slot) as EquipmentItemData


func get_item_by_id(item_id: StringName) -> EquipmentItemData:
	if item_catalog == null:
		return null

	return item_catalog.get_item_by_id(item_id)


func get_total_attribute_bonus(attribute_name: StringName) -> int:
	var total_bonus := 0

	for item_value in equipped_items.values():
		var item := item_value as EquipmentItemData

		if item != null:
			total_bonus += item.get_attribute_bonus(attribute_name)

	return total_bonus


func get_equipped_item_ids() -> Dictionary:
	var equipped_ids := {}

	for slot in EquipmentSlots.ALL:
		var item := get_equipped_item(slot)

		if item != null:
			equipped_ids[String(slot)] = String(item.item_id)

	return equipped_ids


func restore_equipment(equipment_ids: Dictionary) -> void:
	equipped_items.clear()

	for slot in EquipmentSlots.ALL:
		var item_id := StringName(equipment_ids.get(String(slot), ""))
		var item := get_item_by_id(item_id)

		if item != null and item.slot == slot:
			equipped_items[slot] = item

	equipment_updated.emit()
