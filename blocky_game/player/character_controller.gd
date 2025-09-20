extends Node3D
class_name CharacterController

@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 5.0
@export var head: NodePath

@export var multi_terrain_path: NodePath
@onready var multi_terrain: VoxelMultiTerrain = get_node(multi_terrain_path)

var _voxel_tool: VoxelToolMultiTerrain
var _velocity := Vector3()
var _grounded := false
var _head: Node3D = null
var _flying := false


func _ready():
	_voxel_tool = multi_terrain.get_voxel_tool()
	_head = get_node(head)


func _physics_process(delta: float):
	var forward = _head.get_transform().basis.z.normalized()
	forward = Plane(Vector3(0, 1, 0), 0).project(forward)
	var right = _head.get_transform().basis.x.normalized()
	var motor = Vector3()
	
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		motor -= forward
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		motor += forward
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		motor -= right
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		motor += right
	
	motor = motor.normalized() * speed
	
	if Input.is_key_pressed(KEY_F):
		_flying = !_flying
	
	_velocity.x = motor.x
	_velocity.z = motor.z
	if !_flying:
		_velocity.y -= gravity * delta
	
	if _grounded and Input.is_key_pressed(KEY_SPACE):
		_velocity.y = jump_force
		_grounded = false
	
	var motion := _velocity * delta
	
	var aabb := AABB(Vector3(-0.4, -0.9, -0.4), Vector3(0.8, 1.8, 0.8))
	
	# Don't fall to infinity, wait until terrain loads
	var global_aabb := AABB(aabb.position + position, aabb.size)
	var wait_for_load := false
	if !_voxel_tool.is_area_editable(global_aabb):
		wait_for_load = true
	
	if !wait_for_load:
		var prev_motion := motion

		# Modify motion taking collisions into account
		var box_mover_motion := multi_terrain.get_box_mover_motion(position, motion, aabb)
		motion = box_mover_motion.motion
		DDD.set_text("Motion", motion)

		# Apply motion with a raw translation.
		global_translate(motion)

		# If new motion doesnt move vertically and we were falling before, we just landed
		if absf(motion.y) < 0.001 and prev_motion.y < -0.001:
			_grounded = true

		if box_mover_motion.has_stepped_up:
			# When we step up, the motion vector will have vertical movement,
			# however it is not caused by falling or jumping, but by snapping the body on
			# top of the step. So after we applied motion, we consider it grounded,
			# and we reset motion.y so we don't induce a "jump" velocity later.
			motion.y = 0
			_grounded = true
		# Otherwise, if new motion is moving vertically, we may not be grounded anymore
		elif absf(motion.y) > 0.001:
			_grounded = false

		# TODO Stepping up stairs is quite janky. Minecraft seems to smooth it out a little.
		# That would be a visual-only trick to apply it seems.

	assert(delta > 0)
	# Re-inject velocity from resulting motion
	_velocity = motion / delta

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer():
		# Broadcast our position to other peers.
		# Note, for other peers, this is a different script (remote_character.gd).
		# Each peer is authoritative of its own position for now.
		# TODO Make sure this RPC is not sent when we are not connected
		rpc(&"receive_position", position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud"):
		%HUD.visible = !%HUD.visible
		DDD.visible = !DDD.visible


@rpc("authority", "call_remote", "unreliable")
func receive_position(pos: Vector3):
	# We currently don't expect this to be called. The actual targetted script is different.
	# I had to define it otherwise Godot throws a lot of errors everytime I call the RPC...
	push_error("Didn't expect to receive RPC position")
