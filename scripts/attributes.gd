extends Node

signal attribute_changed(attribute_name: StringName, new_value: int)
signal points_changed(unspent_points: int)
signal attributes_updated

const STRENGTH: StringName = &"strength"
const DEXTERITY: StringName = &"dexterity"
const INTELLIGENCE: StringName = &"intelligence"
const VITALITY: StringName = &"vitality"

@export_range(0, 1000, 1) var base_strength: int = 5
@export_range(0, 1000, 1) var base_dexterity: int = 5
@export_range(0, 1000, 1) var base_intelligence: int = 5
@export_range(0, 1000, 1) var base_vitality: int = 5

var strength: int
var dexterity: int
var intelligence: int
var vitality: int
var unspent_points: int = 0


func _ready() -> void:
	strength = base_strength
	dexterity = base_dexterity
	intelligence = base_intelligence
	vitality = base_vitality


func grant_points(amount: int) -> void:
	if amount <= 0:
		return

	unspent_points += amount
	points_changed.emit(unspent_points)
	attributes_updated.emit()


func spend_point(attribute_name: StringName) -> bool:
	if unspent_points <= 0:
		return false

	match attribute_name:
		STRENGTH:
			strength += 1
		DEXTERITY:
			dexterity += 1
		INTELLIGENCE:
			intelligence += 1
		VITALITY:
			vitality += 1
		_:
			return false

	unspent_points -= 1
	attribute_changed.emit(attribute_name, get_value(attribute_name))
	points_changed.emit(unspent_points)
	attributes_updated.emit()
	return true


func get_value(attribute_name: StringName) -> int:
	match attribute_name:
		STRENGTH:
			return strength
		DEXTERITY:
			return dexterity
		INTELLIGENCE:
			return intelligence
		VITALITY:
			return vitality
		_:
			return 0


func get_base_value(attribute_name: StringName) -> int:
	match attribute_name:
		STRENGTH:
			return base_strength
		DEXTERITY:
			return base_dexterity
		INTELLIGENCE:
			return base_intelligence
		VITALITY:
			return base_vitality
		_:
			return 0


func get_bonus(attribute_name: StringName) -> int:
	return maxi(get_value(attribute_name) - get_base_value(attribute_name), 0)


func restore_values(
	saved_strength: int,
	saved_dexterity: int,
	saved_intelligence: int,
	saved_vitality: int,
	saved_unspent_points: int
) -> bool:
	if (
		saved_strength < 0
		or saved_dexterity < 0
		or saved_intelligence < 0
		or saved_vitality < 0
		or saved_unspent_points < 0
	):
		return false

	strength = saved_strength
	dexterity = saved_dexterity
	intelligence = saved_intelligence
	vitality = saved_vitality
	unspent_points = saved_unspent_points
	attribute_changed.emit(STRENGTH, strength)
	attribute_changed.emit(DEXTERITY, dexterity)
	attribute_changed.emit(INTELLIGENCE, intelligence)
	attribute_changed.emit(VITALITY, vitality)
	points_changed.emit(unspent_points)
	attributes_updated.emit()
	return true
