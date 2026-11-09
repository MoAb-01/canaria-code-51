class_name Player
extends BaseCharacter
## Unified Tariq Controller — Natural Locomotion, Stealth Crouch, Pseudo-Z Jump,
## Unarmed Combat (Punch & Defend), Cargo Push/Pull, and 2D Cone Flashlight.

# Motion Variables
@export var walk_speed: float = 180.0
@export var sneak_speed: float = 80.0
@export var sprint_speed: float = 270.0
@export var accel_rate: float = 1400.0
@export var friction_rate: float = 1800.0

# Vertical Height Physics
@export var jump_impulse: float = 285.0
@export var pseudo_gravity: float = 900.0

var z_pos: float = 0.0
var z_velocity: float = 0.0

enum State { NORMAL, CROUCH, JUMP, COMBAT, GRAB }
var current_state: State = State.NORMAL

# Light Settings
@export var has_flashlight: bool = true
var flashlight_on: bool = false

# Grab / Cargo & Dialogue state
var grabbed_object: Node2D = null
var _grab_offset: Vector2 = Vector2.ZERO
var _nearby_interactables: Array[Area2D] = []
var interaction_cooldown: float = 0.0

# Internal Node Access
@onready var interaction_ray: RayCast2D = $InteractionRay if has_node("InteractionRay") else null
@onready var interaction_detector: Area2D = $InteractionDetector if has_node("InteractionDetector") else null
@onready var flashlight_pivot: Node2D = $FlashlightPivot if has_node("FlashlightPivot") else null
@onready var flashlight_cone: PointLight2D = $FlashlightPivot/FlashlightCone if has_node("FlashlightPivot/FlashlightCone") else null
@onready var flashlight_spill: PointLight2D = $FlashlightPivot/FlashlightSpill if has_node("FlashlightPivot/FlashlightSpill") else null
@onready var flashlight_audio: AudioStreamPlayer2D = $FlashlightAudio if has_node("FlashlightAudio") else null

const BASE_VISUAL_Y: float = -14.0
const RAY_LENGTH: float = 54.0

func _ready() -> void:
	super._ready()
	_ensure_input_actions()
	if interaction_ray:
		interaction_ray.target_position = last_facing_dir * RAY_LENGTH
	_update_flashlight_visibility()
	_update_visuals()

	if interaction_detector:
		interaction_detector.area_entered.connect(_on_interaction_area_entered)
		interaction_detector.area_exited.connect(_on_interaction_area_exited)

	var dl = get_node_or_null("/root/DialogueLayer")
	if dl:
		dl.dialogue_finished.connect(_refresh_nearby_prompts)

func _character_process(delta: float) -> void:
	if interaction_cooldown > 0.0:
		interaction_cooldown -= delta

	# Pause actions & locomotion while dialogue is active
	var dl = get_node_or_null("/root/DialogueLayer")
	if dl and dl.is_dialogue_open:
		interaction_cooldown = 0.35
		velocity = velocity.move_toward(Vector2.ZERO, friction_rate * delta)
		move_and_slide()
		var dir := _get_dir_suffix()
		sprite.play(("flashlight_idle_" if flashlight_on else "idle_") + dir)
		return

	_handle_actions()
	_update_z_physics(delta)
	_apply_movement(delta)
	_update_visuals()

	move_and_slide()

	# Move grabbed pushable cargo in lockstep with Tariq
	if current_state == State.GRAB and is_instance_valid(grabbed_object):
		grabbed_object.global_position = (global_position + _grab_offset).round()

func _start_grab(target: Node2D) -> void:
	_release_grab()
	grabbed_object = target
	if grabbed_object:
		_grab_offset = grabbed_object.global_position - global_position
		if grabbed_object is PhysicsBody2D:
			add_collision_exception_with(grabbed_object)
	current_state = State.GRAB

func _release_grab() -> void:
	if is_instance_valid(grabbed_object) and grabbed_object is PhysicsBody2D:
		remove_collision_exception_with(grabbed_object)
	grabbed_object = null
	if current_state == State.GRAB:
		current_state = State.NORMAL

func _handle_actions() -> void:
	if current_state == State.JUMP:
		return

	# Flashlight switch (F key / D-pad Left)
	if has_flashlight and Input.is_action_just_pressed("toggle_flashlight"):
		if current_state == State.COMBAT or current_state == State.GRAB:
			_release_grab()
			current_state = State.NORMAL
		flashlight_on = !flashlight_on
		_play_flashlight_sfx()
		_update_flashlight_visibility()

	# Interactive Grab (E key) on pushable cargo OR NPC Dialogue
	if interaction_cooldown <= 0.0 and Input.is_action_just_pressed("interact"):
		if current_state == State.GRAB:
			_release_grab()
			interaction_cooldown = 0.2
			return
		elif _can_grab_object():
			_start_grab(_get_grab_collider())
			interaction_cooldown = 0.2
			if flashlight_on:
				flashlight_on = false
				_play_flashlight_sfx()
				_update_flashlight_visibility()
			return
		else:
			interaction_cooldown = 0.35
			_try_interact()
			return

	if current_state == State.GRAB:
		if not is_instance_valid(grabbed_object):
			_release_grab()
		return

	# Melee Strike (Left Mouse Button / J)
	if Input.is_action_just_pressed("attack") and current_state != State.COMBAT:
		current_state = State.COMBAT
		if flashlight_on:
			flashlight_on = false
			_update_flashlight_visibility()
		_execute_melee_strike()
		return

	# Defend / Guard Stance (Right Mouse Button / K)
	if Input.is_action_just_pressed("defend") and current_state != State.COMBAT:
		current_state = State.COMBAT
		if flashlight_on:
			flashlight_on = false
			_update_flashlight_visibility()
		_execute_defend_stance()
		return

	if current_state == State.COMBAT:
		return

	# Jump Action (Space)
	if Input.is_action_just_pressed("jump") and current_state != State.CROUCH:
		current_state = State.JUMP
		z_velocity = jump_impulse
		if sprite:
			sprite.frame = 0
		set_collision_mask_value(3, false) # Clear low objects mask (Layer 3)
		_update_flashlight_visibility()
		return

	# Crouching States (Ctrl / C)
	if Input.is_action_pressed("stealth_crouch") or Input.is_action_pressed("crouch"):
		current_state = State.CROUCH
	else:
		current_state = State.NORMAL

func _can_grab_object() -> bool:
	return _get_grab_collider() != null

func _get_grab_collider() -> Node2D:
	if interaction_ray:
		interaction_ray.force_raycast_update()
		if interaction_ray.is_colliding():
			var col = interaction_ray.get_collider()
			if col and col.is_in_group("pushable"):
				return col as Node2D
			if col and col.get_parent() and col.get_parent().is_in_group("pushable"):
				return col.get_parent() as Node2D
	return null

func _execute_melee_strike() -> void:
	velocity = Vector2.ZERO
	sprite.play("punch_" + _get_dir_suffix())
	await sprite.animation_finished
	if current_state == State.COMBAT:
		current_state = State.NORMAL

func _execute_defend_stance() -> void:
	velocity = Vector2.ZERO
	sprite.play("defend_" + _get_dir_suffix())
	await sprite.animation_finished
	if current_state == State.COMBAT:
		current_state = State.NORMAL

func _update_z_physics(delta: float) -> void:
	if current_state == State.JUMP:
		z_velocity -= pseudo_gravity * delta
		z_pos += z_velocity * delta
		if z_pos <= 0.0:
			z_pos = 0.0
			z_velocity = 0.0
			var crouching := Input.is_action_pressed("stealth_crouch") or Input.is_action_pressed("crouch")
			current_state = State.CROUCH if crouching else State.NORMAL
			set_collision_mask_value(3, true)
			_update_flashlight_visibility()

func _apply_movement(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_speed := walk_speed

	match current_state:
		State.CROUCH:
			target_speed = sneak_speed
		State.GRAB:
			target_speed = walk_speed * 0.45 # Encumbered cargo weight
		State.COMBAT:
			target_speed = 0.0
		State.NORMAL:
			if Input.is_action_pressed("speed_sprint") or Input.is_action_pressed("sprint"):
				target_speed = sprint_speed
		State.JUMP:
			target_speed = walk_speed * 1.05

	if input_vec != Vector2.ZERO and current_state != State.COMBAT:
		if current_state != State.GRAB:
			if absf(input_vec.x) > absf(input_vec.y):
				last_facing_dir = Vector2.RIGHT if input_vec.x > 0.0 else Vector2.LEFT
			else:
				last_facing_dir = Vector2.DOWN if input_vec.y > 0.0 else Vector2.UP
			if interaction_ray:
				interaction_ray.target_position = last_facing_dir * RAY_LENGTH
		else:
			# Constrain push/pull movement along the facing axis
			if last_facing_dir.x != 0.0:
				input_vec = Vector2(signf(input_vec.x), 0.0) if absf(input_vec.x) > 0.1 else Vector2.ZERO
			else:
				input_vec = Vector2(0.0, signf(input_vec.y)) if absf(input_vec.y) > 0.1 else Vector2.ZERO

		velocity = velocity.move_toward(input_vec * target_speed, accel_rate * delta)
	else:
		var active_friction := friction_rate * (0.35 if current_state == State.JUMP else 1.0)
		velocity = velocity.move_toward(Vector2.ZERO, active_friction * delta)

func _get_dir_suffix() -> String:
	if last_facing_dir == Vector2.UP:
		if sprite:
			sprite.flip_h = false
		return "up"
	elif last_facing_dir == Vector2.DOWN:
		if sprite:
			sprite.flip_h = false
		return "down"
	else:
		if sprite:
			sprite.flip_h = (last_facing_dir == Vector2.LEFT)
		return "side"

func _play_flashlight_sfx() -> void:
	if flashlight_audio:
		flashlight_audio.pitch_scale = randf_range(1.04, 1.08) if flashlight_on else randf_range(0.94, 0.98)
		flashlight_audio.play()

func _update_flashlight_visibility() -> void:
	var should_light: bool = flashlight_on and (current_state != State.JUMP)
	if flashlight_cone:
		flashlight_cone.enabled = should_light
	if flashlight_spill:
		flashlight_spill.enabled = should_light

func _update_light_orientation() -> void:
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

func _update_visuals() -> void:
	_update_light_orientation()
	_update_flashlight_visibility()
	if not sprite:
		return

	sprite.position.y = BASE_VISUAL_Y - z_pos

	if shadow:
		var size := clampf(1.0 - (z_pos / 45.0) * 0.4, 0.6, 1.0)
		shadow.scale = Vector2(size, size)

	var dir := _get_dir_suffix()
	var moving := velocity.length() > 2.0

	# 1. State Overrides
	if current_state == State.COMBAT:
		return # Animation driven by _execute_melee_strike / _execute_defend_stance

	if current_state == State.GRAB:
		if moving:
			var matches_gaze := velocity.dot(last_facing_dir) > 0.0
			sprite.play(("push_" if matches_gaze else "pull_") + dir)
		else:
			sprite.play("grab_still_" + dir)
		return

	# 2. Flashlight Sets
	if flashlight_on:
		match current_state:
			State.CROUCH:
				sprite.play("flashlight_crouch_" + dir)
				if not moving:
					sprite.pause()
					sprite.frame = 0
			State.NORMAL:
				sprite.play(("flashlight_walk_" if moving else "flashlight_idle_") + dir)
			State.JUMP:
				sprite.play("jump_" + dir)
		return

	# 3. Standard Unarmed Sets
	match current_state:
		State.CROUCH:
			sprite.play(("crouch_walk_" if moving else "crouch_idle_") + dir)
		State.NORMAL:
			sprite.play(("walk_" if moving else "idle_") + dir)
		State.JUMP:
			sprite.play("jump_" + dir)

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

	if interaction_ray and interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider:
			var target = collider.get_parent() if collider is Area2D else collider
			if target and target.has_method("interact"):
				target.interact(self)
			elif collider.has_method("interact"):
				collider.interact(self)

func _ensure_input_actions() -> void:
	var key_bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"crouch": [KEY_CTRL, KEY_C],
		"stealth_crouch": [KEY_CTRL, KEY_C],
		"sprint": [KEY_SHIFT],
		"speed_sprint": [KEY_SHIFT],
		"interact": [KEY_E, KEY_ENTER],
		"toggle_flashlight": [KEY_F],
		"attack": [KEY_J],
		"defend": [KEY_K],
	}
	for action in key_bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in key_bindings[action]:
			var already_bound := false
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey and ev.physical_keycode == key:
					already_bound = true
					break
			if not already_bound:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)

	# Mouse buttons for attack (Left Click) and defend (Right Click)
	var mouse_bindings := {
		"attack": MOUSE_BUTTON_LEFT,
		"defend": MOUSE_BUTTON_RIGHT,
	}
	for action in mouse_bindings:
		var btn: int = mouse_bindings[action]
		var has_btn := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton and ev.button_index == btn:
				has_btn = true
				break
		if not has_btn:
			var mb := InputEventMouseButton.new()
			mb.button_index = btn
			InputMap.action_add_event(action, mb)

	# D-Pad Left joypad button for toggle_flashlight
	var has_dpad := false
	for ev in InputMap.action_get_events("toggle_flashlight"):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_DPAD_LEFT:
			has_dpad = true
			break
	if not has_dpad:
		var joy_ev := InputEventJoypadButton.new()
		joy_ev.button_index = JOY_BUTTON_DPAD_LEFT
		InputMap.action_add_event("toggle_flashlight", joy_ev)
