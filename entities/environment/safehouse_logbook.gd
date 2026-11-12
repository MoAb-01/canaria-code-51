class_name SafehouseLogbook
extends StaticBody2D
## In-world Safehouse Logbook Desk entity.
## Holds interaction area, visual prompt, and the SavePointComponent.

@onready var prompt_bubble: Control = $PromptBubble if has_node("PromptBubble") else null
@onready var save_point_comp: Node2D = $SavePointComponent if has_node("SavePointComponent") else null

func _ready() -> void:
	y_sort_enabled = true
	set_prompt_visible(false)

func set_prompt_visible(is_vis: bool) -> void:
	if prompt_bubble:
		prompt_bubble.visible = is_vis

func interact(initiator: Node2D = null) -> void:
	set_prompt_visible(false)
	if save_point_comp:
		save_point_comp.trigger_save(initiator)

func save_state() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y}
	}

func load_state(data: Dictionary) -> void:
	var pos = data.get("position", {})
	if pos is Dictionary and pos.has("x") and pos.has("y"):
		global_position = Vector2(float(pos["x"]), float(pos["y"]))
