extends Node

@onready var source := get_parent() as Node2D

var skill_slots: Array[Node] = []


func _ready() -> void:
	for child in get_children():
		if child.has_method("update_autocast"):
			skill_slots.append(child)


func _physics_process(delta: float) -> void:
	update_autocast_skills(delta)


func update_autocast_skills(delta: float) -> void:
	if not is_source_available():
		return

	for skill in skill_slots:
		if is_instance_valid(skill) and skill.has_method("update_autocast"):
			skill.call("update_autocast", delta, source.global_position)


func get_skill_in_slot(slot_index: int) -> Node:
	if slot_index < 0 or slot_index >= skill_slots.size():
		return null

	var skill := skill_slots[slot_index]

	if not is_instance_valid(skill):
		return null

	return skill


func set_skill_in_slot(slot_index: int, skill: Node) -> bool:
	if slot_index < 0 or (skill != null and not skill.has_method("update_autocast")):
		return false

	while skill_slots.size() <= slot_index:
		skill_slots.append(null)

	skill_slots[slot_index] = skill
	return true


func apply_intelligence_bonus(attribute_bonus: int) -> void:
	for skill in skill_slots:
		if is_instance_valid(skill) and skill.has_method("apply_intelligence_bonus"):
			skill.call("apply_intelligence_bonus", attribute_bonus)


func is_source_available() -> bool:
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
		return false

	var source_health := source.get_node_or_null("Health")

	if source_health != null and int(source_health.get("current_health")) <= 0:
		return false

	return true
