extends Node
## Centralized Decoupled Event Dispatcher for Canaria Code 51.
## Implements the EventBus pattern so entities, UI, audio, and screens
## can communicate without direct, tightly-coupled node dependencies.

# Player & Locomotion Signals
signal player_state_changed(old_state: int, new_state: int)
signal player_jumped()
signal player_landed()
signal flashlight_toggled(is_on: bool)

# Cargo & Physics Signals
signal cargo_grabbed(cargo: Node2D)
signal cargo_released(cargo: Node2D)

# Dialogue & Interaction Signals
signal interactable_focused(interactable: Node)
signal interactable_unfocused(interactable: Node)
signal dialogue_requested(speaker_name: String, lines: Array[String], portrait: Texture2D)
signal dialogue_started(speaker_name: String, lines: Array[String])
signal dialogue_line_advanced(line_index: int, total_lines: int)
signal dialogue_finished()

# Pause & Cutscene Signals
signal game_paused(is_paused: bool, is_cutscene: bool)
signal cutscene_state_changed(is_active: bool)

# Flow & Settings Signals
signal screen_change_requested(target_scene_path: String)
signal settings_changed(setting_key: String, value: Variant)
signal fullscreen_toggled(is_fullscreen: bool)

