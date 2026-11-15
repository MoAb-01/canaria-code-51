class_name ObjectiveHud
extends PanelContainer
## Top-right 16-bit Objective HUD (pure view).
## Owns zero game state: mirrors ObjectiveManager via EventBus.objectives_updated
## and rebuilds its checklist rows from the emitted task array.

const COLOR_GOLD: Color = Color("#ffd166")
const COLOR_DONE: Color = Color("#72efdd")
const COLOR_TODO: Color = Color("#9cb2c9")
const ALPHA_DONE: float = 0.85
const ALPHA_TODO: float = 1.0
const GLYPH_DONE: String = "☑"
const GLYPH_TODO: String = "☐"

const ROW_SEPARATION: int = 10
const TASK_FONT_SIZE: int = 12
const TASK_LINE_SEPARATION: int = 7 # ≈ CSS line-height 1.6 at 12px
const CHECKBOX_FONT_SIZE: int = 18

## Pixel font used for task labels (Press Start 2P).
@export var task_font: Font
## Font with ☐ / ☑ glyph coverage (pixel fonts lack these symbols).
@export var checkbox_font: Font

@onready var task_list: VBoxContainer = %TaskList

func _ready() -> void:
	EventBus.objectives_updated.connect(_on_objectives_updated)
	_rebuild(ObjectiveManager.tasks)

func _on_objectives_updated(tasks: Array[Dictionary]) -> void:
	_rebuild(tasks)

func _rebuild(tasks: Array[Dictionary]) -> void:
	for child in task_list.get_children():
		task_list.remove_child(child)
		child.queue_free()
	for task in tasks:
		task_list.add_child(_build_row(task))
	visible = not tasks.is_empty()
	_shrink_to_content.call_deferred()

## Collapses height back to content after rows are removed (width stays 320px).
func _shrink_to_content() -> void:
	size = Vector2(size.x, 0.0)

func _build_row(task: Dictionary) -> HBoxContainer:
	var is_done := bool(task.get("complete", false))
	var row := HBoxContainer.new()
	row.name = ("Task_%s" % str(task.get("id", "task"))).validate_node_name()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	row.add_child(_build_checkbox(is_done))
	row.add_child(_build_label(str(task.get("label", "")), is_done))
	return row

func _build_checkbox(is_done: bool) -> Label:
	var box := Label.new()
	box.name = "Checkbox"
	box.text = GLYPH_DONE if is_done else GLYPH_TODO
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = ALPHA_DONE if is_done else ALPHA_TODO
	box.add_theme_color_override("font_color", COLOR_DONE if is_done else COLOR_GOLD)
	box.add_theme_font_size_override("font_size", CHECKBOX_FONT_SIZE)
	if checkbox_font:
		box.add_theme_font_override("font", checkbox_font)
	return box

func _build_label(text: String, is_done: bool) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = "TaskLabel"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = ALPHA_DONE if is_done else ALPHA_TODO
	label.add_theme_color_override("default_color", COLOR_DONE if is_done else COLOR_TODO)
	label.add_theme_constant_override("line_separation", TASK_LINE_SEPARATION)
	label.add_theme_constant_override("strikethrough_alpha", 100) # Engine default is 50%.
	label.add_theme_font_size_override("normal_font_size", TASK_FONT_SIZE)
	if task_font:
		label.add_theme_font_override("normal_font", task_font)
	var safe_text := text.replace("[", "[lb]") # Escape user text from BBCode parsing.
	label.text = ("[s]%s[/s]" % safe_text) if is_done else safe_text
	return label
