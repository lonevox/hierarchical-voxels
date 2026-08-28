class_name StateMachine
extends RefCounted

signal state_changed(previous_state: int, current_state: int)

var _current_state: int
var _enter_callbacks := {}
var _exit_callbacks := {}
var _process_callbacks := {}
var _physics_process_callbacks := {}
var _started := false


func _init(initial_state: int) -> void:
	_current_state = initial_state


func add_state(
		state: int,
		enter: Callable = Callable(),
		exit: Callable = Callable(),
		process: Callable = Callable(),
		physics_process: Callable = Callable()
) -> void:
	assert(not _started, "States cannot be added after the state machine has started")
	_enter_callbacks[state] = enter
	_exit_callbacks[state] = exit
	_process_callbacks[state] = process
	_physics_process_callbacks[state] = physics_process


func start() -> void:
	assert(not _started, "The state machine has already started")
	assert(_enter_callbacks.has(_current_state), "The initial state has not been added")
	_started = true
	_call_if_valid(_enter_callbacks[_current_state])


func transition_to(next_state: int) -> void:
	assert(_started, "The state machine must be started before changing state")
	assert(_enter_callbacks.has(next_state), "The requested state has not been added")
	if next_state == _current_state:
		return

	var previous_state := _current_state
	_call_if_valid(_exit_callbacks[previous_state])
	_current_state = next_state
	_call_if_valid(_enter_callbacks[_current_state])
	state_changed.emit(previous_state, _current_state)


func is_in_state(state: int) -> bool:
	return _current_state == state


func get_state() -> int:
	return _current_state


## Forwards an owning Node's process notification to the active state.
func process(delta: float) -> void:
	assert(_started, "The state machine must be started before processing")
	_call_process_if_valid(_process_callbacks[_current_state], delta)


## Forwards an owning Node's physics-process notification to the active state.
func physics_process(delta: float) -> void:
	assert(_started, "The state machine must be started before physics processing")
	_call_process_if_valid(_physics_process_callbacks[_current_state], delta)


func _call_if_valid(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()


func _call_process_if_valid(callback: Callable, delta: float) -> void:
	if callback.is_valid():
		callback.call(delta)
