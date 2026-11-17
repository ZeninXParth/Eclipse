# Boss & Encounter Architecture (Milestone 4)

## Purpose
Manages boss encounters, multi-phase automaton state machines, hazardous ground shockwaves, arena confinement gates, cinematic HUD health bars, and persistent story flags.

## Core Components
- **`ArchiveWarden` (`res://scripts/bosses/archive_warden.gd`)**:
  - Imposing occult basalt automaton sentry guarding the Ancient Chamber (`scenes/levels/ancient_chamber.tscn`).
  - Extends `EnemyBase` with 30 HP, 85% knockback resistance, and heavy contact damage.
  - **Boss Poise & Strike Integrity**: Retains active attack hitboxes during strike execution (`THRUST_CHARGE`, `SLAM_IMPACT`, `LEAP_SLAM`) and does not get stunned or interrupted by basic player melee strikes.
  - **Phase 1 (100% – 50% HP)**:
    - Menacing stalking approach tracking player position.
    - Overhead mace/blade slam with 0.50s windup telegraph, impact hitbox, 5.0 intensity camera shake, floor shockwave emission, and generous 0.85s recovery window.
    - Sweeping thrust charge (340 px/s) with 360 px/s knockback and 0.85s recovery window.
  - **Phase 2 Enrage Transition (< 50% HP / <= 15 HP)**:
    - 1.20s roar sequence with temporary invulnerability armor and 8.0 intensity camera shake.
    - Permanent celestial purple/cyan aura (`enraged_aura`) with accelerated attack cadence (~0.45s recovery).
    - Leaping Ground Pound: launches into air (-520 px/s) and slams down with 6.0 intensity camera shake, emitting dual opposing shockwaves (left and right).
  - **Defeat Sequence**:
    - Disables hitboxes and activates hurtbox invulnerability.
    - Emits `boss_defeated` and `gates_unlocked` signals.
    - Restores player resources (+33 Soul).
    - Persists `boss_warden_defeated = true` in `PlayerData` save ledger.
    - Respawn override ensures defeated warden never revives on room load or bench checkpoint respawns.
- **`GroundShockwave` (`res://scripts/bosses/ground_shockwave.gd`)**:
  - Traveling ground hazard inheriting from `HazardZone`.
  - Moves along floor at 260 px/s on Layer 8 (Hazards = 128) up to 900px or 2.5s.
  - Detects Layer 1 (World) solid barriers via space raycasting, dissipating immediately upon contacting closed arena gates or chamber walls.
  - Deals contact damage to grounded players.
  - Member of `"pogo_hazard"` group and implements `is_pogo_hazard() -> true`, supporting downward cane sword pogo slashes (-460 px/s upward rebound).
- **`ArenaGate` (`res://scripts/world/arena_gate.gd`)**:
  - Portcullis confinement barrier on Layer 1 (World).
  - Automatically drops and locks upon crossing arena trigger, sealing player inside.
  - Automatically unlocks and retracts permanently on boss defeat.
- **`BossHealthBar` (`res://scripts/ui/boss_health_bar.gd`)**:
  - Cinematic health bar HUD on Layer 25 with occult framing, title "ARCHIVE WARDEN — Ancient Sentry", dual health/lag fills, and alpha fade transitions.
  - Upon fade out completion, automatically resets `is_active` to false and emits `bar_hidden`.
- **`AncientChamber` (`res://scripts/world/ancient_chamber.gd`)**:
  - Room controller inheriting from `RoomBase`.
  - Connects two-way transition with Sunken Archive (`Archive_East` <-> `Chamber_West`).
  - Features 1000px open floor runway (>= 960px) flanked by two 64px elevated stone platforms with `one_way_collision = true` for jump-through shockwave evasion.
  - Inspects `PlayerData` on room load: if `boss_warden_defeated` is true, boss does not respawn and gates remain open.
  - Overrides `respawn_enemies()` to ensure cleared boss state cannot be undone by bench rests.
