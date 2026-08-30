extends ColorRect

signal quit_requested


func _on_quit_button_pressed() -> void:
	quit_requested.emit()
