extends CanvasLayer
## DialogueLayer — Global UI Autoload for character conversations, NPC interactions,
## and narrative prompts with 16-bit visual styling.

signal dialogue_started(speaker_name: String)
signal dialogue_advanced(line_index: int, total_lines: int)
signal dialogue_finished

var is_dialogue_open: bool = false
var _input_cooldown: float = 0.0
var _current_lines: Array[String] = []
var _current_index: int = 0
var _speaker_name: String = ""

@onready var panel: Control = $Panel
@onready var portrait_rect: TextureRect = $Panel/Margin/HBox/PortraitFrame/Portrait
@onready var portrait_frame: Control = $Panel/Margin/HBox/PortraitFrame
@onready var name_label: Label = $Panel/Margin/HBox/TextVBox/NameLabel
@onready var content_label: Label = $Panel/Margin/HBox/TextVBox/ContentLabel
@onready var prompt_label: Label = $Panel/Margin/HBox/TextVBox/PromptLabel

func _ready() -> void:
	layer = 100
	visible = false
	_bind_nodes()
	if panel:
		panel.visible = false

func _process(delta: float) -> void:
	if _input_cooldown > 0.0:
		_input_cooldown -= delta

func _bind_nodes() -> void:
	if not panel:
		panel = get_node_or_null("Panel")
	if not portrait_rect:
		portrait_rect = find_child("Portrait", true, false)
	if not portrait_frame:
		portrait_frame = find_child("PortraitFrame", true, false)
	if not name_label:
		name_label = find_child("NameLabel", true, false)
	if not content_label:
		content_label = find_child("ContentLabel", true, false)
	if not prompt_label:
		prompt_label = find_child("PromptLabel", true, false)

func play_dialogue(speaker: String, portrait_tex: Texture2D, lines: Array[String]) -> void:
	if lines.is_empty():
		return

	_bind_nodes()

	_speaker_name = speaker
	_current_lines = lines.duplicate()
	_current_index = 0
	is_dialogue_open = true
	_input_cooldown = 0.25 # Ignore keypress that triggered interaction

	# Set speaker name
	if name_label:
		name_label.text = speaker.to_upper()

	# Set portrait if available, otherwise hide portrait frame
	if portrait_frame:
		if portrait_tex and portrait_rect:
			portrait_rect.texture = portrait_tex
			portrait_frame.visible = true
		else:
			portrait_frame.visible = false

	_show_current_line()
	visible = true
	if panel:
		panel.visible = true
	dialogue_started.emit(speaker)

func _show_current_line() -> void:
	if _current_index < _current_lines.size():
		if content_label:
			content_label.text = _current_lines[_current_index]
		var is_last := (_current_index == _current_lines.size() - 1)
		if prompt_label:
			prompt_label.text = "▶ [E / ENTER / SPACE] CLOSE" if is_last else "▶ [E / ENTER / SPACE] NEXT"
		dialogue_advanced.emit(_current_index, _current_lines.size())

func advance_dialogue() -> void:
	if not is_dialogue_open:
		return

	_current_index += 1
	if _current_index < _current_lines.size():
		_input_cooldown = 0.15
		_show_current_line()
	else:
		close_dialogue()

func close_dialogue() -> void:
	is_dialogue_open = false
	_input_cooldown = 0.2
	_current_lines.clear()
	_current_index = 0
	visible = false
	if panel:
		panel.visible = false
	dialogue_finished.emit()

func _input(event: InputEvent) -> void:
	if not is_dialogue_open:
		return

	if not (event is InputEventKey):
		return

	if not event.pressed or event.is_echo():
		return

	# ESC immediately cancels/closes dialogue
	if event.keycode == KEY_ESCAPE:
		close_dialogue()
		get_viewport().set_input_as_handled()
		return

	# Debounce check for advancing dialogue
	if _input_cooldown > 0.0:
		return

	# Supported advance keys: E, Enter, Keypad Enter, Space
	if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
		advance_dialogue()
		get_viewport().set_input_as_handled()
