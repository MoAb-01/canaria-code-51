extends Node2D

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_tree().change_scene_to_file("res://screens/main_menu/main_menu.tscn")
