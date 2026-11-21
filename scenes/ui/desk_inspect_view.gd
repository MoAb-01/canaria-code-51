class_name DeskInspectView
extends CanvasLayer
## First-Person Desk Inspect Mode overlay for Chapter I ("Tarek's Office").
## Displays the 16:9 POV desk with 4 clickable hotspots and a bottom caption panel.

signal inspect_closed

const INSPECT_TEXTS := {
	"photo": {
		"title": "Framed Family Photo",
		"text": "My wife and our boy... Smiling like the world wasn't about to fall apart. I promised I'd be home before dinner."
	},
	"phone": {
		"title": "Vintage Desk Phone",
		"text": "The old precinct landline. Still warm from the last call—dispatch hasn't stopped ringing since midnight."
	},
	"ashtray": {
		"title": "Ashtray & Cigarette",
		"text": "Half-burned cigarette, thin ribbon of smoke. Third one since sunrise. Bad habit, worse case."
	},
	"badge": {
		"title": "Gold Service Badge",
		"text": "Twelve years on the force boiled down to a slab of brass. Heavy when you wear it, heavier when you leave it on the desk."
	}
}

@onready var root_control: Control = $Root
@onready var caption_panel: PanelContainer = $Root/CaptionPanel
@onready var title_label: Label = $Root/CaptionPanel/Margin/VBox/TitleLabel
@onready var body_label: Label = $Root/CaptionPanel/Margin/VBox/BodyLabel
@onready var back_button: Button = $Root/BackButton

var is_open: bool = false

func _ready() -> void:
	visible = false
	_wire_hotspots()
	if back_button:
		back_button.pressed.connect(close_view)
	if caption_panel:
		caption_panel.visible = false

func open_view() -> void:
	is_open = true
	visible = true
	_show_caption("Tarek's Desk", "Click an item on the desk to inspect it. Press Esc, Right-Click, or [Back] to step away.")

func close_view() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
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

func _wire_hotspots() -> void:
	var hotspot_map := {
		"Root/DeskStage/DeskPOV/HotspotPhoto": "photo",
		"Root/DeskStage/DeskPOV/HotspotPhone": "phone",
		"Root/DeskStage/DeskPOV/HotspotAshtray": "ashtray",
		"Root/DeskStage/DeskPOV/HotspotBadge": "badge",
	}
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(1.0, 0.88, 0.55, 0.16)
	hover_style.border_color = Color(1.0, 0.86, 0.45, 0.85)
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
	var entry: Dictionary = INSPECT_TEXTS.get(key, {})
	if entry.is_empty():
		return
	_show_caption(String(entry.get("title", "")), String(entry.get("text", "")))

func _show_caption(title_text: String, body_text: String) -> void:
	if title_label:
		title_label.text = title_text
	if body_label:
		body_label.text = body_text
	if caption_panel:
		caption_panel.visible = true
