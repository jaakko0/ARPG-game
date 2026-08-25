extends CharacterBody2D

@export var move_speed: float = 120.0
@export var detection_radius: float = 450.0
@export var target_group: StringName = &"player"
@export var contact_damage: int = 10
@export_range(0.1, 10.0, 0.1) var attack_interval: float = 1.0

var target: Node2D
var attack_cooldown_remaining: float = 0.0


func _ready() -> void:
	target = find_target()


func _physics_process(delta: float) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)

	if not is_instance_valid(target):
		target = find_target()

	velocity = Vector2.ZERO

	if target != null:
		var offset_to_target := target.global_position - global_position

		if offset_to_target.length() <= detection_radius:
			velocity = offset_to_target.normalized() * move_speed

	move_and_slide()
	try_contact_attack()


func try_contact_attack() -> void:
	if attack_cooldown_remaining > 0.0:
		return

	var damage_target := find_contact_damage_target()

	if damage_target != null:
		damage_target.call("take_damage", contact_damage)
		attack_cooldown_remaining = attack_interval


func find_contact_damage_target() -> Node:
	for collision_index in get_slide_collision_count():
		var collider := get_slide_collision(collision_index).get_collider() as Node

		if (
			collider != null
			and collider.is_in_group(target_group)
			and collider.has_method("take_damage")
		):
			return collider

	return null


func find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D
