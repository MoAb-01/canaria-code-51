extends Node
## Centralized AudioManager autoload.
## Caches procedural SFX at startup and plays them via EventBus.sfx_requested.

const DEFAULT_VOLUME_DB := -8.0

var _sfx_cache: Dictionary = {}
var _player: AudioStreamPlayer = null

func _ready() -> void:
	_sfx_cache["office_door_open"] = SfxGenerator.create_office_door_open()

	_player = AudioStreamPlayer.new()
	_player.name = "SfxPlayer"
	_player.volume_db = DEFAULT_VOLUME_DB
	_player.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
	add_child(_player)

	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("sfx_requested"):
		eb.sfx_requested.connect(play_sfx)

func play_sfx(sfx_name: String) -> void:
	if not _player or not _sfx_cache.has(sfx_name):
		return
	_player.stream = _sfx_cache[sfx_name]
	_player.volume_db = DEFAULT_VOLUME_DB
	_player.pitch_scale = randf_range(0.97, 1.03)
	_player.play()
