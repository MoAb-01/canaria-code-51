class_name Player
extends BaseCharacter
## Tariq — Player controller inheriting BaseCharacter.
## Implements top-down movement with 4-direction support,
## sprinting, sneak/crouching, pseudo-Z jumping, 2D cone flashlight,
## and generous proximity-based NPC interaction.

enum State { IDLE, WALK, SPRINT, CROUCH, JUMP, COMBAT, GRAB, NORMAL }

const SPRINT_SPEED: float = 270.0
const WALK_SPEED: float = 180.0
const CROUCH_SPEED: float = 80.0
const ACCEL: float = 1400.0
const FRICTION: float = 1800.0

const JUMP_VELOCITY: float = 285.0
const Z_GRAVITY: float = 900.0
const BASE_VISUAL_Y: float = 0.0

@export var has_flashlight: bool = true
var flashlight_on: bool = false

var current_state: State = State.IDLE
var z_pos: float = 0.0
var z_velocity: float = 0.0

var _nearby_interactables: Array[Area2D] = []
var interaction_cooldown: float = 0.0

@onready var interaction_ray: RayCast2D = $InteractionRay if has_node("InteractionRay") else null
@onready var interaction_detector: Area2D = $InteractionDetector if has_node("InteractionDetector") else null
@onready var flashlight_pivot: Node2D = $FlashlightPivot if has_node("FlashlightPivot") else null
@onready var flashlight_cone: PointLight2D = $FlashlightPivot/FlashlightCone if has_node("FlashlightPivot/FlashlightCone") else null
@onready var flashlight_spill: PointLight2D = $FlashlightPivot/FlashlightSpill if has_node("FlashlightPivot/FlashlightSpill") else null
@onready var flashlight_audio: AudioStreamPlayer2D = $FlashlightAudio if has_node("FlashlightAudio") else null

func _ready() -> void:
	super._ready()
	_ensure_input_actions()
	_update_flashlight_visibility()
	_update_interaction_ray_direction()
	_update_visuals()

	# Connect proximity interaction zone
	if interaction_detector:
		interaction_detector.area_entered.connect(_on_interaction_area_entered)
		interaction_detector.area_exited.connect(_on_interaction_area_exited)

	var dl = get_node_or_null("/root/DialogueLayer")
	if dl:
		dl.dialogue_finished.connect(_refresh_nearby_prompts)

func _character_process(delta: float) -> void:
	if interaction_cooldown > 0.0:
		interaction_cooldown -= delta

	# If dialogue is currently open, freeze movement input & prime cooldown
	var dl = get_node_or_null("/root/DialogueLayer")
	if dl and dl.is_dialogue_open:
		interaction_cooldown = 0.35
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		if flashlight_on:
			play_directional_anim("flashlight_idle")
		else:
			play_locomotion(false)
		return

	_handle_actions()

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wants_crouch := Input.is_action_pressed("crouch")
	var wants_sprint := Input.is_action_pressed("sprint")

	# --- State Transitions ---
	if current_state == State.JUMP:
		z_velocity -= Z_GRAVITY * delta
		z_pos += z_velocity * delta
		if z_pos <= 0.0:
			z_pos = 0.0
			z_velocity = 0.0
			current_state = State.IDLE
	elif Input.is_action_just_pressed("jump") and current_state != State.CROUCH:
		current_state = State.JUMP
		z_velocity = JUMP_VELOCITY
		if sprite:
			sprite.frame = 0
	elif wants_crouch:
		current_state = State.CROUCH
	elif input_dir != Vector2.ZERO:
		current_state = State.SPRINT if wants_sprint else State.WALK
	else:
		current_state = State.IDLE

	# --- Target Speed & Acceleration ---
	var target_speed := WALK_SPEED
	match current_state:
		State.CROUCH:
			target_speed = CROUCH_SPEED
		State.SPRINT:
			target_speed = SPRINT_SPEED
		State.WALK:
			target_speed = WALK_SPEED

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * target_speed, ACCEL * delta)
		var cardinal := _to_cardinal(input_dir)
		if cardinal != last_facing_dir:
			last_facing_dir = cardinal
			_update_interaction_ray_direction()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()
	_update_visuals()

func _handle_actions() -> void:
	# Handle interaction trigger (guarded by cooldown so closing keypress never re-opens)
	if interaction_cooldown <= 0.0 and Input.is_action_just_pressed("interact"):
		interaction_cooldown = 0.35
		_try_interact()

	# Flashlight Toggle (F key / D-pad Left)
	if has_flashlight and Input.is_action_just_pressed("toggle_flashlight"):
		flashlight_on = !flashlight_on
		_play_flashlight_sfx()
		_update_flashlight_visibility()

func _play_flashlight_sfx() -> void:
	if flashlight_audio:
		# Pitch variation for tactile mechanical realism: slightly crisper click on turn-on
		flashlight_audio.pitch_scale = randf_range(1.04, 1.08) if flashlight_on else randf_range(0.94, 0.98)
		flashlight_audio.play()

func _update_flashlight_visibility() -> void:
	var should_light: bool = flashlight_on and (current_state != State.JUMP)
	if flashlight_cone:
		flashlight_cone.enabled = should_light
	if flashlight_spill:
		flashlight_spill.enabled = should_light

func _update_light_direction() -> void:
	if not flashlight_pivot:
		return
	if last_facing_dir == Vector2.RIGHT:
		flashlight_pivot.rotation_degrees = 0.0
	elif last_facing_dir == Vector2.DOWN:
		flashlight_pivot.rotation_degrees = 90.0
	elif last_facing_dir == Vector2.LEFT:
		flashlight_pivot.rotation_degrees = 180.0
	elif last_facing_dir == Vector2.UP:
		flashlight_pivot.rotation_degrees = 270.0

func _update_interaction_ray_direction() -> void:
	if interaction_ray:
		interaction_ray.target_position = last_facing_dir * 60.0

func _on_interaction_area_entered(area: Area2D) -> void:
	if area not in _nearby_interactables:
		_nearby_interactables.append(area)
		var target = area.get_parent()
		if target and target.has_method("set_prompt_visible"):
			target.set_prompt_visible(true)

func _on_interaction_area_exited(area: Area2D) -> void:
	if area in _nearby_interactables:
		_nearby_interactables.erase(area)
		var target = area.get_parent()
		if target and target.has_method("set_prompt_visible"):
			target.set_prompt_visible(false)

func _refresh_nearby_prompts() -> void:
	for area in _nearby_interactables:
		if is_instance_valid(area):
			var target = area.get_parent()
			if target and target.has_method("set_prompt_visible"):
				target.set_prompt_visible(true)

func _try_interact() -> void:
	# 1. Check nearby proximity targets first (easiest & smoothest interaction)
	_nearby_interactables = _nearby_interactables.filter(func(a): return is_instance_valid(a))
	if not _nearby_interactables.is_empty():
		var best_area: Area2D = null
		var best_dist: float = INF
		for area in _nearby_interactables:
			var d := global_position.distance_squared_to(area.global_position)
			if d < best_dist:
				best_dist = d
				best_area = area
		if best_area:
			var target = best_area.get_parent()
			if target and target.has_method("interact"):
				target.interact(self)
				return
			elif best_area.has_method("interact"):
				best_area.interact(self)
				return

	# 2. Fallback to directional RayCast2D
	if interaction_ray and interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider:
			var target = collider.get_parent() if collider is Area2D else collider
			if target and target.has_method("interact"):
				target.interact(self)
			elif collider.has_method("interact"):
				collider.interact(self)

func _update_visuals() -> void:
	_update_light_direction()
	_update_flashlight_visibility()
	if not sprite:
		return

	# Vertical pseudo-Z lift
	sprite.position.y = BASE_VISUAL_Y - z_pos

	# Dynamic shadow scaling with height
	if shadow:
		var s = clampf(1.0 - (z_pos / 45.0) * 0.4, 0.6, 1.0)
		shadow.scale = Vector2(s, s)

	var moving := velocity.length() > 5.0

	if current_state == State.COMBAT or current_state == State.GRAB:
		return

	if flashlight_on:
		match current_state:
			State.CROUCH:
				play_directional_anim("flashlight_crouch")
				if not moving:
					sprite.pause()
					sprite.frame = 0
			State.JUMP:
				play_directional_anim("jump")
			_:
				play_directional_anim("flashlight_walk" if moving else "flashlight_idle")
	else:
		match current_state:
			State.CROUCH:
				play_directional_anim("crouch_walk" if moving else "crouch_idle")
			State.JUMP:
				play_directional_anim("jump")
			_:
				play_directional_anim("walk" if moving else "idle")

func _ensure_input_actions() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"crouch": [KEY_CTRL, KEY_C],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E, KEY_ENTER],
		"toggle_flashlight": [KEY_F],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var already_bound := false
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey and ev.physical_keycode == key:
					already_bound = true
					break
			if not already_bound:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)

	# Also bind D-Pad Left joypad button to toggle_flashlight
	var has_dpad := false
	for ev in InputMap.action_get_events("toggle_flashlight"):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_DPAD_LEFT:
			has_dpad = true
			break
	if not has_dpad:
		var joy_ev := InputEventJoypadButton.new()
		joy_ev.button_index = JOY_BUTTON_DPAD_LEFT
		InputMap.action_add_event("toggle_flashlight", joy_ev)
