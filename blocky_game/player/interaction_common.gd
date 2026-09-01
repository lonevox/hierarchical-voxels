static func place_voxel(
		terrain_tool: VoxelTool,
		pos: Vector3i,
		material_id: int,
		blocks: Blocks,
		shape_name: StringName = Blocks.DEFAULT_SHAPE
	) -> void:
	var material_name := blocks.get_material_name(material_id)
	var voxel_id := blocks.get_model_id(material_name, shape_name)
	terrain_tool.set_voxel(pos, voxel_id)


static func erase_voxel(terrain_tool: VoxelTool, pos: Vector3i) -> void:
	terrain_tool.set_voxel(pos, Blocks.AIR_ID)
