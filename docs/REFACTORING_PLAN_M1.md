# Milestone 1: Player Foundation Refactoring Plan & Architecture

## 1. Objectives & Design Pillars
- **Tight, responsive controls**: Zero input latency, deterministic physics integration, variable jump height, coyote time, jump buffering, wall slide, wall jump, and horizontal dash.
- **Data-driven tuning**: All movement, combat, forgiveness, and reaction constants decoupled into a standalone `PlayerConfig` resource.
- **State machine architecture**: Player locomotion and air mobility structured into explicit, decoupled states with clean transitions and queryable metadata.
- **Juice & game feel**: Integrated hit-stop, quadratic trauma screen shake, damage flash, directional damage knockback, and stationary world-anchored after-image dash ghosts.
- **Zero regressions**: Maintain 100% pass rate on all automated regression tests across physics, combat, and movement suites.

## 2. File & Folder Structure

```text
res://
├── resources/
│   └── player/
│       └── default_player_config.tres       <-- Tunable movement/combat resource
├── scripts/
│   ├── player/
│   │   ├── README.md                        <-- System API and architecture documentation
│   │   ├── player_config.gd                 <-- Resource definition with exports
│   │   ├── player_controller.gd             <-- Refactored state machine controller
│   │   └── player_visuals.gd                <-- Dash ghosts, wall dust, slash FX, damage flash
│   ├── combat/
│   │   ├── README.md                        <-- Combat API and extension guide
│   │   ├── hitbox.gd / hurtbox.gd           <-- Collision & targeting volumes
│   │   ├── health_component.gd              <-- Health & i-frame management
│   │   ├── hit_data.gd                      <-- Damage & knockback transfer payload
│   │   └── hazard_zone.gd                   <-- Environmental hazard resolution
│   ├── camera/
│   │   ├── README.md                        <-- Camera & trauma shake guide
│   │   └── camera_controller.gd             <-- Camera shake & bounds management
│   ├── enemies/
│   │   ├── README.md                        <-- Enemy lifecycle documentation
│   │   └── training_dummy.gd                <-- Practice target with damage flash
│   ├── ui/
│   │   ├── README.md                        <-- UI telemetry guide
│   │   └── debug_hud.gd                     <-- Extended telemetry for M1 features
│   └── world/
│       ├── README.md                        <-- Room structure documentation
│       └── test_room.gd                     <-- Test chamber logic with wall bounds
├── scenes/
│   ├── player/
│   │   └── player.tscn                      <-- Config resource binding & camera hook
│   ├── enemies/
│   │   └── training_dummy.tscn              <-- Visual practice dummy
│   └── levels/
│       └── test_room.tscn                   <-- Enhanced with wall slide towers & dash gap
├── tests/
│   ├── test_player_physics.gd               <-- Core physics regression suite (63 assertions)
│   ├── test_combat_system.gd                <-- Core combat regression suite (113 assertions)
│   └── test_movement_m1.gd                  <-- Advanced M1 verification suite (79 assertions)
└── TEST_CHECKLIST.md                        <-- Quality assurance & milestone verification checklist
```

## 3. Component Architecture & State Machine

### Player States (`PlayerController.State`)
1. `IDLE` (0): Grounded with negligible horizontal velocity.
2. `RUN` (1): Grounded with active horizontal input and acceleration.
3. `JUMP` (2): Airborne with negative vertical velocity (rising upward).
4. `FALL` (3): Airborne with positive vertical velocity (descending).
5. `LAND` (4): Grounded recovery window (0.08s) before returning to IDLE (canceled immediately by movement).
6. `WALL_SLIDE` (5): Airborne against a solid wall while descending; downward speed clamped to `wall_slide_speed`.
7. `WALL_JUMP` (6): Airborne launching away from wall with outward and upward impulse, with brief input-lock (0.12s) to preserve outward trajectory.
8. `DASH` (7): High-speed horizontal burst (550 px/s) over fixed duration (0.16s), suspending gravity and disabling vertical drift.

### State Transitions
```
[IDLE/RUN] ──(jump/buffer)────────► [JUMP]
[IDLE/RUN] ──(dash)───────────────► [DASH]
[IDLE/RUN] ──(fall off ledge)─────► [FALL] (coyote timer active)
[JUMP]     ──(reach apex)─────────► [FALL]
[JUMP/FALL]──(hit wall + falling)─► [WALL_SLIDE]
[JUMP/FALL]──(dash)───────────────► [DASH]
[WALL_SLIDE]─(jump)───────────────► [WALL_JUMP]
[WALL_SLIDE]─(touch ground)───────► [LAND]
[WALL_SLIDE]─(release wall)───────► [FALL] (wall coyote active)
[WALL_SLIDE]─(take damage)────────► [FALL] (knockback stun)
[WALL_JUMP] ──(reach apex)─────────► [FALL]
[DASH]     ──(pogo hit)───────────► [JUMP] (upward rebound)
[DASH]     ──(take damage)────────► [FALL] (knockback stun)
[DASH]     ──(timer expired)──────► [RUN / IDLE / FALL]
[FALL]     ──(touchdown)──────────► [LAND]
```

## 4. Expected Player-Facing Behavior
- **Wall Slide**: Touching a vertical wall while falling automatically reduces downward slide speed to 120 px/s, giving the player time to plan wall jumps.
- **Wall Jump**: Tapping jump while sliding or within 0.12s of leaving the wall propels the player outward (300 px/s) and upward (-480 px/s), automatically orienting the player away from the wall.
- **Dash**: Pressing dash (`C` or gamepad shoulder/face button) triggers a rapid 550 px/s thrust forward. Refreshes upon landing or wall-sliding. Releasing direction stops in IDLE without drift.
- **Hit-Stop & Screen Shake**: Melee strikes and pogo bounces produce an immediate 0.06s hit-stop frame freeze and proportional camera shake, delivering weighty impact.
- **Damage Flash & Stun**: Taking damage causes a luminous white flash for 0.14s on the player silhouette, applies directional knockback, and locks out dash/jump for 0.15s.

## 5. Edge Cases & Safeguards
- **Sub-frame Wall Jump Inputs**: Wall coyote time preserves wall-jump capability if the player slides off a ledge before pressing jump.
- **Wall Jump Stickiness**: An input lock (0.12s) prevents the player from immediately re-attaching to the same wall when holding the directional stick toward the wall during a jump.
- **Dash into Walls**: Moving into solid geometry halts horizontal position without breaking state or passing through geometry.
- **Air Dash Reset Prevention**: Airborne dash cannot be spammed infinitely without touching the ground or a wall.
- **Pogo during Dash**: Rebounding off an enemy or hazard while dashing immediately cancels dash gravity suspension, applying full upward bounce velocity (-460 px/s).
- **Hurt during Dash**: Taking damage while dashing cancels dash and preserves knockback trajectory.
- **Knockback Stun Lockout**: Movement, dash, and jump inputs are locked out during the 0.15s knockback stun window.
- **Non-Truncating Shake**: Short shake triggers do not truncate the remaining duration of longer running screen shakes.
