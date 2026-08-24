extends Node

const Util = preload("res://common/util.gd")
const Blocks = preload("../blocks/blocks.gd")
const WaterUpdater = preload("./../water.gd")
const InteractionCommon = preload("./interaction_common.gd")

@export var terrain_path : NodePath

@onready var _block_types : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _water_updater : WaterUpdater
@onready var _multi_terrain: VoxelMultiTerrain = get_node("/root/Main/Game/VoxelMultiTerrain")

var _voxel_tool: VoxelToolMultiTerrain


func _ready():
	_voxel_tool = _multi_terrain.get_voxel_tool()

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() == false or mp.is_server():
		_water_updater = get_node("/root/Main/Game/Water")


# Actually, we only want this to be called from clients to the server! Not any peer!
# But that specification doesn't exist in the API.
@rpc("any_peer", "call_remote", "reliable", 0)
func receive_place_single_block(terrain_index: int, pos: Vector3, look_dir: Vector3, block_id: int):
	if terrain_index < 0 or terrain_index >= _multi_terrain.terrains.size():
		push_error("Received invalid placement terrain index: ", terrain_index)
		return
	var terrain := _multi_terrain.terrains[terrain_index]
	var terrain_tool := _voxel_tool.voxel_tools[terrain]
	InteractionCommon.place_single_block(
		terrain_tool, pos, look_dir, block_id, _block_types, _water_updater)
