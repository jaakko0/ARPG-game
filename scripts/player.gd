extends CharacterBody2D

@export var move_speed: float = 240.0
@export var attack_damage: int = 10
@export var attack_range: float = 110.0
@export_range(0.1, 10.0, 0.1) var attack_interval: float = 0.8
@export var enemy_group: StringName = &"enemy"

@onready var health = $Health
@onready var experience = $Experience
@onready var health_label: Label = $HUD/HealthLabel
@onready var gold_label: Label = $HUD/GoldLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var experience_label: Label = $HUD/ExperienceLabel
@onready var fireball_skill = $FireballSkill

var starting_position: Vector2
var facing_direction: Vector2 = Vector2.DOWN
var attack_cooldown_remaining: float = 0.0
var gold: int = 0


func _ready() -> void:
	starting_position = global_position
	health.health_changed.connect(_on_health_changed)
	health.depleted.connect(_on_health_depleted)
	experience.experience_changed.connect(_on_experience_changed)
	experience.level_changed.connect(_on_level_changed)
	update_health_display(health.current_health, health.max_health)
	update_gold_display()
	update_experience_display()


func _physics_process(delta: float) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)

	var input_direction := get_movement_input()

	if not input_direction.is_zero_approx():
		facing_direction = input_direction.normalized()

	velocity = input_direction * move_speed
	move_and_slide()
	try_autoattack()

	if Input.is_action_just_pressed("fireball"):
		try_fireball()


# Keeping input collection separate makes a virtual joystick easy to add later.
func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func try_fireball() -> bool:
	return fireball_skill.try_activate(global_position, facing_direction)


func try_autoattack() -> void:
	if attack_cooldown_remaining > 0.0:
		return

	var attack_target := find_nearest_enemy_in_range()

	if attack_target != null:
		attack_target.call("take_damage", attack_damage)
		attack_cooldown_remaining = attack_interval


func find_nearest_enemy_in_range() -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance_squared := attack_range * attack_range

	for candidate in get_tree().get_nodes_in_group(enemy_group):
		var enemy := candidate as Node2D

		if enemy == null or not enemy.has_method("take_damage"):
			continue

		var distance_squared := global_position.distance_squared_to(enemy.global_position)

		if (
			distance_squared <= attack_range * attack_range
			and (nearest_enemy == null or distance_squared < nearest_distance_squared)
		):
			nearest_enemy = enemy
			nearest_distance_squared = distance_squared

	return nearest_enemy


func take_damage(amount: int) -> void:
	health.take_damage(amount)


func heal(amount: int) -> void:
	health.heal(amount)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return

	gold += amount
	update_gold_display()


func add_experience(amount: int) -> void:
	experience.add_experience(amount)


func _on_health_changed(current_health: int, max_health: int) -> void:
	update_health_display(current_health, max_health)


func _on_health_depleted() -> void:
	call_deferred("respawn")


func _on_experience_changed(_current_experience: int, _experience_required: int) -> void:
	update_experience_display()


func _on_level_changed(_new_level: int) -> void:
	update_experience_display()


func respawn() -> void:
	global_position = starting_position
	velocity = Vector2.ZERO
	health.restore_full()


func update_health_display(current_health: int, max_health: int) -> void:
	health_label.text = "HP: %d / %d" % [current_health, max_health]


func update_gold_display() -> void:
	gold_label.text = "Gold: %d" % gold


func update_experience_display() -> void:
	level_label.text = "Level: %d" % experience.current_level
	experience_label.text = "XP: %d / %d" % [
		experience.current_experience,
		experience.experience_required,
	]
