extends CharacterBody2D

const EquipmentItemData = preload("res://scripts/equipment_item_data.gd")

@export var move_speed: float = 240.0
@export var attack_damage: int = 10
@export var attack_range: float = 110.0
@export_range(0.1, 10.0, 0.1) var attack_interval: float = 0.8
@export var enemy_group: StringName = &"enemy"

@onready var health = $Health
@onready var experience = $Experience
@onready var attributes = $Attributes
@onready var equipment = $Equipment
@onready var inventory = $Inventory
@onready var save_system = $SaveSystem
@onready var save_coordinator = $SaveCoordinator
@onready var health_label: Label = $HUD/HealthLabel
@onready var gold_label: Label = $HUD/GoldLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var experience_label: Label = $HUD/ExperienceLabel
@onready var save_status_label: Label = $HUD/SaveStatusLabel
@onready var fireball_skill = $FireballSkill
@onready var attribute_panel = $HUD/AttributePanel
@onready var equipment_panel = $HUD/EquipmentPanel
@onready var inventory_panel = $HUD/InventoryPanel
@onready var character_menu = $HUD/CharacterMenu
@onready var character_menu_button: Button = $HUD/CharacterMenuButton
@onready var mobile_controls: Control = $HUD/MobileControls

var starting_position: Vector2
var facing_direction: Vector2 = Vector2.DOWN
var attack_cooldown_remaining: float = 0.0
var gold: int = 0
var base_attack_damage: int
var base_max_health: int
var base_fireball_damage: int
var save_status_remaining: float = 0.0
var mobile_movement_input: Vector2 = Vector2.ZERO
var is_loading_progression: bool = false
var character_management_open: bool = false


func _ready() -> void:
	starting_position = global_position
	base_attack_damage = attack_damage
	base_max_health = health.max_health
	base_fireball_damage = fireball_skill.damage
	save_coordinator.setup(self, save_system, experience, attributes, inventory, equipment)
	health.health_changed.connect(_on_health_changed)
	health.depleted.connect(_on_health_depleted)
	experience.experience_changed.connect(_on_experience_changed)
	experience.level_changed.connect(_on_level_changed)
	attributes.attribute_changed.connect(_on_attribute_changed)
	equipment.equipment_updated.connect(_on_equipment_updated)
	attribute_panel.setup(attributes)
	equipment_panel.setup(equipment, attributes, self)
	inventory_panel.setup(inventory, equipment, attributes, self)
	character_menu.section_requested.connect(_on_character_menu_section_requested)
	character_menu.close_requested.connect(close_character_management)
	attribute_panel.close_requested.connect(_on_management_panel_back_requested)
	equipment_panel.close_requested.connect(_on_management_panel_back_requested)
	inventory_panel.close_requested.connect(_on_management_panel_back_requested)
	update_equipment_attribute_bonuses()
	apply_attribute_effects()
	set_management_panels_hidden()
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


func _on_character_menu_button_pressed() -> void:
	if character_management_open:
		close_character_management()
	else:
		open_character_management()


func _on_character_menu_section_requested(section_name: StringName) -> void:
	show_character_section(section_name)


func _on_management_panel_back_requested() -> void:
	if not character_management_open:
		return

	set_management_panels_hidden()
	character_menu.visible = true


func try_autoattack() -> void:
	if attack_cooldown_remaining > 0.0:
		return

	var attack_target := find_nearest_enemy_in_range()

	if attack_target != null:
		var hit_direction := (
			attack_target.global_position - global_position
		).normalized()
		attack_target.call("take_damage", attack_damage, hit_direction)
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


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	health.take_damage(amount, hit_direction)


func heal(amount: int) -> void:
	health.heal(amount)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return

	gold += amount
	update_gold_display()


func add_experience(amount: int) -> void:
	experience.add_experience(amount)


func collect_equipment_item(item_data: EquipmentItemData) -> bool:
	if item_data == null or equipment.get_item_by_id(item_data.item_id) == null:
		return false

	if not inventory.add_item(item_data.item_id):
		show_save_status("Inventory Full")
		return false

	show_save_status("Picked up %s" % item_data.display_name)
	return true


func add_debug_inventory_item(item_id: StringName) -> bool:
	var item: EquipmentItemData = equipment.get_item_by_id(item_id)
	return collect_equipment_item(item)


func equip_inventory_item(item_index: int) -> bool:
	var item_id: StringName = inventory.get_item_id_at(item_index)
	var item: EquipmentItemData = equipment.get_item_by_id(item_id)

	if item == null:
		return false

	var previous_item: EquipmentItemData = equipment.get_equipped_item(item.slot)
	var removed_item_id: StringName = inventory.remove_item_at(item_index)

	if removed_item_id.is_empty() or not equipment.equip(item):
		if not removed_item_id.is_empty():
			inventory.add_item(removed_item_id)
		return false

	if previous_item != null and not inventory.add_item(previous_item.item_id):
		equipment.equip(previous_item)
		inventory.add_item(removed_item_id)
		show_save_status("Inventory Full")
		return false

	show_save_status("Equipped %s" % item.display_name)
	return true


func unequip_equipment_to_inventory(slot: StringName) -> bool:
	var equipped_item: EquipmentItemData = equipment.get_equipped_item(slot)

	if equipped_item == null:
		return false

	if inventory.is_full():
		show_save_status("Inventory Full")
		return false

	var removed_item: EquipmentItemData = equipment.unequip(slot)

	if removed_item == null or not inventory.add_item(removed_item.item_id):
		if removed_item != null:
			equipment.equip(removed_item)
		return false

	show_save_status("Unequipped %s" % removed_item.display_name)
	return true


func save_progression() -> bool:
	var result: Dictionary = save_coordinator.save_progression()
	show_save_status(result.get("message", "Save Failed"))
	return result.get("success", false)


func load_progression() -> bool:
	var result: Dictionary = save_coordinator.load_progression()
	show_save_status(result.get("message", "Game Loaded"))
	return result.get("success", false)


func get_gold() -> int:
	return gold


func set_progression_restore_active(is_active: bool) -> void:
	is_loading_progression = is_active


func restore_saved_gold(saved_gold: int) -> void:
	gold = saved_gold


func complete_progression_restore() -> void:
	is_loading_progression = false
	update_equipment_attribute_bonuses()
	apply_attribute_effects()
	update_gold_display()
	update_experience_display()
	equipment_panel.update_display()
	inventory_panel.update_display()


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
	if is_loading_progression:
		return

	apply_attribute_effects()
	equipment_panel.update_display()


func _on_equipment_updated() -> void:
	if is_loading_progression:
		return

	update_equipment_attribute_bonuses()
	apply_attribute_effects()
	equipment_panel.update_display()


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
	attack_damage = base_attack_damage + attributes.get_effective_bonus(&"strength")
	health.set_max_health(
		base_max_health + attributes.get_effective_bonus(&"vitality") * 5
	)
	fireball_skill.damage = (
		base_fireball_damage + attributes.get_effective_bonus(&"intelligence") * 2
	)


func update_equipment_attribute_bonuses() -> void:
	attributes.set_equipment_bonuses(
		equipment.get_total_attribute_bonus(&"strength"),
		equipment.get_total_attribute_bonus(&"dexterity"),
		equipment.get_total_attribute_bonus(&"intelligence"),
		equipment.get_total_attribute_bonus(&"vitality")
	)


func get_derived_stats_debug_data() -> Dictionary:
	return {
		"autoattack_damage": attack_damage,
		"fireball_damage": fireball_skill.damage,
		"max_health": health.max_health,
	}


func open_character_management() -> void:
	character_management_open = true
	set_management_panels_hidden()
	character_menu.visible = true
	character_menu_button.text = "Close Menu"
	mobile_movement_input = Vector2.ZERO
	velocity = Vector2.ZERO
	mobile_controls.call("reset_movement")
	mobile_controls.visible = false
	get_tree().paused = true


func close_character_management() -> void:
	character_management_open = false
	set_management_panels_hidden()
	character_menu_button.text = "Character"
	mobile_controls.visible = true
	get_tree().paused = false


func show_character_section(section_name: StringName) -> bool:
	if not character_management_open:
		return false

	set_management_panels_hidden()

	match section_name:
		&"attributes":
			attribute_panel.visible = true
		&"equipment":
			equipment_panel.visible = true
		&"inventory":
			inventory_panel.visible = true
		_:
			character_menu.visible = true
			return false

	return true


func set_management_panels_hidden() -> void:
	character_menu.visible = false
	attribute_panel.visible = false
	equipment_panel.visible = false
	inventory_panel.visible = false


# Kept as a small compatibility helper for code that opened Inventory directly.
func set_inventory_open(is_open: bool) -> void:
	if is_open:
		open_character_management()
		show_character_section(&"inventory")
	else:
		close_character_management()


func _exit_tree() -> void:
	if character_management_open:
		get_tree().paused = false


func update_save_status(delta: float) -> void:
	if save_status_remaining <= 0.0:
		return

	save_status_remaining = maxf(save_status_remaining - delta, 0.0)

	if save_status_remaining == 0.0:
		save_status_label.text = ""


func show_save_status(message: String) -> void:
	save_status_label.text = message
	save_status_remaining = 3.0
