class_name SaveIndicator
extends CanvasLayer
## Minimalist borderless corner Save Indicator.
## Displays a crisp white floating "Saving..." -> "Saving Completed" transition.

@onready var container: HBoxContainer = $Container
@onready var spinner_icon: Label = $Container/SpinnerIcon
@onready var status_label: Label = $Container/StatusLabel

var _tween: Tween = null
var _is_spinning: bool = false

const BASE_OFFSET_BOTTOM: float = -36.0
const ROTATION_SPEED: float = 8.0

func _ready() -> void:
	container.modulate.a = 0.0
	container.visible = false
	spinner_icon.pivot_offset = Vector2(10, 10)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("save_requested"):
			eb.save_requested.connect(func(_slot, _id): start_save_sequence())
		if eb.has_signal("game_saved"):
			eb.game_saved.connect(_on_game_saved)

func _process(delta: float) -> void:
	if _is_spinning:
		spinner_icon.rotation += delta * ROTATION_SPEED

func _on_game_saved(_slot: int, success: bool) -> void:
	if not success:
		_show_save_error()
		return
	start_save_sequence()

func start_save_sequence() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	container.visible = true
	_is_spinning = true
	spinner_icon.visible = true
	spinner_icon.rotation = 0.0
	spinner_icon.text = "⟳"
	status_label.text = "Saving..."
	container.offset_bottom = BASE_OFFSET_BOTTOM + 4.0

	_tween = create_tween()
	# Phase 1: Fade in (0.2s) and slide up by 4px
	_tween.parallel().tween_property(container, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(container, "offset_bottom", BASE_OFFSET_BOTTOM, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Phase 2: Hold saving state (0.9s)
	_tween.tween_interval(0.9)

	# Phase 3: Completion Phase (1.7s)
	_tween.tween_callback(_transition_to_completed)
	_tween.tween_interval(1.7)

	# Phase 4: Fade Out (0.25s)
	_tween.tween_property(container, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func():
		container.visible = false
		_is_spinning = false
	)

func _transition_to_completed() -> void:
	_is_spinning = false
	spinner_icon.rotation = 0.0
	spinner_icon.visible = false
	spinner_icon.text = ""
	status_label.text = "Saving Completed"

func _show_save_error() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	container.visible = true
	_is_spinning = false
	spinner_icon.rotation = 0.0
	spinner_icon.text = "✕"
	status_label.text = "Save Failed"

	_tween = create_tween()
	_tween.parallel().tween_property(container, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(1.5)
	_tween.tween_property(container, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func(): container.visible = false)
