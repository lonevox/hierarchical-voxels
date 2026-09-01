@tool
extends SlotItem
class_name SlotItem3D

@export var mesh: Mesh:
	set(value):
		mesh = value
		emit_changed()
@export var material: Material:
	set(value):
		material = value
		emit_changed()
