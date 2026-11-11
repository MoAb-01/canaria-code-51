class_name FlashlightController
extends Node2D
## Controls 2D flashlight pivot rotation, cone/spill visibility, and click audio.

@export var cone_light: PointLight2D
@export var spill_light: PointLight2D
@export var click_audio: AudioStreamPlayer2D

var is_on: bool = false
var is_suppressed: bool = false

func _ready() -> void:
	update_visibility()

func toggle() -> bool:
	set_on(!is_on)
	return is_on

func set_on(enabled: bool) -> void:
	if is_on == enabled:
		return
	is_on = enabled
	_play_click_sfx()
	update_visibility()
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.flashlight_toggled.emit(is_on)

func set_suppressed(suppressed: bool) -> void:
	is_suppressed = suppressed
	update_visibility()

func update_orientation(facing_dir: Vector2) -> void:
	if facing_dir == Vector2.RIGHT:
		rotation_degrees = 0.0
	elif facing_dir == Vector2.DOWN:
		rotation_degrees = 90.0
	elif facing_dir == Vector2.LEFT:
		rotation_degrees = 180.0
	elif facing_dir == Vector2.UP:
		rotation_degrees = 270.0

func update_visibility() -> void:
	var active: bool = is_on and not is_suppressed
	if cone_light:
		cone_light.enabled = active
	if spill_light:
		spill_light.enabled = active

func _play_click_sfx() -> void:
	if click_audio:
		click_audio.pitch_scale = randf_range(1.04, 1.08) if is_on else randf_range(0.94, 0.98)
		click_audio.play()
