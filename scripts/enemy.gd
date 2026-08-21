extends CharacterBody2D

@export var move_speed: float = 120.0
@export var detection_radius: float = 450.0
@export var target_group: StringName = &"player"

var target: Node2D


func _ready() -> void:
	target = find_target()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		target = find_target()

	velocity = Vector2.ZERO

	if target != null:
		var offset_to_target := target.global_position - global_position

		if offset_to_target.length() <= detection_radius:
			velocity = offset_to_target.normalized() * move_speed

	move_and_slide()


func find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D
