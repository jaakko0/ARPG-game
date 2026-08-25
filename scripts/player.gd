extends CharacterBody2D

@export var move_speed: float = 240.0

@onready var health = $Health
@onready var health_label: Label = $HUD/HealthLabel

var starting_position: Vector2


func _ready() -> void:
	starting_position = global_position
	health.health_changed.connect(_on_health_changed)
	health.depleted.connect(_on_health_depleted)
	update_health_display(health.current_health, health.max_health)


func _physics_process(_delta: float) -> void:
	var input_direction := get_movement_input()
	velocity = input_direction * move_speed
	move_and_slide()


# Keeping input collection separate makes a virtual joystick easy to add later.
func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func take_damage(amount: int) -> void:
	health.take_damage(amount)


func heal(amount: int) -> void:
	health.heal(amount)


func _on_health_changed(current_health: int, max_health: int) -> void:
	update_health_display(current_health, max_health)


func _on_health_depleted() -> void:
	call_deferred("respawn")


func respawn() -> void:
	global_position = starting_position
	velocity = Vector2.ZERO
	health.restore_full()


func update_health_display(current_health: int, max_health: int) -> void:
	health_label.text = "HP: %d / %d" % [current_health, max_health]
