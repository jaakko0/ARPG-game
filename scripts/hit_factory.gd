extends Node

const HitData = preload("res://scripts/hit_data.gd")

@export_range(0.0, 1.0, 0.01) var critical_chance: float = 0.1
@export_range(1.0, 10.0, 0.1) var critical_damage_multiplier: float = 2.0

var random_number_generator := RandomNumberGenerator.new()


func _ready() -> void:
	random_number_generator.randomize()


func create_hit(
	base_amount: int,
	source: Node,
	hit_direction: Vector2,
	damage_type: StringName,
	tags: Array[StringName] = []
) -> HitData:
	var safe_base_amount := maxi(base_amount, 0)
	var is_critical := (
		safe_base_amount > 0
		and random_number_generator.randf() < critical_chance
	)
	var final_amount := safe_base_amount

	if is_critical:
		final_amount = maxi(
			roundi(float(safe_base_amount) * critical_damage_multiplier),
			0
		)

	return HitData.new(
		final_amount,
		source,
		hit_direction,
		damage_type,
		tags,
		is_critical
	)
