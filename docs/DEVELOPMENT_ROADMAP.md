# ECLIPSE: Echoes of the Forgotten — Development Roadmap

**Engine:** Godot 4.7.2 (GDScript)  
**Status:** In Active Development (Milestones M0, M1, M2, M3, M4 & M5 Complete)  
**Target Platform:** Windows PC (Initial)

---

## Roadmap Overview

```
[M0: Audit & Plan] ──► [M1: Movement Prototype] ──► [M2: Combat Prototype]
                                                            │
[M6: Polish & Audio] ◄── [M5: Progression Slice] ◄── [M4: World & Boss Arena]
```

---

## Milestone Breakdown & Acceptance Gates

### Milestone M0: Project Audit & Planning Framework (COMPLETED)
- [x] Audit existing filesystem and Godot installation (`Godot 4.7.2-stable`).
- [x] Document engineering principles, code conventions, and collaboration protocols.
- [x] Establish documentation suite: `GAME_DESIGN.md`, `TECHNICAL_ARCHITECTURE.md`, `DEVELOPMENT_ROADMAP.md`, `DECISIONS.md`, `ASSET_REGISTER.md`.
- [x] Configure base project settings and virtual viewport (`1280x720`, `canvas_items`, `expand`).
- [x] Configure standard input actions across keyboard and gamepad.
- [x] Set up headless test execution framework for continuous verification.

### Milestone M1: Playable 2D Movement Prototype (COMPLETED)
**Goal:** Deliver a responsive, high-feel 2D character controller in a dedicated test arena.
- [x] Physics-driven `CharacterBody2D` with typed GDScript.
- [x] Snappy horizontal movement with calibrated acceleration and ground friction.
- [x] Jump physics with peak time and variable jump height (short-hop vs. full-jump).
- [x] Coyote time window (jump permitted shortly after falling off ledges).
- [x] Jump buffering window (pre-landing jump input executed upon touching ground).
- [x] Apex hang / gravity modulation for satisfying jump arc feel.
- [x] Smooth camera follow (`Camera2D`) with drag margins and room bounds.
- [x] Interactive test room (`res://scenes/levels/test_room.tscn`) featuring flat runways, tiered platforms, variable gap jumps, and ceiling obstacles.
- [x] Diagnostic HUD displaying real-time velocity, movement state, coyote/buffer statuses, and controls.
- [x] Headless automated test suite verifying all physics behaviors (63 tests).

### Milestone M2: Melee Combat Prototype (COMPLETED)
**Goal:** Implement readable, fair melee combat loop against a responsive dummy/target.
- [x] Attack input handling with distinct startup (0.05s), active hitbox (0.07s), and recovery (0.10s) phases.
- [x] Directional attack resolution: forward slash, upward slash, and airborne downward pogo attack.
- [x] Hitbox/Hurtbox component system using designated collision layers (`layer_4="PlayerHitbox"`, `layer_5="PlayerHurtbox"`, `layer_7="EnemyHurtbox"`, `layer_8="Hazards"`).
- [x] Single-hit per swing validation via target tracking (preventing multi-hit per frame bugs).
- [x] Damage calculation, invulnerability frames (1.0s i-frames), and visual flashing feedback.
- [x] Directional knockback with hit stun attenuation (0.15s).
- [x] Downward aerial pogo bounce (-460 px/s rebound) with coyote time reset.
- [x] Responsive Training Dummy with health, knockback friction, hit flash, and automatic defeat/respawn loop.
- [x] Environmental Hazard Zone (spikes) supporting damage and pogo bounces.
- [x] Player death & respawn lifecycle restoring health and resetting state cleanly.
- [x] Headless automated combat verification test suite (91 tests passing).

### Milestone M3: World Structure & Scene Linking (COMPLETED)
**Goal:** Interconnect multi-room areas with gating and persistence.
- [x] Room transition framework (door triggers, screen fades, priority spawn coordinate offset).
- [x] Area 1: **The Forgotten Entrance** (tutorial sanctuary & bench checkpoint).
- [x] Area 2: **The Sunken Archive** (branching exploration, verticality, mobile enemies, lore props).
- [x] Save/Load persistence (`PlayerData`):
  - JSON and Resource serialization.
  - Player spawn point, health, and soul.
  - Visited rooms and story flags ledger.
  - Safe fallback for missing/corrupt save files.
- [x] Bench checkpoint mechanics: Rest restores vitals, commits save, and respawns room enemies.

### Milestone M4: The Ancient Chamber & First Boss Encounter (COMPLETED)
**Goal:** Introduce readable enemy archetypes and a multi-phase boss fight.
- [x] Enemy Archetype 1: Ground patrol & melee lunge (`WalkerEnemy` / Scavenger Husk).
- [x] Enemy Archetype 2: Aerial swooper / flying pest (`FlyerEnemy` / Gloom Bat).
- [x] Enemy Archetype 3: Armored tank charge (`ChargerEnemy` / Armored Beetle).
- [x] First Boss: "The Archive Warden / Ancient Sentry":
  - Distinct arena (`The Ancient Chamber`) with `ArenaGate` entrance/exit locks.
  - Phase 1: Telegraph ground shockwave slams and forward thrust charges.
  - Phase 2: Accelerated tempo, screen shake, invulnerable roar, and leaping ground pound with dual shockwaves.
  - Cinematic `BossHealthBar` HUD with damage lag fill and smooth alpha transitions.
  - Defeat sequence, persistent defeat state in `PlayerData`, and permanent arena gate unlocking.

### Milestone M5: Progression Systems & Traversal Slice (COMPLETED)
**Goal:** Traversal abilities, world pickups, currency economy, and ability-gated progression.
- [x] Traversal Ability 1: **Double Jump (`Wings of the Lunar Eclipse`)** with variable cutoff, pogo/wall/ground recharge, and spectral wing visuals.
- [x] Traversal Ability 2: **Athletic Mantle / Ledge Grab** with multi-ray detection, zero-velocity hang, vault pull-up, and drop cancellation.
- [x] World Pickup Entity (`AbilityPickup`): Layer 9 interactable with basalt altar, floating sigils, auto-touch collection, and persistent despawn.
- [x] Stygian Shards Currency Economy: Defeating enemies drops currency directly into player ledger; spending logic verified.
- [x] Mask Shards Health Upgrades: 4 collectible fragments forge an extra health mask (increasing max health to 6) and heal player to full.
- [x] New Connected Zone: **The Celestial Sanctuary** (`celestial_sanctuary.tscn`) featuring `Bench_Sanctuary`, Double Jump altar, two-way connection to Ancient Chamber, and an 180px elevated gallery sheltering a secret Mask Shard requiring Double Jump to scale.

### Milestone M6: Vertical-Slice Polish, Audio & Playtesting (NEXT)
**Goal:** Cohesive audio-visual presentation ready for external tester feedback.
- [ ] Sound effects (footsteps, jumps, lands, sword swoosh, impacts, ambient room tone).
- [ ] Music track transitions between sanctuary, ruins, and boss arena.
- [ ] Pause menu with rebindable controls, audio sliders, and fullscreen toggle.
- [ ] Asset license audit and compliance verification in `ASSET_REGISTER.md`.
- [ ] Zero blocking errors, leak-free memory profile, stable 60+ FPS.
