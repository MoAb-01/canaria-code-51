class_name AimIndicator
extends Node2D
## Crisp 16-Bit On-Screen Aiming Sightline, Directional Chevron & Reticle.
## Visible when the linked WeaponComponent is drawn in Combat Mode.

@export var weapon_path: NodePath
@export var sightline_color: Color = Color(1.0, 0.90, 0.45, 0.55)
@export var reticle_color: Color = Color(1.0, 0.95, 0.72, 0.95)
@export var max_sightline_length: float = 160.0

var _weapon: Node2D = null

func _ready() -> void:
	z_index = 40
	if not weapon_path.is_empty():
		_weapon = get_node_or_null(weapon_path) as Node2D

func _process(_delta: float) -> void:
	var active := _weapon != null and bool(_weapon.get("is_drawn"))
	visible = active
	if active:
		queue_redraw()

func _draw() -> void:
	if not _weapon or not _weapon.has_method("get_muzzle_world_position"):
		return
	var muzzle_local := to_local(_weapon.get_muzzle_world_position())
	var mouse_local := get_local_mouse_position()
	var diff := mouse_local - muzzle_local
	var dist := diff.length()
	if dist < 4.0:
		return

	var dir := diff / dist
	var line_len := minf(dist - 10.0, max_sightline_length)
	# Dotted 16-bit pixel sightline
	var step := 14.0
	var pos := 10.0
	while pos < line_len:
		var p1 := muzzle_local + dir * pos
		var p2 := muzzle_local + dir * minf(pos + 5.0, line_len)
		draw_line(p1.round(), p2.round(), sightline_color, 2.0)
		pos += step

	# Directional chevron arrow near barrel
	var arrow_tip := (muzzle_local + dir * minf(36.0, dist * 0.5)).round()
	var perp := dir.orthogonal()
	draw_line(arrow_tip, (arrow_tip - dir * 6.0 + perp * 4.0).round(), reticle_color, 2.0)
	draw_line(arrow_tip, (arrow_tip - dir * 6.0 - perp * 4.0).round(), reticle_color, 2.0)

	# 16-bit Crosshair Reticle at mouse cursor
	var c := mouse_local.round()
	var outline := Color(0.05, 0.06, 0.08, 0.9)
	for tick in [[Vector2(-8, 0), Vector2(-3, 0)], [Vector2(3, 0), Vector2(8, 0)], [Vector2(0, -8), Vector2(0, -3)], [Vector2(0, 3), Vector2(0, 8)]]:
		draw_line(c + tick[0], c + tick[1], outline, 4.0)
		draw_line(c + tick[0], c + tick[1], reticle_color, 2.0)
