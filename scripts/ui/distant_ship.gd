extends Sprite2D

@export var travel_speed: float = 7.0 # Slow, majestic drift across the ocean horizon
@export var bob_amplitude: float = 2.2
@export var bob_frequency: float = 1.3

var base_y: float = 0.0
var elapsed: float = 0.0

func _ready() -> void:
	if texture == null:
		var p: String = ProjectSettings.globalize_path("res://assets/textures/cruise_ship_1980s.png")
		var img: Image = Image.load_from_file(p)
		if img:
			texture = ImageTexture.create_from_image(img)
			
	base_y = position.y

func _process(delta: float) -> void:
	elapsed += delta
	# Subtle bobbing with the ocean swell
	position.y = base_y + sin(elapsed * bob_frequency) * bob_amplitude
	# Slow continuous drift from left to right
	position.x += travel_speed * delta
	
	# Wrap around the horizon seamlessly
	if position.x > 2150.0:
		position.x = -350.0
