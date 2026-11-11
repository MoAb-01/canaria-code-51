extends Control
## Main Menu Controller — Coordinates navigation between Main Buttons, Settings, and Credits.

const CreditsControllerScript = preload("res://screens/main_menu/credits_controller.gd")

const TOTAL_SETTINGS_ROWS: int = 6
var settings_index: int = 0
var credits_ctrl: Node = null
var _settings_tween: Tween = null

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings_rack: VBoxContainer = $SettingsRack

@onready var master_val: Label = $SettingsRack/MasterRow/ValueLabel
@onready var music_val: Label = $SettingsRack/MusicRow/ValueLabel
@onready var sfx_val: Label = $SettingsRack/SfxRow/ValueLabel
@onready var ui_click_val: Label = $SettingsRack/UiClickRow/ValueLabel
@onready var display_val: Label = $SettingsRack/DisplayRow/ValueLabel
@onready var back_btn: Button = $SettingsRack/BackBtn

@export var click_player: AudioStreamPlayer
@export var hover_player: AudioStreamPlayer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if main_buttons:
		main_buttons.mouse_filter = Control.MOUSE_FILTER_PASS

	_setup_credits()

	var fade_overlay := _get_fade_overlay()
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1)
		fade_overlay.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(fade_overlay, "modulate:a", 0.0, 0.4)

	# Wire main buttons
	var play_btn: Button = get_node_or_null("MainButtons/PlayBtn")
	var options_btn: Button = get_node_or_null("MainButtons/OptionsBtn")
	var quit_btn: Button = get_node_or_null("MainButtons/QuitBtn")
	var credits_btn: Button = get_node_or_null("MainButtons/CreditsBtn")

	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
		play_btn.focus_mode = Control.FOCUS_ALL
	if options_btn:
		options_btn.pressed.connect(open_settings)
		options_btn.focus_mode = Control.FOCUS_ALL
	if quit_btn:
		quit_btn.pressed.connect(func(): get_tree().quit())
		quit_btn.focus_mode = Control.FOCUS_ALL
	if credits_btn:
		credits_btn.pressed.connect(open_credits)
		credits_btn.focus_mode = Control.FOCUS_ALL

	back_btn.pressed.connect(close_settings)
	_setup_settings_interactions()

	var fs = get_node_or_null("/root/FullscreenManager")
	if fs:
		fs.fullscreen_changed.connect(func(_enabled: bool): _update_ui_labels())

	_update_ui_labels()
	call_deferred("_grab_initial_focus")

func _grab_initial_focus() -> void:
	var play_btn: Button = get_node_or_null("MainButtons/PlayBtn")
	if play_btn:
		play_btn.grab_focus()

func _setup_credits() -> void:
	credits_ctrl = CreditsControllerScript.new()
	var ui_root := get_node_or_null("../../..")
	if ui_root:
		credits_ctrl.overlay = ui_root.get_node_or_null("CreditsOverlay")
		if credits_ctrl.overlay:
			credits_ctrl.clip_window = credits_ctrl.overlay.get_node_or_null("ClipWindow")
			if credits_ctrl.clip_window:
				credits_ctrl.credits_list = credits_ctrl.clip_window.get_node_or_null("CreditsList")
			credits_ctrl.back_button = credits_ctrl.overlay.get_node_or_null("CreditsBackBtn")
		credits_ctrl.main_margin = ui_root.get_node_or_null("MarginContainer")

	if credits_ctrl.has_signal("credits_closed"):
		credits_ctrl.credits_closed.connect(func():
			var c_btn = get_node_or_null("MainButtons/CreditsBtn")
			if c_btn:
				c_btn.grab_focus()
		)
	add_child(credits_ctrl)

func _setup_settings_interactions() -> void:
	var rows = [$SettingsRack/MasterRow, $SettingsRack/MusicRow, $SettingsRack/SfxRow, $SettingsRack/UiClickRow, $SettingsRack/DisplayRow, back_btn]
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
					var dir = 1 if (idx in [3, 4] or event.position.x >= row_node.size.x * 0.5) else -1
					_adjust_setting(dir)
			)

func _process(delta: float) -> void:
	if credits_ctrl and credits_ctrl.get("is_active"):
		credits_ctrl.update_scroll(delta)

func _unhandled_input(event: InputEvent) -> void:
	if credits_ctrl and credits_ctrl.get("is_active"):
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			credits_ctrl.close()
			get_viewport().set_input_as_handled()
		return

	if not settings_rack.visible:
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		var delta = -1 if event.is_action_pressed("ui_up") else 1
		settings_index = posmod(settings_index + delta, TOTAL_SETTINGS_ROWS)
		play_ui_blip()
		_update_settings_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_adjust_setting(-1 if event.is_action_pressed("ui_left") else 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if settings_index == 5:
			close_settings()
		elif settings_index in [3, 4]:
			_adjust_setting(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close_settings()
		get_viewport().set_input_as_handled()

func _adjust_setting(dir: int) -> void:
	play_ui_blip()
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		match settings_index:
			0: sm.master_volume = clamp(sm.master_volume + (dir * 10), 0, 100)
			1: sm.music_volume = clamp(sm.music_volume + (dir * 10), 0, 100)
			2: sm.sfx_volume = clamp(sm.sfx_volume + (dir * 10), 0, 100)
			3: sm.ui_clicks_enabled = !sm.ui_clicks_enabled
			4:
				sm.is_fullscreen = !sm.is_fullscreen
				var fs = get_node_or_null("/root/FullscreenManager")
				if fs: fs.set_fullscreen(sm.is_fullscreen)
		sm.apply_all_settings()
		sm.save_settings()
	_update_ui_labels()

func _update_settings_highlight() -> void:
	var rows = [$SettingsRack/MasterRow, $SettingsRack/MusicRow, $SettingsRack/SfxRow, $SettingsRack/UiClickRow, $SettingsRack/DisplayRow, back_btn]
	for i in range(rows.size()):
		rows[i].modulate = Color("ff9a1f") if i == settings_index else Color("e5edf5")

func _update_ui_labels() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	master_val.text = "<  %d%%  >" % (sm.master_volume if sm else 80)
	music_val.text = "<  %d%%  >" % (sm.music_volume if sm else 100)
	sfx_val.text = "<  %d%%  >" % (sm.sfx_volume if sm else 80)
	ui_click_val.text = "<  ON  >" if (sm.ui_clicks_enabled if sm else true) else "<  OFF  >"
	display_val.text = "< FULLSCREEN >" if (sm.is_fullscreen if sm else false) else "< WINDOWED >"

func open_settings() -> void:
	play_ui_blip()
	if _settings_tween and _settings_tween.is_valid():
		_settings_tween.kill()

	main_buttons.visible = true
	settings_rack.visible = true
	settings_index = 0
	_update_settings_highlight()

	_settings_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_settings_tween.tween_property(main_buttons, "position:x", -180.0, 0.14)
	_settings_tween.tween_property(main_buttons, "modulate:a", 0.0, 0.14)
	settings_rack.position.x = 180.0
	settings_rack.modulate.a = 0.0
	_settings_tween.tween_property(settings_rack, "position:x", 0.0, 0.18)
	_settings_tween.tween_property(settings_rack, "modulate:a", 1.0, 0.18)
	_settings_tween.chain().tween_callback(func(): main_buttons.visible = false)

func close_settings() -> void:
	play_ui_blip()
	if _settings_tween and _settings_tween.is_valid():
		_settings_tween.kill()

	main_buttons.visible = true
	settings_rack.visible = true

	_settings_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_settings_tween.tween_property(settings_rack, "position:x", 180.0, 0.14)
	_settings_tween.tween_property(settings_rack, "modulate:a", 0.0, 0.14)
	_settings_tween.tween_property(main_buttons, "position:x", 0.0, 0.18)
	_settings_tween.tween_property(main_buttons, "modulate:a", 1.0, 0.18)
	_settings_tween.chain().tween_callback(func():
		settings_rack.visible = false
		var opt_btn = get_node_or_null("MainButtons/OptionsBtn")
		if opt_btn: opt_btn.grab_focus()
	)

func open_credits() -> void:
	play_ui_blip()
	if credits_ctrl and credits_ctrl.has_method("open"):
		credits_ctrl.open()

func play_ui_blip() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if (sm.ui_clicks_enabled if sm else true) and click_player and click_player.stream:
		click_player.play()

func _get_fade_overlay() -> ColorRect:
	var fo: ColorRect = get_node_or_null("../../../FadeOverlay")
	if not fo and owner:
		fo = owner.find_child("FadeOverlay", true, false)
	return fo

func _on_play_pressed() -> void:
	print("[MainMenu] Play button pressed! Loading test deck scene...")
	play_ui_blip()
	var fade_overlay := _get_fade_overlay()
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1)
		fade_overlay.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
		tw.tween_callback(func() -> void:
			get_tree().change_scene_to_file("res://levels/test_deck/test_deck.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://levels/test_deck/test_deck.tscn")
