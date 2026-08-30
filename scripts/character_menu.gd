extends PanelContainer

signal section_requested(section_name: StringName)
signal close_requested


func _ready() -> void:
	$Margin/VBox/AttributesButton.pressed.connect(
		section_requested.emit.bind(&"attributes")
	)
	$Margin/VBox/EquipmentButton.pressed.connect(
		section_requested.emit.bind(&"equipment")
	)
	$Margin/VBox/InventoryButton.pressed.connect(
		section_requested.emit.bind(&"inventory")
	)
	$Margin/VBox/CloseButton.pressed.connect(close_requested.emit)
