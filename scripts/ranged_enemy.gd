extends "res://scripts/enemy.gd"

enum RangeState {
	IDLE,
	APPROACH,
	HOLD,
	RETREAT,
}

@export_range(40.0, 500.0, 5.0) var retreat_start_distance: float = 170.0
@export_range(40.0, 500.0, 5.0) var retreat_stop_distance: float = 220.0
@export_range(40.0, 500.0, 5.0) var approach_stop_distance: float = 300.0
@export_range(40.0, 500.0, 5.0) var approach_start_distance: float = 340.0

@onready var ranged_attack = $RangedAttack

var range_state: RangeState = RangeState.IDLE


func _physics_process(delta: float) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)

	if not is_instance_valid(target):
		target = find_target()

	velocity = Vector2.ZERO
	var active_target: Node2D

	if target != null and global_position.distance_to(target.global_position) <= detection_radius:
		active_target = target

	ranged_attack.call("update_attack", delta, active_target)
	var movement_locked: bool = ranged_attack.call("is_movement_locked")

	if active_target == null:
		range_state = RangeState.IDLE
	elif not movement_locked:
		var offset_to_target := active_target.global_position - global_position
		var distance_to_target := offset_to_target.length()
		update_range_state(distance_to_target)

		if range_state == RangeState.APPROACH:
			velocity = offset_to_target.normalized() * move_speed
		elif range_state == RangeState.RETREAT:
			velocity = -offset_to_target.normalized() * move_speed

	move_and_slide()

	if not movement_locked:
		try_contact_attack()


func update_range_state(distance_to_target: float) -> void:
	match range_state:
		RangeState.APPROACH:
			if distance_to_target <= approach_stop_distance:
				range_state = RangeState.HOLD
		RangeState.RETREAT:
			if distance_to_target >= retreat_stop_distance:
				range_state = RangeState.HOLD
		_:
			if distance_to_target < retreat_start_distance:
				range_state = RangeState.RETREAT
			elif distance_to_target > approach_start_distance:
				range_state = RangeState.APPROACH
			else:
				range_state = RangeState.HOLD


func get_range_state_name() -> StringName:
	match range_state:
		RangeState.IDLE:
			return &"idle"
		RangeState.APPROACH:
			return &"approach"
		RangeState.HOLD:
			return &"hold"
		RangeState.RETREAT:
			return &"retreat"
		_:
			return &"unknown"
