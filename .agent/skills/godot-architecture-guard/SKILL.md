---
name: godot-architecture-guard
description: Enforces architectural discipline, folder conventions, single-responsibility principle, the 300-line script limit, and EventBus decoupled patterns in Godot 4 projects.
---

# Godot 4 Architecture Guard & Codebase Standards

This skill defines the architectural law, directory organization, and script hygiene standards for our Godot 4 codebase. All agent actions, new features, and refactorings must adhere to these directives.

---

## 1. Directory Structure

All files in the project must be placed according to this predictable layout:

```text
res://
├── core/                  # Centralized Autoloads (Singletons)
│   ├── event_bus.gd       # Decoupled global signal dispatcher
│   ├── game_state.gd      # Global session data & story flags
│   ├── save_manager.gd    # File I/O, settings, JSON/Config serialization
│   └── fullscreen_manager.gd # Window / display mode management
├── screens/               # Full-screen pages & UI flows
│   ├── main_menu/         # Main menu scene and controller
│   ├── opening/           # Opening cinematic video/sequence
│   └── teaser/            # Teaser / cutscene sequence
├── levels/                # Playable game environments
│   └── test_deck/         # Test stage / ship deck level
├── entities/              # Self-contained game actors
│   ├── player/            # Player scene (Tariq), frames, controller
│   └── npc/               # Base NPC, archetypes, and specific characters
├── components/            # Reusable sub-nodes & modular behaviors
│   ├── interaction/       # InteractionArea, Interactor, PromptTrigger
│   ├── combat/            # Hitbox, Hurtbox, CombatController
│   └── cargo/             # Pushable, GrabController
├── ui/                    # Reusable HUD overlays & widgets
│   ├── dialogue/          # DialogueLayer, DialogueBox
│   └── hud/               # HealthBar, InventoryBar, StatusDisplay
└── assets/                # Raw sprites, audio, textures, shaders, themes
    ├── audio/             # Sound effects, ambient tracks, music
    ├── sprites/           # Character & prop sprite sheets
    ├── textures/          # Tilesets, environment textures, water frames
    ├── shaders/           # Godot shaders (.gdshader)
    └── themes/            # UI themes and resource definitions
```

---

## 2. The 300-Line Script Limit

- **Hard Ceiling:** No GDScript file should exceed **300 lines of code**.
- **Extraction Threshold:** Once a script approaches 250 lines, refactor cohesive responsibilities out into reusable components, state machine delegates, or helper resources.
- **No Monolithic Controllers:** A controller should orchestrate; it must never implement all physics, animations, inventory, dialog handling, and collision logic in a single file.

---

## 3. Single-Responsibility Principle (SRP)

- Each script and scene must have **one primary responsibility**.
- **Call Down, Signal Up:**
  - Parents call methods on their direct children.
  - Children emit signals to notify parents of events.
  - Never use brittle upward node traversing like `get_parent().get_parent().get_node(...)`.
- **Decoupled Cross-System Communication:**
  - Use `EventBus` (`core/event_bus.gd`) for events spanning multiple systems (e.g., player health changes, dialogue triggers, save/load requests, screen switches).

---

## 4. Core Singletons (Autoloads)

Singletons must remain lightweight, strongly typed, and focused:

1. **`EventBus` (`res://core/event_bus.gd`):**
   - Central signal hub. Defines strongly typed signals for gameplay, UI, dialogue, and audio events.
2. **`GameState` (`res://core/game_state.gd`):**
   - Tracks live gameplay session state (current room/level, quest flags, player stats, runtime inventory).
3. **`SaveManager` (`res://core/save_manager.gd`):**
   - Handles disk persistence (user settings, keybindings, save slots).
   - Manages versioned JSON / `ConfigFile` serialization and file safety.

---

## 5. Visual Fidelity & 2D Retro Standards

- **Texture Filtering:** Default to **Nearest Neighbor** (`Filter: Nearest` / `0`) on all 2D pixel art sprites and textures.
- **Y-Sorting:** Enable `y_sort_enabled = true` on entities and environment layers to preserve natural depth.
- **Pixel Snapping:** Round rendering coordinates or use integer coordinates for camera and sprites to prevent subpixel jitter.
- **Lighting:** Use 2D PointLight2D with soft energy falloffs and shadow casting on designated obstacle layers.

