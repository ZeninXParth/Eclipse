# Camera System

## Purpose
The Camera system delivers smooth, bounded 2D viewport framing with visceral screen shake and non-linear trauma decay. It follows standard game-feel trauma architecture (`trauma^2` curve) to produce punchy melee impacts, damage jolts, and wall-jump rumbles without jarring jitter.

## Core Components
- **`CameraController` (`res://scripts/camera/camera_controller.gd`)**: `Camera2D` extension managing positional smoothing, dynamic trauma decay, rotational camera roll, random displacement offsets, and duration truncation safeguards.

## Public API (`CameraController`)

### Properties
- `trauma_decay: float = 1.0` — Rate per second at which accumulated trauma decays to 0.
- `max_offset: Vector2 = Vector2(16.0, 12.0)` — Maximum horizontal and vertical pixel displacement at 1.0 trauma.
- `max_roll: float = 0.05` — Maximum camera roll rotation in radians at 1.0 trauma.

### Methods
- `apply_shake(intensity: float, duration: float)` — Adds trauma and primes shake timer. Shorter subsequent shakes never truncate an existing longer shake duration.
- `_on_screen_shake_requested(intensity: float, duration: float)` — Signal handler automatically connected to `player.screen_shake_requested` if camera is a child of the player.

## How to Extend
1. **Perlin / Simplex Noise Shake**:
   - Replace `randf_range()` in `_process()` with a `FastNoiseLite` sample using `Time.get_ticks_msec() * frequency` for smoother cinematic rumbling.
2. **Room Boundary Snapping**:
   - Set `limit_left`, `limit_top`, `limit_right`, `limit_bottom` properties when transitioning between hand-crafted room volumes.
