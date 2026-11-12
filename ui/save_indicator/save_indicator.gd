class_name SaveIndicator
extends CanvasLayer
## Minimalist borderless corner Save Indicator.
## State-driven by SaveManager disk I/O with guaranteed minimum display duration.

@onready var container: HBoxContainer = $Container
@onready var spinner_icon: Label = $Container/SpinnerIcon
@onready var status_label: Label = $Container/StatusLabel

const MIN_SAVING_DURATION: float = 0.75
const RESULT_HOLD_DURATION: float = 1.6
const BASE_OFFSET_BOTTOM: float = -36.0
const ROTATION_SPEED: float = 8.0

const COLOR_WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_FAILED: Color = Color(1.0, 0.42, 0.42, 1.0) # #FF6B6B

var _is_saving_in_progress: bool = false
var _disk_write_completed: bool = false
var _last_save_succeeded: bool = true
var _elapsed_saving_time: float = 0.0
var _tween: Tween = null

func _ready() -> void:
	container.modulate.a = 0.0
	container.visible = false
	spinner_icon.pivot_offset = Vector2(10, 10)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("save_requested"):
			eb.save_requested.connect(_on_save_requested)
		if eb.has_signal("game_saved"):
			eb.game_saved.connect(_on_game_saved)

func _process(delta: float) -> void:
	if not _is_saving_in_progress:
		return
	spinner_icon.rotation += delta * ROTATION_SPEED
	_elapsed_saving_time += delta
	if _disk_write_completed and _elapsed_saving_time >= MIN_SAVING_DURATION:
		_is_saving_in_progress = false
		_show_result()

func _on_save_requested(_slot: int = 1, _location_label: String = "") -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_is_saving_in_progress = true
	_disk_write_completed = false
	_elapsed_saving_time = 0.0

	container.visible = true
	spinner_icon.visible = true
	spinner_icon.rotation = 0.0
	spinner_icon.text = "⟳"
	spinner_icon.modulate = COLOR_WHITE
	status_label.text = "Saving..."
	status_label.modulate = COLOR_WHITE
	container.offset_bottom = BASE_OFFSET_BOTTOM + 4.0

	_tween = create_tween()
	_tween.parallel().tween_property(container, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(container, "offset_bottom", BASE_OFFSET_BOTTOM, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_game_saved(_slot: int, success: bool) -> void:
	if not _is_saving_in_progress:
		_on_save_requested(_slot, "")
	_disk_write_completed = true
	_last_save_succeeded = success

func _show_result() -> void:
	spinner_icon.rotation = 0.0
	spinner_icon.visible = false
	spinner_icon.text = ""
	if _last_save_succeeded:
		status_label.text = "Saving Completed"
		status_label.modulate = COLOR_WHITE
	else:
		status_label.text = "Save Failed"
		status_label.modulate = COLOR_FAILED

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(RESULT_HOLD_DURATION)
	_tween.tween_property(container, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func():
		container.visible = false
	)
