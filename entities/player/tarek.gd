class_name Player
extends "res://entities/base_character.gd"
## Unified Player Controller (Tarek).
## Handles Locomotion, Stealth Crouch, Pseudo-Z Jump, Combat, Cargo Push/Pull, and Flashlight.

const GrabHelper := preload("res://components/grab_helper.gd")
const InteractionHelper := preload("res://components/interaction_helper.gd")

@export var walk_speed: float = 180.0
@export var sneak_speed: float = 80.0
@export var sprint_speed: float = 270.0
@export var accel_rate: float = 1400.0
@export var friction_rate: float = 1800.0
@export var jump_impulse: float = 285.0
@export var pseudo_gravity: float = 900.0
@export var has_flashlight: bool = true

var z_pos: float = 0.0
var z_velocity: float = 0.0
enum State { NORMAL, CROUCH, JUMP, COMBAT, GRAB }
var current_state: State = State.NORMAL
var grabbed_object: Node2D = null
var _grab_offset: Vector2 = Vector2.ZERO
var interaction_cooldown: float = 0.0
var flashlight_on: bool = false
var combat_mode: bool = false
var _nearby_interactables: Array[Area2D] = []

@onready var interaction_ray: RayCast2D = get_node_or_null("InteractionRay")
@onready var interaction_detector: Area2D = get_node_or_null("InteractionDetector")
@onready var flashlight_pivot: Node2D = get_node_or_null("FlashlightPivot")
@onready var flashlight_cone: PointLight2D = get_node_or_null("FlashlightPivot/FlashlightCone")
@onready var flashlight_spill: PointLight2D = get_node_or_null("FlashlightPivot/FlashlightSpill")
@onready var flashlight_audio: AudioStreamPlayer2D = get_node_or_null("FlashlightAudio")
@onready var weapon: Node2D = get_node_or_null("WeaponComponent")
var has_weapon: bool:
	get:
		return weapon != null and weapon.weapon_data != null
@onready var health: Node = get_node_or_null("HealthComponent")
@onready var cover: Node2D = get_node_or_null("CoverDetectorComponent")
@onready var dodge: Node = get_node_or_null("DodgeComponent")
@onready var defense: Node = get_node_or_null("DefenseComponent")

const BASE_VISUAL_Y: float = -14.0; const RAY_LENGTH: float = 54.0

func _ready() -> void:
	super._ready()
	add_to_group("player")
	add_to_group("persist")
	if interaction_ray:
		interaction_ray.target_position = last_facing_dir * RAY_LENGTH
		direction_changed.connect(func(dir): interaction_ray.target_position = dir * RAY_LENGTH)
	_update_light_visibility()
	_update_visuals()
	_check_pending_spawn()
	if interaction_detector:
		interaction_detector.area_entered.connect(func(a): if a not in _nearby_interactables: _nearby_interactables.append(a); InteractionHelper.set_prompt(a, true))
		interaction_detector.area_exited.connect(func(a): _nearby_interactables.erase(a); InteractionHelper.set_prompt(a, false))
	var dl = get_node_or_null("/root/DialogueLayer")
	if dl: dl.dialogue_finished.connect(func():
		for a in _nearby_interactables: InteractionHelper.set_prompt(a, true))

func _check_pending_spawn() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_pending_spawn:
		global_position = sm.pending_spawn_point
		if not sm.pending_player_data.is_empty(): load_state(sm.pending_player_data)
		sm.clear_pending_spawn()
func save_state() -> Dictionary:
	return {"has_flashlight": has_flashlight, "flashlight_on": flashlight_on, "facing_dir": {"x": last_facing_dir.x, "y": last_facing_dir.y}}

func load_state(data: Dictionary) -> void:
	if data.is_empty(): return
	has_flashlight = bool(data.get("has_flashlight", true))
	flashlight_on = bool(data.get("flashlight_on", false))
	_update_light_visibility()
	var fd = data.get("facing_dir", {})
	if fd is Dictionary: last_facing_dir = Vector2(float(fd.get("x", 0.0)), float(fd.get("y", 1.0)))

func _character_process(delta: float) -> void:
	if interaction_cooldown > 0.0: interaction_cooldown -= delta
	if health and health.is_dead:
		_stop_defending()
		if weapon: weapon.set_drawn(false)
		velocity = Vector2.ZERO; move_and_slide(); return
	var dl = get_node_or_null("/root/DialogueLayer")
	if dl and dl.is_dialogue_open:
		_stop_defending()
		interaction_cooldown = 0.35
		velocity = velocity.move_toward(Vector2.ZERO, friction_rate * delta)
		move_and_slide()
		sprite.scale = Vector2(3, 3); sprite.offset = Vector2(0, -15)
		sprite.play(("flashlight_idle_" if flashlight_on else "idle_") + get_direction_suffix())
		return
	if dodge and dodge.is_dodging:
		if weapon: weapon.set_drawn(false)
		_update_visuals(); move_and_slide(); return
	if is_defending(): defense.handle_hold_input(Input.is_action_pressed("defend"), get_direction_suffix(), sprite)

	_handle_actions()
	if combat_mode and weapon and not is_defending():
		weapon.set_drawn(true)
		weapon.set_aim_target(get_global_mouse_position())
	_update_z_physics(delta)
	_apply_movement(delta)
	if is_defending():
		defense.process_block(delta, get_direction_suffix(), sprite)
		if not is_defending() and current_state == State.COMBAT: current_state = State.NORMAL
	_update_visuals()
	move_and_slide()
	if current_state == State.GRAB and is_instance_valid(grabbed_object):
		grabbed_object.global_position = (global_position + _grab_offset).round()

func _handle_actions() -> void:
	if current_state == State.JUMP: return
	if has_flashlight and Input.is_action_just_pressed("toggle_flashlight"):
		if current_state in [State.COMBAT, State.GRAB]:
			_release_grab()
			_stop_defending()
			current_state = State.NORMAL
		_toggle_flashlight()

	if interaction_cooldown <= 0.0 and Input.is_action_just_pressed("interact"):
		if current_state == State.GRAB:
			_release_grab(); interaction_cooldown = 0.2; return
		var pushable := _get_pushable_target()
		if pushable:
			_start_grab(pushable)
			interaction_cooldown = 0.2
			if flashlight_on: _toggle_flashlight()
		else:
			interaction_cooldown = 0.35
			_interact_with_target()
		return

	if current_state == State.GRAB:
		if not is_instance_valid(grabbed_object): _release_grab()
		return

	if Input.is_action_just_pressed("toggle_combat") and weapon:
		_set_combat_mode(not combat_mode)
	if Input.is_action_just_pressed("dodge") and dodge:
		var move_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if dodge.try_dodge(move_dir):
			_stop_defending()
			if current_state == State.GRAB: _release_grab()
			if flashlight_on: _toggle_flashlight()
			return
	if Input.is_action_just_pressed("reload") and weapon:
		weapon.reload()
	if Input.is_action_pressed("defend") and current_state != State.COMBAT and defense:
		current_state = State.COMBAT
		if weapon: weapon.set_drawn(false)
		if flashlight_on: _toggle_flashlight()
		velocity = Vector2.ZERO
		defense.start_block(get_direction_suffix(), sprite)
		return
	if Input.is_action_just_pressed("attack"):
		if combat_mode and weapon and not is_defending():
			weapon.set_aim_target(get_global_mouse_position(), true)
			weapon.try_fire()
			return
		elif current_state != State.COMBAT:
			current_state = State.COMBAT
			if flashlight_on: _toggle_flashlight()
			_play_combat_anim("punch")
			return

	if current_state == State.COMBAT: return
	if Input.is_action_just_pressed("jump") and current_state != State.CROUCH:
		current_state = State.JUMP; z_velocity = jump_impulse
		if sprite: sprite.frame = 0
		set_collision_mask_value(3, false); _update_light_visibility(); return

	var crouching := Input.is_action_pressed("stealth_crouch") or Input.is_action_pressed("crouch")
	current_state = State.CROUCH if crouching else State.NORMAL
	if cover: cover.set_crouching(crouching)

func _apply_movement(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_speed := walk_speed
	match current_state:
		State.CROUCH: target_speed = sneak_speed
		State.GRAB: target_speed = walk_speed * 0.45
		State.COMBAT: target_speed = 0.0
		State.NORMAL:
			if weapon and weapon.is_drawn: target_speed = walk_speed * 0.62
			elif Input.is_action_pressed("speed_sprint") or Input.is_action_pressed("sprint"): target_speed = sprint_speed
		State.JUMP: target_speed = walk_speed * 1.05

	if is_defending():
		if input_vec != Vector2.ZERO: last_facing_dir = _to_cardinal(input_vec)
		var block_fric := friction_rate * (0.45 if defense.is_in_impact() else 1.0)
		velocity = velocity.move_toward(Vector2.ZERO, block_fric * delta)
		return

	if input_vec != Vector2.ZERO and current_state != State.COMBAT:
		if current_state != State.GRAB and not (combat_mode and weapon): last_facing_dir = _to_cardinal(input_vec)
		elif current_state == State.GRAB: input_vec = Vector2(signf(input_vec.x), 0.0) if last_facing_dir.x != 0.0 else Vector2(0.0, signf(input_vec.y))
		velocity = velocity.move_toward(input_vec * target_speed, accel_rate * delta)
	else:
		var fric := friction_rate * (0.35 if current_state == State.JUMP else 1.0)
		velocity = velocity.move_toward(Vector2.ZERO, fric * delta)

func _update_z_physics(delta: float) -> void:
	if current_state != State.JUMP: return
	z_velocity -= pseudo_gravity * delta
	z_pos += z_velocity * delta
	if z_velocity <= 0.0 and z_pos <= 0.0:
		z_pos = 0.0; z_velocity = 0.0
		current_state = State.CROUCH if (Input.is_action_pressed("stealth_crouch") or Input.is_action_pressed("crouch")) else State.NORMAL
		set_collision_mask_value(3, true); _update_light_visibility()

func _update_visuals() -> void:
	_update_light_orientation()
	_update_light_visibility()
	if not sprite: return
	sprite.position.y = BASE_VISUAL_Y - z_pos
	if shadow:
		var size := clampf(1.0 - (z_pos / 45.0) * 0.4, 0.6, 1.0)
		shadow.scale = Vector2(size, size)
	if current_state == State.COMBAT or (dodge and dodge.is_dodging): return

	var dir := get_direction_suffix()
	var moving := velocity.length() > 2.0
	if current_state == State.GRAB:
		sprite.play(("push_" if velocity.dot(last_facing_dir) > 0.0 else "pull_") + dir if moving else "grab_still_" + dir)
		return
	if combat_mode and weapon:
		weapon.update_aim_visuals(sprite, dir, velocity, last_facing_dir, current_state == State.CROUCH or (cover != null and cover.is_crouching), cover != null and cover.is_peeking); return
	sprite.speed_scale = 1.0; sprite.flip_h = (last_facing_dir == Vector2.LEFT); sprite.scale = Vector2(3, 3); sprite.offset = Vector2(0, -15)
	if flashlight_on:
		if current_state == State.CROUCH:
			sprite.play("flashlight_crouch_" + dir)
			if not moving: sprite.pause(); sprite.frame = 0
		elif current_state == State.JUMP: sprite.play("jump_" + dir)
		else: sprite.play(("flashlight_walk_" if moving else "flashlight_idle_") + dir)
		return
	match current_state:
		State.CROUCH: sprite.play(("crouch_walk_" if moving else "crouch_idle_") + dir)
		State.JUMP: sprite.play("jump_" + dir)
		State.NORMAL:
			sprite.play(("walk_" if moving else ("damaged_idle_" if (health and health.is_damaged_state) else "idle_")) + dir)

func is_defending() -> bool: return defense != null and defense.is_blocking
func is_defending_against(hit_dir: Vector2) -> bool: return defense != null and defense.can_deflect(hit_dir, last_facing_dir)
func on_hit_deflected(hit_dir: Vector2) -> void:
	if defense: defense.trigger_deflect_impact(hit_dir, self, last_facing_dir, get_direction_suffix(), sprite)
func _stop_defending() -> void:
	if not is_defending(): return
	defense.stop_block()
	if current_state == State.COMBAT: current_state = State.NORMAL

func _play_combat_anim(anim_prefix: String) -> void:
	velocity = Vector2.ZERO
	var anim_name := anim_prefix + "_" + get_direction_suffix()
	if sprite and sprite.sprite_frames:
		var played := anim_name if sprite.sprite_frames.has_animation(anim_name) else (anim_prefix if sprite.sprite_frames.has_animation(anim_prefix) else "")
		if not played.is_empty(): sprite.play(played); await sprite.animation_finished
	if current_state == State.COMBAT: current_state = State.NORMAL

func _start_grab(target: Node2D) -> void:
	_release_grab(); grabbed_object = target
	if grabbed_object: _grab_offset = GrabHelper.attach(self, grabbed_object); current_state = State.GRAB

func _release_grab() -> void:
	GrabHelper.detach(self, grabbed_object); grabbed_object = null
	if current_state == State.GRAB: current_state = State.NORMAL

func _get_pushable_target() -> Node2D: return GrabHelper.find_pushable(interaction_ray)

func _set_combat_mode(active: bool) -> void:
	combat_mode = active
	if combat_mode:
		if current_state == State.GRAB: _release_grab()
		if flashlight_on: _toggle_flashlight()
	if weapon: weapon.set_drawn(combat_mode)

func _toggle_flashlight() -> void:
	flashlight_on = !flashlight_on
	if flashlight_audio:
		flashlight_audio.pitch_scale = randf_range(1.04, 1.08) if flashlight_on else randf_range(0.94, 0.98)
		flashlight_audio.play()
	_update_light_visibility()

func _update_light_visibility() -> void:
	var active: bool = flashlight_on and (current_state != State.JUMP)
	if flashlight_cone: flashlight_cone.enabled = active
	if flashlight_spill: flashlight_spill.enabled = active

func _update_light_orientation() -> void:
	if not flashlight_pivot: return
	flashlight_pivot.rotation = last_facing_dir.angle()
	flashlight_pivot.z_index = -1 if last_facing_dir == Vector2.UP else 1
	var offsets := {Vector2.DOWN: Vector2(-12, -32), Vector2.RIGHT: Vector2(21, -41), Vector2.LEFT: Vector2(-21, -41), Vector2.UP: Vector2(15, -44)}
	flashlight_pivot.position = offsets.get(last_facing_dir, Vector2(-12, -32))

func _interact_with_target() -> void:
	_nearby_interactables = _nearby_interactables.filter(func(a): return is_instance_valid(a))
	InteractionHelper.interact_nearest(self, _nearby_interactables, interaction_ray)
