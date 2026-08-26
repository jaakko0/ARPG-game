extends Node

signal experience_changed(current_experience: int, experience_required: int)
signal level_changed(new_level: int)

@export_range(1, 1000, 1) var starting_level: int = 1
@export_range(1, 1000000, 1) var base_experience_required: int = 30
@export_range(0, 1000000, 1) var experience_growth_per_level: int = 20

var current_level: int
var current_experience: int = 0
var experience_required: int


func _ready() -> void:
	current_level = maxi(starting_level, 1)
	experience_required = get_experience_required_for_level(current_level)


func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	current_experience += amount

	while current_experience >= experience_required:
		current_experience -= experience_required
		current_level += 1
		experience_required = get_experience_required_for_level(current_level)
		level_changed.emit(current_level)

	experience_changed.emit(current_experience, experience_required)


func get_experience_required_for_level(level: int) -> int:
	var safe_level := maxi(level, 1)
	return base_experience_required + (safe_level - 1) * experience_growth_per_level


func restore_progress(saved_level: int, saved_experience: int) -> bool:
	if saved_level < 1 or saved_experience < 0:
		return false

	var saved_experience_required := get_experience_required_for_level(saved_level)

	if saved_experience >= saved_experience_required:
		return false

	current_level = saved_level
	current_experience = saved_experience
	experience_required = saved_experience_required
	experience_changed.emit(current_experience, experience_required)
	return true
