extends CharacterBody2D

const HitData = preload("res://scripts/hit_data.gd")

@export var speed: float = 280.0
@export var lifetime: float = 2.0
@export var target_group: StringName = &"player"

var direction: Vector2 = Vector2.RIGHT
var damage: int = 12
var lifetime_remaining: float
var source: Node


func _ready() -> void:
	lifetime_remaining = lifetime


func setup(
	new_direction: Vector2,
	new_damage: int,
	new_speed: float,
	new_lifetime: float,
	new_source: Node
) -> void:
	if not new_direction.is_zero_approx():
		direction = new_direction.normalized()

	damage = maxi(new_damage, 0)
	speed = maxf(new_speed, 0.0)
	lifetime = maxf(new_lifetime, 0.1)
	lifetime_remaining = lifetime
	source = new_source
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
		and collider.has_method("take_hit")
	):
		collider.call("take_hit", create_hit_data())

	# Any solid collision consumes the projectile, including world obstacles.
	queue_free()


func create_hit_data() -> HitData:
	var hit_tags: Array[StringName] = [&"enemy_attack", &"projectile"]
	var hit_source: Node = source if is_instance_valid(source) else null
	return HitData.new(
		damage,
		hit_source,
		direction,
		&"physical",
		hit_tags,
		false
	)
