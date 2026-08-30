extends CharacterBody2D

@export var speed: float = 280.0
@export var lifetime: float = 2.0
@export var target_group: StringName = &"player"

var direction: Vector2 = Vector2.RIGHT
var damage: int = 12
var lifetime_remaining: float


func _ready() -> void:
	lifetime_remaining = lifetime


func setup(
	new_direction: Vector2,
	new_damage: int,
	new_speed: float,
	new_lifetime: float
) -> void:
	if not new_direction.is_zero_approx():
		direction = new_direction.normalized()

	damage = maxi(new_damage, 0)
	speed = maxf(new_speed, 0.0)
	lifetime = maxf(new_lifetime, 0.1)
	lifetime_remaining = lifetime
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

	# Any solid collision consumes the projectile, including world obstacles.
	queue_free()
