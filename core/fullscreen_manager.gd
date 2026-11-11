extends Node
## Centralized Fullscreen & Window Mode Manager.
## Handles F11 / Alt+Enter hotkeys and OS window resizing.

signal fullscreen_changed(is_fullscreen: bool)

func _ready() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	if err == OK:
		var saved_fs: bool = config.get_value("display", "fullscreen", config.get_value("preferences", "fullscreen", false))
		set_fullscreen.call_deferred(saved_fs, false)
	else:
		set_fullscreen.call_deferred(false, false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.alt_pressed and event.keycode == KEY_ENTER):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()

func is_fullscreen() -> bool:
	var win := get_window()
	if not win:
		return false
	return win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN or win.mode == Window.MODE_FULLSCREEN

func toggle_fullscreen() -> void:
	set_fullscreen(!is_fullscreen())

func set_fullscreen(enabled: bool, persist: bool = true) -> void:
	var win := get_window()
	if not win:
		return

	if enabled:
		win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		win.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		win.size = Vector2i(1280, 720)
		var screen_rect := DisplayServer.screen_get_usable_rect()
		win.position = screen_rect.position + (screen_rect.size - win.size) / 2

	fullscreen_changed.emit(enabled)
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.fullscreen_toggled.emit(enabled)

	if persist:
		_save_display_mode(enabled)

func _save_display_mode(enabled: bool) -> void:
	var config := ConfigFile.new()
	var _err := config.load("user://settings.cfg")
	config.set_value("display", "fullscreen", enabled)
	config.set_value("preferences", "fullscreen", enabled)
	config.save("user://settings.cfg")

