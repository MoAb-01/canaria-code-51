extends Control

@onready var texture_rect: TextureRect = $TextureRect
@onready var audio_player: AudioStreamPlayer = $AudioPlayer
@onready var fade_overlay: ColorRect = $FadeOverlay

const TOTAL_FRAMES: int = 107
const FPS: float = 24.0

var frame_textures: Array[Texture2D] = []
var elapsed: float = 0.0
var is_transitioning: bool = false

func _ready() -> void:
	GameState.is_cutscene_active = true
	EventBus.cutscene_state_changed.emit(true)

	tree_exited.connect(func():
		GameState.is_cutscene_active = false
		EventBus.cutscene_state_changed.emit(false)
	)

	fade_overlay.modulate.a = 1.0
	
	# Load frames
	for i in range(1, TOTAL_FRAMES + 1):
		var p: String = "res://assets/textures/opening_frames/frame_%03d.jpg" % i
		var global_p: String = ProjectSettings.globalize_path(p)
		var img: Image = Image.load_from_file(global_p)
		if img:
			frame_textures.append(ImageTexture.create_from_image(img))
			
	if frame_textures.size() > 0:
		texture_rect.texture = frame_textures[0]
		
	# Play audio
	var ogg_path: String = ProjectSettings.globalize_path("res://assets/audio/opening_audio.ogg")
	var stream: AudioStream = AudioStreamOggVorbis.load_from_file(ogg_path)
	if stream:
		audio_player.stream = stream
		audio_player.play()
		
	var tween: Tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.25)

func _process(delta: float) -> void:
	if is_transitioning:
		return
		
	elapsed += delta
	var frame_idx: int = int(elapsed * FPS)
	
	if frame_idx < frame_textures.size():
		texture_rect.texture = frame_textures[frame_idx]
	else:
		start_fade_out()
		
	if elapsed >= 3.8 and not is_transitioning:
		start_fade_out()

func start_fade_out() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	GameState.is_cutscene_active = false
	EventBus.cutscene_state_changed.emit(false)
	
	var tween: Tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://screens/teaser/teaser.tscn")
	)
