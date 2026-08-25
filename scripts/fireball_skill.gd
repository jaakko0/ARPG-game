extends Node

@export var projectile_scene: PackedScene
@export var damage: int = 20
@export var projectile_speed: float = 520.0
@export var projectile_spawn_distance: float = 44.0
@export_range(0.1, 30.0, 0.1) var cooldown: float = 2.0

var cooldown_remaining: float = 0.0


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)


func try_activate(source_position: Vector2, direction: Vector2) -> bool:
	if cooldown_remaining > 0.0 or direction.is_zero_approx():
		return false

	if projectile_scene == null or get_tree().current_scene == null:
		return false

	var projectile := projectile_scene.instantiate() as CharacterBody2D

	if projectile == null:
		return false

	var fire_direction := direction.normalized()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = source_position + fire_direction * projectile_spawn_distance
	projectile.call("setup", fire_direction, damage, projectile_speed)
	cooldown_remaining = cooldown
	return true
