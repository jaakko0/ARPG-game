extends Node

signal health_changed(current_health: int, max_health: int)
signal depleted

@export_range(1, 100000, 1) var max_health: int = 100

var current_health: int


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return

	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	if current_health == 0:
		depleted.emit()


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return

	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func restore_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func set_max_health(new_max_health: int) -> void:
	var safe_max_health := maxi(new_max_health, 1)

	if safe_max_health == max_health:
		return

	max_health = safe_max_health
	current_health = mini(current_health, max_health)
	health_changed.emit(current_health, max_health)
