extends RefCounted
class_name VoxelToolMultiTerrain


const _VOXEL_CHANNEL := VoxelBuffer.CHANNEL_TYPE
const _VOXEL_CHANNEL_MASK := 1 << _VOXEL_CHANNEL


## The VoxelMultiTerrain to query.
var multi_terrain: VoxelMultiTerrain
## The position at the start of the area in the coordinate space of the smallest VoxelTerrain.
var position: Vector3i
## The size of the area in the coordinate space of the smallest VoxelTerrain.
var area: Vector3i

var voxel_tools: Dictionary[VoxelTerrain, VoxelTool]
var _area_query_buffers: Dictionary[VoxelTerrain, VoxelBuffer]


func _init(multi_terrain: VoxelMultiTerrain) -> void:
	self.multi_terrain = multi_terrain
	self.position = position
	self.area = area
	
	for terrain in multi_terrain.terrains:
		var voxel_tool := terrain.get_voxel_tool()
		voxel_tool.channel = _VOXEL_CHANNEL
		voxel_tool.mode = VoxelTool.MODE_SET
		voxel_tools[terrain] = voxel_tool
		_area_query_buffers[terrain] = VoxelBuffer.new()


## Returns true if the specified voxel area can be edited in every terrain. This can also be
## interpreted as the area being "loaded". Other factors can influence whether an area is editable
## or not, such as streaming mode or terrain bounds.
func is_area_editable(aabb: AABB) -> bool:
	for terrain in multi_terrain.terrains:
		var voxel_tool := voxel_tools[terrain]
		# VoxelTool expects terrain-local voxel coordinates. Transform a fresh AABB
		# for each terrain so conversions do not accumulate between scales.
		var terrain_aabb := terrain.global_transform.affine_inverse() * aabb
		if !voxel_tool.is_area_editable(terrain_aabb):
			return false
	return true


## Casts a raycast with VoxelTool.raycast on all terrains.
func raycast(origin: Vector3, direction: Vector3, max_distance: float = 10.0, collision_mask: int = 0xFFFFFFFF) -> MultiTerrainVoxelRaycastResult:
	var closest_hit: VoxelRaycastResult
	var closest_terrain_index: int
	var closest_global_distance := INF
	for i in range(multi_terrain.terrains.size()):
		var terrain := multi_terrain.terrains[i]
		var voxel_tool := voxel_tools[terrain]
		var hit := voxel_tool.raycast(origin, direction, max_distance, collision_mask)
		var global_distance := hit.distance / terrain.scale.x if hit else INF
		if global_distance < closest_global_distance:
			closest_hit = hit
			closest_terrain_index = i
			closest_global_distance = global_distance
	if closest_hit:
		return MultiTerrainVoxelRaycastResult.new(
			closest_hit, multi_terrain, closest_terrain_index, origin, direction)
	return null


# TODO: Tick larger voxels slower?
func run_blocky_random_tick(area: AABB, voxel_count: int, callback: Callable, batch_count: int = 16) -> void:
	for terrain in multi_terrain.terrains:
		var voxel_tool := voxel_tools[terrain]
		voxel_tool.run_blocky_random_tick(area, voxel_count, callback, batch_count)


## Placement collisions are voxels on other terrains that are within the placement location.
## This can happen when placing a larger voxel in an area with smaller voxels.
## target_terrain is the terrain that you are trying to place a voxel within at position pos.
## Returns a dictionary of terrains containing collisions for each terrain: Dictionary[VoxelTerrain, Array[Vector3i]]
func _get_placement_collisions(target_terrain: VoxelTerrain, pos: Vector3i) -> Dictionary[VoxelTerrain, Array]:
	var out: Dictionary[VoxelTerrain, Array] = {}
	for terrain in multi_terrain.terrains:
		if target_terrain == terrain: continue
		var voxel_tool := voxel_tools[terrain]
		var pos_scaled := Vector3i((pos * target_terrain.scale.x / terrain.scale.x).floor())
		if voxel_tool.get_voxel(pos_scaled) != 0:
			if !out.has(terrain):
				out[terrain] = []
			out[terrain].append(pos_scaled)
	return out


## Returns whether any non-air voxel intersects an area expressed in the coordinate space of the
## smallest terrain.
func has_voxels_in_area(pos: Vector3i, size: Vector3i) -> bool:
	if size.x <= 0 or size.y <= 0 or size.z <= 0:
		return false

	# Check larger terrains first because they cover the area with fewer voxels and can reject the
	# placement before a lower-scale buffer has to be copied.
	for terrain_index in range(multi_terrain.terrains.size() - 1, -1, -1):
		var terrain := multi_terrain.terrains[terrain_index]
		var scaled_area := _get_scaled_area(terrain, pos, size)
		var buffer := _copy_area(terrain, Vector3i(scaled_area.position), Vector3i(scaled_area.size))
		if _buffer_has_voxels(buffer):
			return true

	return false


## Returns every non-air voxel intersecting an area expressed in the coordinate space of the
## smallest terrain, grouped by terrain.
func get_voxels_in_area(pos: Vector3i, size: Vector3i) -> Dictionary[VoxelTerrain, Array]:
	var out: Dictionary[VoxelTerrain, Array] = {}
	if size.x <= 0 or size.y <= 0 or size.z <= 0:
		return out

	for terrain in multi_terrain.terrains:
		var scaled_area := _get_scaled_area(terrain, pos, size)
		var pos_scaled := Vector3i(scaled_area.position)
		var size_scaled := Vector3i(scaled_area.size)
		var buffer := _copy_area(terrain, pos_scaled, size_scaled)
		if not _buffer_has_voxels(buffer):
			continue

		var voxel_positions: Array = []
		# VoxelBuffer stores voxels in ZXY order, with Y contiguous in memory.
		for z in size_scaled.z:
			for x in size_scaled.x:
				for y in size_scaled.y:
					if buffer.get_voxel(x, y, z, _VOXEL_CHANNEL) != 0:
						voxel_positions.append(pos_scaled + Vector3i(x, y, z))

		if not voxel_positions.is_empty():
			out[terrain] = voxel_positions

	return out


func _get_scaled_area(terrain: VoxelTerrain, pos: Vector3i, size: Vector3i) -> AABB:
	var terrain_scale := terrain.scale.x
	var pos_scaled := Vector3i((Vector3(pos) / terrain_scale).floor())
	var end_scaled := Vector3i((Vector3(pos + size) / terrain_scale).ceil())
	return AABB(pos_scaled, end_scaled - pos_scaled)


func _copy_area(terrain: VoxelTerrain, pos: Vector3i, size: Vector3i) -> VoxelBuffer:
	var buffer := _area_query_buffers[terrain]
	if buffer.get_size() != size:
		buffer.create(size.x, size.y, size.z)
	voxel_tools[terrain].copy(pos, buffer, _VOXEL_CHANNEL_MASK, false)
	return buffer


func _buffer_has_voxels(buffer: VoxelBuffer) -> bool:
	# If every value were air, the channel would be uniform. A uniform channel needs one lookup to
	# distinguish uniform air from uniform solid.
	return not buffer.is_uniform(_VOXEL_CHANNEL) or buffer.get_voxel(0, 0, 0, _VOXEL_CHANNEL) != 0
