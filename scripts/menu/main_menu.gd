extends Control

const SFX_HOVER: AudioStream = preload("res://assets/audio/ui_hover.wav")
const SFX_CLICK: AudioStream = preload("res://assets/audio/ui_click.wav")

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton

@onready var options_panel: PanelContainer = %OptionsPanel
@onready var credits_panel: PanelContainer = %CreditsPanel
@onready var volume_slider: HSlider = %VolumeSlider
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var close_options_button: Button = %CloseOptionsButton
@onready var close_credits_button: Button = %CloseCreditsButton

@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var ambient_audio: AudioStreamPlayer = $AmbientAudio
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

func _ready() -> void:
	# Fade in when entering menu
	fade_overlay.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.4)
	
	if not ambient_audio.playing:
		ambient_audio.play()
		
	# Setup all interactive buttons with audio feedback
	var all_buttons: Array[Button] = [
		play_button, options_button, credits_button, quit_button,
		close_options_button, close_credits_button
	]
	for btn in all_buttons:
		btn.mouse_entered.connect(_play_hover_sfx)
		btn.focus_entered.connect(_play_hover_sfx)
		btn.pressed.connect(_play_click_sfx)
		
	# Connect button actions
	play_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	close_options_button.pressed.connect(func(): options_panel.visible = false)
	close_credits_button.pressed.connect(func(): credits_panel.visible = false)
	
	# Options hooks
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	# Focus PLAY button initially so it highlights in orange with ">"
	play_button.call_deferred("grab_focus")

func _play_hover_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_HOVER
		sfx_player.play()

func _play_click_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_CLICK
		sfx_player.play()

func _on_start_pressed() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")
	)

func _on_options_pressed() -> void:
	credits_panel.visible = false
	options_panel.visible = true

func _on_credits_pressed() -> void:
	options_panel.visible = false
	credits_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_volume_changed(val: float) -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(val))

func _on_fullscreen_toggled(is_fullscreen: bool) -> void:
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
