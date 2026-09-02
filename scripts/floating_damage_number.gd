extends Node2D

const HitData = preload("res://scripts/hit_data.gd")
const DamageTypes = preload("res://scripts/damage_types.gd")

@export_range(0.1, 3.0, 0.05) var duration: float = 0.7
@export_range(0.0, 200.0, 1.0) var rise_distance: float = 46.0

@onready var damage_label: Label = $DamageLabel

var displayed_damage_type: StringName = DamageTypes.PHYSICAL


func setup(hit_data: HitData) -> void:
	if hit_data == null:
		queue_free()
		return

	damage_label.text = str(maxi(hit_data.amount, 0))
	displayed_damage_type = hit_data.damage_type

	if hit_data.is_critical:
		damage_label.text += " CRIT"
		damage_label.add_theme_font_size_override("font_size", 36)
		damage_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.35, 0.12, 1.0)
		)

	var tween := create_tween().set_parallel()
	tween.tween_property(
		self,
		"position",
		position + Vector2.UP * rise_distance,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.finished.connect(queue_free)
