extends Node

const EquipmentItemData = preload("res://scripts/equipment_item_data.gd")

@export var pickup_scene: PackedScene
@export_range(0.0, 1.0, 0.05) var drop_chance: float = 1.0
@export var minimum_amount: int = 1
@export var maximum_amount: int = 5
@export var equipment_pickup_scene: PackedScene
# Generous prototype value so equipment drops can be tested without grinding.
@export_range(0.0, 1.0, 0.05) var equipment_drop_chance: float = 0.5
@export var equipment_items: Array = []


func drop_loot(drop_position: Vector2) -> Node2D:
	var gold_pickup := drop_gold(drop_position)
	drop_equipment(drop_position + Vector2(34.0, 0.0))
	return gold_pickup


func drop_gold(drop_position: Vector2) -> Node2D:
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


func drop_equipment(drop_position: Vector2) -> Node2D:
	if (
		equipment_pickup_scene == null
		or equipment_items.is_empty()
		or randf() >= equipment_drop_chance
	):
		return null

	var scene_root := get_tree().current_scene

	if scene_root == null:
		return null

	var item := equipment_items.pick_random() as EquipmentItemData

	if item == null or not item.is_valid_item():
		return null

	var pickup := equipment_pickup_scene.instantiate() as Node2D

	if pickup == null:
		return null

	scene_root.add_child(pickup)
	pickup.global_position = drop_position

	if pickup.has_method("setup"):
		pickup.call("setup", item)

	return pickup
