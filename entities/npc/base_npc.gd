class_name BaseNPC
extends "res://entities/base_character.gd"
## BaseNPC — Reusable NPC controller extending BaseCharacter.
## Holds dialogue lines, character portraits, and interaction triggers.

@export var character_name: String = "CREW MEMBER"
@export var portrait: Texture2D
@export_multiline var dialogue_lines: Array[String] = [
	"Keep your head down, Tariq.",
	"The patrol rotates every twenty minutes.",
	"Get to the communications deck before sunrise."
]
@export var face_player_on_interact: bool = true

@onready var interactable_area: Area2D = $InteractableArea if has_node("InteractableArea") else null
@onready var prompt_bubble: Control = $PromptBubble if has_node("PromptBubble") else null

func _ready() -> void:
	super._ready()
	play_locomotion(false)
	set_prompt_visible(false)

func set_prompt_visible(is_vis: bool) -> void:
	if prompt_bubble:
		prompt_bubble.visible = is_vis

func interact(interactor: Node2D = null) -> void:
	set_prompt_visible(false)

	if face_player_on_interact and interactor:
		var dir_to_player := interactor.global_position - global_position
		last_facing_dir = _to_cardinal(dir_to_player)
		play_locomotion(false)

	var dl := get_node_or_null("/root/DialogueLayer")
	if dl and dl.has_method("play_dialogue"):
		dl.play_dialogue(character_name, portrait, dialogue_lines.duplicate())
		return

	push_warning("[BaseNPC] DialogueLayer autoload not found for " + character_name)

