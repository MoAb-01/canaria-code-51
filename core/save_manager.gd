extends Node
## Centralized Save and Settings Manager.
## Handles persistent user preferences and multi-slot JSON game state serialization.

const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "preferences"
const SAVE_SCHEMA_VERSION: int = 1
const SAVE_DIR: String = "user://saves/"

var master_volume: int = 80
var music_volume: int = 100
var sfx_volume: int = 80
var ui_clicks_enabled: bool = true
var is_fullscreen: bool = false

var bus_master: int = -1
var bus_music: int = -1
var bus_sfx: int = -1

var has_pending_spawn: bool = false
var pending_spawn_point: Vector2 = Vector2.ZERO
var pending_player_data: Dictionary = {}
var pending_entities_data: Dictionary = {}

func _ready() -> void:
	_init_audio_buses()
	load_settings()
	_ensure_save_dir()

# ------------------------------------------------------------------------------
# 1. SETTINGS & PREFERENCES PIPELINE (user://settings.cfg)
# ------------------------------------------------------------------------------

func _init_audio_buses() -> void:
	bus_master = AudioServer.get_bus_index("Master")
	bus_music = AudioServer.get_bus_index("Music") if AudioServer.get_bus_index("Music") != -1 else bus_master
	bus_sfx = AudioServer.get_bus_index("SFX") if AudioServer.get_bus_index("SFX") != -1 else bus_master

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE_PATH) == OK:
		master_volume = config.get_value(SETTINGS_SECTION, "master_vol", 80)
		music_volume = config.get_value(SETTINGS_SECTION, "music_vol", 100)
		sfx_volume = config.get_value(SETTINGS_SECTION, "sfx_vol", 80)
		ui_clicks_enabled = config.get_value(SETTINGS_SECTION, "ui_clicks", true)
		is_fullscreen = config.get_value(SETTINGS_SECTION, "fullscreen", false)
	else:
		save_settings()
	apply_all_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "master_vol", master_volume)
	config.set_value(SETTINGS_SECTION, "music_vol", music_volume)
	config.set_value(SETTINGS_SECTION, "sfx_vol", sfx_volume)
	config.set_value(SETTINGS_SECTION, "ui_clicks", ui_clicks_enabled)
	config.set_value(SETTINGS_SECTION, "fullscreen", is_fullscreen)
	config.save(SETTINGS_FILE_PATH)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").settings_changed.emit("", null)

func set_setting(key: String, value: Variant) -> void:
	match key:
		"master_vol": master_volume = clampi(int(value), 0, 100)
		"music_vol": music_volume = clampi(int(value), 0, 100)
		"sfx_vol": sfx_volume = clampi(int(value), 0, 100)
		"ui_clicks": ui_clicks_enabled = bool(value)
		"fullscreen":
			is_fullscreen = bool(value)
			var fs = get_node_or_null("/root/FullscreenManager")
			if fs: fs.set_fullscreen(is_fullscreen)
	apply_all_settings()
	save_settings()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").settings_changed.emit(key, value)

func apply_all_settings() -> void:
	apply_audio_bus_volume(bus_master, master_volume)
	apply_audio_bus_volume(bus_music, music_volume)
	apply_audio_bus_volume(bus_sfx, sfx_volume)
	apply_display_mode()

func apply_audio_bus_volume(bus_idx: int, vol_percent: int) -> void:
	if bus_idx < 0: return
	AudioServer.set_bus_mute(bus_idx, vol_percent <= 0)
	if vol_percent > 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(float(vol_percent) / 100.0))

func apply_display_mode() -> void:
	var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

# ------------------------------------------------------------------------------
# 2. MULTI-SLOT GAME SAVE / LOAD PIPELINE (user://saves/slot_%d.json)
# ------------------------------------------------------------------------------

func get_save_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot

func save_game(slot: int, spawn_pos: Vector2, location_label: String = "") -> bool:
	_ensure_save_dir()
	var cs := get_tree().current_scene
	var level_path: String = cs.scene_file_path if cs else "res://levels/test_deck/test_deck.tscn"
	if level_path.is_empty(): level_path = "res://levels/test_deck/test_deck.tscn"

	var player_data := {}
	var player_node := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player_node) and player_node.has_method("save_state"):
		player_data = player_node.save_state()
	else:
		var gs_temp = get_node_or_null("/root/GameState")
		player_data = {"has_flashlight": bool(gs_temp.has_flashlight) if gs_temp else true, "flashlight_on": false}

	var entities_data := {}
	for entity in get_tree().get_nodes_in_group("persist"):
		if entity != player_node and entity.has_method("save_state"):
			entities_data[String(entity.get_path())] = entity.save_state()

	var gs = get_node_or_null("/root/GameState")
	var gs_dict: Dictionary = gs.to_dict() if (gs and gs.has_method("to_dict")) else {}

	var save_data := {
		"version": SAVE_SCHEMA_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"location_name": location_label if not location_label.is_empty() else "Crew Quarters - Deck B",
		"level_path": level_path,
		"spawn_point": {"x": spawn_pos.x, "y": spawn_pos.y},
		"player": player_data,
		"game_state": gs_dict,
		"entities": entities_data
	}

	var final_path := get_save_path(slot)
	var temp_path := final_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		var eb = get_node_or_null("/root/EventBus")
		if eb: eb.game_saved.emit(slot, false)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	var rename_err := DirAccess.rename_absolute(temp_path, final_path)
	var success: bool = (rename_err == OK)
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.game_saved.emit(slot, success)
	return success

func load_game(slot: int) -> bool:
	var data := _read_json_file(get_save_path(slot))
	if data.is_empty():
		push_warning("[SaveManager] Save slot %d does not exist or invalid" % slot)
		return false

	var version: int = int(data.get("version", 0))
	if version <= 0 or version > SAVE_SCHEMA_VERSION:
		push_error("[SaveManager] Incompatible save schema version: %d" % version)
		return false

	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("from_dict"):
		gs.from_dict(data.get("game_state", {}))

	var sp: Dictionary = data.get("spawn_point", {})
	var spawn_pos := Vector2(float(sp.get("x", 0.0)), float(sp.get("y", 0.0)))
	has_pending_spawn = true
	pending_spawn_point = spawn_pos
	pending_player_data = data.get("player", {})
	pending_entities_data = data.get("entities", {})

	var target_level: String = str(data.get("level_path", ""))
	if target_level.is_empty(): target_level = "res://levels/test_deck/test_deck.tscn"

	if gs:
		gs.player_spawn_point = spawn_pos
		gs.current_level = target_level

	var player_node := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player_node):
		player_node.global_position = spawn_pos
		if player_node.has_method("load_state") and not pending_player_data.is_empty():
			player_node.load_state(pending_player_data)

	var cs := get_tree().current_scene
	if cs and cs.scene_file_path != target_level:
		get_tree().change_scene_to_file(target_level)

	_apply_pending_entities.call_deferred()
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.game_loaded.emit(slot)
	return true

func clear_pending_spawn() -> void:
	has_pending_spawn = false
	pending_spawn_point = Vector2.ZERO
	pending_player_data.clear()

func _apply_pending_entities() -> void:
	if pending_entities_data.is_empty(): return
	for entity in get_tree().get_nodes_in_group("persist"):
		var key := String(entity.get_path())
		if pending_entities_data.has(key) and entity.has_method("load_state"):
			entity.load_state(pending_entities_data[key])
	pending_entities_data.clear()

func get_slot_metadata(slot: int) -> Dictionary:
	var data := _read_json_file(get_save_path(slot))
	if data.is_empty():
		return {"exists": false, "slot": slot}
	return {
		"exists": true,
		"slot": slot,
		"version": int(data.get("version", 0)),
		"timestamp": str(data.get("timestamp", "")),
		"location_name": str(data.get("location_name", "Unknown Area")),
		"level_path": str(data.get("level_path", ""))
	}

func has_any_save() -> bool:
	_ensure_save_dir()
	var dir := DirAccess.open(SAVE_DIR)
	if not dir: return false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json") and not file_name.ends_with(".tmp"):
			dir.list_dir_end()
			return true
		file_name = dir.get_next()
	dir.list_dir_end()
	return false

func delete_save(slot: int) -> bool:
	var path := get_save_path(slot)
	return DirAccess.remove_absolute(path) == OK if FileAccess.file_exists(path) else false

func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	return json.data if json.parse(text) == OK and json.data is Dictionary else {}

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
