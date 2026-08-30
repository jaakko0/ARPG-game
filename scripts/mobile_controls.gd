extends Control

signal movement_changed(direction: Vector2)
signal fireball_requested

@onready var joystick: Control = $VirtualJoystick
@onready var fireball_button: Button = $FireballButton


func _ready() -> void:
	joystick.connect("direction_changed", _on_joystick_direction_changed)
	fireball_button.pressed.connect(_on_fireball_button_pressed)


func _on_joystick_direction_changed(direction: Vector2) -> void:
	movement_changed.emit(direction)


func _on_fireball_button_pressed() -> void:
	fireball_requested.emit()


func reset_movement() -> void:
	joystick.call("reset_direction")
