class_name BaseCharacter
extends CharacterBody2D
## BaseCharacter — Foundation class for top-down 2D characters (Player, NPCs, Guards).
## Handles feet-anchored Y-sorting, cardinal direction tracking, integer pixel snapping,
## and standardized animation playback across 4 directions.

signal direction_changed(new_dir: Vector2)

@export var move_speed: float = 180.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0

var last_facing_dir: Vector2 = Vector2.DOWN:
	set(val):
		var cardinal := _to_cardinal(val)
		if cardinal != last_facing_dir and cardinal != Vector2.ZERO:
			last_facing_dir = cardinal
			direction_changed.emit(last_facing_dir)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var shadow: Node2D = $Shadow if has_node("Shadow") else null

func _ready() -> void:
	y_sort_enabled = true
	if sprite:
		sprite.y_sort_enabled = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _physics_process(delta: float) -> void:
	_character_process(delta)
	snap_to_pixel()

func _character_process(_delta: float) -> void:
	pass

func snap_to_pixel() -> void:
	global_position = global_position.round()

func play_directional_anim(action_prefix: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return

	var suffix := get_direction_suffix()
	var anim_name := action_prefix + "_" + suffix

	if last_facing_dir == Vector2.LEFT:
		sprite.flip_h = true
	elif last_facing_dir == Vector2.RIGHT:
		sprite.flip_h = false

	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
	else:
		if sprite.sprite_frames.has_animation(action_prefix):
			sprite.play(action_prefix)

func play_locomotion(is_moving: bool) -> void:
	play_directional_anim("walk" if is_moving else "idle")

func get_direction_suffix() -> String:
	if last_facing_dir == Vector2.UP:
		if sprite: sprite.flip_h = false
		return "up"
	elif last_facing_dir == Vector2.DOWN:
		if sprite: sprite.flip_h = false
		return "down"
	if sprite:
		sprite.flip_h = (last_facing_dir == Vector2.LEFT)
	return "side"

func _get_dir_suffix() -> String:
	return get_direction_suffix()

func _to_cardinal(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return last_facing_dir
	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0.0 else Vector2.UP

