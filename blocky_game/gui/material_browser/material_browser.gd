extends ColorRect

const Hotbar = preload("../hotbar/hotbar.gd")
const MaterialSlotScene = preload("material_slot.tscn")

@onready var _block_types = get_node(^"/root/Main/Game/Blocks")
@onready var _hotbar: Hotbar = get_node(^"../HotBar")
@onready var _search_box: LineEdit = $CC/PC/VB/Header/SearchBox
@onready var _material_grid: GridContainer = $CC/PC/VB/MaterialScroll/MaterialGrid

var _material_slots: Dictionary[int, Control] = {}


func _ready() -> void:
	_populate_materials()
	_search_box.text_changed.connect(_on_search_text_changed)
	_hotbar.items_changed.connect(_update_pin_icons)
	_update_pin_icons()


func _populate_materials() -> void:
	# Block zero is air, so it is not a material the player can pin.
	for block_id in range(1, _block_types.get_block_count()):
		var block = _block_types.get_block(block_id)
		var slot = MaterialSlotScene.instantiate()
		_material_grid.add_child(slot)
		slot.configure(block_id, block.base_info.name, block.base_info.sprite_texture)
		slot.pressed.connect(_on_material_pressed)
		_material_slots[block_id] = slot


func open_browser() -> void:
	show()


func close_browser() -> void:
	_search_box.release_focus()
	hide()


func _on_search_text_changed(query: String) -> void:
	var normalized_query := query.strip_edges().replace("_", " ").to_lower()
	for slot in _material_slots.values():
		var searchable_name: String = slot.get_material_name().replace("_", " ").to_lower()
		slot.visible = normalized_query.is_empty() or normalized_query in searchable_name


func _on_material_pressed(block_id: int) -> void:
	if _hotbar.is_material_pinned(block_id):
		_hotbar.unpin_material(block_id)
	else:
		_hotbar.pin_material(block_id)


func _update_pin_icons() -> void:
	for block_id in _material_slots:
		_material_slots[block_id].set_pinned(_hotbar.is_material_pinned(block_id))
