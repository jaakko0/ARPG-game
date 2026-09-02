extends CharacterBody2D

const HitData = preload("res://scripts/hit_data.gd")

@export var move_speed: float = 120.0
@export var detection_radius: float = 450.0
@export var target_group: StringName = &"player"
@export var enemy_rank: StringName = &"normal"
@export var contact_damage: int = 10
@export_range(0.1, 10.0, 0.1) var attack_interval: float = 1.0
@export_range(0, 100000, 1) var experience_reward: int = 10

@onready var health = $Health
@onready var health_label: Label = $HealthLabel
@onready var loot_dropper = $LootDropper
@onready var area_attack = get_node_or_null("AreaAttack")

var target: Node2D
var attack_cooldown_remaining: float = 0.0
var death_processed: bool = false


func _ready() -> void:
	target = find_target()
	health.health_changed.connect(_on_health_changed)
	health.depleted.connect(_on_health_depleted)
	update_health_display(health.current_health, health.max_health)


func _physics_process(delta: float) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)

	if not is_instance_valid(target):
		target = find_target()

	velocity = Vector2.ZERO
	var movement_locked := false

	if area_attack != null:
		area_attack.call("update_attack", delta, target)
		movement_locked = area_attack.call("is_movement_locked")

	if target != null and not movement_locked:
		var offset_to_target := target.global_position - global_position

		if offset_to_target.length() <= detection_radius:
			velocity = offset_to_target.normalized() * move_speed

	move_and_slide()

	if not movement_locked:
		try_contact_attack()


func try_contact_attack() -> void:
	if attack_cooldown_remaining > 0.0:
		return

	var damage_target := find_contact_damage_target()

	if damage_target != null:
		var target_body := damage_target as Node2D
		var hit_direction := Vector2.ZERO

		if target_body != null:
			hit_direction = (target_body.global_position - global_position).normalized()

		damage_target.call("take_hit", create_contact_hit(hit_direction))
		attack_cooldown_remaining = attack_interval


func find_contact_damage_target() -> Node:
	for collision_index in get_slide_collision_count():
		var collider := get_slide_collision(collision_index).get_collider() as Node

		if (
			collider != null
			and collider.is_in_group(target_group)
			and collider.has_method("take_hit")
		):
			return collider

	return null


func create_contact_hit(hit_direction: Vector2) -> HitData:
	var hit_tags: Array[StringName] = [&"enemy_attack", &"contact"]
	return HitData.new(
		contact_damage,
		self,
		hit_direction,
		&"physical",
		hit_tags,
		false
	)


func take_hit(hit_data: HitData) -> int:
	return health.apply_hit(hit_data)


func is_elite() -> bool:
	return enemy_rank == &"elite"


func _on_health_changed(current_health: int, max_health: int) -> void:
	update_health_display(current_health, max_health)


func _on_health_depleted() -> void:
	if death_processed:
		return

	death_processed = true
	loot_dropper.drop_loot(global_position)
	award_experience()
	set_physics_process(false)
	queue_free()


func award_experience() -> void:
	if experience_reward <= 0:
		return

	var reward_target := target

	if not is_instance_valid(reward_target):
		reward_target = find_target()

	if reward_target != null and reward_target.has_method("add_experience"):
		reward_target.call("add_experience", experience_reward)


func update_health_display(current_health: int, max_health: int) -> void:
	health_label.text = "HP: %d / %d" % [current_health, max_health]


func find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D
