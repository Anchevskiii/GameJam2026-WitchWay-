# AGENTS.md

## 1. Project Context for AI Assistant

Name: It's a Feature, Not a Bug: Halloween Edition
Genre: 2D Top-Down Procedural Horror Dungeon Crawler
Engine: Godot 4.3+
Language: GDScript (DO NOT USE C# or GDNative)

## 2. Core Gameplay Logic

- **Sanity Bar:** Reaching max limit causes the player to pee their pants (Game Over state). Player restarts at the beginning of the current level.
- **Glitch / CPU Overload:** Fills up dynamically. When full, turns off lights and reveals invisible traps/entities.
- **The "Bug":** Every level has an intentional game bug (e.g., wall without collision) that the player MUST exploit to find keys/items and progress.
- **Living Room:** The safe zone between levels where saving occurs.

## 3. Vibe-Coding Rules & Instructions

- **Scripting Language:** Write EVERYTHING in GDScript.
- **Typing:** Use strict, static typing for variables, arguments, and return types (e.g., `var move_speed: float = 300.0`).
- **Inspector Variables:** Prioritize `@export` annotations over hardcoded magic numbers.
- **Godot 4.3 Features:**
  - Use `TileMapLayer` (not the deprecated Godot 4.0 TileMap).
  - Use `PointLight2D`, `CanvasModulate`, and `LightOccluder2D` for shadows and darkness.
- **Code Delivery:** Whenever you output code, provide the full block, state exactly what the filename should be (matching the directory structure in README.md), and explain briefly to which Node in the Scene Tree it should be attached.
- Keep architectural complexity low, but provide complete functional code snippets suitable for beginners.
- Do not commit or push code without review from user first. Always ask after completing a feature or changing the code if you can commit and push to repo.
