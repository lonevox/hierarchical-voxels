const Blocks = preload("../blocks/blocks.gd")


static func place_voxel(
		terrain_tool: VoxelTool,
		pos: Vector3i,
		material_id: int,
		blocks: Blocks
	) -> void:
	var material_name := blocks.get_material_name(material_id)
	var voxel_id := blocks.get_model_id(material_name, Blocks.DEFAULT_SHAPE)
	terrain_tool.set_voxel(pos, voxel_id)


static func erase_voxel(terrain_tool: VoxelTool, pos: Vector3i) -> void:
	terrain_tool.set_voxel(pos, Blocks.AIR_ID)
