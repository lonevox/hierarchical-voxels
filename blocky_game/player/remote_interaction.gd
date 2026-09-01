extends Node

const Blocks = preload("../blocks/blocks.gd")
const InteractionCommon = preload("./interaction_common.gd")

@export var terrain_path : NodePath

@onready var _blocks : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _multi_terrain: VoxelMultiTerrain = get_node("/root/Main/Game/VoxelMultiTerrain")

var _voxel_tool: VoxelToolMultiTerrain


func _ready():
	_voxel_tool = _multi_terrain.get_voxel_tool()


# Actually, we only want this to be called from clients to the server! Not any peer!
# But that specification doesn't exist in the API.
@rpc("any_peer", "call_remote", "reliable", 0)
func receive_place_voxel(
		terrain_index: int,
		pos: Vector3i,
		material_id: int,
		shape_name: StringName
	) -> void:
	if terrain_index < 0 or terrain_index >= _multi_terrain.terrains.size():
		push_error("Received invalid placement terrain index: ", terrain_index)
		return
	var terrain := _multi_terrain.terrains[terrain_index]
	var terrain_tool := _voxel_tool.voxel_tools[terrain]
	InteractionCommon.place_voxel(terrain_tool, pos, material_id, _blocks, shape_name)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_erase_voxel(terrain_index: int, pos: Vector3i) -> void:
	if terrain_index < 0 or terrain_index >= _multi_terrain.terrains.size():
		push_error("Received invalid placement terrain index: ", terrain_index)
		return
	var terrain := _multi_terrain.terrains[terrain_index]
	var terrain_tool := _voxel_tool.voxel_tools[terrain]
	InteractionCommon.erase_voxel(terrain_tool, pos)
