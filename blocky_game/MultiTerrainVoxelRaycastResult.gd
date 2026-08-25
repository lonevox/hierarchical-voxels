## An extension to VoxelRaycastResult for use with VoxelMultiTerrains.
extends RefCounted
class_name MultiTerrainVoxelRaycastResult


const _FLOAT32_EPSILON := 1.1920928955078125e-7
const _MIN_INSIDE_OFFSET := 0.0001
const _MAX_INSIDE_OFFSET := 0.75
const _INSIDE_OFFSET_ULPS := 2.0


var raycast_result: VoxelRaycastResult
var terrain: VoxelTerrain
## The index of the terrain within the MultiTerrain.
var terrain_index: int
## Distance between the origin of the ray and the surface of the cube representing the hit voxel
## translated into the smallest terrain's coordinate space.
## See VoxelRaycastResult.distance
var global_distance: float
## The positions of the hit for each terrain scale, translated into the smallest terrain's
## coordinate space. Entries have the same order as VoxelMultiTerrain.terrains.
## See VoxelRaycastResult.position
var global_position: Array[Vector3i] = []
## The previous positions of the hit for each terrain scale, translated into the smallest terrain's
## coordinate space. Entries have the same order as VoxelMultiTerrain.terrains.
## See VoxelRaycastResult.previous_position
var global_previous_position: Array[Vector3i] = []


func _init(
		raycast_result: VoxelRaycastResult,
		multi_terrain: VoxelMultiTerrain,
		terrain_index: int,
		origin: Vector3,
		direction: Vector3
	) -> void:
	self.raycast_result = raycast_result
	self.terrain_index = terrain_index
	terrain = multi_terrain.terrains[terrain_index]
	global_distance = raycast_result.distance / terrain.scale.x
	var inside_position := _get_inside_position(multi_terrain, origin, direction)

	var previous_offset := raycast_result.previous_position - raycast_result.position
	for current_terrain in multi_terrain.terrains:
		var scale := int(current_terrain.scale.x)
		var position_at_scale := Vector3i((inside_position / scale).floor()) * scale
		global_position.append(position_at_scale)
		global_previous_position.append(position_at_scale + previous_offset * scale)

	# Keep the VoxelRaycastResult authoritative at the scale on which the hit was found. This also
	# preserves its behavior for block models whose collision surface does not fill the whole voxel.
	var hit_scale := int(terrain.scale.x)
	global_position[terrain_index] = raycast_result.position * hit_scale
	global_previous_position[terrain_index] = raycast_result.previous_position * hit_scale


## Returns a point just inside the hit surface in the smallest terrain's coordinate space.
## The bounded precision-aware offset prevents cross-scale voxel selection from drifting at large coordinates.
## Use this to reliably derive positions on smaller-scale terrains when a ray hits a larger-scale terrain.
## This is accurate until the 24-bit integer limit (which is also the Vector3 limit).
func _get_inside_position(multi_terrain: VoxelMultiTerrain, origin: Vector3, direction: Vector3) -> Vector3:
	# Reconstruct the surface point in the hit terrain's local space first. At large world
	# coordinates, adding the relatively short ray distance directly to `origin` loses precision.
	var normalized_direction := direction.normalized()
	var world_to_hit_basis := terrain.global_transform.basis.inverse()
	var local_direction_per_world_unit := world_to_hit_basis * normalized_direction
	var local_direction := local_direction_per_world_unit.normalized()
	var local_distance := global_distance * local_direction_per_world_unit.length()
	var local_surface_position := terrain.to_local(origin) + local_direction * local_distance
	var terrain_to_multi := multi_terrain.global_transform.affine_inverse() * terrain.global_transform
	var surface_position := terrain_to_multi * local_surface_position

	# Move far enough inside the collision surface to survive Vector3 rounding at the current
	# coordinate magnitude. Cap the offset below one base voxel so it cannot skip the immediately
	# adjacent smaller-scale cell.
	var world_to_multi_basis := multi_terrain.global_transform.basis.inverse()
	var inside_direction := -(world_to_multi_basis * raycast_result.normal).normalized()
	if inside_direction.is_zero_approx():
		inside_direction = (world_to_multi_basis * normalized_direction).normalized()
	var max_abs_component := maxf(absf(surface_position.x), maxf(absf(surface_position.y), absf(surface_position.z)))
	var inside_offset := clampf(max_abs_component * _FLOAT32_EPSILON * _INSIDE_OFFSET_ULPS, _MIN_INSIDE_OFFSET, _MAX_INSIDE_OFFSET)
	return surface_position + inside_direction * inside_offset
