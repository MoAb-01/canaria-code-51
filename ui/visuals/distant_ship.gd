extends Sprite2D

var time_elapsed: float = 0.0

func _ready() -> void:
	if texture == null:
		var path: String = ProjectSettings.globalize_path("res://assets/ui/menu_distant_ship.png")
		var img: Image = Image.load_from_file(path)
		if img:
			texture = ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	time_elapsed += delta
	# Subtly shift the ship vertically and roll it to match the waves
	position.y += sin(time_elapsed * 1.3) * 0.08
	rotation_degrees = sin(time_elapsed * 0.9) * 0.25
	
	# Slowly slide the HorizonLayer (Parallax2D) past the horizon
	if get_parent() is Parallax2D:
		var horizon_layer: Parallax2D = get_parent() as Parallax2D
		horizon_layer.scroll_offset.x += 2.0 * delta
