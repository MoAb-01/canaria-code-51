class_name WeaponComponent
extends Node2D
## Universal Weapon Engine Component.
## Manages WeaponPivot shoulder rig, MuzzlePoint barrel spawning, pixel-matched
## 48x40 pistol walk/aim/shoot/crouch-shoot animations, brass casings, and reloading.

signal fired(direction: Vector2)
signal reload_started(duration: float)
signal reload_finished()

@export var weapon_data: Resource
@export var bullet_scene: PackedScene
@export var weapon_texture: Texture2D
@export var shoulder_offset: Vector2 = Vector2(0, -61)
@export var crouch_shoulder_offset: Vector2 = Vector2(0, -46)
@export var peek_shoulder_offset: Vector2 = Vector2(0, -48)
@export var muzzle_local_pos: Vector2 = Vector2(35, -6)
@export var show_weapon_when_holstered: bool = false

var aim_direction: Vector2 = Vector2.RIGHT
var current_mag: int = 8
var reserve_ammo: int = 32
var is_reloading: bool = false
var is_drawn: bool = false

var _cooldown_timer: float = 0.0
var _reload_timer: float = 0.0
var _shoot_timer: float = 0.0
var _is_shooting: bool = false
var _shoot_crouching: bool = false
var _shoot_dir_key: String = "right"
var _shoot_flip_h: bool = false
var _bound_sprite: AnimatedSprite2D = null
var _weapon_pivot: Node2D = null
var _weapon_sprite: Sprite2D = null
var _muzzle_point: Marker2D = null
var _muzzle_flash: Polygon2D = null

const BASE_SCALE := Vector2(3.0, 3.0)
const BASE_OFFSET := Vector2(0.0, -15.0)

func _ready() -> void:
	if weapon_data:
		current_mag = int(weapon_data.get("mag_size"))
		reserve_ammo = int(weapon_data.get("max_reserve"))
	_setup_weapon_rig()
	set_drawn(show_weapon_when_holstered)
	call_deferred("_emit_ammo")
	call_deferred("_bind_parent_sprite")

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0: _cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if _is_shooting:
		_shoot_timer -= delta
		var sp := _get_parent_sprite()
		if _shoot_timer <= 0.0 or (sp and not sp.is_playing()):
			_finish_shoot_anim(sp)
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0: _complete_reload()
	_sync_pivot_height()

func set_drawn(active: bool) -> void:
	is_drawn = active
	if _weapon_pivot: _weapon_pivot.visible = active or show_weapon_when_holstered
	if not active:
		_is_shooting = false
		var sp := _get_parent_sprite()
		if sp:
			sp.speed_scale = 1.0; sp.scale = BASE_SCALE; sp.offset = BASE_OFFSET
	_sync_pivot_height()

func sync_sprite_transform(sprite: AnimatedSprite2D) -> void:
	if not sprite: return
	sprite.scale = BASE_SCALE
	sprite.offset = BASE_OFFSET

func update_aim_visuals(sprite: AnimatedSprite2D, dir: String, vel: Vector2, facing_dir: Vector2, crouching: bool, peeking: bool) -> void:
	if not sprite: return
	_bind_sprite(sprite)
	if _is_shooting:
		var anim := String(sprite.animation)
		if _shoot_timer > 0.0 and sprite.is_playing() and (anim.begins_with("pistol_shoot_") or anim.begins_with("pistol_crouch_shoot_")):
			sprite.flip_h = _shoot_flip_h; sprite.speed_scale = 1.0
			sync_sprite_transform(sprite); _sync_pivot_height(); return
		_is_shooting = false
	if peeking:
		sprite.flip_h = (facing_dir == Vector2.LEFT); sprite.speed_scale = 1.0
		sprite.play("peek_shoot_" + dir); sync_sprite_transform(sprite)
		_sync_pivot_height(); return

	var info := _get_pistol_dir_info(aim_direction)
	sprite.flip_h = info.flip; sprite.speed_scale = 1.0
	var prefix := "pistol_crouch_aim_" if crouching else ("pistol_walk_" if vel.length() > 2.0 else "pistol_aim_")
	var want := prefix + String(info.key)
	if sprite.animation != StringName(want) or not sprite.is_playing(): sprite.play(want)
	sync_sprite_transform(sprite); _sync_pivot_height()

func get_muzzle_world_position() -> Vector2:
	return _muzzle_point.global_position if _muzzle_point else global_position

func set_aim_target(world_pos: Vector2, force: bool = false) -> void:
	if _is_shooting and not force: return
	var pivot_origin := _weapon_pivot.global_position if _weapon_pivot else global_position
	var diff := world_pos - pivot_origin
	if diff.length_squared() > 1.0: aim_direction = diff.normalized()

	var facing := _to_quadrant(aim_direction)
	var parent := get_parent()
	if parent and "last_facing_dir" in parent:
		parent.last_facing_dir = facing
		if "sprite" in parent and parent.sprite: parent.sprite.flip_h = (facing == Vector2.LEFT)

	var crouch := _is_parent_crouching(parent)
	var info := _get_pistol_dir_info(aim_direction)
	_update_muzzle_point(crouch, info.key, info.flip)

func try_fire() -> bool:
	if not weapon_data or not bullet_scene or is_reloading or _cooldown_timer > 0.0: return false
	if current_mag <= 0:
		reload(); return false

	var parent := get_parent()
	var cover := _find_cover_component(parent)
	var crouch_now := _is_parent_crouching(parent)
	var is_peeking_cover := false
	if cover and cover.is_crouching:
		cover.start_peek(); is_peeking_cover = true

	var info := _get_pistol_dir_info(aim_direction)
	_is_shooting = true; _shoot_timer = 0.28
	_shoot_crouching = crouch_now; _shoot_dir_key = String(info.key); _shoot_flip_h = bool(info.flip)
	if parent and "last_facing_dir" in parent: parent.last_facing_dir = _to_quadrant(aim_direction)

	_sync_pivot_height()
	_update_muzzle_point(crouch_now, _shoot_dir_key, _shoot_flip_h)

	var spawn_pos := get_muzzle_world_position()
	var fire_dir := aim_direction
	var bullet := bullet_scene.instantiate()
	var world_root := parent.get_parent() if parent and parent.get_parent() else get_tree().current_scene
	if world_root:
		world_root.add_child(bullet)
		if bullet.has_method("setup"):
			bullet.setup(spawn_pos, fire_dir, float(weapon_data.get("bullet_speed")), float(weapon_data.get("damage")), parent, is_peeking_cover)

	current_mag -= 1
	_cooldown_timer = float(weapon_data.get("fire_cooldown"))
	if _muzzle_flash: _muzzle_flash.visible = false
	_spawn_brass_casing(parent, fire_dir)

	var sp := _get_parent_sprite()
	if sp:
		_bind_sprite(sp)
		sp.flip_h = _shoot_flip_h; sp.speed_scale = 1.0
		sp.play(("pistol_crouch_shoot_" if crouch_now else "pistol_shoot_") + _shoot_dir_key)
		sync_sprite_transform(sp)
		sp.frame = 1; sp.frame_progress = 0.0

	var eb := get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("ammo_changed"): eb.ammo_changed.emit(parent, current_mag, reserve_ammo)
		if eb.has_signal("weapon_fired"): eb.weapon_fired.emit(parent, spawn_pos, fire_dir, float(weapon_data.get("noise_radius")))

	fired.emit(fire_dir)
	return true

func reload() -> void:
	if not weapon_data or is_reloading: return
	if current_mag >= int(weapon_data.get("mag_size")) or reserve_ammo <= 0: return
	is_reloading = true; _is_shooting = false
	var dur := float(weapon_data.get("reload_duration"))
	_reload_timer = dur; reload_started.emit(dur)

func _complete_reload() -> void:
	is_reloading = false
	if weapon_data:
		var needed: int = int(weapon_data.get("mag_size")) - current_mag
		var loaded: int = mini(needed, reserve_ammo)
		current_mag += loaded; reserve_ammo -= loaded
	_emit_ammo(); reload_finished.emit()

func _emit_ammo() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("ammo_changed"): eb.ammo_changed.emit(get_parent(), current_mag, reserve_ammo)

func _bind_parent_sprite() -> void: _bind_sprite(_get_parent_sprite())

func _bind_sprite(sp: AnimatedSprite2D) -> void:
	if not sp or sp == _bound_sprite: return
	if _bound_sprite and _bound_sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_bound_sprite.animation_finished.disconnect(_on_sprite_animation_finished)
	_bound_sprite = sp
	if not _bound_sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_bound_sprite.animation_finished.connect(_on_sprite_animation_finished)

func _on_sprite_animation_finished() -> void:
	if not _is_shooting: return
	var sp := _get_parent_sprite()
	if not sp: _is_shooting = false; return
	var anim := String(sp.animation)
	if anim.begins_with("pistol_shoot_") or anim.begins_with("pistol_crouch_shoot_"): _finish_shoot_anim(sp)

func _finish_shoot_anim(sp: AnimatedSprite2D) -> void:
	_is_shooting = false
	if sp and is_drawn:
		var idle_anim := ("pistol_crouch_aim_" if _shoot_crouching else "pistol_aim_") + _shoot_dir_key
		if sp.sprite_frames and sp.sprite_frames.has_animation(idle_anim):
			sp.flip_h = _shoot_flip_h; sp.play(idle_anim); sync_sprite_transform(sp)

func _get_parent_sprite() -> AnimatedSprite2D:
	var p := get_parent()
	return p.sprite as AnimatedSprite2D if (p and "sprite" in p and p.sprite is AnimatedSprite2D) else null

func _is_parent_crouching(parent: Node) -> bool:
	var cover := _find_cover_component(parent)
	return (cover != null and cover.is_crouching) or (parent != null and "current_state" in parent and parent.current_state == 1)

func _setup_weapon_rig() -> void:
	_weapon_pivot = get_node_or_null("WeaponPivot") as Node2D
	if not _weapon_pivot:
		_weapon_pivot = Node2D.new(); _weapon_pivot.name = "WeaponPivot"
		_weapon_pivot.position = shoulder_offset; _weapon_pivot.z_index = 5; add_child(_weapon_pivot)
	_weapon_sprite = _weapon_pivot.get_node_or_null("WeaponSprite") as Sprite2D
	if not _weapon_sprite and weapon_texture:
		_weapon_sprite = Sprite2D.new(); _weapon_sprite.name = "WeaponSprite"
		_weapon_sprite.texture = weapon_texture; _weapon_pivot.add_child(_weapon_sprite)
	if _weapon_sprite:
		_weapon_sprite.hframes = 3; _weapon_sprite.vframes = 1; _weapon_sprite.frame = 0
		_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_weapon_sprite.scale = BASE_SCALE; _weapon_sprite.centered = true; _weapon_sprite.offset = Vector2.ZERO
	_muzzle_point = _weapon_pivot.get_node_or_null("MuzzlePoint") as Marker2D
	if not _muzzle_point:
		_muzzle_point = Marker2D.new(); _muzzle_point.name = "MuzzlePoint"
		_muzzle_point.position = muzzle_local_pos; _weapon_pivot.add_child(_muzzle_point)
	_muzzle_flash = Polygon2D.new()
	_muzzle_flash.name = "MuzzleFlash"; _muzzle_flash.position = _muzzle_point.position
	_muzzle_flash.polygon = PackedVector2Array([Vector2(0, -4), Vector2(4, -2), Vector2(11, 0), Vector2(4, 2), Vector2(0, 4), Vector2(2, 0)])
	_muzzle_flash.color = Color(1.0, 0.94, 0.55, 1.0); _muzzle_flash.z_index = 25; _muzzle_flash.visible = false
	_weapon_pivot.add_child(_muzzle_flash)

func _sync_pivot_height() -> void:
	if not _weapon_pivot: return
	var parent := get_parent()
	var cover := _find_cover_component(parent)
	var base_pos := crouch_shoulder_offset if _is_parent_crouching(parent) else (peek_shoulder_offset if (cover and cover.is_peeking) else shoulder_offset)
	var anim_sprite := _get_parent_sprite()
	var anim := String(anim_sprite.animation) if anim_sprite else ""
	var bob := 3.0 if (anim_sprite and (anim.begins_with("walk_") or anim.begins_with("pistol_walk_") or anim.begins_with("crouch_walk_")) and (anim_sprite.frame % 2 == 1)) else 0.0
	_weapon_pivot.position = base_pos + Vector2(0.0, bob)
	if _weapon_sprite: _weapon_sprite.visible = false if is_drawn else show_weapon_when_holstered

func _update_muzzle_point(crouch: bool, key: String, flip: bool) -> void:
	if not _weapon_pivot or not _muzzle_point: return
	var table := {
		"s_down": Vector2(1, -57), "s_right": Vector2(48, -56), "s_up": Vector2(33, -86),
		"c_down": Vector2(-2, -48), "c_right": Vector2(40, -49), "c_up": Vector2(25, -72)
	}
	var tip: Vector2 = table.get(("c_" if crouch else "s_") + key, Vector2(48, -56))
	if flip: tip.x = -tip.x
	_weapon_pivot.rotation = 0.0; _weapon_pivot.scale = Vector2.ONE
	_weapon_pivot.z_index = -1 if key == "up" else 5
	_muzzle_point.position = tip - _weapon_pivot.position
	if _muzzle_flash:
		_muzzle_flash.position = _muzzle_point.position
		_muzzle_flash.rotation = aim_direction.angle()

func _get_pistol_dir_info(dir: Vector2) -> Dictionary:
	if absf(dir.x) >= absf(dir.y):
		return {"key": "right", "flip": dir.x < 0.0}
	if dir.y < 0.0:
		return {"key": "up", "flip": false}
	return {"key": "down", "flip": false}

func _spawn_brass_casing(parent: Node, fire_dir: Vector2) -> void:
	var world_root := parent.get_parent() if parent and parent.get_parent() else get_tree().current_scene
	if not world_root or not _weapon_pivot: return
	var casing := CPUParticles2D.new()
	casing.global_position = get_muzzle_world_position() - fire_dir * 8.0
	casing.emitting = true; casing.one_shot = true; casing.amount = 1; casing.lifetime = 0.38
	casing.direction = Vector2(-fire_dir.x * 0.6, -1.0).normalized(); casing.spread = 20.0; casing.gravity = Vector2(0, 420)
	casing.initial_velocity_min = 65.0; casing.initial_velocity_max = 95.0
	casing.scale_amount_min = 2.0; casing.scale_amount_max = 3.0; casing.color = Color(0.95, 0.78, 0.28, 1.0)
	world_root.add_child(casing); casing.finished.connect(casing.queue_free)

func _find_cover_component(parent: Node) -> Node:
	if not parent: return null
	for child in parent.get_children():
		if child.has_method("start_peek") and "is_crouching" in child: return child
	return null

func _to_quadrant(dir: Vector2) -> Vector2:
	if absf(dir.x) > absf(dir.y): return Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if dir.y >= 0.0 else Vector2.UP
