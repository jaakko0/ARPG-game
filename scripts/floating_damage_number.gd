extends Node2D

@export_range(0.1, 3.0, 0.05) var duration: float = 0.7
@export_range(0.0, 200.0, 1.0) var rise_distance: float = 46.0

@onready var damage_label: Label = $DamageLabel


func setup(damage_amount: int) -> void:
	damage_label.text = str(maxi(damage_amount, 0))

	var tween := create_tween().set_parallel()
	tween.tween_property(
		self,
		"position",
		position + Vector2.UP * rise_distance,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.finished.connect(queue_free)
