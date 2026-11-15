extends Node2D
## Test Deck Level Controller.
## Coordinates test stage elements and safehouse integration.

func _enter_tree() -> void:
	# Runs before children's _ready(), so the ObjectiveHud reads seeded state on
	# boot and the player has not yet consumed SaveManager's pending-load flag.
	_seed_objectives()

func _ready() -> void:
	pass

## Seeds the stage checklist on fresh entry; keeps tasks restored from a save.
func _seed_objectives() -> void:
	var is_restoring_save: bool = SaveManager.has_pending_spawn and not ObjectiveManager.tasks.is_empty()
	if is_restoring_save:
		return
	ObjectiveManager.set_tasks(_default_objectives())

func _default_objectives() -> Array[Dictionary]:
	return [
		{"id": "inspect_log", "label": "Inspect the Safehouse Ship Log", "complete": true},
		{"id": "bypass_patrol", "label": "Bypass the starboard deck patrol", "complete": false},
		{"id": "unlock_radio", "label": "Unlock the Radio Room bulkhead", "complete": false},
	]
