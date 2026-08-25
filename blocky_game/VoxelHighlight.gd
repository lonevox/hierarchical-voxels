extends MultiMeshInstance3D
class_name VoxelHighlight


var _multi_terrain: VoxelMultiTerrain
var _material: StandardMaterial3D
var _tween: Tween


func _initialize(multi_terrain: VoxelMultiTerrain, highlight_mesh: Mesh) -> void:
	assert(_multi_terrain == null)
	_multi_terrain = multi_terrain

	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	_material.albedo_color = Color(1, 1, 1, 0.5)

	var instance_multimesh := MultiMesh.new()
	instance_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instance_multimesh.mesh = highlight_mesh
	multimesh = instance_multimesh
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()


## Replaces the voxels shown by this highlight. Positions must be in the local coordinate space of
## their corresponding terrain.
func set_voxels(voxels_by_terrain: Dictionary[VoxelTerrain, Array]) -> void:
	var voxel_count := 0
	for terrain in voxels_by_terrain:
		if not _multi_terrain.terrains.has(terrain):
			push_error("Cannot highlight voxels from a terrain outside the configured VoxelMultiTerrain")
			continue
		voxel_count += voxels_by_terrain[terrain].size()

	if voxel_count == 0:
		_hide_voxels()
		return

	if multimesh.instance_count < voxel_count:
		multimesh.instance_count = voxel_count

	var highlight_transform_inverse := global_transform.affine_inverse()
	var instance_index := 0
	for terrain in voxels_by_terrain:
		if not _multi_terrain.terrains.has(terrain):
			continue
		var terrain_to_highlight := highlight_transform_inverse * terrain.global_transform
		var positions: Array = voxels_by_terrain[terrain]
		for position: Vector3i in positions:
			var center := Vector3(position) + Vector3.ONE * 0.5
			var voxel_transform := Transform3D(Basis.IDENTITY, center)
			multimesh.set_instance_transform(instance_index, terrain_to_highlight * voxel_transform)
			instance_index += 1

	multimesh.visible_instance_count = voxel_count
	show()


## Sets a persistent color for this highlight and stops any animation in progress.
func set_color(color: Color) -> void:
	_kill_tween()
	_material.albedo_color = color


## Displays the current voxels with a fade-in, hold, and fade-out animation.
func flash(
		color: Color,
		fade_in_duration: float,
		hold_duration: float,
		fade_out_duration: float
) -> void:
	_kill_tween()
	var transparent_color := Color(color.r, color.g, color.b, 0)
	_material.albedo_color = transparent_color
	_tween = create_tween()
	_tween.tween_property(_material, "albedo_color", color, fade_in_duration)
	_tween.tween_interval(hold_duration)
	_tween.tween_property(_material, "albedo_color", transparent_color, fade_out_duration)
	_tween.tween_callback(_finish_flash)


## Hides the highlighted voxels and stops any animation in progress. Allocated instance capacity is
## retained so subsequent highlights can reuse it.
func clear() -> void:
	_kill_tween()
	_hide_voxels()


func _exit_tree() -> void:
	_kill_tween()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _hide_voxels() -> void:
	hide()
	multimesh.visible_instance_count = 0


func _finish_flash() -> void:
	_hide_voxels()
	_tween = null
