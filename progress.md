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

## Phase 3: Resources + time + day/night tint
- Status: completed
- Implemented:
  - `scripts/systems/day_night_modulate.gd` — `CanvasModulate` subscribing to `EventBus.phase_changed`; tweens the canvas tint over 0.5s. Phase colors: day `(1.00, 0.98, 0.92)`, twilight `(1.00, 0.70, 0.55)`, night `(0.50, 0.60, 0.80)`
  - `scripts/ui/debug_hud.gd` + `scenes/ui/DebugHUD.tscn` — top-left CanvasLayer panel showing all 6 resources (current/max + rate), day/time, phase. Subscribes to `EventBus.resource_changed`/`phase_changed`; updates `TimeLabel` per `_process` only
  - `scenes/world/Ground.tscn` updated to instance `DayNightModulate` (CanvasModulate at root) and `DebugHUD` (CanvasLayer)
  - `tests/phase_3_test.gd` — verifies the 4 done criteria
- Build: clean (`logs/phase_3_build.log`)
- Test: **PASS** (`logs/phase_3_test.log`)
- Bug fixed in-loop: SceneTree-based test scripts cannot resolve autoload globals (`EventBus`, `ResourceManager`, `TimeManager`) at compile time. Refactored test to fetch them via `root.get_node_or_null("…")` and store as locals. (Affects future phase tests too — same pattern.)
- Art swap-in pass: no Phase-3-relevant assets ready yet — terrain wang tileset is still in the deferred-retry list. CanvasModulate placeholder colors are fine; swap-in deferred until `regolith_to_rocky` lands.
- Deferred to later phases:
  - Resource consumption/production hooks driven by buildings → Phase 5
  - Resource bar visualization with bars/icons → Phase 6
  - Pause + speed buttons in UI → Phase 6
- Files added/changed: 4 new (3 scripts/scenes + 1 test), 1 modified (Ground.tscn)

## Phase 4: Full crew (6) + selection + navigation
- Status: completed
- Implemented:
  - `scripts/crew/crew_member.gd` rewritten with `enum Role { ENGINEER, SCIENTIST, BOTANIST, GEOLOGIST, MEDIC, COMMANDER }`, role-tinted placeholder sprite, role-color glow ring, `move_to(target)` setting `NavigationAgent2D.target_position`. WASD when selected; pathfinding overrides WASD when an agent target is active.
  - `scripts/crew/crew_selection_manager.gd` — polls `Input.is_action_just_pressed("select_crew_N")` per frame (so it works with both real key events and synthetic `Input.action_press`), supports shift-multi-select, dispatches click-to-move on left-click via `_unhandled_input` + `get_global_mouse_position()`. Emits `EventBus.crew_selected` and `EventBus.log_message`.
  - `scenes/crew/CrewMember.tscn` — packed scene with SelectionRing, Sprite2D, CollisionShape2D, NavigationAgent2D, and a `Label` nameplate (Godot 4 has no `Label2D`; using a Control child of CharacterBody2D, configured via theme overrides for outline/font color).
  - `scripts/world/ground.gd` extended to spawn 6 crew from a `CREW_ROSTER` constant under `YSort/CrewContainer`, build a `NavigationRegion2D` covering ±2000px (simple rectangular nav polygon — no obstacle baking yet), and attach the Camera2D to crew #1 (Alex). Default selection: Alex.
  - `scenes/world/Ground.tscn` updated: removed inline CrewMember; CrewContainer (script: `crew_selection_manager.gd`) now lives under YSort.
  - `tests/phase_4_test.gd` — verifies all five Phase-4 done criteria.
  - `tests/phase_2_test.gd` — updated to find first `CharacterBody2D` by class instead of by literal name `"CrewMember"` (regression-compatible after the structural change).
- Build: clean (`logs/phase_4_build.log`), prints `[Ground] Phase 4 ready. Tiles=625  Crew=6`
- Test: **Phase 2 regression PASS** (`logs/phase_2_regress.log`); **Phase 4 PASS** (`logs/phase_4_test.log`)
- Bugs fixed in-loop:
  1. `Label2D` doesn't exist in Godot 4 (only `Label` (Control) and `Label3D`). Switched to `Label` and configured outline via theme overrides.
  2. `_unhandled_input` doesn't fire from `Input.action_press(...)` (no synthetic event flows through the viewport). Selection manager moved to a `_process` polling pattern so both real and test-driven inputs work.
  3. Strict-typing inferred `var agent := find_child(...)` to wrong type. Explicitly typed `var agent: NavigationAgent2D = ... as NavigationAgent2D`.
- Art swap-in pass: 6 character UUIDs from round-2 (128px chibi-anime muted) are queued; `alex` confirmed completed via `get_character` (180×180 canvas, ~108px character — this is Pixellab's ~40% padding behavior, accepted per Option A user decision). Visual swap-in deferred to Phase 6 (HUD crew portraits) or Phase 10 polish — placeholder role-tinted astronauts continue to satisfy Phase 4 done criteria.
- Deferred to later phases:
  - Real Pixellab character textures + per-direction facing animation → Phase 6/10
  - Crew status (health/oxygen/stamina) decay + UI display → Phase 6
  - Camera follows whichever crew is currently selected (currently fixed to Alex) → Phase 6 or polish
  - Pathfinding around obstacles (NavigationPolygon currently has no obstacles baked) → Phase 8 (alongside fog of war / props)
- Files added/changed: 4 new (CrewMember.tscn, crew_selection_manager.gd, phase_4_test.gd, this log entry); 4 modified (crew_member.gd, ground.gd, Ground.tscn, phase_2_test.gd)

## Phase 5: Buildings v1
- Status: completed
- Implemented:
  - **`scripts/autoload/building_database.gd`** — new 7th autoload. Loads `data/buildings.json` once at boot (9 definitions), exposes `has_definition`, `get_definition`, `list_keys`, `get_scene_path` for the 3 v1 buildings.
  - **`scripts/autoload/resource_manager.gd`** — extended to 13 tracked resources (6 core + silicon/iron/water/rare_metals/samples/helium3/titanium for the secondary economy referenced in `buildings.json`/`recipes.json`). Added `add_to_rate(name, delta)` (additive — buildings stack), `can_afford(cost)`, `deduct(cost)` (atomic — no partial). `_process` now applies `rate_per_min` to `current` per real second, scaled by `TimeManager.time_scale`. Pauses honor `GameState.is_paused`.
  - **`scripts/buildings/building.gd` (`class_name Building`)** — generic finished building. Reads its definition from `BuildingDatabase`, applies `produces`/`consumes` to ResourceManager rates on `_ready` (and unwinds on `_exit_tree` to prevent leaks). Emits `EventBus.building_completed`. Renders a key-tinted placeholder until real iso-tile art swaps in.
  - **`scripts/buildings/construction_site.gd` (`class_name ConstructionSite`)** — Node2D with progress bar. `_process` calls `tick(delta)` while an Engineer-role CrewMember is within `ENGINEER_REACH=64px`. Public `tick(seconds)` method for tests/cheats. On reaching 1.0, instantiates the building scene at the same global position and queue_frees itself.
  - **`scripts/buildings/build_placement_controller.gd` (`class_name BuildPlacementController`)** — `start_placement(key)` enters placement mode and shows a ghost preview tracking the cursor; left-click in placement mode calls `place_building(key, world_pos)` which validates affordability, atomically deducts the cost, snaps to a 32px grid, and instantiates a ConstructionSite. Right-click cancels. The public `place_building` is also the test-facing API.
  - **3 building scenes**: `scenes/buildings/SolarArray.tscn`, `HabitatModule.tscn`, `MiningDrill.tscn` — each is a `StaticBody2D` with the shared `building.gd` script and a unique `building_key` export. `scenes/buildings/ConstructionSite.tscn` houses the progress bar.
  - **Build menu UI**: `scenes/ui/BuildMenu.tscn` + `scripts/ui/build_menu.gd` — bottom-left CanvasLayer panel listing 3 v1 buildings with cost tooltips. Click → `placement_controller.start_placement(key)`.
  - **Ground.tscn** updated to instance `BuildPlacementController` under `YSort` and the `BuildMenu` CanvasLayer with `placement_controller_path = NodePath("../YSort/BuildPlacementController")`.
  - **`tests/phase_5_test.gd`** — verifies all 7 done criteria.
- Build: clean (`logs/phase_5_build.log`); BuildingDatabase loads 9 definitions, ResourceManager initializes 13 resources.
- Test: **PASS** (`logs/phase_5_test.log`)
- Bug fixed in-loop: GDScript class_name discovery in headless mode is order-sensitive — `BuildPlacementController` could not resolve `ConstructionSite` as a type annotation at parse time. Switched cross-references to typed-as-`Node2D` ducktyping; functionality unchanged.
- Art swap-in pass: 6 round-4 character UUIDs queued at size=128 / 8 dirs / detailed shading, per the user's updated `lunar_colony_character_generation.md`. Round-3 (size=64) is half-deleted (alex+maya removed via MCP) and half still in the user's Pixellab account for comparison. No buildings/terrain/objects swapped in this phase — placeholder colored rects continue to satisfy done criteria.
- Deferred to later phases:
  - Building size grid validation (cost JSON has `size: [W, H]`; ghost only places point objects today) → Phase 8 polish
  - Engineer auto-pathfind to nearest construction site (currently only ticks while passively in range) → Phase 6/8
  - Building destruction UX → Phase 9
  - Visual swap to Pixellab iso tiles for the 5 already-queued building tiles → Phase 6 art pass
- Files added/changed: 11 new (1 autoload + 3 building scripts + 4 building scenes + 1 UI script + 1 UI scene + 1 test); 3 modified (resource_manager.gd, project.godot, Ground.tscn)

## CHECK-IN at Phase 5
- **Built:** First runnable prototype is up. Crew (6 with roles + nameplates + selection + nav), resources (13 tracked, day/night cycle drives rates), buildings (3 buildable end-to-end with cost-deduct → ghost preview → engineer-ticks → completion → ResourceManager rate update). Visual fidelity is still placeholder for everything except UI panels.
- **Run:** `Godot_v4.6.2/Godot_v4.6.2-stable_win64_console.exe --path godot` (or open the editor and F5 from the Godot project at `mission-dashboard/godot/`).
- **What to verify visually:**
  - Six role-tinted astronauts with floating role-color nameplates over their heads, glow ring under Alex (selected by default).
  - Press 1–6: selection ring follows the chosen crew; debug HUD reflects selected crew via `EventBus.log_message`.
  - WASD: moves the currently-selected crew. Click anywhere on the regolith: every selected crew pathfinds to the click point.
  - Day/night: world tint slowly cycles warm-white → orange → blue-grey → back. Speed it up by setting `TimeManager.set_time_scale(60.0)` from the remote inspector.
  - Build menu (bottom-left): click "Solar Array" → ghost rect follows cursor → click on ground → materials/silicon drop in resource bar, ghost replaced by translucent crosshatched ConstructionSite with a progress bar. Move Alex (engineer) within ~64px of it; the bar advances. On full, the construction site is replaced by the placeholder solar-blue panel sprite and `power` rate ticks up by +15/min in the debug HUD.
- **Known placeholders:**
  - All sprites (crew, buildings, regolith tiles, rock decal) are runtime-generated colored rectangles — Pixellab art is queued but not yet integrated.
  - Nameplates are plain Label outlines, not the rounded panels from the screenshots (Phase 6 HUD pass).
  - Camera fixed to Alex; doesn't follow whichever crew is currently selected (Phase 6).
  - No obstacle baking — Mining Drill must be placed manually adjacent to the (not-yet-spawned) resource nodes; pathfinding goes straight-line everywhere.
  - Storage silo / RTG / electrolyzer / hydroponics / comms / research lab buildings exist in the database but are not in the build menu (Phase 8 rounds out the building set).
  - Win/lose conditions, save/load, events, fog of war — all Phase 8/9.
- **Deferred items so far** (consolidated):
  - Real Pixellab character textures + per-direction facing animation → Phase 6 / Phase 10
  - Crew status (health/oxygen/stamina) decay UI → Phase 6
  - Camera-follows-selected-crew → Phase 6
  - Pause + speed buttons in UI → Phase 6
  - Resource bar with bars/icons → Phase 6
  - Building size grid validation → Phase 8 polish
  - Engineer auto-pathfind to construction site → Phase 6/8
  - Building destruction UX → Phase 9
- **Halting per autonomous prompt — do not proceed to Phase 6 without human review.**





