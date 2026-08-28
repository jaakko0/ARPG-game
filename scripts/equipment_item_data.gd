class_name EquipmentItemData
extends Resource

const EquipmentSlots = preload("res://scripts/equipment_slots.gd")

@export var item_id: StringName
@export var display_name: String
@export var slot: StringName = EquipmentSlots.WEAPON
@export_range(0, 1000, 1) var strength_bonus: int = 0
@export_range(0, 1000, 1) var dexterity_bonus: int = 0
@export_range(0, 1000, 1) var intelligence_bonus: int = 0
@export_range(0, 1000, 1) var vitality_bonus: int = 0


func is_valid_item() -> bool:
	return not item_id.is_empty() and not display_name.is_empty() and EquipmentSlots.is_valid(slot)


func get_attribute_bonus(attribute_name: StringName) -> int:
	match attribute_name:
		&"strength":
			return strength_bonus
		&"dexterity":
			return dexterity_bonus
		&"intelligence":
			return intelligence_bonus
		&"vitality":
			return vitality_bonus
		_:
			return 0
