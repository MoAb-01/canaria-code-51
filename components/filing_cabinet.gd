class_name FilingCabinet
extends Node2D
## World Filing Cabinet Component.
## Manages the cabinet InteractionArea, screen-space prompt signaling,
## CabinetInspectView trigger, and SaveManager persistence.

signal inspect_requested
signal focus_changed(is_focused: bool)

@export var cabinet_id: String = "office_filing_cabinet"
@export var inspect_view_path: NodePath

var is_unlocked: bool = false
var is_emptied: bool = false
var is_player_near: bool = false

@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D
@onready var prompt_anchor: Marker2D = get_node_or_null("PromptAnchor") as Marker2D

func _ready() -> void:
	add_to_group("persist")
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
		interaction_area.input_event.connect(_on_area_input_event)

	var view := _get_inspect_view()
	if view and view.has_signal("pistol_collected"):
		view.pistol_collected.connect(_on_pistol_collected)

func interact(_user: Node2D = null) -> void:
	var gs := get_node_or_null("/root/GameState")
	var already_taken: bool = is_emptied or (gs != null and bool(gs.get("has_pistol")))
	if already_taken:
		is_emptied = true
		var eb := get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("dialogue_requested"):
			var lines: Array[String] = ["The top drawer is already empty. Just old case files left."]
			eb.dialogue_requested.emit("", lines, null)
		return

	inspect_requested.emit()
	var view := _get_inspect_view()
	if view and view.has_method("open_view"):
		view.open_view()

func get_prompt_world_position() -> Vector2:
	return prompt_anchor.global_position if prompt_anchor else global_position + Vector2(0.0, -54.0)

func to_dict() -> Dictionary:
	return {
		"cabinet_id": cabinet_id,
		"is_unlocked": is_unlocked,
		"is_emptied": is_emptied,
	}

func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	is_unlocked = bool(data.get("is_unlocked", false))
	is_emptied = bool(data.get("is_emptied", false))

func _get_inspect_view() -> Node:
	if not inspect_view_path.is_empty():
		return get_node_or_null(inspect_view_path)
	return null

func _on_pistol_collected() -> void:
	is_unlocked = true
	is_emptied = true

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		is_player_near = true
		focus_changed.emit(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		is_player_near = false
		focus_changed.emit(false)

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_player_near:
			interact()
