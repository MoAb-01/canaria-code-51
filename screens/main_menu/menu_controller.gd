extends Control
## Main Menu Controller — Coordinates navigation between Main Buttons, OptionsPanel, and Credits.

const CreditsControllerScript = preload("res://screens/main_menu/credits_controller.gd")

var credits_ctrl: Node = null
var _menu_tween: Tween = null

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options_panel: Control = $OptionsPanel if has_node("OptionsPanel") else get_node_or_null("../OptionsPanel")

@export var click_player: AudioStreamPlayer
@export var hover_player: AudioStreamPlayer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if main_buttons:
		main_buttons.mouse_filter = Control.MOUSE_FILTER_PASS

	_setup_credits()
	_setup_options()

	var fade_overlay := _get_fade_overlay()
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1)
		fade_overlay.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(fade_overlay, "modulate:a", 0.0, 0.4)

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

	call_deferred("_grab_initial_focus")

func _setup_options() -> void:
	if not options_panel:
		options_panel = find_child("OptionsPanel", true, false)
	if options_panel:
		options_panel.visible = false
		options_panel.closed.connect(close_settings)

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

func _process(delta: float) -> void:
	if credits_ctrl and credits_ctrl.get("is_active"):
		credits_ctrl.update_scroll(delta)

func _unhandled_input(event: InputEvent) -> void:
	if credits_ctrl and credits_ctrl.get("is_active"):
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			credits_ctrl.close()
			get_viewport().set_input_as_handled()
		return

func open_settings() -> void:
	play_ui_blip()
	if _menu_tween and _menu_tween.is_valid():
		_menu_tween.kill()

	_menu_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(main_buttons, "position:x", -180.0, 0.14)
	_menu_tween.tween_property(main_buttons, "modulate:a", 0.0, 0.14)
	_menu_tween.chain().tween_callback(func():
		main_buttons.visible = false
		if options_panel:
			options_panel.open()
	)

func close_settings() -> void:
	play_ui_blip()
	if _menu_tween and _menu_tween.is_valid():
		_menu_tween.kill()

	main_buttons.visible = true
	_menu_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(main_buttons, "position:x", 0.0, 0.18)
	_menu_tween.tween_property(main_buttons, "modulate:a", 1.0, 0.18)
	_menu_tween.chain().tween_callback(func():
		var options_btn: Button = get_node_or_null("MainButtons/OptionsBtn")
		if options_btn:
			options_btn.grab_focus()
	)

func open_credits() -> void:
	play_ui_blip()
	if credits_ctrl:
		credits_ctrl.open()

func _on_play_pressed() -> void:
	play_ui_blip()
	var fade_overlay := _get_fade_overlay()
	if fade_overlay:
		var tw := create_tween()
		tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.35)
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://levels/test_deck/test_deck.tscn"))
	else:
		get_tree().change_scene_to_file("res://levels/test_deck/test_deck.tscn")

func _get_fade_overlay() -> ColorRect:
	var ui_root := get_node_or_null("../../..")
	if ui_root:
		return ui_root.get_node_or_null("FadeOverlay") as ColorRect
	return null

func play_ui_blip() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and not sm.ui_clicks_enabled:
		return
	if click_player:
		click_player.pitch_scale = randf_range(0.98, 1.02)
		click_player.play()
