extends CanvasLayer
## DialogueLayer — Global UI Autoload delegating presentation & typewriter pacing
## to res://ui/dialogue_box/dialogue_box.tscn with full backward compatibility.

signal dialogue_started(speaker_name: String)
signal dialogue_advanced(line_index: int, total_lines: int)
signal dialogue_finished

var is_dialogue_open: bool:
	get:
		return dialogue_box != null and dialogue_box.is_open

@onready var dialogue_box: DialogueBox = $DialogueBox

var _active_lines: Array[String] = []

func _ready() -> void:
	layer = 100
	visible = false
	if dialogue_box:
		dialogue_box.dialogue_started.connect(_on_box_started)
		dialogue_box.dialogue_advanced.connect(_on_box_advanced)
		dialogue_box.dialogue_finished.connect(_on_box_finished)

	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("dialogue_requested"):
		eb.dialogue_requested.connect(_on_dialogue_requested)

func play_dialogue(speaker: String, portrait_tex: Texture2D, lines: Array) -> void:
	if lines.is_empty() or not dialogue_box:
		return
	_active_lines.clear()
	for entry in lines:
		_active_lines.append(String(entry))
	visible = true
	dialogue_box.play_dialogue(speaker, portrait_tex, _active_lines)

func play_narration(lines: Array, speaker: String = "") -> void:
	play_dialogue(speaker, null, lines)

func advance_dialogue() -> void:
	if dialogue_box:
		dialogue_box.advance_or_complete()

func close_dialogue() -> void:
	if dialogue_box:
		dialogue_box.close_dialogue()

func _input(event: InputEvent) -> void:
	if not is_dialogue_open or not dialogue_box:
		return
	if dialogue_box.handle_advance_input(event):
		get_viewport().set_input_as_handled()

func _on_dialogue_requested(speaker_name: String, lines: Array[String], portrait: Texture2D) -> void:
	play_dialogue(speaker_name, portrait, lines)

func _on_box_started(speaker_name: String) -> void:
	dialogue_started.emit(speaker_name)
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("dialogue_started"):
		eb.dialogue_started.emit(speaker_name, _active_lines)

func _on_box_advanced(line_index: int, total_lines: int) -> void:
	dialogue_advanced.emit(line_index, total_lines)
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("dialogue_line_advanced"):
		eb.dialogue_line_advanced.emit(line_index, total_lines)

func _on_box_finished() -> void:
	visible = false
	_active_lines.clear()
	dialogue_finished.emit()
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("dialogue_finished"):
		eb.dialogue_finished.emit()
