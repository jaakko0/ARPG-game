extends Node

@export var pickup_scene: PackedScene
@export_range(0.0, 1.0, 0.05) var drop_chance: float = 1.0
@export var minimum_amount: int = 1
@export var maximum_amount: int = 5


func drop_loot(drop_position: Vector2) -> Node2D:
	if pickup_scene == null or randf() >= drop_chance:
		return null

	var scene_root := get_tree().current_scene

	if scene_root == null:
		return null

	var pickup := pickup_scene.instantiate() as Node2D

	if pickup == null:
		return null

	var lowest_amount := mini(minimum_amount, maximum_amount)
	var highest_amount := maxi(minimum_amount, maximum_amount)
	var dropped_amount := randi_range(lowest_amount, highest_amount)

	scene_root.add_child(pickup)
	pickup.global_position = drop_position

	if pickup.has_method("setup"):
		pickup.call("setup", dropped_amount)

	return pickup
