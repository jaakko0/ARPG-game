extends CharacterBody2D

@export var move_speed: float = 240.0
@export var attack_damage: int = 10
@export var attack_range: float = 110.0
@export_range(0.1, 10.0, 0.1) var attack_interval: float = 0.8
@export var enemy_group: StringName = &"enemy"

@onready var health = $Health
@onready var experience = $Experience
@onready var attributes = $Attributes
@onready var save_system = $SaveSystem
@onready var health_label: Label = $HUD/HealthLabel
@onready var gold_label: Label = $HUD/GoldLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var experience_label: Label = $HUD/ExperienceLabel
@onready var save_status_label: Label = $HUD/SaveStatusLabel
@onready var fireball_skill = $FireballSkill
@onready var attribute_panel = $HUD/AttributePanel

var starting_position: Vector2
var facing_direction: Vector2 = Vector2.DOWN
var attack_cooldown_remaining: float = 0.0
var gold: int = 0
var base_attack_damage: int
var base_max_health: int
var base_fireball_damage: int
var save_status_remaining: float = 0.0
var mobile_movement_input: Vector2 = Vector2.ZERO


func _ready() -> void:
	starting_position = global_position
	base_attack_damage = attack_damage
	base_max_health = health.max_health
	base_fireball_damage = fireball_skill.damage
	health.health_changed.connect(_on_health_changed)
	health.depleted.connect(_on_health_depleted)
	experience.experience_changed.connect(_on_experience_changed)
	experience.level_changed.connect(_on_level_changed)
	attributes.attribute_changed.connect(_on_attribute_changed)
	attribute_panel.setup(attributes)
	apply_attribute_effects()
	update_health_display(health.current_health, health.max_health)
	update_gold_display()
	update_experience_display()


func _physics_process(delta: float) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	update_save_status(delta)

	var input_direction := get_movement_input()

	if not input_direction.is_zero_approx():
		facing_direction = input_direction.normalized()

	velocity = input_direction * move_speed
	move_and_slide()
	try_autoattack()

	if Input.is_action_just_pressed("fireball"):
		try_fireball()

	if Input.is_action_just_pressed("save_game"):
		save_progression()

	if Input.is_action_just_pressed("load_game"):
		load_progression()


# Keyboard and touch input meet here before the existing movement logic uses them.
func get_movement_input() -> Vector2:
	var keyboard_input := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	return (keyboard_input + mobile_movement_input).limit_length(1.0)


func try_fireball() -> bool:
	return fireball_skill.try_activate(global_position, facing_direction)


func _on_mobile_movement_changed(direction: Vector2) -> void:
	mobile_movement_input = direction.limit_length(1.0)


func _on_mobile_fireball_requested() -> void:
	try_fireball()


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


func save_progression() -> bool:
	var result: Dictionary = save_system.save_game(get_progression_save_data())
	show_save_status(result.get("message", "Save Failed"))
	return result.get("success", false)


func load_progression() -> bool:
	var result: Dictionary = save_system.load_game()

	if not result.get("success", false):
		show_save_status(result.get("message", "Load Failed"))
		return false

	var player_data: Dictionary = result.get("player_data", {})

	if not apply_progression_save_data(player_data):
		show_save_status("Load Failed: Invalid Progression")
		return false

	show_save_status(result.get("message", "Game Loaded"))
	return true


func get_progression_save_data() -> Dictionary:
	return {
		"level": experience.current_level,
		"current_xp": experience.current_experience,
		"gold": gold,
		"attributes": {
			"strength": attributes.strength,
			"dexterity": attributes.dexterity,
			"intelligence": attributes.intelligence,
			"vitality": attributes.vitality,
			"unspent_points": attributes.unspent_points,
		},
	}


func apply_progression_save_data(player_data: Dictionary) -> bool:
	var saved_level := int(player_data.get("level", 0))
	var saved_experience := int(player_data.get("current_xp", -1))
	var saved_experience_required: int = experience.get_experience_required_for_level(
		saved_level
	)
	var attribute_data: Dictionary = player_data.get("attributes", {})
	var saved_gold := int(player_data.get("gold", -1))
	var saved_strength := int(attribute_data.get("strength", -1))
	var saved_dexterity := int(attribute_data.get("dexterity", -1))
	var saved_intelligence := int(attribute_data.get("intelligence", -1))
	var saved_vitality := int(attribute_data.get("vitality", -1))
	var saved_unspent_points := int(attribute_data.get("unspent_points", -1))

	if (
		saved_level < 1
		or saved_experience < 0
		or saved_experience >= saved_experience_required
		or saved_gold < 0
		or saved_strength < 0
		or saved_dexterity < 0
		or saved_intelligence < 0
		or saved_vitality < 0
		or saved_unspent_points < 0
	):
		return false

	if not experience.restore_progress(saved_level, saved_experience):
		return false

	if not attributes.restore_values(
		saved_strength,
		saved_dexterity,
		saved_intelligence,
		saved_vitality,
		saved_unspent_points
	):
		return false

	gold = saved_gold
	apply_attribute_effects()
	update_gold_display()
	update_experience_display()
	return true


func _on_health_changed(current_health: int, max_health: int) -> void:
	update_health_display(current_health, max_health)


func _on_health_depleted() -> void:
	call_deferred("respawn")


func _on_experience_changed(_current_experience: int, _experience_required: int) -> void:
	update_experience_display()


func _on_level_changed(_new_level: int) -> void:
	attributes.grant_points(1)
	update_experience_display()


func _on_attribute_changed(_attribute_name: StringName, _new_value: int) -> void:
	apply_attribute_effects()


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


func apply_attribute_effects() -> void:
	attack_damage = base_attack_damage + attributes.get_bonus(&"strength")
	health.set_max_health(base_max_health + attributes.get_bonus(&"vitality") * 5)
	fireball_skill.damage = (
		base_fireball_damage + attributes.get_bonus(&"intelligence") * 2
	)


func update_save_status(delta: float) -> void:
	if save_status_remaining <= 0.0:
		return

	save_status_remaining = maxf(save_status_remaining - delta, 0.0)

	if save_status_remaining == 0.0:
		save_status_label.text = ""


func show_save_status(message: String) -> void:
	save_status_label.text = message
	save_status_remaining = 3.0
