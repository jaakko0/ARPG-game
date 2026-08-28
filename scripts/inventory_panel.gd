extends PanelContainer

const EquipmentItemData = preload("res://scripts/equipment_item_data.gd")
const EquipmentSlots = preload("res://scripts/equipment_slots.gd")

signal close_requested

@onready var capacity_label: Label = $Margin/VBox/CapacityLabel
@onready var item_list: ItemList = $Margin/VBox/ItemList
@onready var selected_item_label: Label = $Margin/VBox/SelectedItemLabel
@onready var equip_button: Button = $Margin/VBox/EquipSelectedButton
@onready var derived_stats_label: Label = $Margin/VBox/DerivedStatsLabel

var inventory: Node
var equipment: Node
var attributes: Node
var player: Node
var selected_inventory_index: int = -1
var slot_labels: Dictionary


func _ready() -> void:
	slot_labels = {
		&"weapon": $Margin/VBox/EquippedSlots/WeaponValue,
		&"head": $Margin/VBox/EquippedSlots/HeadValue,
		&"chest": $Margin/VBox/EquippedSlots/ChestValue,
		&"hands": $Margin/VBox/EquippedSlots/HandsValue,
		&"feet": $Margin/VBox/EquippedSlots/FeetValue,
		&"ring": $Margin/VBox/EquippedSlots/RingValue,
		&"amulet": $Margin/VBox/EquippedSlots/AmuletValue,
	}
	$Margin/VBox/Header/CloseButton.pressed.connect(close_requested.emit)
	item_list.item_selected.connect(_on_item_selected)
	equip_button.pressed.connect(_on_equip_selected_pressed)


func setup(
	inventory_component: Node,
	equipment_component: Node,
	attribute_component: Node,
	player_node: Node
) -> void:
	inventory = inventory_component
	equipment = equipment_component
	attributes = attribute_component
	player = player_node

	if not inventory.is_connected("inventory_updated", update_display):
		inventory.connect("inventory_updated", update_display)

	if not equipment.is_connected("equipment_updated", update_display):
		equipment.connect("equipment_updated", update_display)

	if not attributes.is_connected("attributes_updated", update_display):
		attributes.connect("attributes_updated", update_display)

	update_display()


func update_display() -> void:
	if inventory == null or equipment == null or attributes == null or player == null:
		return

	var previous_selection := selected_inventory_index
	var inventory_item_ids: Array = inventory.call("get_item_ids")
	item_list.clear()

	for item_id_value in inventory_item_ids:
		var item_id := StringName(item_id_value)
		var item: EquipmentItemData = equipment.call("get_item_by_id", item_id)

		if item != null:
			item_list.add_item("%s  [%s]" % [
				item.display_name,
				EquipmentSlots.get_display_name(item.slot),
			])

	capacity_label.text = "Equipment items: %d / %d" % [
		inventory.call("get_item_count"),
		inventory.get("capacity"),
	]

	if item_list.item_count > 0:
		selected_inventory_index = clampi(previous_selection, 0, item_list.item_count - 1)
		item_list.select(selected_inventory_index)
	else:
		selected_inventory_index = -1

	update_selected_item_display()
	update_equipped_display()


func _on_item_selected(item_index: int) -> void:
	selected_inventory_index = item_index
	update_selected_item_display()


func _on_equip_selected_pressed() -> void:
	if player != null and selected_inventory_index >= 0:
		player.call("equip_inventory_item", selected_inventory_index)


func update_selected_item_display() -> void:
	if inventory == null or equipment == null or selected_inventory_index < 0:
		selected_item_label.text = "Select an item, then tap Equip Selected."
		equip_button.disabled = true
		return

	var item_id: StringName = inventory.call("get_item_id_at", selected_inventory_index)
	var item: EquipmentItemData = equipment.call("get_item_by_id", item_id)

	if item == null:
		selected_item_label.text = "Unknown item"
		equip_button.disabled = true
		return

	selected_item_label.text = "%s — %s" % [item.display_name, get_bonus_text(item)]
	equip_button.disabled = false


func update_equipped_display() -> void:
	for slot in EquipmentSlots.ALL:
		var item: EquipmentItemData = equipment.call("get_equipped_item", slot)
		var value_label := slot_labels.get(slot) as Label

		if value_label != null:
			value_label.text = "Empty" if item == null else item.display_name

	var derived_stats: Dictionary = player.call("get_derived_stats_debug_data")
	derived_stats_label.text = "Effective STR %d  DEX %d  INT %d  VIT %d\nAttack %d  Fireball %d  Max HP %d" % [
		attributes.call("get_effective_value", &"strength"),
		attributes.call("get_effective_value", &"dexterity"),
		attributes.call("get_effective_value", &"intelligence"),
		attributes.call("get_effective_value", &"vitality"),
		derived_stats.get("autoattack_damage", 0),
		derived_stats.get("fireball_damage", 0),
		derived_stats.get("max_health", 0),
	]


func get_bonus_text(item: EquipmentItemData) -> String:
	var bonuses: Array[String] = []

	if item.strength_bonus > 0:
		bonuses.append("+%d STR" % item.strength_bonus)
	if item.dexterity_bonus > 0:
		bonuses.append("+%d DEX" % item.dexterity_bonus)
	if item.intelligence_bonus > 0:
		bonuses.append("+%d INT" % item.intelligence_bonus)
	if item.vitality_bonus > 0:
		bonuses.append("+%d VIT" % item.vitality_bonus)

	return "No bonuses" if bonuses.is_empty() else ", ".join(bonuses)
