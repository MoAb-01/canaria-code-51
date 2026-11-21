extends Node2D
## Chapter I Opening Sequence — "Tarek's Office".
## Handles the "Chapter I" fade-in intro cutscene, seated-to-standing transition,
## Y-sorted desk/room navigation, doorway trigger, and First-Person Desk Inspect Mode.

signal doorway_entered

const SEATED_POS := Vector2(66.0, -15.0)
const STAND_OUT_POS := Vector2(-46.0, 18.0)

@onready var tarek: CharacterBody2D = $Entities/Tarek
@onready var desk_zone: Area2D = $Entities/OfficeDesk/DeskInteractZone
@onready var desk_prompt_anchor: Marker2D = $Entities/OfficeDesk/DeskPromptAnchor
@onready var desk_ember: ColorRect = $Entities/OfficeDesk/DeskAshtrayFX/DeskEmber
@onready var desk_smoke: CPUParticles2D = $Entities/OfficeDesk/DeskAshtrayFX/DeskSmoke
@onready var prompt_label: Label = $HUDLayer/PromptLabel
@onready var doorway_trigger: Area2D = $DoorwayTrigger
@onready var intro_overlay: CanvasLayer = $IntroOverlay
@onready var intro_black: ColorRect = $IntroOverlay/BlackScreen
@onready var intro_title: Label = $IntroOverlay/ChapterLabel
@onready var desk_inspect: DeskInspectView = $DeskInspectView

var _intro_active: bool = true
var _is_seated: bool = true
var _is_standing_up: bool = false
var _player_near_desk: bool = false

func _ready() -> void:
	_setup_seated_tarek()
	_setup_desk_smoke_fx()
	if prompt_label:
		prompt_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		prompt_label.visible = false
	if intro_title:
		intro_title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if desk_zone:
		desk_zone.body_entered.connect(_on_desk_zone_entered)
		desk_zone.body_exited.connect(_on_desk_zone_exited)
		desk_zone.input_event.connect(_on_desk_clicked)
	if doorway_trigger:
		doorway_trigger.body_entered.connect(_on_doorway_entered)
	if desk_inspect:
		desk_inspect.inspect_closed.connect(_on_inspect_closed)
	_play_intro_cutscene()

func _setup_seated_tarek() -> void:
	if not tarek:
		return
	tarek.position = SEATED_POS
	tarek.velocity = Vector2.ZERO
	if "last_facing_dir" in tarek:
		tarek.last_facing_dir = Vector2.DOWN
	_set_player_locked(true)
	if "sprite" in tarek and tarek.sprite:
		tarek.sprite.flip_h = false
		tarek.sprite.play("idle_down")
	var cam := tarek.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.enabled = false

func _play_intro_cutscene() -> void:
	_intro_active = true
	if intro_overlay:
		intro_overlay.visible = true
	if intro_black:
		intro_black.color = Color(0.0, 0.0, 0.0, 1.0)
		intro_black.modulate.a = 1.0
	if intro_title:
		intro_title.text = "Chapter I"
		intro_title.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(intro_title, "modulate:a", 1.0, 1.2)
	tw.tween_interval(1.5)
	tw.tween_property(intro_title, "modulate:a", 0.0, 1.0)
	tw.tween_property(intro_black, "modulate:a", 0.0, 1.5)
	tw.tween_callback(_on_intro_finished)

func _on_intro_finished() -> void:
	_intro_active = false
	if intro_overlay:
		intro_overlay.visible = false
	_update_desk_prompt()

func _process(_delta: float) -> void:
	_sync_prompt_position()
	if _intro_active or _is_standing_up:
		return
	if desk_inspect and desk_inspect.is_open:
		return

	if _is_seated:
		var move_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if move_vec.length_squared() > 0.01:
			_stand_up_from_desk()
			return

	if (_is_seated or _player_near_desk) and Input.is_action_just_pressed("interact"):
		_open_desk_inspect()

func _stand_up_from_desk() -> void:
	if not _is_seated or _is_standing_up or not tarek:
		return
	_is_standing_up = true
	_is_seated = false
	_update_desk_prompt()

	if "sprite" in tarek and tarek.sprite:
		tarek.sprite.flip_h = true
		tarek.sprite.play("walk_side")

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(tarek, "position", STAND_OUT_POS, 0.35)
	tw.tween_callback(_on_stood_up)

func _on_stood_up() -> void:
	_is_standing_up = false
	if tarek and "last_facing_dir" in tarek:
		tarek.last_facing_dir = Vector2.DOWN
	_set_player_locked(false)
	_update_desk_prompt()

func _open_desk_inspect() -> void:
	if not desk_inspect or desk_inspect.is_open:
		return
	_set_player_locked(true)
	if prompt_label:
		prompt_label.visible = false
	desk_inspect.open_view()

func _on_inspect_closed() -> void:
	if not _is_seated and not _intro_active and not _is_standing_up:
		_set_player_locked(false)
	_update_desk_prompt()

func _set_player_locked(locked: bool) -> void:
	if not tarek:
		return
	tarek.set_physics_process(not locked)
	tarek.set_process(not locked)
	if locked:
		tarek.velocity = Vector2.ZERO

func _on_desk_zone_entered(body: Node) -> void:
	if body == tarek:
		_player_near_desk = true
		_update_desk_prompt()

func _on_desk_zone_exited(body: Node) -> void:
	if body == tarek:
		_player_near_desk = false
		_update_desk_prompt()

func _on_desk_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _intro_active or _is_standing_up or (desk_inspect and desk_inspect.is_open):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_desk_inspect()

func _update_desk_prompt() -> void:
	if not prompt_label:
		return
	var show := (not _intro_active) and (not _is_standing_up) and (not (desk_inspect and desk_inspect.is_open)) and (_is_seated or _player_near_desk)
	prompt_label.visible = show
	if show:
		_sync_prompt_position()

func _sync_prompt_position() -> void:
	if not prompt_label or not prompt_label.visible or not desk_prompt_anchor:
		return
	prompt_label.global_position = get_viewport().get_canvas_transform() * desk_prompt_anchor.global_position - Vector2(prompt_label.size.x * 0.5, 24.0)

func _on_doorway_entered(body: Node) -> void:
	if body == tarek and not _intro_active and not _is_seated:
		doorway_entered.emit()
		var eb := get_node_or_null("/root/EventBus")
		if eb:
			if eb.has_signal("sfx_requested"):
				eb.sfx_requested.emit("office_door_open")
			if eb.has_signal("room_transition_requested"):
				eb.room_transition_requested.emit("office_exit")

func _setup_desk_smoke_fx() -> void:
	if desk_ember:
		desk_ember.modulate.a = 0.45
		var tw := create_tween().set_loops()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(desk_ember, "modulate:a", 1.0, 0.9)
		tw.tween_property(desk_ember, "modulate:a", 0.45, 0.9)
	if desk_smoke:
		var img := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		desk_smoke.texture = ImageTexture.create_from_image(img)
		desk_smoke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var grad := Gradient.new()
		grad.set_offset(0, 0.0)
		grad.set_color(0, Color(0.85, 0.85, 0.88, 0.5))
		grad.set_offset(1, 1.0)
		grad.set_color(1, Color(0.85, 0.85, 0.88, 0.0))
		desk_smoke.color_ramp = grad
		desk_smoke.emitting = true
