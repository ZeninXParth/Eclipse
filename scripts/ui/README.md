# UI & Diagnostic Telemetry System

## Purpose
Provides developer overlays and HUD diagnostic telemetry for tuning physics constants, monitoring state machine transitions, validating input forgiveness windows (coyote time, jump buffering, attack buffering, wall coyote, dash cooldowns), and inspecting combat stats in real-time.

## Core Components
- **`DebugHUD` (`res://scripts/ui/debug_hud.gd`)**: `CanvasLayer` overlay displaying live velocity, grounded/wall-contact states, coyote time remaining, jump buffer status, dash cooldown, air dashes left, health pips, and control mappings. Can be toggled on/off at runtime via `F1` or `H`.
- **`BossHealthBar` (`res://scripts/ui/boss_health_bar.gd`)**: Dedicated cinematic boss encounter health bar anchored at bottom center of the viewport (Layer 25). Displays boss title ("ARCHIVE WARDEN — Ancient Sentry"), primary crimson health fill, trailing amber damage lag fill, and smooth alpha fade transitions (`show_bar()`, `fade_out()`, `update_health()`).

## Public API (`DebugHUD`)

### Properties
- `player: CharacterBody2D` — Target player node whose state and physics properties are polled.

### Methods
- `_build_ui()` — Dynamically constructs HUD panels and labels with dark slate styling.

## Public API (`BossHealthBar`)

### Properties
- `boss_title: String` — Formatted title displayed above the health bar.
- `max_health: int` — Maximum HP capacity.
- `current_health: int` — Current remaining HP.
- `bar_width: float` — Total pixel width of the health bar container (default 560px).

### Methods
- `initialize_bar(title, max_hp, current_hp)` — Configures title and fills.
- `show_bar(animate: bool)` — Fades in and displays HUD.
- `hide_bar(instant: bool)` — Conceals health bar immediately.
- `fade_out()` — Smoothly fades out HUD upon boss defeat.
- `update_health(current, max)` — Smoothly steps health and damage lag bars.

## How to Extend
1. **Adding Metrics (e.g. Soul Meter, Currency)**:
   - Add new fields to the telemetry string in `_process()`.
2. **Production Game HUD**:
   - Create a dedicated player HUD scene displaying heart masks, soul vessels, and geo counters using texture rects and animated shaders, leaving `DebugHUD` available for debug builds.
