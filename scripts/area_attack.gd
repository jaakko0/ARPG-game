extends Node2D

const HitData = preload("res://scripts/hit_data.gd")

signal telegraph_started
signal attack_executed(hit_target: bool)
signal state_changed(state_name: StringName)

enum AttackState {
	READY,
	TELEGRAPH,
	RECOVERY,
	COOLDOWN,
}

@export var ability_name: String = "Area Attack"
@export var warning_text: String = "MOVE!"
@export_range(40.0, 500.0, 5.0) var attack_range: float = 165.0
@export_range(1, 1000, 1) var damage: int = 30
@export_range(0.1, 5.0, 0.05) var windup_duration: float = 0.9
@export_range(0.0, 5.0, 0.05) var recovery_duration: float = 0.6
@export_range(0.1, 20.0, 0.1) var cooldown_duration: float = 2.5
@export var telegraph_fill_color: Color = Color(1.0, 0.2, 0.08, 0.24)
@export var telegraph_outline_color: Color = Color(1.0, 0.72, 0.15, 0.95)

@onready var warning_label := get_node_or_null("WarningLabel") as Label

var state: AttackState = AttackState.READY
var state_time_remaining: float = 0.0


func _ready() -> void:
	visible = false

	if warning_label != null:
		warning_label.text = warning_text


func update_attack(delta: float, target: Node2D) -> void:
	match state:
		AttackState.READY:
			if is_target_in_range(target):
				start_telegraph()
		AttackState.TELEGRAPH:
			state_time_remaining = maxf(state_time_remaining - delta, 0.0)
			queue_redraw()

			if state_time_remaining == 0.0:
				execute_attack(target)
				enter_state(AttackState.RECOVERY, recovery_duration)
		AttackState.RECOVERY:
			state_time_remaining = maxf(state_time_remaining - delta, 0.0)

			if state_time_remaining == 0.0:
				enter_state(AttackState.COOLDOWN, cooldown_duration)
		AttackState.COOLDOWN:
			state_time_remaining = maxf(state_time_remaining - delta, 0.0)

			if state_time_remaining == 0.0:
				enter_state(AttackState.READY, 0.0)


func is_movement_locked() -> bool:
	return state == AttackState.TELEGRAPH or state == AttackState.RECOVERY


func is_target_in_range(target: Node2D) -> bool:
	return (
		is_instance_valid(target)
		and global_position.distance_to(target.global_position) <= attack_range
	)


func start_telegraph() -> void:
	enter_state(AttackState.TELEGRAPH, windup_duration)
	visible = true
	queue_redraw()
	telegraph_started.emit()


func execute_attack(target: Node2D) -> void:
	visible = false
	var hit_target := is_target_in_range(target) and target.has_method("take_hit")

	if hit_target:
		var hit_direction := (target.global_position - global_position).normalized()
		target.call("take_hit", create_attack_hit(hit_direction))

	attack_executed.emit(hit_target)


func create_attack_hit(hit_direction: Vector2) -> HitData:
	var hit_tags: Array[StringName] = [&"enemy_attack", &"area"]
	return HitData.new(
		damage,
		get_parent(),
		hit_direction,
		&"physical",
		hit_tags,
		false
	)


func enter_state(new_state: AttackState, duration: float) -> void:
	state = new_state
	state_time_remaining = maxf(duration, 0.0)
	state_changed.emit(get_state_name())


func get_state_name() -> StringName:
	match state:
		AttackState.READY:
			return &"ready"
		AttackState.TELEGRAPH:
			return &"telegraph"
		AttackState.RECOVERY:
			return &"recovery"
		AttackState.COOLDOWN:
			return &"cooldown"
		_:
			return &"unknown"


func _draw() -> void:
	if state != AttackState.TELEGRAPH:
		return

	var progress := 1.0 - state_time_remaining / maxf(windup_duration, 0.001)
	var fill_color := telegraph_fill_color
	fill_color.a = lerpf(telegraph_fill_color.a * 0.55, telegraph_fill_color.a, progress)
	draw_circle(Vector2.ZERO, attack_range, fill_color)
	draw_arc(
		Vector2.ZERO,
		attack_range,
		0.0,
		TAU,
		64,
		telegraph_outline_color,
		lerpf(4.0, 9.0, progress),
		true
	)
