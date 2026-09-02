extends CharacterBody2D

const HitData = preload("res://scripts/hit_data.gd")
const DamageTypes = preload("res://scripts/damage_types.gd")

@export var speed: float = 520.0
@export var lifetime: float = 1.5
@export var target_group: StringName = &"enemy"

var direction: Vector2 = Vector2.RIGHT
var damage: int = 20
var lifetime_remaining: float
var source: Node
var hit_factory: Node
var damage_type: StringName = DamageTypes.FIRE
var hit_tags: Array[StringName] = []


func _ready() -> void:
	lifetime_remaining = lifetime


func setup(
	new_direction: Vector2,
	new_damage: int,
	new_speed: float,
	new_source: Node,
	new_hit_factory: Node,
	new_damage_type: StringName,
	new_hit_tags: Array[StringName]
) -> void:
	if not new_direction.is_zero_approx():
		direction = new_direction.normalized()

	damage = maxi(new_damage, 0)
	speed = maxf(new_speed, 0.0)
	source = new_source
	hit_factory = new_hit_factory
	damage_type = DamageTypes.normalize(new_damage_type)
	hit_tags.assign(new_hit_tags)
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

	queue_free()


func create_hit_data() -> HitData:
	var hit_source: Node = source if is_instance_valid(source) else null

	if is_instance_valid(hit_factory) and hit_factory.has_method("create_hit"):
		return hit_factory.call(
			"create_hit",
			damage,
			hit_source,
			direction,
			damage_type,
			hit_tags
		)

	return HitData.new(
		damage,
		hit_source,
		direction,
		damage_type,
		hit_tags,
		false
	)
