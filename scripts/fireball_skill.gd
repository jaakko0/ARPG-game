extends Node

const DamageTypes = preload("res://scripts/damage_types.gd")

@export var projectile_scene: PackedScene
@export var damage: int = 20
@export var projectile_speed: float = 520.0
@export var projectile_spawn_distance: float = 44.0
@export_range(0.1, 30.0, 0.1) var cooldown: float = 2.0
@export var intelligence_damage_per_point: int = 2
@export var damage_type: StringName = DamageTypes.FIRE

var cooldown_remaining: float = 0.0
var base_damage: int


func _ready() -> void:
	base_damage = damage


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)


func apply_intelligence_bonus(attribute_bonus: int) -> void:
	damage = base_damage + maxi(attribute_bonus, 0) * intelligence_damage_per_point


func try_activate(source: Node2D, direction: Vector2, hit_factory: Node) -> bool:
	if (
		cooldown_remaining > 0.0
		or source == null
		or not is_instance_valid(source)
		or direction.is_zero_approx()
	):
		return false

	if projectile_scene == null or get_tree().current_scene == null:
		return false

	var projectile := projectile_scene.instantiate() as CharacterBody2D

	if projectile == null:
		return false

	var fire_direction := direction.normalized()
	var hit_tags: Array[StringName] = [&"skill", &"projectile"]
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = (
		source.global_position + fire_direction * projectile_spawn_distance
	)
	projectile.call(
		"setup",
		fire_direction,
		damage,
		projectile_speed,
		source,
		hit_factory,
		damage_type,
		hit_tags
	)
	cooldown_remaining = cooldown
	return true
