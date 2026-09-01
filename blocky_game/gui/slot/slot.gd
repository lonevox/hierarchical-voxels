@tool
extends Control

signal pressed(slot_item: SlotItem)


@export var slot_item: SlotItem:
	set(value):
		if slot_item == value:
			return
		if slot_item and slot_item.changed.is_connected(_on_slot_item_changed):
			slot_item.changed.disconnect(_on_slot_item_changed)
		
		slot_item = value
		
		if slot_item:
			slot_item.changed.connect(_on_slot_item_changed)
		if is_node_ready():
			_on_slot_item_changed()

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			%IconTextureRect.texture = icon

@export var selected := false:
	set(value):
		selected = value
		if is_node_ready():
			%OutlinePanel.self_modulate = Color.WHITE if selected else Color.TRANSPARENT


func _ready() -> void:
	%IconTextureRect.texture = icon
	%OutlinePanel.self_modulate = Color.WHITE if selected else Color.TRANSPARENT
	_on_slot_item_changed()


func _on_slot_item_changed() -> void:
	if not is_node_ready():
		return
	if slot_item is SlotItem2D:
		%TextureRect.texture = slot_item.texture
	elif slot_item is SlotItem3D:
		%MeshInstance3D.mesh = slot_item.mesh
		%MeshInstance3D.material_override = slot_item.material
		%TextureRect.texture = %SubViewport.get_texture()
	else:
		%TextureRect.texture = null
		%MeshInstance3D.mesh = null
		%MeshInstance3D.material_override = null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		pressed.emit(slot_item)
		accept_event()
