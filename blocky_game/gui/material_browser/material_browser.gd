extends ColorRect

signal material_pressed(material_id: int)

const SlotScene = preload("../slot/slot.tscn")
const Slot = preload("../slot/slot.gd")
const PIN_ICON := preload("Pin.svg")

@onready var _blocks = get_node(^"/root/Main/Game/Blocks")
@onready var _search_box: LineEdit = $CC/PC/VB/Header/SearchBox
@onready var _material_grid: GridContainer = $CC/PC/VB/MaterialScroll/MaterialGrid

var _material_slots: Dictionary[int, Slot] = {}
var _material_items: Dictionary[int, SlotItem3D] = {}
var _material_names: Dictionary[int, StringName] = {}
var _preview_mesh := BoxMesh.new()


func _ready() -> void:
	_populate_materials()
	_search_box.text_changed.connect(_on_search_text_changed)


func _populate_materials() -> void:
	for material_id in _blocks.get_material_count():
		var material_name: StringName = _blocks.get_material_name(material_id)
		var item := SlotItem3D.new()
		item.mesh = _preview_mesh
		item.material = _blocks.get_material_by_id(material_id)

		var slot: Slot = SlotScene.instantiate()
		_material_grid.add_child(slot)
		slot.slot_item = item
		slot.tooltip_text = String(material_name).replace("_", " ").capitalize()
		slot.pressed.connect(_on_slot_pressed.bind(material_id))
		_material_slots[material_id] = slot
		_material_items[material_id] = item
		_material_names[material_id] = material_name


func open_browser() -> void:
	show()


func close_browser() -> void:
	_search_box.release_focus()
	hide()


func _on_search_text_changed(query: String) -> void:
	var normalized_query := query.strip_edges().replace("_", " ").to_lower()
	for material_id in _material_slots:
		var searchable_name := String(_material_names[material_id]).replace("_", " ").to_lower()
		_material_slots[material_id].visible = (
			normalized_query.is_empty() or normalized_query in searchable_name
		)


func get_material_ids() -> Array[int]:
	var material_ids: Array[int] = []
	material_ids.assign(_material_items.keys())
	return material_ids


func get_material_item(material_id: int) -> SlotItem3D:
	return _material_items.get(material_id) as SlotItem3D


func get_material_id(item: SlotItem) -> int:
	for material_id in _material_items:
		if _material_items[material_id] == item:
			return material_id
	return -1


func set_material_pinned(material_id: int, pinned: bool) -> void:
	assert(_material_slots.has(material_id))
	_material_slots[material_id].icon = PIN_ICON if pinned else null


func _on_slot_pressed(_item: SlotItem, material_id: int) -> void:
	material_pressed.emit(material_id)
