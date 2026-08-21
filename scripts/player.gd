extends CharacterBody2D

@export var move_speed: float = 240.0


func _physics_process(_delta: float) -> void:
	var input_direction := get_movement_input()
	velocity = input_direction * move_speed
	move_and_slide()


# Keeping input collection separate makes a virtual joystick easy to add later.
func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
