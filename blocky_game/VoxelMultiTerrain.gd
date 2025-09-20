extends Node3D
class_name VoxelMultiTerrain


const VOXEL_SCALE_SHADER_MATERIAL = preload("uid://cl8ftl3f0exim")

@export var library: VoxelBlockyLibrary

## The VoxelTerrains within this MultiVoxelTerrain.
## The terrains should always be ordered by scale, lowest to highest.
@onready var terrains: Array[VoxelTerrain] = [
	get_node("./VoxelTerrain1"),
	get_node("./VoxelTerrain2"),
	get_node("./VoxelTerrain3"),
	get_node("./VoxelTerrain4"),
	get_node("./VoxelTerrain5"),
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


# TODO: When touching voxels from two different terrains at once, clipping can happen. Needs fixing.
## Get box mover motion taking into account all terrains.
func get_box_mover_motion(pos: Vector3, motion: Vector3, aabb: AABB) -> BoxMoverMotion:
	var total_motion := Vector3.INF
	var has_stepped_up := false
	for terrain in terrains:
		var box_mover_motion := _box_mover.get_motion(pos, motion, aabb, terrain)
		if terrain == terrains[0] && _box_mover.has_stepped_up():
			# Step up only on the smallest terrain
			has_stepped_up = true
		if abs(total_motion) > abs(box_mover_motion):
			total_motion = box_mover_motion
	return BoxMoverMotion.new(total_motion, has_stepped_up)


class BoxMoverMotion:
	var motion: Vector3
	var has_stepped_up: bool
	
	func _init(motion: Vector3, has_stepped_up: bool) -> void:
		self.motion = motion
		self.has_stepped_up = has_stepped_up
