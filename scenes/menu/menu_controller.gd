extends Control

# Audio bus indices
var bus_master: int
var bus_music: int
var bus_sfx: int

# Persistent Settings State
var master_vol: int = 80
var music_vol: int = 100
var sfx_vol: int = 80
var ui_clicks_enabled: bool = true
var is_fullscreen: bool = false

# UI Row Selection Index for Settings
var settings_index: int = 0
const TOTAL_SETTINGS_ROWS: int = 6 # 0:Master, 1:Music, 2:SFX, 3:Clicks, 4:Display, 5:Back

# Node references
@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings_rack: VBoxContainer = $SettingsRack

@onready var master_val: Label = $SettingsRack/MasterRow/ValueLabel
@onready var music_val: Label = $SettingsRack/MusicRow/ValueLabel
@onready var sfx_val: Label = $SettingsRack/SfxRow/ValueLabel
@onready var ui_click_val: Label = $SettingsRack/UiClickRow/ValueLabel
@onready var display_val: Label = $SettingsRack/DisplayRow/ValueLabel
@onready var back_btn: Button = $SettingsRack/BackBtn

# --- CREDITS STATE ---
@export var credits_scroll_speed: float = 60.0
@export var fast_multiplier: float = 3.0

var is_in_credits: bool = false
var credits_y: float = 0.0
var credits_accumulator: float = 0.0

@onready var credits_overlay: Control = %CreditsOverlay
@onready var clip_window: Control = %CreditsOverlay/ClipWindow
@onready var credits_list: VBoxContainer = %CreditsOverlay/ClipWindow/CreditsList
@onready var credits_back_btn: Button = %CreditsOverlay/CreditsBackBtn
@onready var margin_container: MarginContainer = get_node("../../../MarginContainer")

# Optional AudioStreamPlayer for menu clicks
@export var click_player: AudioStreamPlayer
@export var hover_player: AudioStreamPlayer

func _ready() -> void:
	bus_master = AudioServer.get_bus_index("Master")
	bus_music = AudioServer.get_bus_index("Music") if AudioServer.get_bus_index("Music") != -1 else bus_master
	bus_sfx = AudioServer.get_bus_index("SFX") if AudioServer.get_bus_index("SFX") != -1 else bus_master

	# 1. Load saved settings from disk immediately on launch
	_load_settings_from_disk()

	# 2. Fade in from black on scene start
	var fade_overlay = get_node_or_null("../../FadeOverlay")
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1)
		fade_overlay.modulate.a = 1.0
		var tw = create_tween()
		tw.tween_property(fade_overlay, "modulate:a", 0.0, 0.4)

	# 3. Wire main buttons
	$MainButtons/OptionsBtn.pressed.connect(open_settings)
	$MainButtons/PlayBtn.pressed.connect(_on_play_pressed)
	$MainButtons/QuitBtn.pressed.connect(func(): get_tree().quit())
	if has_node("MainButtons/CreditsBtn"):
		$MainButtons/CreditsBtn.pressed.connect(open_credits)
	back_btn.pressed.connect(close_settings)
	if credits_back_btn:
		credits_back_btn.pressed.connect(close_credits)
		credits_back_btn.mouse_entered.connect(func():
			if credits_overlay and credits_overlay.visible:
				play_ui_blip()
		)

	# 4. Connect mouse hover and click interactions on settings rows
	var rows = [
		$SettingsRack/MasterRow,
		$SettingsRack/MusicRow,
		$SettingsRack/SfxRow,
		$SettingsRack/UiClickRow,
		$SettingsRack/DisplayRow,
		back_btn
	]
	for i in range(rows.size()):
		var row_node = rows[i]
		var idx = i
		row_node.mouse_entered.connect(func():
			if settings_rack.visible:
				settings_index = idx
				play_ui_blip()
				_update_settings_highlight()
		)
		if row_node is HBoxContainer:
			row_node.mouse_filter = Control.MOUSE_FILTER_STOP
			row_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			for child in row_node.get_children():
				if child is Control:
					child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_node.gui_input.connect(func(event: InputEvent):
				if settings_rack.visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					settings_index = idx
					_update_settings_highlight()
					if idx in [3, 4]:
						_adjust_setting(1)
					else:
						var half_w = row_node.size.x * 0.5
						var dir = -1 if event.position.x < half_w else 1
						_adjust_setting(dir)
			)
		else:
			row_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if FullscreenManager:
		FullscreenManager.fullscreen_changed.connect(func(fs: bool):
			is_fullscreen = fs
			_update_ui_labels()
		)

	# 5. Apply loaded audio and display settings
	_apply_all_settings()
	_update_ui_labels()
	$MainButtons/PlayBtn.call_deferred("grab_focus")

func play_ui_blip() -> void:
	if ui_clicks_enabled and click_player and click_player.stream:
		click_player.play()

# In-Place Slide Transitions
func open_settings() -> void:
	play_ui_blip()
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_buttons, "position:x", -180.0, 0.14)
	tw.tween_property(main_buttons, "modulate:a", 0.0, 0.14)
	
	settings_rack.visible = true
	settings_rack.position.x = 180.0
	settings_rack.modulate.a = 0.0
	tw.tween_property(settings_rack, "position:x", 0.0, 0.18)
	tw.tween_property(settings_rack, "modulate:a", 1.0, 0.18)
	
	await tw.finished
	main_buttons.visible = false
	settings_index = 0
	_update_settings_highlight()

func close_settings() -> void:
	play_ui_blip()
	_save_settings_to_disk()
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(settings_rack, "position:x", 180.0, 0.14)
	tw.tween_property(settings_rack, "modulate:a", 0.0, 0.14)
	
	main_buttons.visible = true
	tw.tween_property(main_buttons, "position:x", 0.0, 0.18)
	tw.tween_property(main_buttons, "modulate:a", 1.0, 0.18)
	
	await tw.finished
	settings_rack.visible = false
	$MainButtons/OptionsBtn.grab_focus()

func open_credits() -> void:
	play_ui_blip()
	is_in_credits = true

	# Start at bottom of the clip window so it rolls UPWARD
	credits_y = clip_window.size.y
	credits_accumulator = 0.0
	credits_list.position.y = floor(credits_y)

	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if margin_container:
		tw.tween_property(margin_container, "modulate:a", 0.0, 0.2)

	credits_overlay.visible = true
	credits_overlay.modulate.a = 0.0
	tw.tween_property(credits_overlay, "modulate:a", 1.0, 0.25)

	await tw.finished
	if margin_container:
		margin_container.visible = false
	if credits_back_btn:
		credits_back_btn.grab_focus()

func close_credits() -> void:
	play_ui_blip()
	is_in_credits = false

	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(credits_overlay, "modulate:a", 0.0, 0.2)

	if margin_container:
		margin_container.visible = true
		tw.tween_property(margin_container, "modulate:a", 1.0, 0.25)

	await tw.finished
	credits_overlay.visible = false
	$MainButtons/CreditsBtn.grab_focus()

# --- UPWARD SCROLL & INTEGER SNAPPING ---
func _process(delta: float) -> void:
	if not is_in_credits:
		return

	var speed = credits_scroll_speed
	if Input.is_action_pressed("ui_down"):
		speed *= fast_multiplier
	elif Input.is_action_pressed("ui_up"):
		speed = -credits_scroll_speed * 1.5

	# Integer pixel accumulator: step position by whole integer pixels
	credits_accumulator += speed * delta
	var step_pixels = floor(credits_accumulator)
	if step_pixels != 0.0:
		credits_accumulator -= step_pixels
		credits_y -= step_pixels # UPWARD motion

	# Loop reset when entire list exits the top of the clip area
	var list_h = maxf(credits_list.size.y, credits_list.get_minimum_size().y)
	if credits_y < -list_h:
		credits_y = clip_window.size.y

	# Snap position to whole integer pixel
	credits_list.position.y = floor(credits_y)

# Input Handling for Settings Navigation (Keyboard / Controller)
func _unhandled_input(event: InputEvent) -> void:
	if is_in_credits and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		close_credits()
		get_viewport().set_input_as_handled()
		return

	if not settings_rack.visible:
		return

	if event.is_action_pressed("ui_up"):
		settings_index = (settings_index - 1 + TOTAL_SETTINGS_ROWS) % TOTAL_SETTINGS_ROWS
		play_ui_blip()
		_update_settings_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		settings_index = (settings_index + 1) % TOTAL_SETTINGS_ROWS
		play_ui_blip()
		_update_settings_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_adjust_setting(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_adjust_setting(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if settings_index == 5: # Back button
			close_settings()
		elif settings_index in [3, 4]: # Toggles
			_adjust_setting(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close_settings()
		get_viewport().set_input_as_handled()

func _adjust_setting(dir: int) -> void:
	play_ui_blip()
	match settings_index:
		0:
			master_vol = clamp(master_vol + (dir * 10), 0, 100)
			AudioServer.set_bus_volume_db(bus_master, linear_to_db(float(master_vol) / 100.0))
		1:
			music_vol = clamp(music_vol + (dir * 10), 0, 100)
			AudioServer.set_bus_volume_db(bus_music, linear_to_db(float(music_vol) / 100.0))
		2:
			sfx_vol = clamp(sfx_vol + (dir * 10), 0, 100)
			AudioServer.set_bus_volume_db(bus_sfx, linear_to_db(float(sfx_vol) / 100.0))
		3:
			ui_clicks_enabled = !ui_clicks_enabled
		4:
			is_fullscreen = !is_fullscreen
			_apply_display_mode()
	
	_update_ui_labels()
	# Save immediately on every adjustment so changes persist even if the game is force-closed
	_save_settings_to_disk()

func _apply_display_mode() -> void:
	if FullscreenManager:
		FullscreenManager.set_fullscreen(is_fullscreen)
	else:
		var win = get_window()
		if is_fullscreen:
			if win: win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			if win:
				win.mode = Window.MODE_WINDOWED
				win.size = Vector2i(1280, 720)
				var screen_rect = DisplayServer.screen_get_usable_rect()
				win.position = screen_rect.position + (screen_rect.size - win.size) / 2
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _update_settings_highlight() -> void:
	var rows = [
		$SettingsRack/MasterRow,
		$SettingsRack/MusicRow,
		$SettingsRack/SfxRow,
		$SettingsRack/UiClickRow,
		$SettingsRack/DisplayRow,
		back_btn
	]
	for i in range(rows.size()):
		var target_color = Color("ff9a1f") if i == settings_index else Color("e5edf5")
		rows[i].modulate = target_color

func _update_ui_labels() -> void:
	master_val.text = "<  %d%%  >" % master_vol
	music_val.text  = "<  %d%%  >" % music_vol
	sfx_val.text    = "<  %d%%  >" % sfx_vol
	ui_click_val.text = "<  ON  >" if ui_clicks_enabled else "<  OFF  >"
	display_val.text  = "< FULLSCREEN >" if is_fullscreen else "< WINDOWED >"

func _apply_all_settings() -> void:
	AudioServer.set_bus_volume_db(bus_master, linear_to_db(float(master_vol) / 100.0))
	AudioServer.set_bus_volume_db(bus_music, linear_to_db(float(music_vol) / 100.0))
	AudioServer.set_bus_volume_db(bus_sfx, linear_to_db(float(sfx_vol) / 100.0))
	_apply_display_mode()

func _load_settings_from_disk() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		master_vol = config.get_value("audio", "master", 80)
		music_vol = config.get_value("audio", "music", 100)
		sfx_vol = config.get_value("audio", "sfx", 80)
		ui_clicks_enabled = config.get_value("audio", "ui_clicks", true)
		is_fullscreen = config.get_value("display", "fullscreen", is_fullscreen)
	else:
		# Fall back to current window mode
		var win = get_window()
		if win:
			is_fullscreen = (win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN or win.mode == Window.MODE_FULLSCREEN)
		else:
			var cur_mode = DisplayServer.window_get_mode()
			is_fullscreen = (cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _save_settings_to_disk() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_vol)
	config.set_value("audio", "music", music_vol)
	config.set_value("audio", "sfx", sfx_vol)
	config.set_value("audio", "ui_clicks", ui_clicks_enabled)
	config.set_value("display", "fullscreen", is_fullscreen)
	config.save("user://settings.cfg")

func _on_play_pressed() -> void:
	play_ui_blip()
	var fade_overlay = get_node_or_null("../../FadeOverlay")
	if fade_overlay:
		var tw = create_tween()
		tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
		tw.tween_callback(func() -> void:
			get_tree().change_scene_to_file("res://scenes/game/game.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")
