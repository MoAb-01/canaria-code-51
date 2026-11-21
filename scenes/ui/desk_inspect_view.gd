class_name DeskInspectView
extends CanvasLayer
## First-Person Desk Inspect Mode overlay for Chapter I ("Tarek's Office").
## Uses the unified borderless gradient DialogueBox for inspection narration lines.

signal inspect_closed

const INSPECT_LINES := {
	"photo": "My {amber}wife and our boy{/amber}... Smiling like the world wasn't about to fall apart. I promised I'd be home before dinner.",
	"phone": "The old {amber}precinct landline{/amber}. Still warm from the last call — dispatch hasn't stopped ringing since midnight.",
	"ashtray": "Half-burned {amber}cigarette{/amber}, thin ribbon of smoke. Third one since sunrise. Bad habit, worse case.",
	"badge": "Twelve years on the force boiled down to a slab of {amber}gold brass{/amber}. Heavy when you wear it, heavier when you leave it on the desk."
}

@onready var dialogue_box: DialogueBox = $Root/DialogueBox
@onready var back_button: Button = $Root/BackButton

var is_open: bool = false

func _ready() -> void:
	visible = false
	_wire_hotspots()
	if back_button:
		back_button.pressed.connect(close_view)

func open_view() -> void:
	is_open = true
	visible = true
	if dialogue_box:
		dialogue_box.play_narration(["Click an item on the desk to inspect it. Press {amber}Esc{/amber} or right-click to step away."])

func close_view() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if dialogue_box:
		dialogue_box.close_dialogue()
	inspect_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_view()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		close_view()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]):
		if dialogue_box and dialogue_box.is_typing:
			dialogue_box.advance_or_complete()
			get_viewport().set_input_as_handled()

func _wire_hotspots() -> void:
	var hotspot_map := {
		"Root/DeskStage/DeskPOV/HotspotPhoto": "photo",
		"Root/DeskStage/DeskPOV/HotspotPhone": "phone",
		"Root/DeskStage/DeskPOV/HotspotAshtray": "ashtray",
		"Root/DeskStage/DeskPOV/HotspotBadge": "badge",
	}
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(1.0, 0.88, 0.55, 0.16)
	hover_style.border_color = Color(0.941, 0.745, 0.349, 0.85)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(6)

	var normal_style := StyleBoxEmpty.new()

	for path in hotspot_map.keys():
		var btn := get_node_or_null(path) as Button
		if not btn:
			continue
		var key: String = hotspot_map[path]
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		btn.add_theme_stylebox_override("focus", hover_style)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): _on_hotspot_clicked(key))

func _on_hotspot_clicked(key: String) -> void:
	var line: String = String(INSPECT_LINES.get(key, ""))
	if not line.is_empty() and dialogue_box:
		dialogue_box.play_narration([line])
