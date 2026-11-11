extends Node
## Centralized Save and Settings Manager.
## Handles persistent user preferences and game state serialization to disk.

const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "preferences"

var master_volume: int = 80
var music_volume: int = 100
var sfx_volume: int = 80
var ui_clicks_enabled: bool = true
var is_fullscreen: bool = false

var bus_master: int = -1
var bus_music: int = -1
var bus_sfx: int = -1

func _ready() -> void:
	_init_audio_buses()
	load_settings()

func _init_audio_buses() -> void:
	bus_master = AudioServer.get_bus_index("Master")
	bus_music = AudioServer.get_bus_index("Music") if AudioServer.get_bus_index("Music") != -1 else bus_master
	bus_sfx = AudioServer.get_bus_index("SFX") if AudioServer.get_bus_index("SFX") != -1 else bus_master

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE_PATH)
	if err == OK:
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
		get_node("/root/EventBus").settings_changed.emit()

func apply_all_settings() -> void:
	apply_audio_bus_volume(bus_master, master_volume)
	apply_audio_bus_volume(bus_music, music_volume)
	apply_audio_bus_volume(bus_sfx, sfx_volume)
	apply_display_mode()

func apply_audio_bus_volume(bus_idx: int, vol_percent: int) -> void:
	if bus_idx < 0:
		return
	if vol_percent <= 0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		var db_val: float = linear_to_db(float(vol_percent) / 100.0)
		AudioServer.set_bus_volume_db(bus_idx, db_val)

func apply_display_mode() -> void:
	var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

