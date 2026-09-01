## Builds and indexes every voxel model used by the blocky game.
##
## A logical voxel is a material and a shape. Each logical voxel expands to one
## library model per geometrically distinct rotation and per shape part. Shape
## parts make multi-voxel shapes (such as the tall slopes) explicit without
## making their callers know how model IDs are laid out in the library.
extends Node
class_name Blocks

const AIR_ID := 0
const DEFAULT_MATERIAL: StringName = &"concrete"
const DEFAULT_SHAPE: StringName = &"cube"

const SHAPE_ROOT := "res://blocky_game/voxel_shapes"
const CONCRETE_MATERIAL := preload("res://blocky_game/concrete_triplanar.tres")

const _SIGNATURE_SCALE := 10000.0
const _SLOPE_COUNT := 8
const _SLOPE_COLLISION_SLICES := 8


class ShapePart:
	var mesh: Mesh
	## Cell offset from the shape anchor before rotation.
	var offset: Vector3i
	var collision_aabbs: Array[AABB]

	func _init(part_mesh: Mesh, part_offset: Vector3i, part_collision_aabbs: Array[AABB]) -> void:
		mesh = part_mesh
		offset = part_offset
		collision_aabbs = part_collision_aabbs


class ShapeRotation:
	## GridMap/godot_voxel orthogonal rotation index.
	var orthogonal_index: int
	var basis: Basis
	## One model ID per part, grouped by material name.
	var model_ids_by_material: Dictionary = {}

	func _init(rotation_index: int, rotation_basis: Basis) -> void:
		orthogonal_index = rotation_index
		basis = rotation_basis


class ShapeDefinition:
	var name: StringName
	var parts: Array[ShapePart]
	var rotations: Array[ShapeRotation] = []
	## Multi-voxel shapes have one part for each occupied voxel.
	var is_multi_voxel: bool

	func _init(shape_name: StringName, shape_parts: Array[ShapePart]) -> void:
		name = shape_name
		parts = shape_parts
		is_multi_voxel = shape_parts.size() > 1


class RawMapping:
	var material_id := -1
	var material_name: StringName
	var shape_name: StringName
	var rotation_index := 0
	var part_index := 0


var _voxel_library: VoxelBlockyLibrary
var _materials: Dictionary[StringName, Material] = {}
var _material_order: Array[StringName] = []
var _shapes: Dictionary[StringName, ShapeDefinition] = {}
var _shape_order: Array[StringName] = []
var _raw_mappings: Array[RawMapping] = []


func _ready() -> void:
	_generate_library()


func get_model_library() -> VoxelBlockyLibrary:
	assert(_voxel_library != null, "The voxel library is available after Blocks._ready()")
	return _voxel_library


func get_material_names() -> Array[StringName]:
	return _material_order.duplicate()


func get_material_count() -> int:
	return _material_order.size()


func get_material_id(material_name: StringName) -> int:
	var material_id := _material_order.find(material_name)
	assert(material_id != -1, "Unknown voxel material: %s" % material_name)
	return material_id


func get_material_name(material_id: int) -> StringName:
	assert(material_id >= 0 and material_id < _material_order.size())
	return _material_order[material_id]


func get_material_by_id(material_id: int) -> Material:
	return get_material(get_material_name(material_id))


func get_material(material_name: StringName) -> Material:
	assert(_materials.has(material_name), "Unknown voxel material: %s" % material_name)
	return _materials[material_name]


func get_shape_names() -> Array[StringName]:
	return _shape_order.duplicate()


func get_single_voxel_shape_names() -> Array[StringName]:
	var shape_names: Array[StringName] = []
	for shape_name in _shape_order:
		if not _shapes[shape_name].is_multi_voxel:
			shape_names.append(shape_name)
	return shape_names


func get_shape_mesh(shape_name: StringName) -> Mesh:
	var shape := _get_shape(shape_name)
	assert(not shape.is_multi_voxel, "A multi-voxel shape has more than one mesh")
	return shape.parts[0].mesh


func is_shape_multi_voxel(shape_name: StringName) -> bool:
	return _get_shape(shape_name).is_multi_voxel


func get_rotation_count(shape_name: StringName) -> int:
	return _get_shape(shape_name).rotations.size()


func get_rotation_basis(shape_name: StringName, rotation_index: int) -> Basis:
	var shape := _get_shape(shape_name)
	assert(rotation_index >= 0 and rotation_index < shape.rotations.size())
	return shape.rotations[rotation_index].basis


func get_model_id(material_name: StringName, shape_name: StringName, rotation_index := 0, part_index := 0) -> int:
	assert(_materials.has(material_name), "Unknown voxel material: %s" % material_name)
	var shape := _get_shape(shape_name)
	assert(rotation_index >= 0 and rotation_index < shape.rotations.size())
	assert(part_index >= 0 and part_index < shape.parts.size())
	var rotation := shape.rotations[rotation_index]
	assert(rotation.model_ids_by_material.has(material_name))
	return rotation.model_ids_by_material[material_name][part_index]


## Returns the component layout of a shape without modifying voxel data.
## Each entry has `offset: Vector3i` and `voxel_id: int` keys.
func get_shape_parts(material_name: StringName, shape_name: StringName, rotation_index := 0) -> Array[Dictionary]:
	var shape := _get_shape(shape_name)
	assert(rotation_index >= 0 and rotation_index < shape.rotations.size())
	var rotation := shape.rotations[rotation_index]
	var voxels: Array[Dictionary] = []
	for part_index in shape.parts.size():
		var part := shape.parts[part_index]
		voxels.append({
			"offset": _rotate_cell_offset(part.offset, rotation.basis),
			"voxel_id": get_model_id(material_name, shape_name, rotation_index, part_index),
		})
	return voxels


func get_raw_mapping(raw_id: int) -> RawMapping:
	assert(raw_id >= 0 and raw_id < _raw_mappings.size())
	return _raw_mappings[raw_id]


func _generate_library() -> void:
	assert(_voxel_library == null, "The voxel library must only be generated once")
	_register_material(DEFAULT_MATERIAL, CONCRETE_MATERIAL)
	_register_shapes()

	_voxel_library = VoxelBlockyLibrary.new()
	var air := VoxelBlockyModelEmpty.new()
	air.resource_name = "air"
	_voxel_library.add_model(air)
	_raw_mappings.append(RawMapping.new())

	for shape_name in _shape_order:
		var shape := _shapes[shape_name]
		shape.rotations = _find_distinct_rotations(shape)
	for material_id in _material_order.size():
		var material_name := _material_order[material_id]
		for shape_name in _shape_order:
			_add_shape_models(material_id, material_name, _shapes[shape_name])


func _register_material(material_name: StringName, material: Material) -> void:
	assert(not _materials.has(material_name))
	_materials[material_name] = material
	_material_order.append(material_name)


func _register_shapes() -> void:
	_register_shape(&"cube", [
		ShapePart.new(
			_load_mesh("%s/cube.obj" % SHAPE_ROOT),
			Vector3i.ZERO,
			[AABB(Vector3.ZERO, Vector3.ONE)])
	])
	_register_shape(&"slab", [
		ShapePart.new(
			_load_mesh("%s/slab.obj" % SHAPE_ROOT),
			Vector3i.ZERO,
			[AABB(Vector3.ZERO, Vector3(1.0, 0.5, 1.0))])
	])
	_register_shape(&"panel", [
		ShapePart.new(
			_load_mesh("%s/panel.obj" % SHAPE_ROOT),
			Vector3i.ZERO,
			[AABB(Vector3.ZERO, Vector3(1.0, 0.125, 1.0))])
	])
	_register_shape(&"stairs", [
		ShapePart.new(
			_load_mesh("%s/stairs.obj" % SHAPE_ROOT),
			Vector3i.ZERO,
			[
				AABB(Vector3.ZERO, Vector3(1.0, 0.5, 1.0)),
				AABB(Vector3(0.0, 0.5, 0.0), Vector3(0.5, 0.5, 1.0)),
			])
	])
	_register_shape(&"beam", [
		ShapePart.new(
			_load_mesh("%s/beam.obj" % SHAPE_ROOT),
			Vector3i.ZERO,
			[AABB(Vector3(0.0, 0.0, 0.25), Vector3(1.0, 0.3, 0.5))])
	])
	_register_shape(&"cylinder", [
		ShapePart.new(
			_load_mesh("%s/cylinder.obj" % SHAPE_ROOT),
			Vector3i.ZERO,
			[])
	])
	_register_shape(&"prism_corner", [
		ShapePart.new(
			_load_mesh("%s/prism_corner.obj" % SHAPE_ROOT),
			Vector3i.ZERO,
			[])
	])
	_register_shape(&"inner_prism_corner", [
		ShapePart.new(
			_load_mesh("%s/inner_prism_corner.obj" % SHAPE_ROOT),
			Vector3i.ZERO,
			[])
	])

	# A slope_N is one voxel wide and N voxels tall. Part 1 occupies the
	# anchor cell, part 2 the cell above it, and so on. Rotating the shape also
	# rotates these offsets, so horizontal and upside-down slopes need no
	# special representation.
	for height in range(1, _SLOPE_COUNT + 1):
		var parts: Array[ShapePart] = []
		for part_number in range(1, height + 1):
			var path := "%s/slopes/slope_%d_%d.obj" % [SHAPE_ROOT, height, part_number]
			parts.append(ShapePart.new(
				_load_mesh(path),
				Vector3i(0, part_number - 1, 0),
				_make_slope_collision_aabbs(height, part_number)))
		_register_shape(StringName("slope_%d" % height), parts)


func _register_shape(shape_name: StringName, parts: Array[ShapePart]) -> void:
	assert(not parts.is_empty())
	assert(not _shapes.has(shape_name))
	_shapes[shape_name] = ShapeDefinition.new(shape_name, parts)
	_shape_order.append(shape_name)


func _find_distinct_rotations(shape: ShapeDefinition) -> Array[ShapeRotation]:
	var rotations: Array[ShapeRotation] = []
	var signatures := {}
	var grid_map := GridMap.new()
	for orthogonal_index in 24:
		var basis := grid_map.get_basis_with_orthogonal_index(orthogonal_index)
		var signature := _get_shape_signature(shape, basis)
		if not signatures.has(signature):
			signatures[signature] = true
			rotations.append(ShapeRotation.new(orthogonal_index, basis))
	grid_map.free()
	return rotations


func _get_shape_signature(shape: ShapeDefinition, basis: Basis) -> String:
	# Coplanar triangle diagonals are importer details, not visible geometry.
	# A canonical set of transformed vertices correctly captures the symmetry of
	# these low-poly voxel solids without treating those diagonals as features.
	var unique_points := {}
	for part in shape.parts:
		var rotated_offset := basis * Vector3(part.offset)
		var faces := part.mesh.get_faces()
		assert(faces.size() % 3 == 0)
		for source_vertex in faces:
			var vertex := basis * (source_vertex - Vector3.ONE * 0.5)
			vertex += Vector3.ONE * 0.5 + rotated_offset
			unique_points[_vector_signature(vertex)] = true
	var points: Array[String] = []
	points.assign(unique_points.keys())
	points.sort()
	return ";".join(points)


func _vector_signature(vector: Vector3) -> String:
	return "%d,%d,%d" % [
		roundi(vector.x * _SIGNATURE_SCALE),
		roundi(vector.y * _SIGNATURE_SCALE),
		roundi(vector.z * _SIGNATURE_SCALE),
	]


func _add_shape_models(material_id: int, material_name: StringName, shape: ShapeDefinition) -> void:
	var material := _materials[material_name]
	for rotation_index in shape.rotations.size():
		var rotation := shape.rotations[rotation_index]
		var model_ids := PackedInt32Array()
		for part_index in shape.parts.size():
			var part := shape.parts[part_index]
			var model := VoxelBlockyModelMesh.new()
			model.resource_name = _model_resource_name(material_name, shape.name, rotation.orthogonal_index, part_index)
			model.mesh = part.mesh
			model.mesh_ortho_rotation_index = rotation.orthogonal_index
			model.collision_aabbs = _rotate_aabbs(part.collision_aabbs, rotation.basis)
			model.set_material_override(0, material)
			for surface_index in mini(part.mesh.get_surface_count(), 2):
				model.set_mesh_collision_enabled(surface_index, true)
			var model_id := _voxel_library.add_model(model)
			model_ids.append(model_id)
			var raw_mapping := RawMapping.new()
			raw_mapping.material_id = material_id
			raw_mapping.material_name = material_name
			raw_mapping.shape_name = shape.name
			raw_mapping.rotation_index = rotation_index
			raw_mapping.part_index = part_index
			_raw_mappings.append(raw_mapping)
		rotation.model_ids_by_material[material_name] = model_ids


func _get_shape(shape_name: StringName) -> ShapeDefinition:
	assert(_shapes.has(shape_name), "Unknown voxel shape: %s" % shape_name)
	return _shapes[shape_name]


func _model_resource_name(material_name: StringName, shape_name: StringName, orthogonal_index: int, part_index: int) -> String:
	return "%s:%s:r%d:p%d" % [material_name, shape_name, orthogonal_index, part_index]


func _rotate_cell_offset(offset: Vector3i, basis: Basis) -> Vector3i:
	var rotated := basis * Vector3(offset)
	return Vector3i(roundi(rotated.x), roundi(rotated.y), roundi(rotated.z))


func _rotate_aabbs(aabbs: Array[AABB], basis: Basis) -> Array[AABB]:
	var rotated: Array[AABB] = []
	for aabb in aabbs:
		var result := AABB()
		var has_point := false
		for corner_index in 8:
			var corner := aabb.get_endpoint(corner_index) - Vector3.ONE * 0.5
			corner = basis * corner + Vector3.ONE * 0.5
			if has_point:
				result = result.expand(corner)
			else:
				result = AABB(corner, Vector3.ZERO)
				has_point = true
		rotated.append(result)
	return rotated


func _make_slope_collision_aabbs(height: int, part_number: int) -> Array[AABB]:
	# VoxelBoxMover only supports boxes. Approximate the sloping face with
	# narrow columns so interaction/collision remains useful without turning
	# every slope part into a solid cube.
	var boxes: Array[AABB] = []
	var width := 1.0 / float(_SLOPE_COLLISION_SLICES)
	for slice_index in _SLOPE_COLLISION_SLICES:
		var x0 := float(slice_index) * width
		var x1 := float(slice_index + 1) * width
		var local_height := clampf(float(height) * (1.0 - x1) - float(part_number - 1), 0.0, 1.0)
		if local_height > 0.0:
			boxes.append(AABB(Vector3(x0, 0.0, 0.0), Vector3(width, local_height, 1.0)))
	return boxes


func _load_mesh(path: String) -> Mesh:
	var mesh := load(path) as Mesh
	assert(mesh != null, "Could not load voxel shape mesh: %s" % path)
	return mesh
