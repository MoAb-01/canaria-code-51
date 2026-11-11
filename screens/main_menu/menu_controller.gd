extends Control
## Main Menu Controller — Coordinates navigation between Main Buttons, Settings, and Credits.

const TOTAL_SETTINGS_ROWS: int = 6
var settings_index: int = 0

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

var credits_ctrl: CreditsController

func _ready() -> void:
	_setup_credits()

	var fade_overlay := get_node_or_null("../../FadeOverlay")
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1)
		fade_overlay.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(fade_overlay, "modulate:a", 0.0, 0.4)

	$MainButtons/PlayBtn.pressed.connect(_on_play_pressed)
	$MainButtons/OptionsBtn.pressed.connect(open_settings)
	$MainButtons/QuitBtn.pressed.connect(func(): get_tree().quit())
	if has_node("MainButtons/CreditsBtn"):
		$MainButtons/CreditsBtn.pressed.connect(open_credits)
	back_btn.pressed.connect(close_settings)

	_setup_settings_interactions()

	var fs = get_node_or_null("/root/FullscreenManager")
	if fs:
		fs.fullscreen_changed.connect(func(_enabled: bool): _update_ui_labels())

	_update_ui_labels()
	$MainButtons/PlayBtn.call_deferred("grab_focus")

func _setup_credits() -> void:
	credits_ctrl = CreditsController.new()
	credits_ctrl.overlay = get_node_or_null("%CreditsOverlay")
	credits_ctrl.clip_window = get_node_or_null("%CreditsOverlay/ClipWindow")
	credits_ctrl.credits_list = get_node_or_null("%CreditsOverlay/ClipWindow/CreditsList")
	credits_ctrl.back_button = get_node_or_null("%CreditsOverlay/CreditsBackBtn")
	credits_ctrl.main_margin = get_node_or_null("../../../MarginContainer")
	credits_ctrl.credits_closed.connect(func():
		$MainButtons/CreditsBtn.grab_focus()
	)
	add_child(credits_ctrl)

func _setup_settings_interactions() -> void:
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

func _process(delta: float) -> void:
	if credits_ctrl and credits_ctrl.is_active:
		credits_ctrl.update_scroll(delta)

func _unhandled_input(event: InputEvent) -> void:
	if credits_ctrl and credits_ctrl.is_active:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			credits_ctrl.close()
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
	match settings_index:
		0:
			if sm: sm.master_volume = clamp(sm.master_volume + (dir * 10), 0, 100)
		1:
			if sm: sm.music_volume = clamp(sm.music_volume + (dir * 10), 0, 100)
		2:
			if sm: sm.sfx_volume = clamp(sm.sfx_volume + (dir * 10), 0, 100)
		3:
			if sm: sm.ui_clicks_enabled = !sm.ui_clicks_enabled
		4:
			if sm:
				sm.is_fullscreen = !sm.is_fullscreen
				var fs = get_node_or_null("/root/FullscreenManager")
				if fs: fs.set_fullscreen(sm.is_fullscreen)

	if sm:
		sm.apply_all_settings()
		sm.save_settings()
	_update_ui_labels()

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
	var sm = get_node_or_null("/root/SaveManager")
	var m_vol: int = sm.master_volume if sm else 80
	var mu_vol: int = sm.music_volume if sm else 100
	var s_vol: int = sm.sfx_volume if sm else 80
	var clicks: bool = sm.ui_clicks_enabled if sm else true
	var fs_mode: bool = sm.is_fullscreen if sm else false

	master_val.text = "<  %d%%  >" % m_vol
	music_val.text = "<  %d%%  >" % mu_vol
	sfx_val.text = "<  %d%%  >" % s_vol
	ui_click_val.text = "<  ON  >" if clicks else "<  OFF  >"
	display_val.text = "< FULLSCREEN >" if fs_mode else "< WINDOWED >"

func open_settings() -> void:
	play_ui_blip()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
	if credits_ctrl:
		credits_ctrl.open()

func play_ui_blip() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	var allowed: bool = sm.ui_clicks_enabled if sm else true
	if allowed and click_player and click_player.stream:
		click_player.play()

func _on_play_pressed() -> void:
	play_ui_blip()
	var fade_overlay := get_node_or_null("../../FadeOverlay")
	if fade_overlay:
		var tw := create_tween()
		tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
		tw.tween_callback(func() -> void:
			get_tree().change_scene_to_file("res://levels/test_deck/test_deck.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://levels/test_deck/test_deck.tscn")
