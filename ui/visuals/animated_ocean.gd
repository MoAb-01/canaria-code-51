extends TextureRect

@export var fps: float = 8.0

var frames: Array[Texture2D] = []
var current_frame_index: int = 0
var timer: float = 0.0

func _ready() -> void:
	# Load the 16 looping pixel-art animation frames in true 1080p color
	for i in range(16):
		var file_path: String = "res://assets/textures/water_frames/water_%02d.png" % i
		if ResourceLoader.exists(file_path):
			var tex: Texture2D = load(file_path)
			if tex:
				frames.append(tex)
				continue
		var global_p: String = ProjectSettings.globalize_path(file_path)
		var img: Image = Image.load_from_file(global_p)
		if img:
			frames.append(ImageTexture.create_from_image(img))
			
	if frames.size() > 0:
		texture = frames[0]

func _process(delta: float) -> void:
	if frames.size() <= 1:
		return
		
	timer += delta
	var frame_duration: float = 1.0 / fps
	if timer >= frame_duration:
		timer -= frame_duration
		current_frame_index = (current_frame_index + 1) % frames.size()
		texture = frames[current_frame_index]
