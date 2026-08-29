extends Control

signal pressed(block_id: int)

@onready var _hover: TextureRect = $Hover
@onready var _icon: TextureRect = $Icon
@onready var _pin: TextureRect = $Pin

var _block_id := 0
var _material_name := ""


func configure(block_id: int, material_name: String, texture: Texture2D) -> void:
	_block_id = block_id
	_material_name = material_name
	_icon.texture = texture
	tooltip_text = material_name.replace("_", " ").capitalize()


func get_material_name() -> String:
	return _material_name


func set_pinned(pinned: bool) -> void:
	_pin.visible = pinned


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(_block_id)
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
