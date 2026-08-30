extends CenterContainer

signal items_changed

const HotbarItem = preload("../../player/hotbar_item.gd")

const VISIBLE_SLOT_COUNT := 9
const SELECTED_SLOT_INDEX := 4

@onready var _slot_container = $HBoxContainer
@onready var _blocks = get_node(^"/root/Main/Game/Blocks")

var _items: Array[HotbarItem] = []
var _selected_item_index := 0


func _ready() -> void:
	assert(_slot_container.get_child_count() == VISIBLE_SLOT_COUNT)
	_update_views()


func set_items(items: Array[HotbarItem]) -> void:
	_items = items.duplicate()
	_selected_item_index = 0
	_update_views_if_ready()
	items_changed.emit()


func add_item(item: HotbarItem) -> void:
	_items.append(item)
	_update_views_if_ready()
	items_changed.emit()


func remove_item_at(item_index: int) -> void:
	assert(item_index >= 0 and item_index < _items.size())
	_items.remove_at(item_index)

	if _items.is_empty():
		_selected_item_index = 0
	elif item_index < _selected_item_index:
		_selected_item_index -= 1
	else:
		_selected_item_index %= _items.size()

	_update_views_if_ready()
	items_changed.emit()


func pin_material(material_id: int) -> void:
	if is_material_pinned(material_id):
		return

	var item := HotbarItem.new()
	item.type = HotbarItem.TYPE_MATERIAL
	item.id = material_id
	add_item(item)


func unpin_material(material_id: int) -> void:
	for item_index in _items.size():
		var item := _items[item_index]
		if item != null and item.type == HotbarItem.TYPE_MATERIAL and item.id == material_id:
			remove_item_at(item_index)
			return


func is_material_pinned(material_id: int) -> bool:
	for item in _items:
		if item != null and item.type == HotbarItem.TYPE_MATERIAL and item.id == material_id:
			return true
	return false


func get_item_count() -> int:
	return _items.size()


func _update_views_if_ready() -> void:
	if is_node_ready():
		_update_views()


func _update_views() -> void:
	if _items.is_empty():
		for slot_index in VISIBLE_SLOT_COUNT:
			var slot_view = _slot_container.get_child(slot_index)
			slot_view.get_display().set_item(null)
		return

	var visible_item_count := mini(_items.size(), VISIBLE_SLOT_COUNT)
	var left_item_count := mini(
		SELECTED_SLOT_INDEX,
		floori(float(visible_item_count - 1) / 2.0)
	)
	var right_item_count := visible_item_count - left_item_count - 1

	for slot_index in VISIBLE_SLOT_COUNT:
		var item: HotbarItem = null
		var offset := slot_index - SELECTED_SLOT_INDEX
		if offset >= -left_item_count and offset <= right_item_count:
			var item_index := posmod(_selected_item_index + offset, _items.size())
			item = _items[item_index]

		var slot_view = _slot_container.get_child(slot_index)
		slot_view.get_display().set_item(item)


## Rotates the item currently displayed in slot [param slot_index] into the
## selected center slot. Empty visible slots do nothing.
func select_slot(slot_index: int) -> void:
	assert(slot_index >= 0 and slot_index < VISIBLE_SLOT_COUNT)
	if _items.is_empty():
		return

	var visible_item_count := mini(_items.size(), VISIBLE_SLOT_COUNT)
	var left_item_count := mini(SELECTED_SLOT_INDEX, floori(float(visible_item_count - 1) / 2.0))
	var right_item_count := visible_item_count - left_item_count - 1
	var offset := slot_index - SELECTED_SLOT_INDEX
	if offset < -left_item_count or offset > right_item_count:
		return

	_select_item(_selected_item_index + offset)


func _select_item(item_index: int) -> void:
	if _items.is_empty():
		return

	item_index = posmod(item_index, _items.size())
	if _selected_item_index == item_index:
		return

	_selected_item_index = item_index
	_update_views_if_ready()

	var item := _items[_selected_item_index]
	if is_node_ready() and item != null:
		if item.type == HotbarItem.TYPE_MATERIAL:
			print("Hotbar select material ", _blocks.get_material_name(item.id))

		elif item.type == HotbarItem.TYPE_ITEM:
			# TODO Item db
			print("Hotbar select item ", item.id)


func get_selected_item() -> HotbarItem:
	if _items.is_empty():
		return null
	return _items[_selected_item_index]


func try_select_slot_by_material_id(material_id: int) -> void:
	for item_index in _items.size():
		var item := _items[item_index]
		if item != null and item.type == HotbarItem.TYPE_MATERIAL and item.id == material_id:
			_select_item(item_index)
			return


func select_next_slot() -> void:
	_select_item(_selected_item_index + 1)


func select_previous_slot() -> void:
	_select_item(_selected_item_index - 1)
