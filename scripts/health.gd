extends Node

signal health_changed(current_health: int, max_health: int)
signal damage_taken(damage_amount: int, hit_direction: Vector2)
signal depleted

@export_range(1, 100000, 1) var max_health: int = 100

var current_health: int


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> int:
	if amount <= 0 or current_health <= 0:
		return 0

	var damage_amount := mini(amount, current_health)
	current_health -= damage_amount
	damage_taken.emit(damage_amount, hit_direction.normalized())
	health_changed.emit(current_health, max_health)

	if current_health == 0:
		depleted.emit()

	return damage_amount


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
