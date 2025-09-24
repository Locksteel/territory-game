extends Window
class_name CreateUnitDialog

@onready var header: Label = $VBoxContainer/Header
@onready var type_selector: OptionButton = $VBoxContainer/Type/TypeSelector
@onready var name_edit: LineEdit = $VBoxContainer/Name/NameEdit

var creator: Player
var temp_resources: int

signal done(data: Array)

func _ready() -> void:
	Unit.fill_unit_selector(type_selector)


func _on_about_to_popup() -> void:
	if not creator:
		# Invalid, cancel call
		emit_signal("done", null)
		hide()
	
	header.text = creator.name + ": Create a Unit"
	name_edit.clear()


func _on_create_pressed() -> void:
	hide()
	
	var selected_type: Unit.UnitType = type_selector.get_selected_id()
	var name = name_edit.text
	
	# Success, return unit data
	emit_signal("done", [selected_type, name])


func _on_close_requested() -> void:
	hide()
	# Cancelled
	emit_signal("done", null)

func _on_cancel_pressed() -> void:
	_on_close_requested()
