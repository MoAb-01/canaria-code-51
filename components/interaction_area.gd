class_name InteractionArea
extends Area2D
## Reusable interaction trigger zone.
## Add this Area2D as a child of any interactable entity (NPC, terminal, item).

signal interacted_by(initiator: Node2D)
signal focused()
signal unfocused()

@export var prompt_message: String = "Interact"
@export var is_interactable: bool = true

func _ready() -> void:
	collision_layer = 4 # Interaction layer (Layer 3)
	collision_mask = 0

func interact(initiator: Node2D) -> void:
	if not is_interactable:
		return
	interacted_by.emit(initiator)
	var parent := get_parent()
	if parent and parent.has_method("interact"):
		parent.interact(initiator)

func set_focused(focused_state: bool) -> void:
	if focused_state:
		focused.emit()
	else:
		unfocused.emit()
	var parent := get_parent()
	if parent and parent.has_method("set_prompt_visible"):
		parent.set_prompt_visible(focused_state)

