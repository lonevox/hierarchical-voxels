@tool
extends Node

@export_tool_button("Save to File") var save_to_file := _on_save_to_file_button_pressed
@export var noise_texture_3d: NoiseTexture3D

func _on_save_to_file_button_pressed():
	var image_texture := ImageTexture3D.new()
	image_texture.create(noise_texture_3d.get_format(), noise_texture_3d.width, noise_texture_3d.height, noise_texture_3d.depth, noise_texture_3d.has_mipmaps(), noise_texture_3d.get_data())
	ResourceSaver.save(image_texture, "res://noise_texture_out.tres")
