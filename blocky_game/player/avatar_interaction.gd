extends Node

const Util = preload("res://common/util.gd")
const Blocks = preload("../blocks/blocks.gd")
const ItemDB = preload("../items/item_db.gd")
const InventoryItem = preload("./inventory_item.gd")
const Hotbar = preload("../gui/hotbar/hotbar.gd")
const WaterUpdater = preload("./../water.gd")
const InteractionCommon = preload("./interaction_common.gd")

const COLLISION_LAYER_AVATAR = 2
const SERVER_PEER_ID = 1
const BASE_RAYCAST_MAX_DISTANCE = 16.0

const _hotbar_keys = {
	KEY_1: 0,
	KEY_2: 1,
	KEY_3: 2,
	KEY_4: 3,
	KEY_5: 4,
	KEY_6: 5,
	KEY_7: 6,
	KEY_8: 7,
	KEY_9: 8
}

@export var terrain_path : NodePath
@export var cursor_material : Material

# TODO Eventually invert these dependencies
@onready var _head : Camera3D = get_parent().get_node("Camera")
@onready var _hotbar : Hotbar = get_node("../HUD/HotBar")
@onready var _block_types : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _item_db : ItemDB = get_node("/root/Main/Game/Items")
@onready var _water_updater : WaterUpdater
@onready var _multi_terrain: VoxelMultiTerrain = get_node("/root/Main/Game/VoxelMultiTerrain")
@onready var _voxel_tool := _multi_terrain.get_voxel_tool()
@onready var _voxel_highlight_manager: VoxelHighlightManager = get_node("/root/Main/Game/VoxelHighlightManager")

var _cursor: MeshInstance3D = null
var _action_place := false
var _action_use := false
var _action_pick := false
## One-based index of the terrain on which blocks are placed.
var _placement_scale := 1
var _error_highlight: VoxelHighlight


func _ready():
	var mesh := Util.create_wirecube_mesh(Color(0,0,0))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if cursor_material != null:
		mesh_instance.material_override = cursor_material
	mesh_instance.set_scale(Vector3.ONE * 1.01)
	_cursor = mesh_instance
	_multi_terrain.add_child(_cursor)

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() == false or mp.is_server():
		_water_updater = get_node("/root/Main/Game/Water")

	_error_highlight = _voxel_highlight_manager.create_highlight(self)


## Returns the result of a raycast from the player's head in the direction they are looking,
## up to a maximum distance based on the placement scale.
func _get_pointed_voxel() -> MultiTerrainVoxelRaycastResult:
	var origin := _head.get_global_transform().origin
	assert(not Util.vec3_has_nan(origin))
	var forward := -_head.get_transform().basis.z.normalized()
	var placement_terrain_index := _placement_scale - 1
	var placement_terrain_scale := _multi_terrain.terrains[placement_terrain_index].scale.x
	var max_distance := BASE_RAYCAST_MAX_DISTANCE * placement_terrain_scale
	var hit := _voxel_tool.raycast(origin, forward, max_distance)
	return hit


func _physics_process(_delta):
	if _multi_terrain == null:
		return
	
	DDD.set_text("Placement scale", str(_placement_scale))

	var hit := _get_pointed_voxel()
	if hit != null:
		var placement_terrain_index := _placement_scale - 1
		var placement_terrain := _multi_terrain.terrains[placement_terrain_index]
		_cursor.show()
		_cursor.position = hit.global_previous_position[placement_terrain_index]
		_cursor.scale = Vector3.ONE * placement_terrain.scale.x * 1.01
		DDD.set_text("Global pointed voxel", str(hit.global_position))
		DDD.set_text("Pointed voxel", str(hit.raycast_result.position))
		DDD.set_text("Global dist", str(hit.global_distance))
		DDD.set_text("Dist", str(hit.raycast_result.distance))
	else:
		_cursor.hide()
		DDD.set_text("Global pointed voxel", "---")
		DDD.set_text("Pointed voxel", "---")

	var inv_item := _hotbar.get_selected_item()
	
	# These inputs have to be in _fixed_process because they rely on collision queries
	if inv_item == null or inv_item.type == InventoryItem.TYPE_BLOCK:
		if hit != null:
			var voxel_tool := _voxel_tool.voxel_tools[hit.terrain]
			var hit_raw_id := voxel_tool.get_voxel(hit.raycast_result.position)
			var has_voxel := hit_raw_id != 0
			
			if _action_use and has_voxel:
				var pos := hit.raycast_result.position
				_place_single_block(hit.terrain_index, pos, 0)
			
			elif _action_place && inv_item != null:
				var placement_terrain_index := _placement_scale - 1
				var placement_terrain := _multi_terrain.terrains[placement_terrain_index]
				var placement_terrain_scale := int(placement_terrain.scale.x)
				var global_pos := hit.global_previous_position[placement_terrain_index]
				if has_voxel == false:
					global_pos = hit.global_position[placement_terrain_index]
				var pos := Vector3i(global_pos / placement_terrain_scale)
				# TODO: The collision area isn't necessarily going to be a whole cube voxel if e.g., the placed voxel is a stair shape
				var placement_size := Vector3i.ONE * placement_terrain_scale
				if not _voxel_tool.has_voxels_in_area(global_pos, placement_size):
					_place_single_block(placement_terrain_index, pos, inv_item.id)
				else:
					var placement_collisions := _voxel_tool.get_voxels_in_area(global_pos, placement_size)
					_error_highlight.set_voxels(placement_collisions)
					_error_highlight.flash(Color.RED, 0.1, 0.5, 0.3)
	
	elif inv_item.type == InventoryItem.TYPE_ITEM:
		if _action_use:
			var item = _item_db.get_item(inv_item.id)
			item.use(_head.global_transform)
	
	if _action_pick and hit != null:
		var voxel_tool := _voxel_tool.voxel_tools[hit.terrain]
		var hit_raw_id = voxel_tool.get_voxel(hit.raycast_result.position)
		var rm := _block_types.get_raw_mapping(hit_raw_id)
		_hotbar.try_select_slot_by_block_id(rm.block_id)

	_action_place = false
	_action_use = false
	_action_pick = false


func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_action_use = true
				MOUSE_BUTTON_RIGHT:
					_action_place = true
				MOUSE_BUTTON_MIDDLE:
					_action_pick = true
				MOUSE_BUTTON_WHEEL_DOWN:
					_hotbar.select_next_slot()
				MOUSE_BUTTON_WHEEL_UP:
					_hotbar.select_previous_slot()

	elif event is InputEventKey:
		if event.pressed:
			if _hotbar_keys.has(event.keycode):
				var slot_index = _hotbar_keys[event.keycode]
				_hotbar.select_slot(slot_index)
			elif event.keycode == KEY_EQUAL:
				_placement_scale = mini(_placement_scale + 1, _multi_terrain.terrains.size())
			elif event.keycode == KEY_MINUS:
				_placement_scale = maxi(_placement_scale - 1, 1)


func _place_single_block(terrain_index: int, pos: Vector3, block_id: int):
	var look_dir := -_head.get_transform().basis.z
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_place_single_block", terrain_index, pos, look_dir, block_id)
	else:
		var terrain := _multi_terrain.terrains[terrain_index]
		var terrain_tool := _voxel_tool.voxel_tools[terrain]
		InteractionCommon.place_single_block(terrain_tool, pos, look_dir,
			block_id, _block_types, _water_updater)


# TODO Maybe use `rpc_config` so this would be less awkward?
@rpc("any_peer", "call_remote", "reliable", 0)
func receive_place_single_block(terrain_index: int, pos: Vector3, look_dir: Vector3, block_id: int):
	# The server has a different script for remote players
	push_error("Didn't expect this method to be called")


class VoxelAreaResult:
	var terrain: VoxelTerrain
	var voxel_positions: Array[Vector3i]
	
	func _init(terrain: VoxelTerrain, voxel_positions: Array[Vector3i]) -> void:
		self.terrain = terrain
		self.voxel_positions = voxel_positions
