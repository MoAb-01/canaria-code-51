extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var ladder_area: Area2D = $Environment/Ladder
@onready var water_area: Area2D = $Environment/WaterZone
@onready var ambient_audio: AudioStreamPlayer = $AmbientAudio

func _ready() -> void:
	if not ambient_audio.playing:
		ambient_audio.play()
		
	# Wire up ladder climbing
	ladder_area.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			player.is_on_ladder = true
	)
	ladder_area.body_exited.connect(func(body: Node2D) -> void:
		if body == player:
			player.is_on_ladder = false
	)
	
	# Wire up ocean water physics
	water_area.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			player.is_in_water = true
	)
	water_area.body_exited.connect(func(body: Node2D) -> void:
		if body == player:
			player.is_in_water = false
	)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
