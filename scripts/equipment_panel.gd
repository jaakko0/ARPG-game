extends PanelContainer

const EquipmentItemData = preload("res://scripts/equipment_item_data.gd")
const EquipmentSlots = preload("res://scripts/equipment_slots.gd")

signal close_requested

@onready var effective_attributes_label: Label = $Margin/VBox/EffectiveAttributesLabel
@onready var derived_stats_label: Label = $Margin/VBox/DerivedStatsLabel

var equipment: Node
var attributes: Node
var derived_stats_provider: Node
var slot_labels: Dictionary


func _ready() -> void:
	$Margin/VBox/Header/BackButton.pressed.connect(close_requested.emit)
	slot_labels = {
		&"weapon": $Margin/VBox/Slots/WeaponValue,
		&"head": $Margin/VBox/Slots/HeadValue,
		&"chest": $Margin/VBox/Slots/ChestValue,
		&"hands": $Margin/VBox/Slots/HandsValue,
		&"feet": $Margin/VBox/Slots/FeetValue,
		&"ring": $Margin/VBox/Slots/RingValue,
		&"amulet": $Margin/VBox/Slots/AmuletValue,
	}
	$Margin/VBox/WeaponButtons/TrainingSwordButton.pressed.connect(
		_equip_item.bind(&"training_sword")
	)
	$Margin/VBox/WeaponButtons/PracticeBladeButton.pressed.connect(
		_equip_item.bind(&"practice_blade")
	)
	$Margin/VBox/WeaponButtons/UnequipWeaponButton.pressed.connect(
		_unequip_slot.bind(&"weapon")
	)
	$Margin/VBox/HeadButtons/ApprenticeHoodButton.pressed.connect(
		_equip_item.bind(&"apprentice_hood")
	)
	$Margin/VBox/HeadButtons/UnequipHeadButton.pressed.connect(
		_unequip_slot.bind(&"head")
	)
	$Margin/VBox/ChestButtons/SturdyVestButton.pressed.connect(
		_equip_item.bind(&"sturdy_vest")
	)
	$Margin/VBox/ChestButtons/UnequipChestButton.pressed.connect(
		_unequip_slot.bind(&"chest")
	)


func setup(
	equipment_component: Node,
	attribute_component: Node,
	stats_provider: Node
) -> void:
	equipment = equipment_component
	attributes = attribute_component
	derived_stats_provider = stats_provider

	if not equipment.is_connected("equipment_updated", update_display):
		equipment.connect("equipment_updated", update_display)

	if not attributes.is_connected("attributes_updated", update_display):
		attributes.connect("attributes_updated", update_display)

	update_display()


func _equip_item(item_id: StringName) -> void:
	if derived_stats_provider != null:
		derived_stats_provider.call("add_debug_inventory_item", item_id)


func _unequip_slot(slot: StringName) -> void:
	if derived_stats_provider != null:
		derived_stats_provider.call("unequip_equipment_to_inventory", slot)


func update_display() -> void:
	if equipment == null or attributes == null or derived_stats_provider == null:
		return

	for slot in EquipmentSlots.ALL:
		var item: EquipmentItemData = equipment.call("get_equipped_item", slot)
		var value_label := slot_labels.get(slot) as Label

		if value_label != null:
			value_label.text = "Empty" if item == null else item.display_name

	effective_attributes_label.text = "Effective  STR %d   DEX %d   INT %d   VIT %d" % [
		attributes.call("get_effective_value", &"strength"),
		attributes.call("get_effective_value", &"dexterity"),
		attributes.call("get_effective_value", &"intelligence"),
		attributes.call("get_effective_value", &"vitality"),
	]

	var derived_stats: Dictionary = derived_stats_provider.call("get_derived_stats_debug_data")
	derived_stats_label.text = "Attack %d   Fireball %d   Max HP %d" % [
		derived_stats.get("autoattack_damage", 0),
		derived_stats.get("fireball_damage", 0),
		derived_stats.get("max_health", 0),
	]
