# Core Systems Architecture (Milestone 3)

## Purpose
Provides global persistence, save data ledger serialization, and scene streaming orchestration for `ECLIPSE`.

## Core Components
- **`PlayerData` (`res://scripts/core/player_data.gd`)**:
  - Flat serializable save data ledger resource.
  - Tracks player vitals (`max_health`, `current_health`, `soul`, `max_soul`).
  - Records world exploration progress (`unlocked_abilities`, `visited_rooms`, `story_flags`).
  - Maintains respawn location anchors (`respawn_room_path`, `respawn_gate_id`, `last_bench_id`).
  - Provides binary save/load methods (`save_to_file("user://save_slot_1.res")`, `load_from_file(...)`) and dictionary serialization roundtrips (`to_dict()`, `from_dict()`).
- **`GameManager` (`res://scripts/core/game_manager.gd`)**:
  - Global singleton / autoload orchestrator registered in `project.godot`.
  - Coordinates seamless scene streaming and room transitions:
    1. Locks player locomotion and combat inputs (`lock_player`).
    2. Executes smooth screen fade-to-black via fullscreen canvas overlay.
    3. Unloads current room and instantiates the target room.
    4. Anchors the player at the target gate marker with preserved direction and entry velocity.
    5. Snaps camera boundaries to prevent frame tearing.
    6. Fades in and restores player inputs (`unlock_player`).
  - Manages game save/load cycles and bench respawns (`respawn_at_last_bench`).
