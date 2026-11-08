extends Control

const START_CHIME: AudioStream = preload("res://assets/audio/sfx_beacon.wav")

@onready var press_prompt: Label = $PressKeyPrompt
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var audio_player: AudioStreamPlayer = $AmbientAudio
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

const PROMPT_DELAY: float = 0.8
var elapsed_time: float = 0.0
var is_starting: bool = false

func _ready() -> void:
	press_prompt.modulate.a = 0.0
	fade_overlay.modulate.a = 1.0
	
	if not audio_player.playing:
		audio_player.play()
		
	# Smooth fade-in from black
	var tween: Tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.4)

func _process(delta: float) -> void:
	if is_starting:
		return
		
	elapsed_time += delta
	
	# Prompt pulses gently in gold
	if elapsed_time >= PROMPT_DELAY:
		var pulse_time: float = elapsed_time - PROMPT_DELAY
		var pulse: float = (sin(pulse_time * 4.0) * 0.5 + 0.5) * 0.75 + 0.25
		press_prompt.modulate.a = pulse

func _unhandled_input(event: InputEvent) -> void:
	if is_starting:
		return
		
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		start_game_transition()

func start_game_transition() -> void:
	if is_starting:
		return
	is_starting = true
	
	if sfx_player:
		sfx_player.stream = START_CHIME
		sfx_player.play()
		
	# Prompt flash and smooth transition to main menu
	var tween: Tween = create_tween()
	tween.tween_property(press_prompt, "modulate:a", 1.0, 0.08)
	tween.tween_property(press_prompt, "modulate:a", 0.0, 0.12)
	tween.tween_interval(0.1)
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)
