extends Area2D

@export var amount: int = 1
@export var collector_group: StringName = &"player"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(gold_amount: int) -> void:
	amount = maxi(gold_amount, 1)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(collector_group) or not body.has_method("add_gold"):
		return

	body.call("add_gold", amount)
	queue_free()
