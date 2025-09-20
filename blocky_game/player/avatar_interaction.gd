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

var _cursor: MeshInstance3D = null
var _action_place := false
var _action_use := false
var _action_pick := false


func _ready():
	var mesh := Util.create_wirecube_mesh(Color(0,0,0))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if cursor_material != null:
		mesh_instance.material_override = cursor_material
	mesh_instance.set_scale(Vector3.ONE * 1.01)
	_cursor = mesh_instance
	_multi_terrain.terrains[0].add_child(_cursor)

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() == false or mp.is_server():
		_water_updater = get_node("/root/Main/Game/Water")


func _get_pointed_voxel() -> MultiTerrainVoxelRaycastResult:
	var origin := _head.get_global_transform().origin
	assert(not Util.vec3_has_nan(origin))
	var forward := -_head.get_transform().basis.z.normalized()
	var hit := _voxel_tool.raycast(origin, forward)
	return hit


func _physics_process(_delta):
	if _multi_terrain == null:
		return
	
	var hit := _get_pointed_voxel()
	if hit != null:
		if _cursor.get_parent() != hit.terrain:
			_cursor.reparent(hit.terrain, false)
		_cursor.show()
		_cursor.set_position(hit.raycast_result.position)
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
				_place_single_block(voxel_tool, pos, 0)
			
			elif _action_place && inv_item != null:
				var pos := hit.raycast_result.previous_position
				var global_pos := hit.global_previous_position
				if has_voxel == false:
					pos = hit.raycast_result.position
					global_pos = hit.global_position
				# TODO: The collision area isn't necessarily going to be a whole cube voxel if e.g., the placed voxel is a stair shape
				var placement_collisions := _voxel_tool.get_voxels_in_area(global_pos, hit.terrain.scale)
				placement_collisions.erase(hit.terrain)
				print(placement_collisions)
				if placement_collisions.is_empty():
					_place_single_block(voxel_tool, pos, inv_item.id)
					print("Place voxel at ", pos)
				else:
					print("Can't place here!")
					for terrain in placement_collisions:
						var collisions := placement_collisions[terrain]
						for collision in collisions:
							_error_on_voxel(terrain, collision)
	
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


func _error_on_voxel(terrain: VoxelTerrain, pos: Vector3i) -> void:
	var box := CSGBox3D.new()
	box.scale = Vector3.ONE * 1.01
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.albedo_color = Color(1, 0, 0, 0)
	box.material = material
	
	terrain.add_child(box)
	box.position = Vector3(pos) + box.size / 2
	
	var tween := get_tree().create_tween()
	tween.tween_property(material, "albedo_color", Color.RED, 0.1)
	tween.tween_interval(0.5)
	tween.tween_property(material, "albedo_color", Color(1, 0, 0, 0), 0.3)
	tween.tween_callback(func():
		terrain.remove_child(box)
		box.queue_free()
	)


func _place_single_block(terrain_tool: VoxelTool, pos: Vector3, block_id: int):
	var look_dir := -_head.get_transform().basis.z
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_place_single_block", pos, look_dir, block_id)
	else:
		InteractionCommon.place_single_block(terrain_tool, pos, look_dir,
			block_id, _block_types, _water_updater)


# TODO Maybe use `rpc_config` so this would be less awkward?
@rpc("any_peer", "call_remote", "reliable", 0)
func receive_place_single_block(pos: Vector3, look_dir: Vector3, block_id: int):
	# The server has a different script for remote players
	push_error("Didn't expect this method to be called")


class VoxelAreaResult:
	var terrain: VoxelTerrain
	var voxel_positions: Array[Vector3i]
	
	func _init(terrain: VoxelTerrain, voxel_positions: Array[Vector3i]) -> void:
		self.terrain = terrain
		self.voxel_positions = voxel_positions
