extends VoxelTerrain

func _ready() -> void:
	stream = VoxelStreamSQLite.new()
	stream.database_path = "res://save.file"

func _on_tree_exited() -> void:
	save_modified_blocks()
