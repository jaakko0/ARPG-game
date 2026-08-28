extends Area2D

const EquipmentItemData = preload("res://scripts/equipment_item_data.gd")

@export var item_data: EquipmentItemData
@export var collector_group: StringName = &"player"

@onready var item_label: Label = $ItemLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	update_display()


func setup(equipment_item: EquipmentItemData) -> void:
	item_data = equipment_item

	if is_node_ready():
		update_display()


func _on_body_entered(body: Node) -> void:
	if (
		item_data == null
		or not body.is_in_group(collector_group)
		or not body.has_method("collect_equipment_item")
	):
		return

	if body.call("collect_equipment_item", item_data):
		queue_free()


func update_display() -> void:
	item_label.text = "Equipment" if item_data == null else item_data.display_name
