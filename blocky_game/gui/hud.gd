class_name PlayerHUD
extends Control

const Hotbar = preload("./hotbar/hotbar.gd")
const Blocks = preload("../blocks/blocks.gd")

enum State {
	GAMEPLAY,
	PAUSED,
	MATERIAL_BROWSER,
	RADIAL_MENU,
}

signal state_changed(state: int)
signal quit_requested

@onready var _crosshair: Control = $Crosshair
@onready var _blocks: Blocks = get_node(^"/root/Main/Game/Blocks")
@onready var _material_hotbar: Hotbar = $HotBars/HBoxContainer/MaterialHotBar
@onready var _shape_hotbar: Hotbar = $HotBars/HBoxContainer/ShapeHotBar
@onready var _pause_menu = $PauseMenu
@onready var _material_browser = $MaterialBrowser
@onready var _radial_menu: RadialMenu = $RadialMenu

var _state_machine: StateMachine
var _gameplay_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _selected_hotbar: Hotbar
var _shape_items: Dictionary[StringName, SlotItem3D] = {}


func _ready() -> void:
	_pause_menu.quit_requested.connect(_on_pause_menu_quit_requested)
	_populate_shape_hotbar()
	_select_hotbar(_material_hotbar)
	_update_material_pin_icons()

	_state_machine = StateMachine.new(State.GAMEPLAY)
	_state_machine.add_state(State.GAMEPLAY, _enter_gameplay, _exit_gameplay)
	_state_machine.add_state(State.PAUSED, _enter_paused, _exit_paused)
	_state_machine.add_state(State.MATERIAL_BROWSER, _enter_material_browser, _exit_material_browser)
	_state_machine.add_state(State.RADIAL_MENU, _enter_radial_menu, _exit_radial_menu)
	_state_machine.state_changed.connect(_on_state_changed)
	_state_machine.start()


func _process(_delta: float) -> void:
	if not _state_machine.is_in_state(State.GAMEPLAY) \
			and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
	if _state_machine.is_in_state(State.RADIAL_MENU) and event is InputEventMouse:
		# The radial menu has no Control nodes to consume pointer input for it, so we handle it here.
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud"):
		visible = !visible
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause") and _state_machine.is_in_state(State.GAMEPLAY):
		_state_machine.transition_to(State.PAUSED)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_close_dialog") and _state_machine.is_in_state(State.PAUSED):
		_state_machine.transition_to(State.GAMEPLAY)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("switch_hotbar") and _state_machine.is_in_state(State.GAMEPLAY):
		_switch_hotbar()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_material_browser"):
		_toggle_material_browser()
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_close_dialog") and _state_machine.is_in_state(State.MATERIAL_BROWSER):
		_state_machine.transition_to(State.GAMEPLAY)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("show_building_radial_menu"):
		if _state_machine.is_in_state(State.GAMEPLAY):
			_state_machine.transition_to(State.RADIAL_MENU)
		get_viewport().set_input_as_handled()
	elif event.is_action_released("show_building_radial_menu"):
		if _state_machine.is_in_state(State.RADIAL_MENU):
			_state_machine.transition_to(State.GAMEPLAY)
		get_viewport().set_input_as_handled()
	elif not _state_machine.is_in_state(State.GAMEPLAY) and event is InputEventMouse:
		# Material browser Controls normally consume their own mouse input. This catches
		# anything they intentionally allow through before it reaches the world.
		get_viewport().set_input_as_handled()


func _toggle_material_browser() -> void:
	if _state_machine.is_in_state(State.GAMEPLAY):
		_state_machine.transition_to(State.MATERIAL_BROWSER)
	elif _state_machine.is_in_state(State.MATERIAL_BROWSER):
		_state_machine.transition_to(State.GAMEPLAY)


func get_hotbar() -> Hotbar:
	return _selected_hotbar


func get_selected_material_id() -> int:
	return _material_browser.get_material_id(_material_hotbar.get_selected_item())


func get_selected_shape_name() -> StringName:
	var item := _shape_hotbar.get_selected_item()
	for shape_name in _shape_items:
		if _shape_items[shape_name] == item:
			return shape_name
	return Blocks.DEFAULT_SHAPE


func try_select_material(material_id: int) -> void:
	var item: SlotItem = _material_browser.get_material_item(material_id)
	if item != null:
		_material_hotbar.try_select_item(item)


func try_select_shape(shape_name: StringName) -> void:
	if _shape_items.has(shape_name):
		_shape_hotbar.try_select_item(_shape_items[shape_name])


func select_hotbar_slot(slot_index: int) -> void:
	_selected_hotbar.select_slot(slot_index)


func select_next_hotbar_slot() -> void:
	_selected_hotbar.select_next_slot()


func select_previous_hotbar_slot() -> void:
	_selected_hotbar.select_previous_slot()


func _populate_shape_hotbar() -> void:
	var items: Array[SlotItem] = []
	for shape_name in _blocks.get_single_voxel_shape_names():
		var item := SlotItem3D.new()
		item.mesh = _blocks.get_shape_mesh(shape_name)
		item.material = null
		_shape_items[shape_name] = item
		items.append(item)
	_shape_hotbar.set_items(items)
	assert(_shape_items.has(Blocks.DEFAULT_SHAPE))
	_shape_hotbar.try_select_item(_shape_items[Blocks.DEFAULT_SHAPE])


func _select_hotbar(hotbar: Hotbar) -> void:
	_selected_hotbar = hotbar
	_material_hotbar.selected = hotbar == _material_hotbar
	_shape_hotbar.selected = hotbar == _shape_hotbar


func _switch_hotbar() -> void:
	_select_hotbar(
		_shape_hotbar if _selected_hotbar == _material_hotbar else _material_hotbar
	)


func _enter_gameplay() -> void:
	_crosshair.visible = true
	Input.set_mouse_mode(_gameplay_mouse_mode)


func _exit_gameplay() -> void:
	_crosshair.visible = false
	_gameplay_mouse_mode = Input.get_mouse_mode()


func _enter_paused() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_pause_menu.show()


func _exit_paused() -> void:
	_pause_menu.hide()


func _enter_material_browser() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_material_browser.open_browser()


func _exit_material_browser() -> void:
	_material_browser.close_browser()


func _enter_radial_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_radial_menu.open_menu()


func _exit_radial_menu() -> void:
	_radial_menu.close_menu()


func _on_state_changed(_previous_state: int, current_state: int) -> void:
	state_changed.emit(current_state)


func _on_pause_menu_quit_requested() -> void:
	quit_requested.emit()


func _on_material_browser_material_pressed(material_id: int) -> void:
	var item: SlotItem = _material_browser.get_material_item(material_id)
	if item == null:
		return
	if not _material_hotbar.remove_item(item):
		_material_hotbar.add_item(item)


func _on_hotbar_items_changed() -> void:
	_update_material_pin_icons()


func _update_material_pin_icons() -> void:
	for material_id in _material_browser.get_material_ids():
		var item: SlotItem = _material_browser.get_material_item(material_id)
		_material_browser.set_material_pinned(material_id, _material_hotbar.has_item(item))
