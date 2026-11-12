class_name WeaponComponent
extends Node2D
## Universal Weapon Engine Component.
## Manages WeaponPivot shoulder rig, MuzzlePoint barrel spawning, muzzle flash,
## pistol recoil kick, brass casing ejection, and magazine reloading.

signal fired(direction: Vector2)
signal reload_started(duration: float)
signal reload_finished()

@export var weapon_data: Resource
@export var bullet_scene: PackedScene
@export var weapon_texture: Texture2D
@export var shoulder_offset: Vector2 = Vector2(0, -56)
@export var crouch_shoulder_offset: Vector2 = Vector2(0, -40)
@export var peek_shoulder_offset: Vector2 = Vector2(0, -48)
@export var muzzle_local_pos: Vector2 = Vector2(42, -6)
@export var show_weapon_when_holstered: bool = false

var aim_direction: Vector2 = Vector2.RIGHT
var current_mag: int = 8
var reserve_ammo: int = 32
var is_reloading: bool = false
var is_drawn: bool = false

var _cooldown_timer: float = 0.0
var _reload_timer: float = 0.0
var _flash_timer: float = 0.0
var _weapon_pivot: Node2D = null
var _weapon_sprite: Sprite2D = null
var _muzzle_point: Marker2D = null
var _muzzle_flash: Polygon2D = null
var _recoil_tween: Tween = null

func _ready() -> void:
	if weapon_data:
		current_mag = int(weapon_data.get("mag_size"))
		reserve_ammo = int(weapon_data.get("max_reserve"))
	_setup_weapon_rig()
	set_drawn(show_weapon_when_holstered)
	call_deferred("_emit_ammo")

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _muzzle_flash:
			_muzzle_flash.visible = false
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_complete_reload()
	_sync_pivot_height()

func set_drawn(active: bool) -> void:
	is_drawn = active
	if _weapon_pivot:
		_weapon_pivot.visible = active or show_weapon_when_holstered

func get_muzzle_world_position() -> Vector2:
	return _muzzle_point.global_position if _muzzle_point else global_position

func set_aim_target(world_pos: Vector2) -> void:
	var pivot_origin := _weapon_pivot.global_position if _weapon_pivot else global_position
	var diff := world_pos - pivot_origin
	if diff.length_squared() > 1.0:
		aim_direction = diff.normalized()

	if _weapon_pivot:
		var angle := aim_direction.angle()
		_weapon_pivot.rotation = angle
		_weapon_pivot.scale.y = -1.0 if absf(angle) > PI * 0.5 else 1.0

	var parent := get_parent()
	if parent and "last_facing_dir" in parent:
		parent.last_facing_dir = _to_quadrant(aim_direction)

func try_fire() -> bool:
	if not weapon_data or not bullet_scene or is_reloading or _cooldown_timer > 0.0:
		return false
	if current_mag <= 0:
		reload()
		return false

	var parent := get_parent()
	var cover := _find_cover_component(parent)
	var is_peeking_cover := false
	if cover and cover.is_crouching:
		cover.start_peek()
		is_peeking_cover = true
		_sync_pivot_height()

	var spawn_pos := get_muzzle_world_position()
	var fire_dir := Vector2.RIGHT.rotated(_weapon_pivot.global_rotation) if _weapon_pivot else aim_direction
	var bullet := bullet_scene.instantiate()
	var world_root := parent.get_parent() if parent and parent.get_parent() else get_tree().current_scene
	if world_root:
		world_root.add_child(bullet)
		if bullet.has_method("setup"):
			bullet.setup(spawn_pos, fire_dir, float(weapon_data.get("bullet_speed")), float(weapon_data.get("damage")), parent, is_peeking_cover)

	current_mag -= 1
	_cooldown_timer = float(weapon_data.get("fire_cooldown"))
	_trigger_muzzle_flash()
	_trigger_recoil_kick()
	_spawn_brass_casing(parent, fire_dir)

	var eb := get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("ammo_changed"):
			eb.ammo_changed.emit(parent, current_mag, reserve_ammo)
		if eb.has_signal("weapon_fired"):
			eb.weapon_fired.emit(parent, spawn_pos, fire_dir, float(weapon_data.get("noise_radius")))

	fired.emit(fire_dir)
	return true

func reload() -> void:
	if not weapon_data or is_reloading:
		return
	if current_mag >= int(weapon_data.get("mag_size")) or reserve_ammo <= 0:
		return
	is_reloading = true
	var dur := float(weapon_data.get("reload_duration"))
	_reload_timer = dur
	reload_started.emit(dur)

func _complete_reload() -> void:
	is_reloading = false
	if weapon_data:
		var needed: int = int(weapon_data.get("mag_size")) - current_mag
		var loaded: int = mini(needed, reserve_ammo)
		current_mag += loaded
		reserve_ammo -= loaded
	_emit_ammo()
	reload_finished.emit()

func _emit_ammo() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("ammo_changed"):
		eb.ammo_changed.emit(get_parent(), current_mag, reserve_ammo)

func _setup_weapon_rig() -> void:
	_weapon_pivot = get_node_or_null("WeaponPivot") as Node2D
	if not _weapon_pivot:
		_weapon_pivot = Node2D.new()
		_weapon_pivot.name = "WeaponPivot"
		_weapon_pivot.position = shoulder_offset
		_weapon_pivot.z_index = 5
		add_child(_weapon_pivot)

	_weapon_sprite = _weapon_pivot.get_node_or_null("WeaponSprite") as Sprite2D
	if not _weapon_sprite and weapon_texture:
		_weapon_sprite = Sprite2D.new()
		_weapon_sprite.name = "WeaponSprite"
		_weapon_sprite.texture = weapon_texture
		_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_weapon_sprite.scale = Vector2(3, 3)
		_weapon_sprite.offset = Vector2(7, 0)
		_weapon_pivot.add_child(_weapon_sprite)

	_muzzle_point = _weapon_pivot.get_node_or_null("MuzzlePoint") as Marker2D
	if not _muzzle_point:
		_muzzle_point = Marker2D.new()
		_muzzle_point.name = "MuzzlePoint"
		_muzzle_point.position = muzzle_local_pos
		_weapon_pivot.add_child(_muzzle_point)

	_muzzle_flash = _muzzle_pivot_flash()

func _muzzle_pivot_flash() -> Polygon2D:
	var flash := Polygon2D.new()
	flash.name = "MuzzleFlash"
	flash.position = _muzzle_point.position
	flash.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(4, -2), Vector2(11, 0),
		Vector2(4, 2), Vector2(0, 4), Vector2(2, 0)
	])
	flash.color = Color(1.0, 0.94, 0.55, 1.0)
	flash.z_index = 25
	flash.visible = false
	_weapon_pivot.add_child(flash)
	return flash

func _sync_pivot_height() -> void:
	if not _weapon_pivot:
		return
	var cover := _find_cover_component(get_parent())
	if cover and cover.is_peeking:
		_weapon_pivot.position = peek_shoulder_offset
	elif cover and cover.is_crouching:
		_weapon_pivot.position = crouch_shoulder_offset
	else:
		_weapon_pivot.position = shoulder_offset

func _trigger_muzzle_flash() -> void:
	if _muzzle_flash:
		_muzzle_flash.visible = true
		_flash_timer = 0.06

func _trigger_recoil_kick() -> void:
	if not _weapon_sprite:
		return
	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()
	_weapon_sprite.position.x = 0.0
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_weapon_sprite, "position:x", -6.0, 0.04)
	_recoil_tween.tween_property(_weapon_sprite, "position:x", 0.0, 0.10)

func _spawn_brass_casing(parent: Node, fire_dir: Vector2) -> void:
	var world_root := parent.get_parent() if parent and parent.get_parent() else get_tree().current_scene
	if not world_root or not _weapon_pivot:
		return
	var casing := CPUParticles2D.new()
	casing.global_position = _weapon_pivot.global_position + fire_dir * 20.0
	casing.emitting = true
	casing.one_shot = true
	casing.amount = 1
	casing.lifetime = 0.38
	casing.direction = Vector2(-fire_dir.x * 0.6, -1.0).normalized()
	casing.spread = 20.0
	casing.gravity = Vector2(0, 420)
	casing.initial_velocity_min = 65.0
	casing.initial_velocity_max = 95.0
	casing.scale_amount_min = 2.0
	casing.scale_amount_max = 3.0
	casing.color = Color(0.95, 0.78, 0.28, 1.0)
	world_root.add_child(casing)
	casing.finished.connect(casing.queue_free)

func _find_cover_component(parent: Node) -> Node:
	if not parent:
		return null
	for child in parent.get_children():
		if child.has_method("start_peek") and "is_crouching" in child:
			return child
	return null

func _to_quadrant(dir: Vector2) -> Vector2:
	if absf(dir.x) > absf(dir.y):
		return Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if dir.y >= 0.0 else Vector2.UP
