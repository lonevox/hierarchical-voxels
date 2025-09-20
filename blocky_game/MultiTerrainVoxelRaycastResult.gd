## An extension to VoxelRaycastResult for use with VoxelMultiTerrains.
extends RefCounted
class_name MultiTerrainVoxelRaycastResult


var raycast_result: VoxelRaycastResult
var terrain: VoxelTerrain
## Distance between the origin of the ray and the surface of the cube representing the hit voxel
## translated into the smallest terrain's coordinate space.
## See VoxelRaycastResult.distance
var global_distance: float
## The position of the hit translated into the smallest terrain's coordinate space.
## See VoxelRaycastResult.position
var global_position: Vector3i
## The previous position of the hit translated into the smallest terrain's coordinate space.
## See VoxelRaycastResult.previous_position
var global_previous_position: Vector3i


func _init(raycast_result: VoxelRaycastResult, terrain: VoxelTerrain) -> void:
	self.raycast_result = raycast_result
	self.terrain = terrain
	global_distance = raycast_result.distance / terrain.scale.x
	global_position = raycast_result.position * terrain.scale.x
	global_previous_position = raycast_result.previous_position * terrain.scale.x
