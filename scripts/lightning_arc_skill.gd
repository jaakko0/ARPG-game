extends Node

const HitData = preload("res://scripts/hit_data.gd")

@export var enemy_group: StringName = &"enemy"
@export_range(1.0, 2000.0, 1.0) var target_range: float = 320.0
@export_range(1.0, 1000.0, 1.0) var chain_radius: float = 200.0
@export var damage: int = 16
@export_range(0.0, 1.0, 0.05) var chain_damage_multiplier: float = 0.75
@export_range(0.1, 30.0, 0.1) var cooldown: float = 1.5
@export var intelligence_damage_per_point: int = 2
@export var damage_type: StringName = &"lightning"
@export var visual_color: Color = Color(0.45, 0.9, 1.0, 1.0)
@export_range(1.0, 30.0, 1.0) var visual_width: float = 8.0
@export_range(0.0, 30.0, 1.0) var visual_jitter: float = 8.0
@export_range(0.05, 1.0, 0.01) var visual_lifetime: float = 0.18

var cooldown_remaining: float = 0.0
var base_damage: int


func _ready() -> void:
	base_damage = damage


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)


func apply_intelligence_bonus(attribute_bonus: int) -> void:
	damage = base_damage + maxi(attribute_bonus, 0) * intelligence_damage_per_point


func try_activate(source: Node2D, _aim_direction: Vector2, hit_factory: Node) -> bool:
	if cooldown_remaining > 0.0 or source == null or not is_instance_valid(source):
		return false

	var source_position := source.global_position
	var first_target := find_nearest_target(source_position, target_range)

	if first_target == null:
		return false

	var first_position := first_target.global_position

	if not damage_target(first_target, damage, source, hit_factory, source_position, false):
		return false

	var hit_positions: Array[Vector2] = [source_position, first_position]
	var second_target := find_nearest_target(first_position, chain_radius, first_target)

	if second_target != null:
		var second_position := second_target.global_position

		if damage_target(
			second_target,
			get_chain_damage(),
			source,
			hit_factory,
			first_position,
			true
		):
			hit_positions.append(second_position)

	spawn_visual(hit_positions)
	cooldown_remaining = cooldown
	return true


func find_nearest_target(
	search_origin: Vector2,
	search_radius: float,
	excluded_target: Node = null
) -> Node2D:
	var nearest_target: Node2D
	var nearest_distance_squared := search_radius * search_radius

	for candidate in get_tree().get_nodes_in_group(enemy_group):
		var target := candidate as Node2D

		if not is_valid_target(target, excluded_target):
			continue

		var distance_squared := search_origin.distance_squared_to(target.global_position)

		if (
			distance_squared <= search_radius * search_radius
			and (nearest_target == null or distance_squared < nearest_distance_squared)
		):
			nearest_target = target
			nearest_distance_squared = distance_squared

	return nearest_target


func is_valid_target(target: Node2D, excluded_target: Node = null) -> bool:
	if (
		target == null
		or target == excluded_target
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
	amount: int,
	source: Node,
	hit_factory: Node,
	hit_origin: Vector2,
	is_chain_hit: bool
) -> bool:
	if not is_valid_target(target) or amount <= 0:
		return false

	var hit_direction := (target.global_position - hit_origin).normalized()
	var hit_tags: Array[StringName] = [&"skill"]

	if is_chain_hit:
		hit_tags.append(&"chain")
	else:
		hit_tags.append(&"direct")

	var hit_data := create_hit_data(
		amount,
		source,
		hit_factory,
		hit_direction,
		hit_tags
	)
	target.call("take_hit", hit_data)
	return true


func create_hit_data(
	amount: int,
	source: Node,
	hit_factory: Node,
	hit_direction: Vector2,
	hit_tags: Array[StringName]
) -> HitData:
	if is_instance_valid(hit_factory) and hit_factory.has_method("create_hit"):
		return hit_factory.call(
			"create_hit",
			amount,
			source,
			hit_direction,
			damage_type,
			hit_tags
		)

	return HitData.new(
		amount,
		source,
		hit_direction,
		damage_type,
		hit_tags,
		false
	)


func get_chain_damage() -> int:
	return maxi(roundi(damage * chain_damage_multiplier), 1)


func spawn_visual(hit_positions: Array[Vector2]) -> void:
	if hit_positions.size() < 2 or get_tree().current_scene == null:
		return

	var lightning_line := Line2D.new()
	lightning_line.name = "LightningArcVisual"
	lightning_line.width = visual_width
	lightning_line.default_color = visual_color
	lightning_line.antialiased = true
	lightning_line.z_index = 20
	lightning_line.add_to_group(&"lightning_arc_visual")
	get_tree().current_scene.add_child(lightning_line)
	lightning_line.global_position = Vector2.ZERO
	lightning_line.points = build_visual_points(hit_positions)

	var fade_tween := lightning_line.create_tween()
	fade_tween.tween_property(
		lightning_line,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		visual_lifetime
	)
	fade_tween.tween_callback(Callable(lightning_line, "queue_free"))


func build_visual_points(hit_positions: Array[Vector2]) -> PackedVector2Array:
	var visual_points := PackedVector2Array()

	for segment_index in range(hit_positions.size() - 1):
		append_arc_segment(
			visual_points,
			hit_positions[segment_index],
			hit_positions[segment_index + 1]
		)

	return visual_points


func append_arc_segment(
	visual_points: PackedVector2Array,
	start_position: Vector2,
	end_position: Vector2
) -> void:
	if visual_points.is_empty():
		visual_points.append(start_position)

	var perpendicular := (end_position - start_position).normalized().orthogonal()

	for step in range(1, 4):
		var progress := float(step) / 4.0
		var offset_sign := 1.0 if step % 2 == 1 else -1.0
		visual_points.append(
			start_position.lerp(end_position, progress)
			+ perpendicular * visual_jitter * offset_sign
		)

	visual_points.append(end_position)
