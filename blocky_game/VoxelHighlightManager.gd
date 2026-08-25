extends Node3D
class_name VoxelHighlightManager


const VoxelHighlightScript = preload("./VoxelHighlight.gd")

@export var multi_terrain_path: NodePath
@export_range(1.0, 1.1, 0.001) var voxel_size_multiplier := 1.01

@onready var _multi_terrain: VoxelMultiTerrain = get_node(multi_terrain_path)

var _highlight_mesh: BoxMesh


func _ready() -> void:
	_highlight_mesh = BoxMesh.new()
	_highlight_mesh.size = Vector3.ONE * voxel_size_multiplier


## Creates an independently styled and animated voxel highlight layer. The manager owns the
## renderer node. If a lifetime owner is supplied, the layer is released when that node exits.
func create_highlight(lifetime_owner: Node = null) -> VoxelHighlight:
	assert(_highlight_mesh != null, "Voxel highlights cannot be created before the manager is ready")
	var highlight := VoxelHighlightScript.new() as VoxelHighlight
	highlight.name = "VoxelHighlight"
	highlight._initialize(_multi_terrain, _highlight_mesh)
	add_child(highlight)
	if lifetime_owner != null:
		lifetime_owner.tree_exiting.connect(
			release_highlight.bind(highlight), CONNECT_ONE_SHOT)
	return highlight


## Releases a layer previously created by this manager.
func release_highlight(highlight: VoxelHighlight) -> void:
	if not is_instance_valid(highlight):
		return
	if highlight.get_parent() != self:
		push_error("Cannot release a voxel highlight owned by another manager")
		return
	highlight.queue_free()
