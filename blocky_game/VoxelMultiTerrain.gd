extends Node3D
class_name VoxelMultiTerrain


const VOXEL_SCALE_SHADER_MATERIAL = preload("uid://cl8ftl3f0exim")
## This is the separation applied by VoxelBoxMover in terrain-local coordinates,
## visible as `EPSILON` in the Godot Voxel source here:
## https://github.com/Zylann/godot_voxel/blob/e74312304c2f9112728307aa7a778a8a44b5b9e5/terrain/fixed_lod/voxel_box_mover.cpp#L61
const _BOX_MOVER_COLLISION_MARGIN := 0.001

## The max view distance of all terrains. See VoxelTerrain.max_view_distance.
@export_range(0, 512) var max_view_diatance := 128:
	set(value):
		assert(max_view_diatance >= 0)
		assert(max_view_diatance <= 512)
		max_view_diatance = value
		for terrain in terrains:
			terrain.max_view_distance = value
@export var library: VoxelBlockyLibrary

## The VoxelTerrains within this MultiVoxelTerrain.
## The terrains should always be ordered by scale, lowest to highest.
@onready var terrains: Array[VoxelTerrain] = [
	get_node("./VoxelTerrain1"),
	get_node("./VoxelTerrain2"),
	get_node("./VoxelTerrain3"),
	get_node("./VoxelTerrain4"),
	get_node("./VoxelTerrain5"),
	get_node("./VoxelTerrain6"),
	get_node("./VoxelTerrain7"),
	get_node("./VoxelTerrain8"),
]

var _box_mover := VoxelBoxMover.new()


func _ready() -> void:
	_box_mover.set_collision_mask(1) # Excludes rails
	_box_mover.set_step_climbing_enabled(true)
	_box_mover.set_max_step_height(0.5)
	
	# Scale the model textures in the terrains based on the terrain scale
	# TODO: This only works for dirt right now
	for terrain in terrains:
		var library_copy: VoxelBlockyLibrary = library.duplicate_deep()
		#var voxel_scale_shader_material := VOXEL_SCALE_SHADER_MATERIAL.duplicate()
		#voxel_scale_shader_material.set_shader_parameter("scale", terrain.scale.x)
		#library_copy.models[1].set_material_override(0, voxel_scale_shader_material)
		library_copy.bake()
		terrain.mesher.library = library_copy


## Creates an instance of VoxelToolMultiTerrain bound to this node, to access voxels and edition methods.
## You can keep it in a member variable to avoid creating one again, as long as the node still exists.
func get_voxel_tool() -> VoxelToolMultiTerrain:
	return VoxelToolMultiTerrain.new(self)


## Get box mover motion taking into account all terrains.
func get_box_mover_motion(pos: Vector3, motion: Vector3, aabb: AABB) -> BoxMoverMotion:
	var total_motion := motion
	var has_stepped_up := false
	var step_climbing_enabled := _box_mover.is_step_climbing_enabled()
	# A collision on one terrain can change the path relative to another terrain,
	# so repeat until every terrain accepts the combined result.
	for _pass in terrains.size():
		var previous_motion := total_motion
		for terrain_index in terrains.size():
			# Larger voxels cannot be climbed as a half-voxel step.
			_box_mover.set_step_climbing_enabled(
				step_climbing_enabled && terrain_index == 0)
			total_motion = _box_mover.get_motion(
				pos, total_motion, aabb, terrains[terrain_index])
			if terrain_index == 0 && _box_mover.has_stepped_up():
				has_stepped_up = true
		if total_motion.is_equal_approx(previous_motion):
			break
	_box_mover.set_step_climbing_enabled(step_climbing_enabled)
	return BoxMoverMotion.new(total_motion, has_stepped_up)


## Returns whether the box has terrain directly beneath it.
## The probe accounts for VoxelBoxMover's collision margin growing with terrain scale.
func is_box_mover_on_floor(pos: Vector3, aabb: AABB) -> bool:
	for terrain in terrains:
		var world_margin := _BOX_MOVER_COLLISION_MARGIN * terrain.global_transform.basis.y.length()
		var probe_motion := Vector3.DOWN * world_margin * 2.0
		var resolved_motion := _box_mover.get_motion(pos, probe_motion, aabb, terrain)
		if resolved_motion.y > probe_motion.y and !is_equal_approx(resolved_motion.y, probe_motion.y):
			return true
	return false


class BoxMoverMotion:
	var motion: Vector3
	var has_stepped_up: bool
	
	func _init(motion: Vector3, has_stepped_up: bool) -> void:
		self.motion = motion
		self.has_stepped_up = has_stepped_up
