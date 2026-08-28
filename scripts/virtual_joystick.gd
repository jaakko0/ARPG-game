extends Control

signal direction_changed(direction: Vector2)

@export_range(20.0, 200.0, 1.0) var joystick_radius: float = 90.0
@export_range(0.0, 0.9, 0.05) var dead_zone: float = 0.1
@export var base_color: Color = Color(0.12, 0.16, 0.22, 0.65)
@export var outline_color: Color = Color(0.7, 0.8, 0.95, 0.8)
@export var knob_color: Color = Color(0.3, 0.7, 1.0, 0.9)

var direction: Vector2 = Vector2.ZERO
var active_touch_index: int = -1
var mouse_dragging: bool = false


func _ready() -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		handle_screen_drag(event)
	elif event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion and mouse_dragging:
		update_direction(event.position)
		get_viewport().set_input_as_handled()


func handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if active_touch_index == -1 and get_global_rect().has_point(event.position):
			active_touch_index = event.index
			update_direction(event.position)
			get_viewport().set_input_as_handled()
	elif event.index == active_touch_index:
		active_touch_index = -1
		reset_direction()
		get_viewport().set_input_as_handled()


func handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != active_touch_index:
		return

	update_direction(event.position)
	get_viewport().set_input_as_handled()


func handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or active_touch_index != -1:
		return

	if event.pressed and get_global_rect().has_point(event.position):
		mouse_dragging = true
		update_direction(event.position)
		get_viewport().set_input_as_handled()
	elif not event.pressed and mouse_dragging:
		mouse_dragging = false
		reset_direction()
		get_viewport().set_input_as_handled()


func update_direction(pointer_position: Vector2) -> void:
	var offset := pointer_position - get_global_rect().get_center()
	var new_direction := offset.limit_length(joystick_radius) / joystick_radius

	if new_direction.length() < dead_zone:
		new_direction = Vector2.ZERO

	if new_direction.is_equal_approx(direction):
		return

	direction = new_direction
	direction_changed.emit(direction)
	queue_redraw()


func reset_direction() -> void:
	if direction.is_zero_approx():
		return

	direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, joystick_radius, base_color)
	draw_arc(center, joystick_radius, 0.0, TAU, 64, outline_color, 4.0, true)
	draw_circle(center + direction * joystick_radius, 34.0, knob_color)
