extends PanelContainer

signal close_requested

@onready var points_label: Label = $Margin/VBox/PointsLabel
@onready var strength_label: Label = $Margin/VBox/StrengthRow/ValueLabel
@onready var dexterity_label: Label = $Margin/VBox/DexterityRow/ValueLabel
@onready var intelligence_label: Label = $Margin/VBox/IntelligenceRow/ValueLabel
@onready var vitality_label: Label = $Margin/VBox/VitalityRow/ValueLabel
@onready var strength_button: Button = $Margin/VBox/StrengthRow/AddButton
@onready var dexterity_button: Button = $Margin/VBox/DexterityRow/AddButton
@onready var intelligence_button: Button = $Margin/VBox/IntelligenceRow/AddButton
@onready var vitality_button: Button = $Margin/VBox/VitalityRow/AddButton

var attributes: Node


func _ready() -> void:
	$Margin/VBox/Header/BackButton.pressed.connect(close_requested.emit)
	strength_button.pressed.connect(_spend_attribute.bind(&"strength"))
	dexterity_button.pressed.connect(_spend_attribute.bind(&"dexterity"))
	intelligence_button.pressed.connect(_spend_attribute.bind(&"intelligence"))
	vitality_button.pressed.connect(_spend_attribute.bind(&"vitality"))


func setup(attribute_component: Node) -> void:
	attributes = attribute_component

	if not attributes.is_connected("attributes_updated", update_display):
		attributes.connect("attributes_updated", update_display)

	update_display()


func _spend_attribute(attribute_name: StringName) -> void:
	if attributes != null:
		attributes.call("spend_point", attribute_name)


func update_display() -> void:
	if attributes == null:
		return

	points_label.text = "Attribute Points: %d" % attributes.get("unspent_points")
	strength_label.text = "STR: %d" % attributes.call("get_value", &"strength")
	dexterity_label.text = "DEX: %d" % attributes.call("get_value", &"dexterity")
	intelligence_label.text = "INT: %d" % attributes.call("get_value", &"intelligence")
	vitality_label.text = "VIT: %d" % attributes.call("get_value", &"vitality")

	var cannot_spend: bool = attributes.get("unspent_points") <= 0
	strength_button.disabled = cannot_spend
	dexterity_button.disabled = cannot_spend
	intelligence_button.disabled = cannot_spend
	vitality_button.disabled = cannot_spend
