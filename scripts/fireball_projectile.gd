extends CharacterBody2D

@export var speed: float = 520.0
@export var lifetime: float = 1.5
@export var target_group: StringName = &"enemy"

var direction: Vector2 = Vector2.RIGHT
var damage: int = 20
var lifetime_remaining: float


func _ready() -> void:
	lifetime_remaining = lifetime


func setup(new_direction: Vector2, new_damage: int, new_speed: float) -> void:
	if not new_direction.is_zero_approx():
		direction = new_direction.normalized()

	damage = maxi(new_damage, 0)
	speed = maxf(new_speed, 0.0)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	lifetime_remaining -= delta

	if lifetime_remaining <= 0.0:
		queue_free()
		return

	var collision := move_and_collide(direction * speed * delta)

	if collision == null:
		return

	var collider := collision.get_collider() as Node

	if (
		collider != null
		and collider.is_in_group(target_group)
		and collider.has_method("take_damage")
	):
		collider.call("take_damage", damage, direction)

	queue_free()
