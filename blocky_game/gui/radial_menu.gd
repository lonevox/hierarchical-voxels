@tool
class_name RadialMenu
extends Node2D

## Emitted when closing the menu changes the selected option.
signal option_selected(option: RadialMenuOption)

const CENTER_SEGMENT := -1


@export var open_radius := 150.0
@export var open_width := 100.0
@export var animation_duration := 0.05
@export var label_settings: LabelSettings:
	set(value):
		label_settings = value
		if _label != null:
			_label.label_settings = value
			_update_label_layout()
@export var label_offset := 16.0:
	set(value):
		label_offset = value
		_update_label_layout()
@export var center_option: RadialMenuOption:
	set(value):
		var previous_center_option := center_option
		center_option = value
		if is_node_ready():
			if _selected_option == previous_center_option:
				_selected_option = value
			_update_label()
			queue_redraw()
			update_configuration_warnings()
@export var options: Array[RadialMenuOption] = []

var _highlighted_segment := CENTER_SEGMENT
var _selected_option: RadialMenuOption
var _is_open := false
var _label: Label

var radius := 0.0:
	set(value):
		radius = value
		queue_redraw()
		_update_label_layout()

var width := 0.0:
	set(value):
		width = value
		queue_redraw()
		_update_label_layout()

var _animation_tween: Tween


func _ready() -> void:
	if not Engine.is_editor_hint():
		assert(center_option != null, "RadialMenu requires a center_option")

	_create_label()
	_highlighted_segment = CENTER_SEGMENT
	_selected_option = center_option
	radius = open_radius
	width = open_width
	_update_label()

	if Engine.is_editor_hint():
		return

	radius = 0
	width = 0
	visible = false


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _is_open:
		_update_highlighted_segment()


func open_menu() -> void:
	if _is_open:
		return

	_is_open = true
	_animate_menu(open_radius, open_width, true)
	_update_highlighted_segment()


func close_menu() -> void:
	if not _is_open:
		return

	_is_open = false
	_animate_menu(0, 0, false)

	var highlighted_option := _get_highlighted_option()
	if highlighted_option != null and highlighted_option != _selected_option:
		_selected_option = highlighted_option
		option_selected.emit(_selected_option)


func _update_highlighted_segment() -> void:
	var center := get_viewport().get_visible_rect().size / 2
	var offset := get_local_mouse_position() - center
	var segment_inner_radius := maxf(radius - width / 2, 0)
	var has_reached_segment_ring := (
		offset.length_squared() >= segment_inner_radius * segment_inner_radius
	)
	var hovered_segment := _highlighted_segment

	if not has_reached_segment_ring:
		hovered_segment = CENTER_SEGMENT
	elif has_reached_segment_ring and not options.is_empty() and not offset.is_zero_approx():
		var angle_correction := -TAU / 4
		var angle := fposmod(offset.angle() - angle_correction, TAU)
		hovered_segment = int(angle / (TAU / options.size()))

	if hovered_segment != _highlighted_segment:
		_highlighted_segment = hovered_segment
		_update_label()
		queue_redraw()


func _animate_menu(target_radius: float, target_width: float, opening: bool) -> void:
	if _animation_tween != null and _animation_tween.is_valid():
		_animation_tween.kill()

	if opening:
		visible = true

	_animation_tween = create_tween()
	_animation_tween.set_trans(Tween.TRANS_QUAD)
	_animation_tween.set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN)
	_animation_tween.tween_property(self, "radius", target_radius, animation_duration)
	_animation_tween.parallel().tween_property(self, "width", target_width, animation_duration)

	if not opening:
		_animation_tween.tween_callback(func(): visible = false)


func _draw() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2

	if center_option != null:
		draw_circle(center, radius / 3, Color(0, 0, 0, 0.75), true, -1, true)
		if _highlighted_segment == CENTER_SEGMENT:
			draw_circle(center, radius / 3, Color(1, 1, 1, 0.25), true, -1, true)
		if center_option.texture != null:
			_draw_option_texture(center_option.texture, center, radius / 3)

	if options.is_empty():
		return

	# TAU represents a full circle rotation in radians
	var segment_size := TAU / options.size()
	var highlight_start := segment_size * _highlighted_segment
	var angle_correction := -TAU / 4
	draw_arc(center, radius, 0, TAU, options.size() * 8, Color(0, 0, 0, 0.75), width, true)
	if _highlighted_segment >= 0:
		draw_arc(center, radius, highlight_start + angle_correction, highlight_start + segment_size + angle_correction, 8, Color(1, 1, 1, 0.25), width, true)

	for option_index in options.size():
		var option := options[option_index]
		if option == null or option.texture == null:
			continue

		var option_angle := angle_correction + segment_size * (option_index + 0.5)
		var option_center := center + Vector2.from_angle(option_angle) * radius
		_draw_option_texture(option.texture, option_center, width / 2)


func _draw_option_texture(texture: Texture2D, texture_center: Vector2, maximum_dimension: float) -> void:
	var texture_size := texture.get_size()
	var largest_dimension := maxf(texture_size.x, texture_size.y)
	if largest_dimension <= 0:
		return

	# Keep icons inside their option and preserve their original aspect ratios.
	var draw_size := texture_size * minf(maximum_dimension / largest_dimension, 1)
	var draw_rect := Rect2(texture_center - draw_size / 2, draw_size)
	draw_texture_rect(texture, draw_rect, false)


func _create_label() -> void:
	_label = Label.new()
	_label.name = "OptionLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.label_settings = label_settings
	_label.minimum_size_changed.connect(_update_label_layout)
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	get_viewport().size_changed.connect(_update_label_layout)


func _update_label() -> void:
	if _label == null:
		return

	var highlighted_option := _get_highlighted_option()
	if highlighted_option == null or highlighted_option.name.is_empty():
		_label.hide()
		return

	_label.text = highlighted_option.name
	_label.show()
	_update_label_layout()


func _update_label_layout() -> void:
	if _label == null or not _label.visible:
		return

	_label.reset_size()
	var label_size := _label.size
	var center := get_viewport().get_visible_rect().size / 2
	var menu_outer_radius := radius + width / 2
	_label.position = center + Vector2(-label_size.x / 2, menu_outer_radius + label_offset)


## Returns the currently selected option.
func get_selected_option() -> RadialMenuOption:
	return _selected_option


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if center_option == null:
		warnings.append("RadialMenu requires a center_option.")
	return warnings


func _get_highlighted_option() -> RadialMenuOption:
	if _highlighted_segment == CENTER_SEGMENT:
		return center_option
	if _highlighted_segment >= 0 and _highlighted_segment < options.size():
		return options[_highlighted_segment]
	return null
