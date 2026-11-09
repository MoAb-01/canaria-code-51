extends Sprite2D

@export var bob_amplitude: float = 1.1       # Gentle rise and fall
@export var bob_frequency: float = 1.4       # Smooth, natural pace
@export var roll_degree: float = 0.35        # Tiny rolling sway in place

@onready var start_y: float = position.y
var timer: float = 0.0

func _process(delta: float) -> void:
	timer += delta
	# Gentle sinus bobbing motion
	position.y = start_y + sin(timer * bob_frequency) * bob_amplitude
	# Slight roll (rotation) to simulate ocean swells
	rotation_degrees = sin(timer * (bob_frequency * 0.85)) * roll_degree

