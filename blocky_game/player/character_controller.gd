extends Node3D
class_name CharacterController

const Hotbar = preload("../gui/hotbar/hotbar.gd")

enum MovementState {
	GROUNDED,
	AIRBORNE,
	FLYING,
}

const CHARACTER_AABB := AABB(Vector3(-0.4, -0.9, -0.4), Vector3(0.8, 1.8, 0.8))

class MovementResult:
	var landed := false
	var has_stepped_up := false

@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 5.0
@export var head: NodePath

@export var multi_terrain_path: NodePath
@onready var multi_terrain: VoxelMultiTerrain = get_node(multi_terrain_path)

var _voxel_tool: VoxelToolMultiTerrain
var _velocity := Vector3()
var _head: Node3D = null
var _movement_state_machine: StateMachine


func set_hotbar(hotbar: Hotbar) -> void:
	$Interaction.set_hotbar(hotbar)


func _ready():
	_voxel_tool = multi_terrain.get_voxel_tool()
	_head = get_node(head)

	_movement_state_machine = StateMachine.new(MovementState.AIRBORNE)
	_movement_state_machine.add_state(
		MovementState.GROUNDED,
		_enter_grounded,
		Callable(),
		Callable(),
		_physics_process_grounded
	)
	_movement_state_machine.add_state(
		MovementState.AIRBORNE,
		Callable(),
		Callable(),
		Callable(),
		_physics_process_airborne
	)
	_movement_state_machine.add_state(
		MovementState.FLYING,
		_enter_flying,
		Callable(),
		Callable(),
		_physics_process_flying
	)
	_movement_state_machine.start()


func _physics_process(delta: float):
	_movement_state_machine.physics_process(delta)
	DDD.set_text("Movement state", MovementState.find_key(_movement_state_machine.get_state()))
	_broadcast_position()


func _broadcast_position() -> void:
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer():
		# Broadcast our position to other peers.
		# Note, for other peers, this is a different script (remote_character.gd).
		# Each peer is authoritative of its own position for now.
		# TODO Make sure this RPC is not sent when we are not connected
		rpc(&"receive_position", position)


func _get_horizontal_motor() -> Vector3:
	var input_direction := Input.get_vector("move_left", "move_right", "move_forwards", "move_backwards")
	var forward := _head.get_transform().basis.z.normalized()
	forward = Plane(Vector3.UP, 0).project(forward).normalized()
	var right := _head.get_transform().basis.x.normalized()
	return (right * input_direction.x + forward * input_direction.y) * speed


func _physics_process_grounded(delta: float) -> void:
	_update_on_foot_velocity(delta)
	var area_editable := _is_movement_area_editable()

	# VoxelBoxMover separates bodies from voxels by a margin in terrain-local
	# coordinates. At larger terrain scales gravity can be smaller than the
	# resulting world-space gap, causing the player to jitter up and down, so
	# don't apply gravity while on the floor.
	if area_editable and _movement_state_machine.is_in_state(MovementState.GROUNDED):
		if multi_terrain.is_box_mover_on_floor(position, CHARACTER_AABB):
			_velocity.y = 0
		else:
			_movement_state_machine.transition_to(MovementState.AIRBORNE)

	var result := _move_and_collide(delta, area_editable, _movement_state_machine.is_in_state(MovementState.AIRBORNE))
	_handle_ground_contact(result)


func _physics_process_airborne(delta: float) -> void:
	_update_on_foot_velocity(delta)
	var result := _move_and_collide(delta, _is_movement_area_editable(), true)
	_handle_ground_contact(result)


func _update_on_foot_velocity(delta: float) -> void:
	var motor := _get_horizontal_motor()
	_velocity.x = motor.x
	_velocity.z = motor.z
	_velocity.y -= gravity * delta

	if Input.is_action_pressed("move_up") and _movement_state_machine.is_in_state(MovementState.GROUNDED):
		_velocity.y = jump_force
		_movement_state_machine.transition_to(MovementState.AIRBORNE)


func _physics_process_flying(delta: float) -> void:
	var motor := _get_horizontal_motor()
	var speed_multiplier := 5.0
	if Input.is_key_pressed(KEY_CTRL):
		speed_multiplier *= 10.0

	_velocity.x = motor.x * speed_multiplier
	_velocity.z = motor.z * speed_multiplier
	_velocity.y = Input.get_axis("move_down", "move_up") * speed * speed_multiplier
	_move_and_collide(delta, _is_movement_area_editable(), false)


func _is_movement_area_editable() -> bool:
	var global_aabb := AABB(CHARACTER_AABB.position + position, CHARACTER_AABB.size)
	return _voxel_tool.is_area_editable(global_aabb)


func _move_and_collide(delta: float, area_editable: bool, detect_landing: bool) -> MovementResult:
	var result := MovementResult.new()
	var requested_motion := _velocity * delta
	var motion := requested_motion

	# Don't move into terrain that has not loaded yet.
	if area_editable:
		var box_mover_motion := multi_terrain.get_box_mover_motion(position, motion, CHARACTER_AABB)
		motion = box_mover_motion.motion
		result.has_stepped_up = box_mover_motion.has_stepped_up
		result.landed = (
			detect_landing
			and requested_motion.y < 0
			and motion.y > requested_motion.y
			and not is_equal_approx(motion.y, requested_motion.y)
		)

		# The collision margin can produce a small upward correction on contact.
		# Remaining at the current height is enough when approaching from above.
		if result.landed and motion.y > 0:
			motion.y = 0

		global_translate(motion)
		DDD.set_text("Motion", motion)

	assert(delta > 0)
	_velocity = motion / delta
	return result


func _handle_ground_contact(result: MovementResult) -> void:
	if result.landed or result.has_stepped_up:
		# Step-up motion includes vertical displacement used to place the body on
		# the step, but that displacement must not become upward velocity.
		_velocity.y = 0
		_movement_state_machine.transition_to(MovementState.GROUNDED)


func _enter_grounded() -> void:
	_velocity.y = 0


func _enter_flying() -> void:
	_velocity.y = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fly"):
		var next_state := MovementState.AIRBORNE if _movement_state_machine.is_in_state(MovementState.FLYING) else MovementState.FLYING
		_movement_state_machine.transition_to(next_state)


@rpc("authority", "call_remote", "unreliable")
func receive_position(pos: Vector3):
	# We currently don't expect this to be called. The actual targetted script is different.
	# I had to define it otherwise Godot throws a lot of errors everytime I call the RPC...
	push_error("Didn't expect to receive RPC position")
