class_name DialogueBox
extends Control
## Gradient-backed dialogue & narration box with crisp VT323 pixel typography,
## amber highlights, exact punctuation-aware typewriter pacing, and optional portrait support.

signal dialogue_started(speaker_name: String)
signal dialogue_advanced(line_index: int, total_lines: int)
signal line_revealed(line_index: int)
signal dialogue_finished

const BASE_DELAY_SEC: float = 0.018
const COMMA_PAUSE_SEC: float = 0.06
const PERIOD_PAUSE_SEC: float = 0.11
const SPACE_DELAY_SEC: float = 0.012
const AMBER_HEX: String = "#f0be59"
const MAX_INNER_WIDTH: float = 820.0
const VT323_PATH: String = "res://assets/fonts/VT323-Regular.ttf"

var is_open: bool = false
var is_typing: bool = false

var _lines: Array[String] = []
var _line_index: int = 0
var _speaker_name: String = ""
var _parsed_text: String = ""
var _char_timer: float = 0.0
var _input_cooldown: float = 0.0
var _fade_tween: Tween = null

@onready var inner_box: HBoxContainer = $GradientBg/Margin/Center/InnerBox
@onready var portrait_frame: PanelContainer = $GradientBg/Margin/Center/InnerBox/PortraitFrame
@onready var portrait_rect: TextureRect = $GradientBg/Margin/Center/InnerBox/PortraitFrame/Portrait
@onready var speaker_label: Label = $GradientBg/Margin/Center/InnerBox/TextVBox/SpeakerLabel
@onready var dialogue_text: RichTextLabel = $GradientBg/Margin/Center/InnerBox/TextVBox/DialogueText

static func get_char_delay(ch: String) -> float:
	if ch == "." or ch == "!" or ch == "?":
		return PERIOD_PAUSE_SEC
	if ch == "," or ch == ";" or ch == ":":
		return COMMA_PAUSE_SEC
	if ch == " ":
		return SPACE_DELAY_SEC
	return BASE_DELAY_SEC

static func hl_amber(text: String) -> String:
	return "[color=%s]%s[/color]" % [AMBER_HEX, text]

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_update_inner_width()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_inner_width()

func _update_inner_width() -> void:
	if not inner_box:
		return
	var avail := maxf(320.0, size.x - 64.0) if size.x > 0.0 else MAX_INNER_WIDTH
	inner_box.custom_minimum_size.x = minf(MAX_INNER_WIDTH, avail)

func _process(delta: float) -> void:
	if _input_cooldown > 0.0:
		_input_cooldown = maxf(0.0, _input_cooldown - delta)
	if not is_open or not is_typing:
		return

	_char_timer -= delta
	while _char_timer <= 0.0 and is_typing:
		var next_count := dialogue_text.visible_characters + 1
		if next_count >= _parsed_text.length():
			_finish_current_line()
			break
		dialogue_text.visible_characters = next_count
		var revealed_ch := _parsed_text.substr(next_count - 1, 1)
		_char_timer += get_char_delay(revealed_ch)

func play_dialogue(speaker: String, portrait_tex: Texture2D, lines: Array) -> void:
	if lines.is_empty():
		return
	_speaker_name = speaker.strip_edges()
	_lines.clear()
	for entry in lines:
		_lines.append(String(entry))
	_line_index = 0
	is_open = true
	_input_cooldown = 0.22

	_apply_layout_mode(_speaker_name, portrait_tex)
	_start_current_line()

	visible = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.16)

	dialogue_started.emit(_speaker_name)

func play_narration(lines: Array, speaker: String = "") -> void:
	play_dialogue(speaker, null, lines)

func advance_or_complete() -> void:
	if not is_open:
		return
	if is_typing:
		_finish_current_line()
		_input_cooldown = 0.12
		return
	_line_index += 1
	if _line_index < _lines.size():
		_input_cooldown = 0.12
		_start_current_line()
	else:
		close_dialogue()

func close_dialogue() -> void:
	if not is_open:
		return
	is_open = false
	is_typing = false
	_input_cooldown = 0.2
	_lines.clear()
	_line_index = 0
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = false
	modulate.a = 0.0
	dialogue_finished.emit()

func _apply_layout_mode(speaker: String, portrait_tex: Texture2D) -> void:
	var has_portrait := portrait_tex != null
	if portrait_frame and portrait_rect:
		if has_portrait:
			portrait_rect.texture = portrait_tex
			portrait_frame.visible = true
		else:
			portrait_rect.texture = null
			portrait_frame.visible = false

	if dialogue_text:
		dialogue_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if speaker_label:
		speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not speaker.is_empty():
			speaker_label.text = speaker.to_upper()
			speaker_label.visible = true
		else:
			speaker_label.text = ""
			speaker_label.visible = false

func _start_current_line() -> void:
	if not dialogue_text or _line_index >= _lines.size():
		return
	dialogue_text.text = _format_bbcode(_lines[_line_index])
	_parsed_text = dialogue_text.get_parsed_text()
	dialogue_text.visible_characters = 0

	if _parsed_text.is_empty():
		_finish_current_line()
	else:
		is_typing = true
		_char_timer = BASE_DELAY_SEC

	dialogue_advanced.emit(_line_index, _lines.size())

func _finish_current_line() -> void:
	is_typing = false
	if dialogue_text:
		dialogue_text.visible_characters = -1
	line_revealed.emit(_line_index)

func _format_bbcode(raw: String) -> String:
	var out := raw
	out = out.replace("<span class=\"hl-amber\">", "[color=%s]" % AMBER_HEX)
	out = out.replace("<span class='hl-amber'>", "[color=%s]" % AMBER_HEX)
	out = out.replace("</span>", "[/color]")
	out = out.replace("{amber}", "[color=%s]" % AMBER_HEX)
	out = out.replace("{/amber}", "[/color]")
	return out

func handle_advance_input(event: InputEvent) -> bool:
	if not is_open:
		return false
	if event.is_action_pressed("ui_cancel"):
		close_dialogue()
		return true
	if event.is_action_pressed("ui_accept"):
		if _input_cooldown <= 0.0:
			advance_or_complete()
			return true
		return false
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			close_dialogue()
			return true
		if _input_cooldown > 0.0:
			return false
		if event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			advance_or_complete()
			return true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _input_cooldown <= 0.0:
			advance_or_complete()
			return true
	return false
