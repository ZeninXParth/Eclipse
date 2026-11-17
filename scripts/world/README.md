# World & Level Architecture (Milestone 3)

## Purpose
Manages room boundaries, camera viewport constraints, hazard volumes, spawn gates, interactive bench checkpoints, and seamless room transitions. Follows the proven *Hollow Knight* scene-linking architecture.

## Core Components
- **`RoomBase` (`res://scripts/world/room_base.gd`)**:
  - Base class for all game rooms in `ECLIPSE`.
  - Configures camera limits (`limit_left`, `limit_right`, `limit_top`, `limit_bottom`).
  - Scans and maintains a registry of room gates (`TransitionPoint`, `Marker2D`, `BenchCheckpoint`).
  - Controls dynamic enemy respawning: captures snapshots of all initial room enemies and restores them upon bench rest.
  - Monitors pit respawn thresholds (`respawn_y_threshold`).
- **`TransitionPoint` (`res://scripts/world/transition_point.gd`)**:
  - `Area2D` spatial gateway on Layer 1 (World), detecting Layer 2 (Player) and Layer 5 (PlayerHurtbox).
  - Exports `gate_id`, `target_room_path`, `target_gate_id`, and `travel_direction`.
  - Emits `transition_triggered` and instructs `GameManager` to orchestrate room transition.
- **`BenchCheckpoint` (`res://scripts/world/bench_checkpoint.gd`)**:
  - Interactive gothic iron bench and archival post lamp on Layer 9 (Interactables = 256).
  - Resting restores full health masks (5/5), refills Soul/Aether (99/99), updates `PlayerData` respawn anchors, serializes save data to `user://save_slot_1.res`, and respawns room enemies.
- **`ArenaGate` (`res://scripts/world/arena_gate.gd`)**:
  - `StaticBody2D` portcullis confinement barrier on Layer 1 (World).
  - Drops and locks automatically upon entering boss combat encounters, sealing arena entrances and exits.
  - Automatically unlocks and retracts permanently upon boss defeat.
- **`AncientChamber` (`res://scripts/world/ancient_chamber.gd`)**:
  - Dedicated boss encounter arena controller inheriting from `RoomBase`.
  - Coordinates encounter triggers, confinement gates (`ArenaGate_West` & `ArenaGate_East`), boss health HUD, and `PlayerData` defeat persistence.
- **`AbilityPickup` (`res://scripts/world/ability_pickup.gd`)**:
  - Reusable altar interactable on Layer 9 (Interactables = 256) supporting `ABILITY`, `MASK_SHARD`, `CURRENCY`, and `RELIC` rewards.
  - Automatically records unique `pickup_id` in `PlayerData.story_flags` and despawns permanently on subsequent room visits.
- **`CelestialSanctuary` (`res://scripts/world/celestial_sanctuary.gd`)**:
  - Gothic sanctuary controller past the Ancient Chamber managing `Bench_Sanctuary`, the Double Jump altar, and ability-gated secret balcony.
- **Hand-Crafted Connected Level Scenes (`res://scenes/levels/`)**:
  - `forgotten_entrance.tscn`: Starting sanctuary featuring `Bench_Entrance`, stone arches, platforming corridors, and `Gate_East` leading to the Sunken Archive.
  - `sunken_archive.tscn`: Atmospheric subterranean archival ruin with vertical drop shaft, `WalkerEnemy`, `FlyerEnemy`, hazard spike pit, `Gate_West` returning to Entrance, and `Gate_East` leading to the Ancient Chamber.
  - `ancient_chamber.tscn`: Dedicated boss encounter arena with 1000px open floor runway, two 64px elevated stone platforms, confinement portcullises, `ArchiveWarden` first boss, two-way transition gateway `Gate_West` (`Chamber_West`) returning to Sunken Archive, and `Gate_East` (`Chamber_East`) connecting to the Celestial Sanctuary.
  - `celestial_sanctuary.tscn`: Serene cathedral oasis housing `Bench_Sanctuary`, the `Wings of the Lunar Eclipse` Double Jump altar, and an 180px elevated gallery sheltering a secret `Fragment of the Ancient Mask` collectible.
  - `test_room.tscn`: Movement & mechanics calibration proving ground (extends `RoomBase`).
  - `combat_room.tscn`: Combat encounter proving ground with training dummy and mobile enemy terraces (extends `RoomBase`).

## Room Transition Flow
1. Player enters a `TransitionPoint` Area2D.
2. `TransitionPoint` requests transition via `GameManager.change_room(target_path, target_gate, travel_dir)`.
3. `GameManager` locks player inputs and initiates screen fade-to-black.
4. Old room unloads and target room scene instantiates.
5. Player is anchored at the target gate marker with preserved direction and entry velocity.
6. Camera boundaries snap cleanly to the new room geometry without frame tearing.
7. Screen fades in and player inputs are restored.
