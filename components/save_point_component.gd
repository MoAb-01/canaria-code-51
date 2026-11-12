class_name SavePointComponent
extends Node2D
## Reusable Safehouse Save Point Component.
## Interacts with SaveManager to write slot saves from bunk, logbook, or radio desks.

@export var location_name: String = "Crew Bunk"
@export var spawn_offset: Vector2 = Vector2(0, 16)
@export var active_slot: int = 1
@export var notification_text: String = "LOGBOOK UPDATED"

@onready var interaction_area: Area2D = $InteractionArea if has_node("InteractionArea") else null

func _ready() -> void:
	if not interaction_area:
		interaction_area = get_parent().get_node_or_null("InteractionArea") as Area2D
	if interaction_area:
		interaction_area.interacted_by.connect(_on_interacted)

func _on_interacted(initiator: Node2D) -> void:
	trigger_save(initiator)

func interact(initiator: Node2D) -> void:
	trigger_save(initiator)

func trigger_save(_initiator: Node2D = null) -> bool:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.is_cutscene_active:
		return false

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and "current_state" in player:
		# Check if player is currently in combat (State.COMBAT == 3)
		if player.get("current_state") == 3:
			return false

	var safe_pos: Vector2 = (global_position + spawn_offset).round()
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		push_error("[SavePointComponent] SaveManager autoload not found.")
		return false

	var success: bool = sm.save_game(active_slot, safe_pos, location_name)
	if success:
		var eb = get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("notification_displayed"):
			eb.notification_displayed.emit(notification_text, 2.5)
	return success
