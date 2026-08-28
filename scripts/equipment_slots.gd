class_name EquipmentSlots
extends RefCounted

const WEAPON: StringName = &"weapon"
const HEAD: StringName = &"head"
const CHEST: StringName = &"chest"
const HANDS: StringName = &"hands"
const FEET: StringName = &"feet"
const RING: StringName = &"ring"
const AMULET: StringName = &"amulet"

const ALL: Array[StringName] = [
	WEAPON,
	HEAD,
	CHEST,
	HANDS,
	FEET,
	RING,
	AMULET,
]


static func is_valid(slot: StringName) -> bool:
	return ALL.has(slot)


static func get_display_name(slot: StringName) -> String:
	match slot:
		WEAPON:
			return "Weapon"
		HEAD:
			return "Head"
		CHEST:
			return "Chest"
		HANDS:
			return "Hands"
		FEET:
			return "Feet"
		RING:
			return "Ring"
		AMULET:
			return "Amulet"
		_:
			return "Unknown"
