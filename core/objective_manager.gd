extends Node
## Objective / Task-List State Autoload.
## Pure data owner for the active objective checklist. Never touches UI —
## views listen to EventBus.objectives_updated and rebuild themselves.
## Each task entry: { "id": String, "label": String, "complete": bool }.

var tasks: Array[Dictionary] = []

# ------------------------------------------------------------------------------
# PUBLIC API
# ------------------------------------------------------------------------------

## Replaces the whole checklist (ordering is preserved, duplicate ids dropped).
func set_tasks(new_tasks: Array[Dictionary]) -> void:
	tasks.clear()
	for entry in new_tasks:
		var task := _sanitize(entry)
		if not task.is_empty() and get_task_index(task["id"]) == -1:
			tasks.append(task)
	_emit_updated()

## Appends a new incomplete task. Ignored if the id is empty or already tracked.
func add_task(id: String, label: String) -> void:
	if id.is_empty() or has_task(id):
		return
	tasks.append({"id": id, "label": label, "complete": false})
	_emit_updated()

## Marks a task complete. No-op for unknown or already-completed ids.
func complete_task(task_id: String) -> void:
	var idx := get_task_index(task_id)
	if idx == -1 or bool(tasks[idx].get("complete", false)):
		return
	tasks[idx]["complete"] = true
	EventBus.objective_task_completed.emit(task_id)
	_emit_updated()

func clear_tasks() -> void:
	tasks.clear()
	_emit_updated()

func has_task(task_id: String) -> bool:
	return get_task_index(task_id) != -1

func is_task_complete(task_id: String) -> bool:
	var idx := get_task_index(task_id)
	return idx != -1 and bool(tasks[idx].get("complete", false))

func get_task_index(task_id: String) -> int:
	for i in tasks.size():
		if str(tasks[i].get("id", "")) == task_id:
			return i
	return -1

# ------------------------------------------------------------------------------
# SAVE / LOAD SERIALIZATION (primitive arrays + dictionaries only)
# ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var serialized: Array = []
	for task in tasks:
		serialized.append({
			"id": str(task.get("id", "")),
			"label": str(task.get("label", "")),
			"complete": bool(task.get("complete", false))
		})
	return {"tasks": serialized}

func from_dict(data: Dictionary) -> void:
	var restored: Array[Dictionary] = []
	var raw: Variant = data.get("tasks", [])
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				restored.append(entry)
	set_tasks(restored)

# ------------------------------------------------------------------------------
# INTERNALS
# ------------------------------------------------------------------------------

func _sanitize(entry: Dictionary) -> Dictionary:
	var id := str(entry.get("id", ""))
	if id.is_empty():
		return {}
	return {
		"id": id,
		"label": str(entry.get("label", id)),
		"complete": bool(entry.get("complete", false))
	}

## Emits a deep copy so listeners can never mutate the authoritative state.
func _emit_updated() -> void:
	EventBus.objectives_updated.emit(tasks.duplicate(true))
