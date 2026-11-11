class_name CreditsController
extends Node
## Manages credits overlay display, vertical pixel scrolling, and speed multipliers.

@export var overlay: Control
@export var clip_window: Control
@export var credits_list: VBoxContainer
@export var back_button: Button
@export var main_margin: Control
@export var scroll_speed: float = 60.0
@export var fast_multiplier: float = 3.0

var is_active: bool = false
var credits_y: float = 0.0
var accumulator: float = 0.0

signal credits_closed()

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(close)

func open() -> void:
	if not overlay or not clip_window or not credits_list:
		return
	is_active = true
	credits_y = clip_window.size.y
	accumulator = 0.0
	credits_list.position.y = floorf(credits_y)

	var tw: Tween = overlay.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if main_margin:
		tw.tween_property(main_margin, "modulate:a", 0.0, 0.2)
	overlay.visible = true
	overlay.modulate.a = 0.0
	tw.tween_property(overlay, "modulate:a", 1.0, 0.25)
	await tw.finished
	if main_margin:
		main_margin.visible = false
	if back_button:
		back_button.grab_focus()

func close() -> void:
	if not is_active:
		return
	is_active = false
	var tw: Tween = overlay.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.2)
	if main_margin:
		main_margin.visible = true
		tw.tween_property(main_margin, "modulate:a", 1.0, 0.25)
	await tw.finished
	overlay.visible = false
	credits_closed.emit()

func update_scroll(delta: float) -> void:
	if not is_active or not credits_list or not clip_window:
		return

	var speed: float = scroll_speed
	if Input.is_action_pressed("ui_down"):
		speed *= fast_multiplier
	elif Input.is_action_pressed("ui_up"):
		speed = -scroll_speed * 1.5

	accumulator += speed * delta
	var step_pixels: float = floorf(accumulator)
	if step_pixels != 0.0:
		accumulator -= step_pixels
		credits_y -= step_pixels

	var list_h: float = maxf(credits_list.size.y, credits_list.get_minimum_size().y)
	if credits_y < -list_h:
		credits_y = clip_window.size.y

	credits_list.position.y = floorf(credits_y)
