extends Control

signal movement_changed(direction: Vector2)
signal skill_slot_requested(slot_index: int)

@onready var joystick: Control = $VirtualJoystick
@onready var skill_buttons: Array[Button] = [
	$FireballButton,
	$LightningArcButton,
]


func _ready() -> void:
	joystick.connect("direction_changed", _on_joystick_direction_changed)

	for slot_index in range(skill_buttons.size()):
		skill_buttons[slot_index].pressed.connect(
			_on_skill_button_pressed.bind(slot_index)
		)


func _on_joystick_direction_changed(direction: Vector2) -> void:
	movement_changed.emit(direction)


func _on_skill_button_pressed(slot_index: int) -> void:
	skill_slot_requested.emit(slot_index)


func reset_movement() -> void:
	joystick.call("reset_direction")
