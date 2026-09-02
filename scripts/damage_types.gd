class_name DamageTypes
extends RefCounted

const PHYSICAL: StringName = &"physical"
const FIRE: StringName = &"fire"
const LIGHTNING: StringName = &"lightning"


static func get_supported_types() -> Array[StringName]:
	return [PHYSICAL, FIRE, LIGHTNING]


static func is_valid(damage_type: StringName) -> bool:
	return (
		damage_type == PHYSICAL
		or damage_type == FIRE
		or damage_type == LIGHTNING
	)


static func normalize(damage_type: StringName) -> StringName:
	if is_valid(damage_type):
		return damage_type

	return PHYSICAL
