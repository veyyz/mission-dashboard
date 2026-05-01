# Lunar Colony — Autonomous Run Progress Log

## Pre-Phase 2: Setup
- Status: in_progress
- Started: 2026-05-01
- Godot binary: `Godot_v4.6.2/Godot_v4.6.2-stable_win64_console.exe` (confirmed `4.6.2.stable`)
- Phase 1 reviewed: skeleton verified — 6 autoloads stub, Main.tscn boot, InputMap programmatic
- Tracking files created: `progress.md`, `godot/art_queue.json`, `godot/docs/pixellab_godot.md`, `godot/tests/`, `godot/logs/`
- Pixellab MCP docs ingested: `overview`, `godot/wang-tilesets`, `godot/isometric-tiles`
- Plan:
  - Queue Tier-1 art batch (6 chars, 10 buildings, 1 wang tileset, 7 map objects, 6 walking animations)
  - Save UUIDs to art_queue.json
  - Begin Phase 2 immediately while art generates in background
- Tier-1 batch result: **11/24 queued, 13 deferred** (Pixellab account caps concurrent jobs at 8)
  - Queued: 6 characters (alex, maya, zane, rin, medic, commander) + 5 buildings (landing_module, solar_array, rtg, habitat_module, electrolyzer)
  - Deferred to per-phase retry: 5 buildings, 1 wang tileset, 7 map objects, 6 walking animations
  - Strategy: each phase's art swap-in pass will both download completed jobs and re-queue any items whose retry slot is now free
- Status: completed (with deferrals tracked in `art_queue.json._pending_retry`)

## Phase 2: Ground scene + crew movement
- Status: completed
- Implemented:
  - `scenes/world/Ground.tscn` (Node2D root, TileMapLayer, YSort with y_sort_enabled, CrewMember + Sprite2D + CollisionShape2D + Camera2D, placeholder Rock for Y-sort verification)
  - `scripts/world/ground.gd` — runtime placeholder regolith tileset (32px), paints a 25×25 patch (625 cells)
  - `scripts/crew/crew_member.gd` (`class_name CrewMember`) — WASD movement at 140 px/s via `Input.is_action_pressed`, builds a 20×28 astronaut placeholder texture
  - `scripts/world/placeholder_rock.gd` — generates a 40×28 oblong rock with outline; allows visual Y-sort check
  - `tests/phase_2_test.gd` — SceneTree script; loads Ground.tscn, verifies all node-shape requirements, presses `move_up` for 0.5 sim seconds, asserts `position.y` decreased
  - `project.godot` main_scene swapped from `Main.tscn` → `Ground.tscn`
- Build: clean (`logs/phase_2_build.log`); all 6 autoloads `Ready.`, ground prints "Tiles painted: 625"
- Test: **PASS** (`logs/phase_2_test.log`)
- Bug fixed in-loop: GDScript strict-typing rejected `var dx := abs(x-20) / 18.0` (mixed int/float inference); explicitly typed as `float`
- Deferred to later phases:
  - Real Wang regolith tileset → Phase 3+ (asset queued or pending re-queue)
  - Real character sprites → Phase 4 art swap-in
  - Tilemap variations / decals layer → Phase 8
  - Navigation map / pathfinding → Phase 4
- Files added/changed: 6 new (4 scripts/scenes + 1 test + this log line), 1 modified (project.godot)


