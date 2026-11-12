class_name SaveIndicator
extends CanvasLayer
## Reusable retro corner Save Indicator.
## Displays animated "Saving..." -> "Saving Completed" transition in the bottom-right corner.

@onready var container: PanelContainer = $Container
@onready var icon_label: Label = $Container/HBox/IconLabel
@onready var status_label: Label = $Container/HBox/StatusLabel

var _tween: Tween = null
var _is_spinning: bool = false
var _spin_time: float = 0.0

const COLOR_SAVING: Color = Color(0.898, 0.663, 0.235, 1.0) # #E5A93C
const COLOR_COMPLETED: Color = Color(0.847, 0.953, 0.863, 1.0) # #D8F3DC
const COLOR_FAILED: Color = Color(0.95, 0.35, 0.35, 1.0)
const SPINNER_CHARS: Array[String] = ["•", "◌", "○", "●"]

func _ready() -> void:
	container.modulate.a = 0.0
	container.visible = false
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("save_requested"):
			eb.save_requested.connect(func(_slot, _id): start_save_sequence())
		if eb.has_signal("game_saved"):
			eb.game_saved.connect(_on_game_saved)

func _process(delta: float) -> void:
	if _is_spinning:
		_spin_time += delta
		var frame: int = int(_spin_time * 7.0) % SPINNER_CHARS.size()
		icon_label.text = SPINNER_CHARS[frame]

func _on_game_saved(_slot: int, success: bool) -> void:
	if not success:
		_show_save_error()
		return
	start_save_sequence()

func start_save_sequence() -> void:
	if _tween and _tween.is_valid(): _tween.kill()
	container.visible = true
	_is_spinning = true
	_spin_time = 0.0
	icon_label.text = "●"
	icon_label.modulate = COLOR_SAVING
	status_label.text = "Saving..."
	status_label.modulate = COLOR_SAVING

	_tween = create_tween()
	# Phase 1: Fade in (0.15s), show saving for 0.6s
	_tween.tween_property(container, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(0.6)

	# Phase 2: Completed (1.6s)
	_tween.tween_callback(_transition_to_completed)
	_tween.tween_interval(1.6)

	# Phase 3: Fade out (0.3s)
	_tween.tween_property(container, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func():
		container.visible = false
		_is_spinning = false
	)

func _transition_to_completed() -> void:
	_is_spinning = false
	icon_label.text = "✓"
	icon_label.modulate = COLOR_COMPLETED
	status_label.text = "Saving Completed"
	status_label.modulate = COLOR_COMPLETED

func _show_save_error() -> void:
	if _tween and _tween.is_valid(): _tween.kill()
	container.visible = true
	_is_spinning = false
	icon_label.text = "✕"
	icon_label.modulate = COLOR_FAILED
	status_label.text = "Save Failed"
	status_label.modulate = COLOR_FAILED

	_tween = create_tween()
	_tween.tween_property(container, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(1.5)
	_tween.tween_property(container, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func(): container.visible = false)
