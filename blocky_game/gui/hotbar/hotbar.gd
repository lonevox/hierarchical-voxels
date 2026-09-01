@tool
extends Container

signal items_changed

const Slot = preload("../slot/slot.gd")
const VISIBLE_SLOT_COUNT := 5
const SELECTED_SLOT_INDEX := 2

@export var selected := false:
	set(value):
		selected = value
		self_modulate = Color.WHITE if selected else Color.TRANSPARENT

@onready var _slot_container: HBoxContainer = %HBoxContainer

var _items: Array[SlotItem] = []
var _selected_item_index := 0


func _ready() -> void:
	assert(_slot_container.get_child_count() == VISIBLE_SLOT_COUNT)
	self_modulate = Color.WHITE if selected else Color.TRANSPARENT
	_update_views()


func set_items(items: Array[SlotItem]) -> void:
	_items = items.duplicate()
	_selected_item_index = 0
	_update_views_if_ready()
	items_changed.emit()


func add_item(item: SlotItem) -> void:
	assert(item != null)
	_items.append(item)
	_update_views_if_ready()
	items_changed.emit()


func remove_item(item: SlotItem) -> bool:
	var item_index := _items.find(item)
	if item_index == -1:
		return false
	remove_item_at(item_index)
	return true


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


func has_item(item: SlotItem) -> bool:
	return item in _items


func get_item_count() -> int:
	return _items.size()


func _update_views_if_ready() -> void:
	if is_node_ready():
		_update_views()


func _update_views() -> void:
	if _items.is_empty():
		for slot_index in VISIBLE_SLOT_COUNT:
			var slot_view: Slot = _slot_container.get_child(slot_index)
			slot_view.slot_item = null
		return

	var visible_item_count := mini(_items.size(), VISIBLE_SLOT_COUNT)
	var left_item_count := mini(
		SELECTED_SLOT_INDEX,
		floori(float(visible_item_count - 1) / 2.0)
	)
	var right_item_count := visible_item_count - left_item_count - 1

	for slot_index in VISIBLE_SLOT_COUNT:
		var item: SlotItem = null
		var offset := slot_index - SELECTED_SLOT_INDEX
		if offset >= -left_item_count and offset <= right_item_count:
			var item_index := posmod(_selected_item_index + offset, _items.size())
			item = _items[item_index]

		var slot_view: Slot = _slot_container.get_child(slot_index)
		slot_view.slot_item = item


## Rotates the item currently displayed in slot [param slot_index] into the
## selected center slot. Empty visible slots do nothing.
func select_slot(slot_index: int) -> void:
	assert(slot_index >= 0 and slot_index < VISIBLE_SLOT_COUNT)
	if not selected or _items.is_empty():
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


func get_selected_item() -> SlotItem:
	if _items.is_empty():
		return null
	return _items[_selected_item_index]


func try_select_item(item: SlotItem) -> bool:
	var item_index := _items.find(item)
	if item_index == -1:
		return false
	_select_item(item_index)
	return true


func select_next_slot() -> void:
	if selected:
		_select_item(_selected_item_index + 1)


func select_previous_slot() -> void:
	if selected:
		_select_item(_selected_item_index - 1)
