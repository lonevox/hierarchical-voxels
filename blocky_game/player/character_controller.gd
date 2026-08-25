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
	
	_velocity.x = motor.x
	_velocity.z = motor.z
	if !_flying:
		_velocity.y -= gravity * delta
	else:
		_velocity.x *= 5
		_velocity.z *= 5
		if Input.is_key_pressed(KEY_CTRL):
			_velocity.x *= 2
			_velocity.z *= 2
		_velocity.y = 0
	
	if Input.is_key_pressed(KEY_F):
		_flying = !_flying
		if _flying:
			_velocity.y = 0
	
	if Input.is_key_pressed(KEY_SPACE):
		if _grounded:
			_velocity.y = jump_force
			_grounded = false
		elif _flying:
			_velocity.y = speed * 5
	if _flying and Input.is_key_pressed(KEY_SHIFT):
		_velocity.y = -speed * 5
	
	var motion := _velocity * delta
	
	var aabb := AABB(Vector3(-0.4, -0.9, -0.4), Vector3(0.8, 1.8, 0.8))
	
	# Don't fall to infinity, wait until terrain loads
	var global_aabb := AABB(aabb.position + position, aabb.size)
	var wait_for_load := false
	if !_voxel_tool.is_area_editable(global_aabb):
		wait_for_load = true
	
	if !wait_for_load:
		# VoxelBoxMover separates bodies from voxels by a margin in terrain-local
		# coordinates. At larger terrain scales gravity can be smaller than the
		# resulting world-space gap, causing the player to jitter up and down,
		# so don't apply gravity while on the floor.
		if !_flying and _grounded:
			if multi_terrain.is_box_mover_on_floor(position, aabb):
				_velocity.y = 0
				motion.y = 0
			else:
				_grounded = false

		var prev_motion := motion

		# Modify motion taking collisions into account
		var box_mover_motion := multi_terrain.get_box_mover_motion(position, motion, aabb)
		motion = box_mover_motion.motion
		DDD.set_text("Motion", motion)
		var landed := (
			!_flying
			and prev_motion.y < 0
			and motion.y > prev_motion.y
			and !is_equal_approx(motion.y, prev_motion.y)
		)
		# The collision margin can produce a small upward correction on contact.
		# Remaining at the current height is enough when approaching from above.
		if landed and motion.y > 0:
			motion.y = 0

		# Apply motion with a raw translation.
		global_translate(motion)

		# A downward motion constrained by terrain means we just landed. Apply any
		# downward distance needed to reach the surface, but don't retain it as velocity.
		if landed:
			_grounded = true
			motion.y = 0
		elif !_flying and box_mover_motion.has_stepped_up:
			# When we step up, the motion vector will have vertical movement due
			# to snapping the body on top of the step. So after we applied motion,
			# we consider it grounded, and we reset motion.y so we don't induce
			# a "jump" velocity in the next physics step.
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
