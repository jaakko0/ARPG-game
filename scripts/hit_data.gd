class_name HitData
extends RefCounted

const DamageTypes = preload("res://scripts/damage_types.gd")

var amount: int = 0
var source: Node
var hit_direction: Vector2 = Vector2.ZERO
var damage_type: StringName = DamageTypes.PHYSICAL
var tags: Array[StringName] = []
var is_critical: bool = false


func _init(
	new_amount: int = 0,
	new_source: Node = null,
	new_hit_direction: Vector2 = Vector2.ZERO,
	new_damage_type: StringName = DamageTypes.PHYSICAL,
	new_tags: Array[StringName] = [],
	new_is_critical: bool = false
) -> void:
	amount = maxi(new_amount, 0)
	source = new_source
	hit_direction = new_hit_direction.normalized()
	damage_type = DamageTypes.normalize(new_damage_type)
	tags.append_array(new_tags)
	is_critical = new_is_critical


func with_amount(new_amount: int) -> RefCounted:
	return get_script().new(
		new_amount,
		source,
		hit_direction,
		damage_type,
		tags,
		is_critical
	)
