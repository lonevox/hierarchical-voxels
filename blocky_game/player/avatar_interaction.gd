extends Node

const Util = preload("res://common/util.gd")
const InteractionCommon = preload("./interaction_common.gd")

const COLLISION_LAYER_AVATAR = 2
const SERVER_PEER_ID = 1
const BASE_RAYCAST_MAX_DISTANCE = 16.0
const CURSOR_SCALE = 0.95

# These timings are used for voxel placement errors.
const ERROR_FADE_IN_DURATION := 0.1;
const ERROR_HOLD_DURATION := 0.5;
const ERROR_FADE_OUT_DURATION := 0.3;

const _hotbar_keys = {
	KEY_1: 0,
	KEY_2: 1,
	KEY_3: 2,
	KEY_4: 3,
	KEY_5: 4
}

@export var terrain_path : NodePath
@export var cursor_material : Material

# TODO Eventually invert these dependencies
@onready var _head : Camera3D = get_parent().get_node("Camera")
@onready var _blocks : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _multi_terrain: VoxelMultiTerrain = get_node("/root/Main/Game/VoxelMultiTerrain")
@onready var _voxel_tool := _multi_terrain.get_voxel_tool()
@onready var _voxel_highlight_manager: VoxelHighlightManager = get_node("/root/Main/Game/VoxelHighlightManager")

var _cursor: MeshInstance3D = null
var _hud: PlayerHUD
var _action_place := false
var _action_use := false
var _action_pick := false
## One-based index of the terrain on which blocks are placed.
var _placement_scale := 1
var _error_highlight: VoxelHighlight


func set_hud(hud: PlayerHUD) -> void:
	_hud = hud


func _ready():
	assert(_hud != null)

	var mesh := Util.create_wirecube_mesh(Color(0,0,0))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if cursor_material != null:
		mesh_instance.material_override = cursor_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.scale = Vector3.ONE * CURSOR_SCALE
	_cursor = mesh_instance
	_multi_terrain.add_child(_cursor)

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
		var voxel_size := placement_terrain.scale.x
		var cursor_size := voxel_size * CURSOR_SCALE
		# This offset is used to center the cursor on the voxel, since the cursor's origin
		# is on its corner so when its scaled it needs to be moved.
		var cursor_offset := Vector3.ONE * (voxel_size - cursor_size) * 0.5
		_cursor.show()
		_cursor.position = Vector3(hit.global_previous_position[placement_terrain_index]) + cursor_offset
		_cursor.scale = Vector3.ONE * cursor_size
		DDD.set_text("Global pointed voxel", str(hit.global_position))
		DDD.set_text("Pointed voxel", str(hit.raycast_result.position))
		DDD.set_text("Global dist", str(hit.global_distance))
		DDD.set_text("Dist", str(hit.raycast_result.distance))
	else:
		_cursor.hide()
		DDD.set_text("Global pointed voxel", "---")
		DDD.set_text("Pointed voxel", "---")

	var material_id := _hud.get_selected_material_id()
	var shape_name := _hud.get_selected_shape_name()
	
	# These inputs have to be in _fixed_process because they rely on collision queries
	if hit != null:
		var voxel_tool := _voxel_tool.voxel_tools[hit.terrain]
		var hit_raw_id := voxel_tool.get_voxel(hit.raycast_result.position)
		var has_voxel := hit_raw_id != 0

		if _action_use and has_voxel:
			var pos := hit.raycast_result.position
			_erase_voxel(hit.terrain_index, pos)

		elif _action_place and material_id != -1:
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
				_place_voxel(placement_terrain_index, pos, material_id, shape_name)
			else:
				# Render voxel errors
				var placement_collisions := _voxel_tool.get_voxels_in_area(global_pos, placement_size)
				_error_highlight.set_voxels(placement_collisions)
				_error_highlight.flash(Color.RED, ERROR_FADE_IN_DURATION, ERROR_HOLD_DURATION, ERROR_FADE_OUT_DURATION)
				# Flash the cursor red
				var tween := create_tween()
				tween.tween_property(_cursor.material_override, "albedo_color", Color.RED, ERROR_FADE_IN_DURATION)
				tween.tween_interval(ERROR_HOLD_DURATION)
				tween.tween_property(_cursor.material_override, "albedo_color", Color.WHITE, ERROR_FADE_OUT_DURATION)
	
	if _action_pick and hit != null:
		var voxel_tool := _voxel_tool.voxel_tools[hit.terrain]
		var hit_raw_id = voxel_tool.get_voxel(hit.raycast_result.position)
		var mapping := _blocks.get_raw_mapping(hit_raw_id)
		_hud.try_select_material(mapping.material_id)
		_hud.try_select_shape(mapping.shape_name)

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
					_hud.select_next_hotbar_slot()
				MOUSE_BUTTON_WHEEL_UP:
					_hud.select_previous_hotbar_slot()

	elif event is InputEventKey:
		if event.pressed:
			if _hotbar_keys.has(event.keycode):
				var slot_index = _hotbar_keys[event.keycode]
				_hud.select_hotbar_slot(slot_index)
			elif event.keycode == KEY_EQUAL:
				_placement_scale = mini(_placement_scale + 1, _multi_terrain.terrains.size())
			elif event.keycode == KEY_MINUS:
				_placement_scale = maxi(_placement_scale - 1, 1)


func _place_voxel(
		terrain_index: int,
		pos: Vector3i,
		material_id: int,
		shape_name: StringName
	) -> void:
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(
			SERVER_PEER_ID,
			&"receive_place_voxel",
			terrain_index,
			pos,
			material_id,
			shape_name
		)
	else:
		var terrain := _multi_terrain.terrains[terrain_index]
		var terrain_tool := _voxel_tool.voxel_tools[terrain]
		InteractionCommon.place_voxel(terrain_tool, pos, material_id, _blocks, shape_name)


func _erase_voxel(terrain_index: int, pos: Vector3i) -> void:
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_erase_voxel", terrain_index, pos)
	else:
		var terrain := _multi_terrain.terrains[terrain_index]
		var terrain_tool := _voxel_tool.voxel_tools[terrain]
		InteractionCommon.erase_voxel(terrain_tool, pos)


# TODO Maybe use `rpc_config` so this would be less awkward?
@rpc("any_peer", "call_remote", "reliable", 0)
func receive_place_voxel(
		terrain_index: int,
		pos: Vector3i,
		material_id: int,
		shape_name: StringName
	) -> void:
	# The server has a different script for remote players.
	push_error("Didn't expect this method to be called")


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_erase_voxel(terrain_index: int, pos: Vector3i) -> void:
	# The server has a different script for remote players
	push_error("Didn't expect this method to be called")


class VoxelAreaResult:
	var terrain: VoxelTerrain
	var voxel_positions: Array[Vector3i]
	
	func _init(terrain: VoxelTerrain, voxel_positions: Array[Vector3i]) -> void:
		self.terrain = terrain
		self.voxel_positions = voxel_positions
