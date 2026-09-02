extends Control

signal movement_changed(direction: Vector2)
signal skill_slot_requested(slot_index: int)

@export var skill_button_slot_index: int = 0

@onready var joystick: Control = $VirtualJoystick
@onready var skill_button: Button = $FireballButton


func _ready() -> void:
	joystick.connect("direction_changed", _on_joystick_direction_changed)
	skill_button.pressed.connect(_on_skill_button_pressed)


func _on_joystick_direction_changed(direction: Vector2) -> void:
	movement_changed.emit(direction)


func _on_skill_button_pressed() -> void:
	skill_slot_requested.emit(skill_button_slot_index)


func reset_movement() -> void:
	joystick.call("reset_direction")
