@tool
extends SlotItem
class_name SlotItem2D

@export var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
