class_name PlayerHUD
extends Control

enum State {
	GAMEPLAY,
	MATERIAL_BROWSER,
	RADIAL_MENU,
}

signal state_changed(state: int)

@onready var _crosshair: Control = $Crosshair
@onready var _material_browser = $MaterialBrowser
@onready var _radial_menu: RadialMenu = $RadialMenu

var _state_machine: StateMachine
var _gameplay_mouse_mode := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	_state_machine = StateMachine.new(State.GAMEPLAY)
	_state_machine.add_state(State.GAMEPLAY, _enter_gameplay, _exit_gameplay)
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_toggle_material_browser()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_ESCAPE and _state_machine.is_in_state(State.MATERIAL_BROWSER):
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


func _enter_gameplay() -> void:
	_crosshair.visible = true
	Input.set_mouse_mode(_gameplay_mouse_mode)


func _exit_gameplay() -> void:
	_crosshair.visible = false
	_gameplay_mouse_mode = Input.get_mouse_mode()


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


func _exit_tree() -> void:
	if _state_machine != null and not _state_machine.is_in_state(State.GAMEPLAY):
		Input.set_mouse_mode(_gameplay_mouse_mode)
