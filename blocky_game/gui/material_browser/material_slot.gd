extends Control

signal pressed(material_id: int)

@onready var _hover: TextureRect = $Hover
@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Label
@onready var _pin: TextureRect = $Pin

var _material_id := 0
var _material_name := ""


func configure(material_id: int, material_name: String, texture: Texture2D) -> void:
	_material_id = material_id
	_material_name = material_name
	_icon.texture = texture
	_label.text = material_name.replace("_", " ").capitalize()
	_label.visible = texture == null
	tooltip_text = material_name.replace("_", " ").capitalize()


func get_material_name() -> String:
	return _material_name


func set_pinned(pinned: bool) -> void:
	_pin.visible = pinned


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(_material_id)
		accept_event()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hover.show()
		NOTIFICATION_MOUSE_EXIT:
			_hover.hide()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_hover.hide()
