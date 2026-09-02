extends Node

const HitData = preload("res://scripts/hit_data.gd")

@export var enemy_group: StringName = &"enemy"
@export_range(0.1, 60.0, 0.1) var autocast_interval: float = 5.0
@export_range(1.0, 1000.0, 1.0) var radius: float = 170.0
@export var damage: int = 22
@export var intelligence_damage_per_point: int = 2
@export var damage_type: StringName = &"fire"
@export var visual_color: Color = Color(1.0, 0.32, 0.08, 0.9)
@export_range(1.0, 30.0, 1.0) var visual_width: float = 10.0
@export_range(0.05, 1.0, 0.01) var visual_lifetime: float = 0.3

var time_until_ready: float
var base_damage: int


func _ready() -> void:
	base_damage = damage
	time_until_ready = autocast_interval


func apply_intelligence_bonus(attribute_bonus: int) -> void:
	damage = base_damage + maxi(attribute_bonus, 0) * intelligence_damage_per_point


func update_autocast(delta: float, source: Node2D, hit_factory: Node) -> bool:
	time_until_ready = maxf(time_until_ready - delta, 0.0)

	if time_until_ready > 0.0 or source == null or not is_instance_valid(source):
		return false

	return try_activate(source, hit_factory)


func try_activate(source: Node2D, hit_factory: Node) -> bool:
	var source_position := source.global_position
	var targets := find_targets_in_radius(source_position)

	if targets.is_empty():
		return false

	var targets_damaged := 0

	for target in targets:
		if damage_target(target, source, hit_factory, source_position):
			targets_damaged += 1

	if targets_damaged == 0:
		return false

	spawn_visual(source_position)
	time_until_ready = autocast_interval
	return true


func find_targets_in_radius(source_position: Vector2) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var seen_target_ids: Dictionary = {}
	var radius_squared := radius * radius

	for candidate in get_tree().get_nodes_in_group(enemy_group):
		var target := candidate as Node2D

		if not is_valid_target(target):
			continue

		var target_id := target.get_instance_id()

		if (
			seen_target_ids.has(target_id)
			or source_position.distance_squared_to(target.global_position) > radius_squared
		):
			continue

		seen_target_ids[target_id] = true
		targets.append(target)

	return targets


func is_valid_target(target: Node2D) -> bool:
	if (
		target == null
		or not is_instance_valid(target)
		or target.is_queued_for_deletion()
		or not target.has_method("take_hit")
	):
		return false

	var target_health := target.get_node_or_null("Health")

	if target_health != null and int(target_health.get("current_health")) <= 0:
		return false

	return true


func damage_target(
	target: Node2D,
	source: Node,
	hit_factory: Node,
	source_position: Vector2
) -> bool:
	if not is_valid_target(target):
		return false

	var hit_direction := (target.global_position - source_position).normalized()
	var hit_tags: Array[StringName] = [&"skill", &"autocast", &"area"]
	var hit_data := create_hit_data(source, hit_factory, hit_direction, hit_tags)
	target.call("take_hit", hit_data)
	return true


func create_hit_data(
	source: Node,
	hit_factory: Node,
	hit_direction: Vector2,
	hit_tags: Array[StringName]
) -> HitData:
	if is_instance_valid(hit_factory) and hit_factory.has_method("create_hit"):
		return hit_factory.call(
			"create_hit",
			damage,
			source,
			hit_direction,
			damage_type,
			hit_tags
		)

	return HitData.new(
		damage,
		source,
		hit_direction,
		damage_type,
		hit_tags,
		false
	)


func spawn_visual(source_position: Vector2) -> void:
	if get_tree().current_scene == null:
		return

	var nova_ring := Line2D.new()
	nova_ring.name = "FlameNovaVisual"
	nova_ring.width = visual_width
	nova_ring.default_color = visual_color
	nova_ring.closed = true
	nova_ring.antialiased = true
	nova_ring.z_index = 19
	nova_ring.points = build_circle_points()
	nova_ring.scale = Vector2.ONE * 0.25
	nova_ring.add_to_group(&"flame_nova_visual")
	get_tree().current_scene.add_child(nova_ring)
	nova_ring.global_position = source_position

	var visual_tween := nova_ring.create_tween().set_parallel()
	visual_tween.tween_property(nova_ring, "scale", Vector2.ONE, visual_lifetime)
	visual_tween.tween_property(
		nova_ring,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		visual_lifetime
	)
	visual_tween.chain().tween_callback(Callable(nova_ring, "queue_free"))


func build_circle_points() -> PackedVector2Array:
	var circle_points := PackedVector2Array()
	var point_count := 48

	for point_index in range(point_count):
		var angle := TAU * float(point_index) / float(point_count)
		circle_points.append(Vector2.from_angle(angle) * radius)

	return circle_points
