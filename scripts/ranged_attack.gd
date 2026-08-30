extends Node2D

signal telegraph_started
signal projectile_fired(projectile: CharacterBody2D)

enum AttackState {
	READY,
	WINDUP,
	COOLDOWN,
}

@export var projectile_scene: PackedScene
@export_range(40.0, 500.0, 5.0) var attack_range: float = 340.0
@export_range(1, 1000, 1) var damage: int = 12
@export_range(20.0, 1000.0, 10.0) var projectile_speed: float = 280.0
@export_range(0.1, 10.0, 0.1) var projectile_lifetime: float = 2.0
@export_range(0.1, 3.0, 0.05) var windup_duration: float = 0.55
@export_range(0.1, 10.0, 0.1) var cooldown_duration: float = 2.2
@export_range(10.0, 100.0, 1.0) var spawn_distance: float = 36.0
@export var aim_color: Color = Color(1.0, 0.35, 0.75, 1.0)

@onready var warning_label := get_node_or_null("WarningLabel") as Label

var state: AttackState = AttackState.READY
var state_time_remaining: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	visible = false


func update_attack(delta: float, target: Node2D) -> void:
	match state:
		AttackState.READY:
			if is_target_in_range(target):
				start_windup(target)
		AttackState.WINDUP:
			state_time_remaining = maxf(state_time_remaining - delta, 0.0)
			queue_redraw()

			if state_time_remaining == 0.0:
				fire_projectile(target)
				enter_cooldown()
		AttackState.COOLDOWN:
			state_time_remaining = maxf(state_time_remaining - delta, 0.0)

			if state_time_remaining == 0.0:
				state = AttackState.READY


func is_movement_locked() -> bool:
	return state == AttackState.WINDUP


func is_target_in_range(target: Node2D) -> bool:
	return (
		is_instance_valid(target)
		and global_position.distance_to(target.global_position) <= attack_range
	)


func start_windup(target: Node2D) -> void:
	var offset_to_target := target.global_position - global_position

	if not offset_to_target.is_zero_approx():
		aim_direction = offset_to_target.normalized()

	state = AttackState.WINDUP
	state_time_remaining = windup_duration
	visible = true
	queue_redraw()
	telegraph_started.emit()


func fire_projectile(target: Node2D) -> CharacterBody2D:
	visible = false

	if not is_instance_valid(target) or projectile_scene == null:
		return null

	var scene_root := get_tree().current_scene

	if scene_root == null:
		return null

	var projectile := projectile_scene.instantiate() as CharacterBody2D

	if projectile == null:
		return null

	scene_root.add_child(projectile)
	projectile.global_position = global_position + aim_direction * spawn_distance
	projectile.call(
		"setup",
		aim_direction,
		damage,
		projectile_speed,
		projectile_lifetime
	)
	projectile_fired.emit(projectile)
	return projectile


func enter_cooldown() -> void:
	state = AttackState.COOLDOWN
	state_time_remaining = cooldown_duration


func get_state_name() -> StringName:
	match state:
		AttackState.READY:
			return &"ready"
		AttackState.WINDUP:
			return &"windup"
		AttackState.COOLDOWN:
			return &"cooldown"
		_:
			return &"unknown"


func _draw() -> void:
	if state != AttackState.WINDUP:
		return

	var progress := 1.0 - state_time_remaining / maxf(windup_duration, 0.001)
	var line_length := lerpf(62.0, 94.0, progress)
	var line_width := lerpf(4.0, 8.0, progress)
	draw_line(Vector2.ZERO, aim_direction * line_length, aim_color, line_width, true)
	draw_circle(aim_direction * line_length, 7.0, aim_color)
