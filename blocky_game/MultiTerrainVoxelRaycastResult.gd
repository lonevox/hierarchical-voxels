## An extension to VoxelRaycastResult for use with VoxelMultiTerrains.
extends RefCounted
class_name MultiTerrainVoxelRaycastResult


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

	# Sample just inside the hit surface. Multiplying raycast_result.position by the hit terrain's
	# scale only gives the large voxel's lowest corner, losing where the ray landed within that voxel.
	var normalized_direction := direction.normalized()
	var inside_position := multi_terrain.to_local(
		origin + normalized_direction * (global_distance + 0.0001))
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
