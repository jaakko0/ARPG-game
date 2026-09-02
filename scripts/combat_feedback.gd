extends Node

const HitData = preload("res://scripts/hit_data.gd")

@export var damage_number_scene: PackedScene
@export_node_path("Node2D") var visual_path: NodePath = NodePath("../Placeholder")
@export var damage_number_offset: Vector2 = Vector2(0.0, -82.0)
@export_range(0.0, 20.0, 1.0) var reaction_distance: float = 8.0
@export_range(0.01, 1.0, 0.01) var reaction_duration: float = 0.12
@export var flash_modulate: Color = Color(2.0, 2.0, 2.0, 1.0)

@onready var damage_target := get_parent() as Node2D
@onready var visual := get_node_or_null(visual_path) as Node2D

var original_visual_position: Vector2
var original_visual_modulate: Color
var reaction_tween: Tween


func _ready() -> void:
	if visual != null:
		original_visual_position = visual.position
		original_visual_modulate = visual.modulate


func show_damage(hit_data: HitData) -> void:
	if hit_data == null or hit_data.amount <= 0:
		return

	spawn_damage_number(hit_data)
	play_hit_reaction(hit_data.hit_direction)


func spawn_damage_number(hit_data: HitData) -> void:
	if damage_number_scene == null or damage_target == null:
		return

	var scene_root := get_tree().current_scene

	if scene_root == null:
		return

	var damage_number := damage_number_scene.instantiate() as Node2D

	if damage_number == null:
		return

	scene_root.add_child(damage_number)
	damage_number.global_position = damage_target.global_position + damage_number_offset
	damage_number.call("setup", hit_data)


func play_hit_reaction(hit_direction: Vector2) -> void:
	if visual == null:
		return

	if reaction_tween != null and reaction_tween.is_valid():
		reaction_tween.kill()

	var recoil_direction := hit_direction.normalized()
	visual.position = original_visual_position + recoil_direction * reaction_distance
	visual.modulate = flash_modulate

	reaction_tween = create_tween().set_parallel()
	reaction_tween.tween_property(
		visual,
		"position",
		original_visual_position,
		reaction_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reaction_tween.tween_property(
		visual,
		"modulate",
		original_visual_modulate,
		reaction_duration
	)
