extends Window

@onready var name_node: LineEdit = $VBoxContainer/PlayerName
@onready var color_node: ColorPickerButton = $VBoxContainer/PlayerColor
@onready var unit_count_node: SpinBox = $VBoxContainer/Units/Count

func _on_about_to_popup() -> void:
	name_node.text = ""
	color_node.color = Color.WHITE
