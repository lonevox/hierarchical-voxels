extends RefCounted
class_name VoxelToolMultiTerrain


## The VoxelMultiTerrain to query.
var multi_terrain: VoxelMultiTerrain
## The position at the start of the area in the coordinate space of the smallest VoxelTerrain.
var position: Vector3i
## The size of the area in the coordinate space of the smallest VoxelTerrain.
var area: Vector3i

var voxel_tools: Dictionary[VoxelTerrain, VoxelTool]


func _init(multi_terrain: VoxelMultiTerrain) -> void:
	self.multi_terrain = multi_terrain
	self.position = position
	self.area = area
	
	for terrain in multi_terrain.terrains:
		var voxel_tool := terrain.get_voxel_tool()
		voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
		voxel_tool.mode = VoxelTool.MODE_SET
		voxel_tools[terrain] = voxel_tool


## Returns true if the specified voxel area can be edited in every terrain. This can also be
## interpreted as the area being "loaded". Other factors can influence whether an area is editable
## or not, such as streaming mode or terrain bounds.
func is_area_editable(aabb: AABB) -> bool:
	for terrain in multi_terrain.terrains:
		var voxel_tool := voxel_tools[terrain]
		aabb.position /= terrain.scale
		if !voxel_tool.is_area_editable(aabb):
			return false
	return true


## Casts a raycast with VoxelTool.raycast on all terrains.
func raycast(origin: Vector3, direction: Vector3, max_distance: float = 10.0, collision_mask: int = 0xFFFFFFFF) -> MultiTerrainVoxelRaycastResult:
	var closest_hit: VoxelRaycastResult
	var closest_terrain: VoxelTerrain
	for terrain in multi_terrain.terrains:
		var voxel_tool := voxel_tools[terrain]
		var hit := voxel_tool.raycast(origin, direction, max_distance, collision_mask)
		if hit && (closest_hit == null || hit.distance / terrain.scale.x < closest_hit.distance):
			closest_hit = hit
			closest_terrain = terrain
	if closest_hit:
		return MultiTerrainVoxelRaycastResult.new(closest_hit, closest_terrain)
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


## Returns the positions of voxels in an area, but only the voxels of the largest terrain found, if any.
## Returns null if no voxels are found.
## This can be used to confirm that there are voxels within an area.
## If you want to get all voxels in an area in all terrains, instead use _get_voxels_in_area.
#func _are_voxels_in_area(pos: Vector3i, size: Vector3i) -> VoxelAreaResult:
	#for i in multi_terrain.terrains.size():
		## Get terrains in reverse order so they're highest to lowest scale
		#var terrain := multi_terrain.terrains[-i - 1]
		#var voxel_tool := voxel_tools[terrain]
		#var voxel_positions: Array[Vector3i] = []
		#var pos_scaled := Vector3i((pos * terrain.scale.x).floor())
		#for area_pos in _get_positions_in_area(pos, size):
			#if voxel_tool.get_voxel(area_pos) != 0:
				#voxel_positions.append(area_pos)
		#if !voxel_positions.is_empty():
			#return VoxelAreaResult.new(terrain, voxel_positions)
	#return null


func get_voxels_in_area(pos: Vector3i, size: Vector3i) -> Dictionary[VoxelTerrain, Array]:
	var out: Dictionary[VoxelTerrain, Array] = {}
	for terrain in multi_terrain.terrains:
		out[terrain] = []
		var voxel_tool := voxel_tools[terrain]
		var pos_scaled := Vector3i((pos / terrain.scale.x).floor())
		_for_each_position_in_area(pos_scaled, size, func(position_in_area: Vector3i):
			if voxel_tool.get_voxel(position_in_area) != 0:
				out[terrain].append(position_in_area))
	
	# Remove empty terrain entries. They're there so that less code needs to happen in the nested for loop.
	var empty_terrains: Array[VoxelTerrain] = []
	for key in out:
		var position_array := out[key]
		if position_array.is_empty():
			empty_terrains.append(key)
	for terrain in empty_terrains:
		out.erase(terrain)
	
	return out


func _get_positions_in_area(pos: Vector3i, size: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				out.append(pos + Vector3i(x, y, z))
	return out


func _for_each_position_in_area(pos: Vector3i, size: Vector3i, callback: Callable) -> void:
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				callback.call(pos + Vector3i(x, y, z))
