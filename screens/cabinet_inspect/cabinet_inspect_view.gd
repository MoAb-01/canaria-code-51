class_name CabinetInspectView
extends CanvasLayer
## Close-up Filing Cabinet Drawer Unlock & Pistol Retrieval View.
## Implements X (push-in key) -> K tap-to-fill (0->45 deg) -> J tap-to-fill (45->90 deg) -> Open & Collect.

signal inspect_closed
signal pistol_collected

enum Stage { CLOSED, WAIT_X, INSERTING_KEY, WAIT_K, WAIT_J, OPENING, OPENED }

@onready var drawer_closed: Sprite2D = $Root/StageAnchor/DrawerFrontClosed
@onready var drawer_open: Sprite2D = $Root/StageAnchor/DrawerInteriorOpen
@onready var key_bow: Sprite2D = $Root/StageAnchor/KeyInsertedBow
@onready var pistol_button: TextureButton = $Root/StageAnchor/PistolPickup
@onready var x_prompt: PanelContainer = $Root/StageAnchor/KeyholePromptX
@onready var dual_arcs: DualLockArcs = $Root/StageAnchor/DualLockArcs
@onready var back_button: Button = $Root/BackButton

var is_open: bool = false
var current_stage: Stage = Stage.CLOSED

var _prompt_tween: Tween = null
var _action_tween: Tween = null

func _ready() -> void:
	visible = false
	if back_button:
		back_button.pressed.connect(close_view)
	if pistol_button:
		pistol_button.pressed.connect(_collect_pistol)
	if dual_arcs:
		dual_arcs.progress_changed.connect(_on_arc_progress_changed)
		dual_arcs.right_arc_completed.connect(_on_right_arc_completed)
		dual_arcs.left_arc_completed.connect(_on_left_arc_completed)

func open_view() -> void:
	is_open = true
	visible = true
	_reset_visuals()
	current_stage = Stage.WAIT_X
	_start_x_prompt_pulse()
	_emit_prompt(["Locked top drawer. Press {amber}X{/amber} to insert the brass key."])

func close_view() -> void:
	if not is_open:
		return
	is_open = false
	current_stage = Stage.CLOSED
	visible = false
	_kill_tweens()
	var dl := get_node_or_null("/root/DialogueLayer")
	if dl and dl.is_dialogue_open:
		dl.close_dialogue()
	inspect_closed.emit()

func _reset_visuals() -> void:
	_kill_tweens()
	if drawer_closed:
		drawer_closed.visible = true; drawer_closed.position = Vector2.ZERO; drawer_closed.modulate.a = 1.0
	if drawer_open: drawer_open.visible = false
	if pistol_button: pistol_button.visible = false
	if key_bow:
		key_bow.visible = false; key_bow.scale = Vector2.ONE
		key_bow.rotation_degrees = 0.0; key_bow.modulate.a = 1.0
	if x_prompt: x_prompt.visible = true; x_prompt.modulate.a = 1.0
	if dual_arcs: dual_arcs.visible = false; dual_arcs.reset_arcs()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open: return
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled(); close_view(); return
	if not (event is InputEventKey and event.pressed and not event.is_echo()): return

	match current_stage:
		Stage.WAIT_X:
			if event.keycode == KEY_X:
				get_viewport().set_input_as_handled()
				_begin_insert_key()
		Stage.WAIT_K:
			if event.keycode == KEY_K and dual_arcs:
				get_viewport().set_input_as_handled()
				dual_arcs.add_right_tap()
		Stage.WAIT_J:
			if event.keycode == KEY_J and dual_arcs:
				get_viewport().set_input_as_handled()
				dual_arcs.add_left_tap()
		Stage.OPENED:
			if event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
				get_viewport().set_input_as_handled()
				_collect_pistol()

func _begin_insert_key() -> void:
	current_stage = Stage.INSERTING_KEY
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if x_prompt:
		x_prompt.visible = false
	if key_bow:
		key_bow.visible = true
		key_bow.scale = Vector2(1.85, 1.85)
		key_bow.rotation_degrees = 0.0
		key_bow.modulate.a = 0.0
	_action_tween = create_tween().set_parallel(true)
	_action_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(key_bow, "scale", Vector2.ONE, 0.35)
	_action_tween.tween_property(key_bow, "modulate:a", 1.0, 0.35)
	_action_tween.chain().tween_callback(_on_key_inserted)

func _on_key_inserted() -> void:
	current_stage = Stage.WAIT_K
	if dual_arcs:
		dual_arcs.visible = true
		dual_arcs.reset_arcs()
		dual_arcs.set_active_side("right")
	_emit_prompt(["Key's in. Tap {amber}K{/amber} repeatedly to turn the cylinder right."])

func _on_arc_progress_changed(side: String, progress: float) -> void:
	if not key_bow:
		return
	if side == "right":
		key_bow.rotation_degrees = lerpf(0.0, 45.0, progress)
	elif side == "left":
		key_bow.rotation_degrees = lerpf(45.0, 90.0, progress)

func _on_right_arc_completed() -> void:
	if current_stage != Stage.WAIT_K:
		return
	current_stage = Stage.WAIT_J
	_emit_prompt(["Halfway. Tap {amber}J{/amber} repeatedly to release the bolt."])

func _on_left_arc_completed() -> void:
	if current_stage != Stage.WAIT_J:
		return
	_open_drawer()

func _open_drawer() -> void:
	current_stage = Stage.OPENING
	if dual_arcs: dual_arcs.visible = false
	if drawer_open: drawer_open.visible = true
	if pistol_button:
		pistol_button.visible = true
		pistol_button.modulate.a = 0.0

	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("sfx_requested"):
		eb.sfx_requested.emit("office_door_open")

	_action_tween = create_tween().set_parallel(true)
	_action_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if drawer_closed:
		_action_tween.tween_property(drawer_closed, "position:y", 180.0, 0.45)
		_action_tween.tween_property(drawer_closed, "modulate:a", 0.0, 0.45)
	if key_bow:
		_action_tween.tween_property(key_bow, "modulate:a", 0.0, 0.25)
	if pistol_button:
		_action_tween.tween_property(pistol_button, "modulate:a", 1.0, 0.4)
	_action_tween.chain().tween_callback(func():
		if drawer_closed: drawer_closed.visible = false
		if key_bow: key_bow.visible = false
		current_stage = Stage.OPENED
		_emit_prompt(["There it is. Click the {amber}pistol{/amber} or press {amber}E{/amber} to take it."])
	)

func _collect_pistol() -> void:
	if current_stage != Stage.OPENED:
		return
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.has_pistol = true
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("item_collected"):
		eb.item_collected.emit("pistol")
	pistol_collected.emit()
	close_view()
	_emit_prompt(["Service pistol secured. Twelve rounds — hope I won't need them."])

func _start_x_prompt_pulse() -> void:
	if not x_prompt:
		return
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prompt_tween.tween_property(x_prompt, "modulate:a", 0.45, 0.65)
	_prompt_tween.tween_property(x_prompt, "modulate:a", 1.0, 0.65)

func _emit_prompt(lines: Array) -> void:
	var typed: Array[String] = []
	for line in lines:
		typed.append(String(line))
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("dialogue_requested"):
		eb.dialogue_requested.emit("", typed, null)

func _kill_tweens() -> void:
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if _action_tween and _action_tween.is_valid():
		_action_tween.kill()
