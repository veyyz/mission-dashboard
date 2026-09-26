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

## Phase 6: Full HUD per Section 8
- Status: completed
- Implemented:
  - **`scenes/ui/HUD.tscn`** — root `CanvasLayer` instancing 8 panel scenes; replaced the old DebugHUD instance in `Ground.tscn`.
  - **8 panel scenes**, each its own `.tscn` under `scenes/ui/panels/`:
    - **HUDPanelDayTime** (top-left) — MISSION DAY N + clock + phase, polls `TimeManager` per-frame, subscribes to `EventBus.phase_changed`
    - **HUDPanelResources** (top-center) — 6 resource entries (power/oxygen/food/materials/science/crew) with glyph + value + `+rate/min`, builds entries dynamically, binds to `EventBus.resource_changed`
    - **HUDPanelTutorial** (top-right, below ZoomControls) — bullet-list tip panel; F1 toggles visibility (checks both `keycode` and `physical_keycode` for headless-test compatibility)
    - **HUDPanelLog** (middle-left) — scrollable message list, subscribes to `EventBus.log_message`, color-coded by category, capped at 80 entries with auto-scroll
    - **HUDPanelCrew** (bottom-left) — auto-populates from `get_tree().get_nodes_in_group("crew")` once the world spawns crew, one toggle Button per crew_id, binds to `EventBus.crew_selected`, click-to-select emits `crew_selected`
    - **HUDPanelActions** (bottom-center) — 5 quick-action buttons (Move/Scan/Probe/Sample/Crew Menu) with key hints; click handlers stubbed to `log_message` until Phase 8 wires R/F/G/C
    - **HUDPanelMinimap** (bottom-right) — placeholder ColorRect + Power/O₂ ProgressBars; real minimap dots + fog blackout in Phase 8
    - **HUDPanelHotbar** (bottom-edge between Crew and Minimap) — 10 toggle slots, polls KEY_0..KEY_9 via `Input.is_key_pressed | is_physical_key_pressed` rising-edge detection in `_physics_process`, exposes `current_slot()`
  - **`tests/phase_6_test.gd`** — verifies HUD CanvasLayer, all 8 panel scene files exist + are instanced, resource bar updates on `add()`, crew bar press tracks `crew_selected`, hotbar slot 5 selects on KEY_5 press, F1 toggles tutorial visibility
  - `Ground.tscn` swapped DebugHUD → HUD instance; DebugHUD scene/script left in place but no longer referenced
- Build: clean (`logs/phase_6_build.log`); `[HUD] Ready. Panels: 8`
- Test: **PASS** (`logs/phase_6_test.log`); full regression on phases 2/3/4/5 also PASS
- Bugs fixed in-loop:
  1. `_input` event matching — `event.keycode` is 0 when only `physical_keycode` is set on `InputEventKey`. Tutorial check now matches either field.
  2. `Input.is_key_pressed` doesn't see physical-only synthetic events. Hotbar polls both `is_key_pressed | is_physical_key_pressed`.
- Deferred to later phases:
  - Real character portraits in crew bar (currently text labels with role-color font) → integration after round-N art lands (Phase 8 art swap-in)
  - Hotbar slot bindings (build menu, blueprints, flag/marker icons) → Phase 8
  - Action button R/F/G/C wiring → Phase 8
  - Strategic-zoom-only top-left panels (Mission Overview / Environment / Resources Detected per `fq_full_world_view.png`) + zoom-driven panel fade → Phase 7
  - Minimap world map + crew/building dots + fog overlay → Phase 8
  - Pause + speed buttons → could land in DayTimePanel as Phase 7 polish
- Files added/changed: 17 new (1 hud + 8 panel scripts + 8 panel scenes + 1 HUD.tscn + 1 test); 1 modified (Ground.tscn)

## Phase 7: Strategic zoom + landing flow
- Status: completed
- Implemented:
  - **`data/orbit_deposits.json`** — 7 strategic-grid tiles (10×10 system, A–J × 1–10) with resource deposits, terrain, hazards, recommendation. `suggested_landing_tile` = E5 (4, 4).
  - **`scripts/world/orbit_map.gd`** + **`scenes/ui/OrbitMap.tscn`** — strategic-zoom UI overlay (CanvasLayer). Loads JSON, builds A–J × 1–10 corner labels, builds clickable deposit-marker buttons (color-coded by primary deposit). Suggested landing zone marker pulses via Tween. Click a marker → tooltip panel (terrain / hazards / recommendation) lights up + Confirm Landing enables. Confirm Landing stores `GameState.selected_landing_tile`, emits `EventBus.landing_confirmed`, locks the button to `LANDED`.
  - **Smooth fade**: visible content lives under a `Root` Control child (CanvasLayer itself has no `modulate`); `EventBus.zoom_changed` Tween-fades `Root.modulate.a` between 1.0 (strategic) and 0.0 (gameplay) over 0.35s. `mouse_filter` flips in sync so clicks pass through to the gameplay world when faded out.
  - **`EventBus`** new signals: `zoom_changed(level: String)` ("strategic" / "gameplay") and `landing_confirmed(grid_pos: Vector2i)`.
  - **`WorldCamera`** new `current_level()` + `_emit_level_changed()` — emits `EventBus.zoom_changed` on `_ready` and after every `_apply_step()`. Threshold: `step <= 2 ⇒ strategic` (covers 0.13×, 0.18×, 0.25× zoom levels).
  - **`Ground.tscn`** instances `OrbitMap` alongside HUD.
  - **`tests/phase_7_test.gd`** — verifies JSON, scene, ≥6 deposits loaded, `EventBus.zoom_changed` fires on zoom-in past threshold, Confirm Landing falls back to suggested tile when no marker is clicked, GameState gets the right `selected_landing_tile`, and `EventBus.landing_confirmed` carries it.
- Build: clean. Test: **PASS**. Full regression on phases 2–7: all PASS.
- Bug fixed in-loop: `CanvasLayer.modulate` doesn't exist (CanvasItem property). Wrapped fade-able content in a `Root` Control child and tweened that.
- Deferred:
  - The strategic-zoom-only sidebar panels per `fq_full_world_view.png` (Mission Day repurposed, Environment, Resources Detected, Landing Module, Terrain Analysis, Hazards, Recommendation as separate panels rather than a single tooltip) → Phase 8/10 polish
  - Camera auto-zoom-in on Confirm Landing (currently only stores the tile + emits signal; the actual camera fly-in is up to the user via the `+` button) → Phase 8 polish
  - Ground.gd reading `selected_landing_tile` to seed deposit-node spawn positions → Phase 8 (alongside resource node placement)
- Files added: 4 new (1 data/json + 1 script + 1 scene + 1 test); 3 modified (event_bus.gd, world_camera.gd, Ground.tscn)

## Phase 8: Scanning + fog + samples + remaining buildings + recipes
- Status: completed
- Implemented:
  - **6 new building scenes**: `RTG.tscn`, `Electrolyzer.tscn`, `HydroponicsBay.tscn`, `StorageSilo.tscn`, `CommsDish.tscn`, `ResearchLab.tscn` — all reuse the shared `building.gd` script with their own `building_key`. `BuildingDatabase.SCENE_PATHS` extended to 9 entries.
  - **`scripts/world/resource_node.gd`** + **`ResourceNode.tscn`** — `class_name ResourceNode`. Six placeholder deposits spawned by `ground.gd._spawn_resource_nodes()` near the landing zone (iron, silicon, water_ice, titanium, helium3, rare_metals). Starts undiscovered (faded sprite, hidden label); `reveal()` flips it to discovered. `can_be_sampled_by(crew_pos)` + `collect_one()` API. Auto-joins "resource_node" group.
  - **`scripts/world/probe.gd`** + **`Probe.tscn`** — Scientist-deployed static vision source. Joins "probe" + "vision_source" groups. Emits `EventBus.probe_deployed` on spawn.
  - **`scripts/systems/fog_of_war.gd`** + **`FogOfWar.tscn`** — `CanvasLayer` (layer 2) sweeps every "vision_source" each `_physics_process` and stores revealed cells in a Dictionary. 64-px reveal grid, configurable per-source `vision_radius()`. Real shader-based punch-through is Phase 10 polish; current placeholder still satisfies done criterion #4.
  - **`scripts/autoload/recipe_processor.gd`** (new 8th autoload) — loads `data/recipes.json` filtered to recipes with explicit `input`+`output` dicts. Per-recipe duration timer ticks down at `TimeManager.time_scale`-scaled rate; runs cycle when a building of `recipe.building` (or `required_building`) is in the "buildings" group AND `ResourceManager.can_afford(input)`. Public `try_run(key)` for tests.
  - **`scripts/buildings/building.gd`** — `_ready` now adds the building to the "buildings" group so `RecipeProcessor` can find them.
  - **`scripts/crew/crew_member.gd`** — `_ready` adds the crew to "vision_source" group (crew vision contributes to fog reveal).
  - **`scripts/crew/crew_selection_manager.gd`** — extended `_physics_process` to detect `scan` / `deploy_probe` / `collect_sample` action edges. `_do_scan` reveals nearby resource nodes (Geologist gets 2× radius: 440 vs 220 px). `_do_deploy_probe` requires `Role.SCIENTIST`, instantiates `Probe.tscn` at the crew's position. `_do_collect_sample` finds the first sampleable node in range, calls `collect_one()`, which adds 1 to `samples` and emits `EventBus.sample_collected`.
  - **`tests/phase_8_test.gd`** — verifies all 6 done criteria.
- Build: clean. `[RecipeProcessor] Ready. 2 recipes loaded.` `[Ground] Phase 4 ready. Tiles=21025  Crew=6  Nodes=6`
- Test: **PASS**. Full regression on phases 2–8 all PASS.
- Bug fixed in-loop: SceneTree-extending test scripts must call group-lookup methods directly (`get_nodes_in_group`), not via `get_tree().get_nodes_in_group` — `get_tree()` doesn't exist on a SceneTree, since `self` IS the SceneTree.
- Deferred:
  - Real fog-of-war shader with soft falloff + actual rendering of darkened canvas → Phase 10 polish
  - Resource node spawn driven by `GameState.selected_landing_tile` + `data/orbit_deposits.json` (currently hardcoded layout) → Phase 9 polish
  - Extraction recipes (`input_resource: <node_type>`) wired through `_do_collect_sample` to drive different yields per deposit → Phase 9 / 10
  - Building costs not yet using the unlocked secondary resources beyond materials/silicon/iron → balance pass
- Files added: 12 new (6 building scenes + 4 scripts + 2 scenes for resource node/probe/fog + 1 autoload + 1 test); 4 modified (project.godot, building.gd, crew_member.gd, crew_selection_manager.gd, ground.gd, Ground.tscn)

## Phase 9: Win/lose + events + save/load + CHECK-IN
- Status: completed
- Implemented:
  - **`scripts/autoload/win_lose_manager.gd`** (9th autoload) — listens to `EventBus.resource_changed` (defeat on power/oxygen/food == 0) and `EventBus.mission_day_advanced` (win on 3 consecutive day-checkpoints with positive net rate on all 3 critical resources). Locks itself after firing once. Public `reset()` for new-game flow.
  - **`scripts/autoload/event_manager.gd`** (10th autoload) — loads `data/events.json` (5 events: meteor_shower, supply_drop, equipment_failure, solar_flare, rescue_signal). On every `EventBus.mission_day_advanced` rolls each event against `trigger_chance_per_day`, gated by `min_day` and optional `requires_building`. Applies the `add_resource` effect immediately; other effects (damage_random_outdoor_building, disable_random_building, radiation_pulse, spawn_rescue_objective) are stubs that emit a log message — full gameplay wiring deferred to Phase 10. Public `try_event(id)` ignores RNG/gating for tests.
  - **`scripts/autoload/save_system.gd`** — full Phase-9 implementation replacing the Phase-1 stub. `save_game(slot)` builds a Dictionary with sections: `_version`, `game_state` (mode/day/pause/landing tile), `resources` (all 13 with current/max/rate), `time` (minute_of_day/day/scale/phase), `crew` (6 entries with id/name/role/skill/position/health/stamina/oxygen/selected), `buildings` (key + position), `resource_nodes` (type + amount + discovered + position), `probes` (positions), `fog_revealed_cells` (flattened Vector2i list). `load_game(slot)` restores everything in-place — crew + autoloads are mutated, buildings/nodes/probes are torn down + re-instantiated under YSort. Per spec §5.6 the world is unified, so load doesn't reload Ground.
  - **`EventBus`** new signals: `victory`, `defeat(reason)`, `random_event_fired(event_id, summary)`, `game_saved(slot)`, `game_loaded(slot)`.
  - **`tests/phase_9_test.gd`** — 6 done-criteria checks: lose on oxygen=0, win on 3 sustainable days, `EventManager.try_event('supply_drop')` adds materials + emits random_event_fired, `save_game` writes a parseable JSON with all sections, round-trip restores power and crew position.
- Build: clean. `[EventManager] Ready. 5 events loaded.` Test: **PASS** first try. Full regression phases 2–9: all PASS.
- Deferred:
  - Win / Lose modal UI screens (per spec — currently signals fire but no full-screen overlay) → Phase 10 polish
  - Stub-effect events (`damage_random_outdoor_building`, `disable_random_building`, `radiation_pulse`, `spawn_rescue_objective`) → Phase 10 / 11
  - Autosave every in-game day per spec §5.7 → Phase 10
  - Save/load slot management UI → Phase 10
  - Probe + ResourceNode restoration uses tree position not the original spawn parent — adequate for round-trip but may need to honor Y-sort semantics on full session reloads → Phase 10
- Files added: 4 new (2 autoloads + full save_system rewrite + 1 test); 2 modified (event_bus.gd, project.godot)

## CHECK-IN at Phase 9 (final, per autonomous prompt)
- **Built:** Mechanically complete colony game. Crew + selection + click-to-move pathfinding (Phase 4), 3 fully-functional buildings end-to-end (Phase 5), 6 more building scenes wired into the database (Phase 8), spec-§8 HUD with 8 separate-scene panels (Phase 6), strategic-zoom orbit map with 7 deposit tiles + Confirm Landing flow (Phase 7), scan/probe/sample actions + fog-of-war placeholder + recipe processor (Phase 8), win condition (3 sustainable days), lose condition (critical resource depletion), 5 random events with chance/min-day gating, full save/load round-trip with 9 state sections (Phase 9). All 8 phase tests + Phase-2/4 regressions consistently PASS.
- **Run:** open the Godot project at `mission-dashboard/godot/` in Godot 4.6.2 and press F5. Or headlessly: `Godot_v4.6.2-stable_win64_console.exe --path mission-dashboard/godot/`.
- **What to verify before Phase 10:**
  - WASD/arrow keys move the selected crew; 1–6 select; Shift+# multi-select; click-to-move on selected crew.
  - Top-right ± buttons step zoom in 10 increments from full strategic to close gameplay; selecting a different crew at high zoom auto-recenters.
  - Top-center resource bar shows live values + rates from `EventBus.resource_changed`.
  - Bottom-left build menu places construction sites; Engineer adjacent advances the bar; on completion the building's produces/consumes apply to ResourceManager rates.
  - Strategic zoom (zoom step 1–3) shows the orbit-map overlay with grid labels A–J × 1–10, deposit markers, pulsing E5 suggested-landing zone, tooltip + Confirm Landing.
  - Sit at gameplay zoom long enough for `mission_day_advanced` to fire — debug HUD's day counter ticks; events may roll; if you set a positive net rate on power/oxygen/food and let 3 days pass, victory fires (debug log).
  - **From the remote inspector** (Debug menu): call `SaveSystem.save_game()` then mutate any state then call `SaveSystem.load_game()` — state restores. JSON file at `%APPDATA%/Godot/app_userdata/Lunar Colony/saves/autosave.json`.
- **Known placeholders / not in scope for Phase 10**:
  - All sprite art is still runtime-generated colored rectangles. Round-15 character UUIDs are queued at Pixellab (kid cadets in sleek high-tech exosuits per `lunar_colony_character_generation.md`) plus 5 building iso tiles + 3 extras (kai/noor/tali) — see `art_queue.json`. **Phase 10 art swap-in is the bulk of the work remaining.**
  - Real fog-of-war shader (currently revealed-cells dictionary only; no actual canvas darkening) → Phase 10.
  - Win/Lose modal UI overlay (signals fire but no full-screen victory/defeat screen) → Phase 10.
  - Audio is entirely placeholder (AudioManager stubs from Phase 1) → Phase 10.
  - Stub event effects → Phase 10/11.
  - TileMapLayer culling + sprite LOD at strategic zoom → Phase 11 (already on roadmap).
- **Halting per autonomous prompt — do not start Phase 10. Halt for human review.**








## Gamepad support (generic Bluetooth pad: 1 stick + 3 buttons)
- Status: completed
- Hardware target: basic BT pad, one 360° analog stick + three usable buttons, enumerating with **raw unmapped indices** (`buttons[2]` cancel, `buttons[3]` confirm, `buttons[4]` stick-click). No SDL mapping, so `JOY_BUTTON_A/B/X/Y` do not describe it — every binding is by integer index from data.
- Control scheme — two modes, toggled by stick click:
  - **CREW**: stick walks the selected crew (analog). `[3]` fires the role context action (Scientist → deploy probe, else sample if a deposit is in range, else scan). `[2]` advances a 7-slot focus ring: crew 1→2→…→6→**free explore**→1.
  - **Free explore** (7th slot): nobody selected, camera forced to `PAN`, stick flies the camera. Crew walking stops by itself because `crew_member.gd` only reads the stick while `selected`. `[3]` snaps back to the last crew.
  - **CURSOR**: stick drives an on-screen cursor that warps the real mouse, so every existing pointer consumer works untouched — build menu, ghost placement, demolish, landing confirm, zoom buttons, sliders, panel drag. `[3]` is left click (press/release mirrored so hold-drag works; double-tap sets `double_click` for click-to-move), `[2]` is right click.
- Implemented:
  - **`data/gamepad.json`** (new) — device/axis/button indices, deadzone, cursor speed ramp, pan speed, double-tap window, `debug_probe`. The only remap surface; no remap UI.
  - **`scripts/autoload/game_state.gd`** — loads the pad config (forward-compatible, merged over a `PAD_DEFAULTS` fallback) and gained `_setup_joypad_bindings()`. Stick axes are added to the **existing** `move_up/down/left/right` actions, so crew walking is analog for free; three new actions `pad_confirm` / `pad_cancel` / `pad_mode` carry the joypad buttons. `InputMap.action_set_deadzone` drops the move actions from Godot's default 0.5 to 0.22 (a cheap pad drifts). `_add_event_once` keeps re-running the setup idempotent.
  - **`scripts/autoload/pad_input.gd`** (new 11th autoload) — mode state, virtual cursor, click synthesis, hint label. `PROCESS_MODE_ALWAYS` so the cursor survives pause. Owns a `CanvasLayer` at layer 100 with a runtime-generated arrow texture (no art dependency, same approach as `build_placement_controller._build_ghost_texture`) and a bottom-centre hint line that prints the actual configured button numbers. Manual prev-frame edge tracking, matching the `is_action_just_pressed`-is-unreliable note in `crew_selection_manager.gd:13-17`.
  - **`scripts/crew/crew_selection_manager.gd`** — joins group `crew_manager`; new `cycle_focus(step)` (7-slot ring, free-explore slot emits `crew_selected(0)`), `has_selection()`, `deselect_all()`, `invoke_context_action() -> bool` (false ⇒ free explore ⇒ PadInput recenters instead). `_do_collect_sample` split so `_find_sampleable()` can be probed without emitting the "no deposit" alert. `_select` now records `_focus_slot` so number keys and the crew panel keep the ring in step.
  - **`scripts/world/world_camera.gd`** — `pan_by(screen_delta)` extracted from the inlined drag math and now shared by mouse drag, trackpad pan gesture and the free-explore stick. `recenter_on_last_crew()` + `_last_crew` + `_free_explore`. `_on_crew_selected(0)` clears the follow target and switches to `PAN` (previously it fell through the loop and left `_selected_crew` stale); returning to a crew restores `FOLLOW` only if free explore put it in `PAN`.
  - **`scripts/crew/crew_member.gd`** — the four `is_action_pressed` branches collapsed into `Input.get_vector(...)` (analog on a stick, unit on keys), gated by `PadInput.suppresses_crew_movement()` so the stick doesn't walk crew while it's driving the cursor.
  - **`scripts/autoload/event_bus.gd`** — `pad_mode_changed(mode)`, `pad_connected(connected, device_name)`.
  - **`tests/gamepad_test.gd`** (new) — 8 checks: button/axis bindings match the JSON, deadzone applied, setup idempotent, mode toggle + signal, cursor moves and clamps, synthetic click places a building and right-click cancels, the full 7-slot ring, free-explore pan moves the camera and no crew, keyboard movement regression.
- Bug fixed in-loop: a pan issued while a zoom/recenter `Tween` was still in flight went nowhere — the tween rewrote `global_position` every frame. `pan_by` now kills the tween and snaps `zoom` to `ZOOM_LEVELS[step]` so deliberate input outranks the animation. This also affected existing mouse-drag panning during a zoom step.
- Fixed alongside: crew movement was applying a **screen-space** direction as **world-space** velocity. `Ground.tscn` sets `rotation = 0.0872665` (5°) while `ground.gd` sets `camera.ignore_rotation = true`, so screen-up walked 5° off. `crew_member.gd` now rotates the input direction by the world root's rotation, the same conversion `pan_by` does. Pre-existing on keyboard; noticed because the stick made it obvious.
- Build: clean (`[PadInput] Ready. Pad connected: false`). 180-frame headless boot of `Ground.tscn` produces no warnings or errors.
- Test: **PASS**. Full regression phases 2–9: all PASS.
- Deferred:
  - Pad-native zoom — reachable by clicking the `ZoomControls` buttons in CURSOR mode. Stick/chord zoom not wired.
  - `pause_game`, `speed_1x/2x/4x` still unbound on the pad (they have no consumer on the keyboard either).
  - No focus-chain retrofit (`focus_mode`/`grab_focus` are still unused project-wide) — CURSOR mode covers UI instead. Revisit if a pad with a d-pad + 4 face buttons becomes a target.
  - `hud_panel_hotbar.gd` still polls raw `KEY_0..KEY_9` and stays keyboard-only; its slots bind to nothing yet.
  - No remap UI and no button glyph art — `data/gamepad.json` and plain-text hints.
- Files added: 3 new (`data/gamepad.json`, `scripts/autoload/pad_input.gd`, `tests/gamepad_test.gd`); 6 modified (`project.godot`, `game_state.gd`, `event_bus.gd`, `crew_member.gd`, `crew_selection_manager.gd`, `world_camera.gd`)

## Roster expansion: 5 new characters (Rainbow, Rush, Mister E, PrimeMax, Brandon)
- Status: completed
- Source: 5 Pixellab zip exports (`export_version` 3.1), each `Idle/rotations/{8 dirs}.png` + `metadata.json`. **Idle rotations only — no walk animation frames.** `_build_sprite_frames` already falls back to reusing the idle rotation for `walking_*`, so they animate direction-correctly but don't have a walk cycle.
- Decisions taken (user):
  - All five are a **new `Role.SPECIALIST`**, appended last in the enum so the existing role ints stay valid in save files. Specialists can scan; they cannot build (`construction_site.gd:94` gates on `ENGINEER`) or deploy probes (`crew_selection_manager.gd:90` gates on `SCIENTIST`).
  - **Per-crew number keys dropped.** 11 crew outgrew the number row, so `select_crew_1..6` is gone and selection is a single cycle: **Tab** forward, **Shift+Tab** backward, through all 11 crew plus the free-explore slot. Same ring the gamepad cycle button drives, so keyboard and pad now share one selection model.
  - **All sprites normalized** to a common on-screen height.
- Implemented:
  - **`assets/sprites/crew/{rainbow,rush,mistere,primemax,brandon}/rotations/*.png`** — extracted flat (the zips' `Idle/` level dropped) to match the existing `<folder>/rotations/<dir>.png` convention. Each folder also keeps `pixellab_metadata.json` for prompt provenance.
  - **`scripts/crew/crew_member.gd`** — `Role.SPECIALIST` + its colour (steel grey) and label. New `@export var sprite_folder` with `_art_folder()` resolving per-crew override before the role default, because `CREW_FOLDER` is keyed by role and five crew now share one. New `TARGET_SPRITE_HEIGHT = 180.0`: `_ready` scales `AnimatedSprite2D` by `180 / texture_height`. Exports range 92×136 to 164×244, so without this Brandon and Rush rendered ~1.8× over Mister E. `offset` is applied before `scale`, so the existing feet-anchor Y-sort trick still holds.
  - **`scripts/world/ground.gd`** — `CREW_ROSTER` grew to 11 with an `art` field per entry; `_spawn_crew` passes it to `crew.sprite_folder`. New crew occupy two more offset rows.
  - **`scripts/autoload/game_state.gd`** — `select_crew_1..6` replaced by one `cycle_crew` action on `KEY_TAB`.
  - **`scripts/crew/crew_selection_manager.gd`** — `MAX_CREW` 6 → 11; the six-way select poll replaced by a `cycle_crew` edge that calls `cycle_focus(-1 if shift else 1)`. Ring is now 12 slots. Polling `Input.is_action_pressed` rather than consuming the event means Godot's built-in `ui_focus_next` (also Tab) can't swallow it.
  - **`crew_ids.json`** — the 5 new Pixellab character IDs recorded with import date and source.
- Verified: all 11 crew resolve real art (`_use_animated == true`) and land on a 180 px screen height — measured scales 0.74 (Rush, Brandon) to 1.32 (Mister E). PNG import clean, no errors on boot.
- Tests updated: `phase_4_test` (roster count 6→11, role range 0..5→0..6, `select_crew_3` press → `cycle_crew` press asserting crew 1→2), `phase_7_test` (post-landing crew count 6→11), `gamepad_test` (ring walks `range(2, MAX_CREW + 1)`).
- Test: **PASS** — gamepad plus full regression phases 2–9.
- Deferred:
  - Walk-cycle animations for the 5 new characters (Pixellab `animate_character`); they currently reuse the idle rotation while moving.
  - No per-specialist ability differentiation — all five behave identically. Split into distinct roles if they need their own kit.
  - HUD crew panel is a flat `HBox` of portraits; at 11 crew it will want wrapping or scrolling.
  - Sprite normalization keys off canvas height, not the character's actual pixel extent, so characters with unusual padding may still read slightly off.
- Files added: 5 asset folders (40 PNGs + 5 metadata); modified: `crew_member.gd`, `ground.gd`, `game_state.gd`, `crew_selection_manager.gd`, `crew_ids.json`, `phase_4_test.gd`, `phase_7_test.gd`, `gamepad_test.gd`

## Roster expansion (cont.): Athena
- Status: completed
- Same Pixellab zip shape as the previous five (export v3.1, 8 idle rotations + `metadata.json`, **no walk frames**), 172×256 — the tallest export so far.
- Added as the 6th `Role.SPECIALIST`, `crew_id` 12, skill 89, spawn offset `Vector2(96, 144)`. `MAX_CREW` 11 → 12, so the focus ring is now 13 slots (12 crew + free explore). Pixellab id recorded in `crew_ids.json`.
- Verified: all 12 crew resolve real art; Athena normalizes at scale 0.70 (256 → 180 px screen height).
- Gotcha worth remembering: **new PNGs need an explicit import pass before a `-s` script run can see them.** `ResourceLoader.exists()` returns false until the `.import` files exist, so `_build_sprite_frames` silently falls back to the placeholder rect and the crew reads `_use_animated == false`. Earlier batches happened to get imported by an incidental `--quit-after` boot; Athena did not. Fix is one command before testing new art:
  `Godot_v4.6.2/Godot_v4.6.2-stable_win64_console.exe --headless --path godot --import`
- Tests updated: `phase_4_test` (12 crew), `phase_7_test` (post-landing count 12).
- Test: **PASS** — gamepad plus full regression phases 2–9.
- Files added: `assets/sprites/crew/athena/` (8 PNGs + metadata); modified: `ground.gd`, `crew_selection_manager.gd`, `crew_ids.json`, `phase_4_test.gd`, `phase_7_test.gd`

## Art swap-in: MatterForge building sprite
- Status: completed
- User supplied `MatterForge.png` (1920×1080 "MOON FORGE" iso render). `building.gd::_load_building_texture` already looks for `assets/sprites/buildings/<building_key>.png`, so the only work was conditioning the image — no code change to the building path.
- **`tools/import_building_art.gd`** (new, reusable) — `-s tools/import_building_art.gd -- <source.png> <building_key> [bg_tolerance] [max_width]`:
  1. **Background → alpha by flood fill inward from the canvas border**, not a global colour threshold. A threshold would punch holes in the artwork's own dark pixels (vents, outlines, the shadowed furnace interior); only background connected to the edge is cleared. Tolerance defaults to 24/255 so a near-black export still keys out.
  2. **Crop to `get_used_rect()`.** Required, not cosmetic: `_apply_iso_transform` scales by the texture rect, so leftover empty margin would shrink the visible building inside its footprint.
  3. **Downscale to 512 px wide** (Lanczos). The source cropped to 1453×1044 at 1.9 MB against 28–42 KB siblings, and an 8-cell footprint only renders 356×256. With `textures/canvas_textures/default_texture_filter=0` (nearest), squeezing a 1453 px texture down at runtime just shimmers. 512 leaves headroom for the 2.85× zoom step and matches the existing `habitat_xl.png`.
- Result: `assets/sprites/buildings/matter_forge.png`, 512×368, 327 KB. Verified in-engine — `_is_real_sprite == true`, scale 0.696, renders 356×256 inside the 8-cell (512×256) iso box.
- Gotcha (same as the crew art): run `--headless --path godot --import` after dropping in a new PNG, or `ResourceLoader.exists` misses it and the building silently falls back to its placeholder rect.
- Test: **PASS** — phases 5–9 plus gamepad.
- Deferred: the other 9 buildings still render generated placeholder rects. `data/buildings.json` also points `matter_forge.icon` at `assets/sprites/ui/icon_matter_forge.png`, which does not exist yet — no consumer reads `icon` today.
- Files added: `tools/import_building_art.gd`, `assets/sprites/buildings/matter_forge.png`

## Build gate removed: any crew can construct
- Status: completed
- Answering "who can build?": before this, **only Alex**. Placement was never role-gated — anyone could open the build menu and drop a site — but `construction_site.gd::_engineer_in_reach()` only ticked the progress bar while a `Role.ENGINEER` stood within reach, so every construction job in the colony funnelled through one crew member. With a 12-strong roster (six sharing SPECIALIST) that was a hard bottleneck.
- Change: `_engineer_in_reach()` → `_builder_in_reach()`, role check dropped; `ENGINEER_REACH` → `BUILD_REACH` (still 128 px). Any crew in the group now advances a site. No speed bonus for Engineers — the ask was flat parity; add a per-role multiplier in `tick()` later if building should still favour them.
- Also updated: the tutorial panel line ("Engineer (Alex) ticks the construction bar" → "Any crew member…"), and the now-wrong SPECIALIST comment in `crew_member.gd` claiming they cannot build.
- Test added — `phase_5_test` check 7: parks every Engineer 5000 px away, puts a non-Engineer on a fresh site, asserts progress advances.
- **Headless trap found while writing that test** (worth remembering, cost a debugging round): *naming `CrewMember` inside a `SceneTree` test script silently breaks crew spawning.* `Ground._spawn_crew` prints `Crew=0` and the "crew" group comes back empty — GDScript's `class_name` discovery is order-sensitive in headless mode, the same failure already documented for `BuildPlacementController`/`ConstructionSite` in Phase 5. No error is raised; the roster just never spawns, so unrelated assertions in the same test keep passing and only crew-dependent ones fail. **Test scripts must duck-type crew** (`node.get("role")`, compare against a local role int) instead of casting to `CrewMember`.
- Test: **PASS** — full regression phases 2–9 plus gamepad.
- Files modified: `construction_site.gd`, `hud_panel_tutorial.gd`, `crew_member.gd` (comment), `phase_5_test.gd`

## MatterForge scaled 2×
- Status: completed
- `data/buildings.json` → `matter_forge.footprint_cells` 8 → 16. That drives the visual iso-diamond fit, the inset collision diamond, and the nav obstacle together, so the building, its blocker, and its walkable perimeter all scale as one.
- Re-imported the art at `max_width 1024` (was 512). The doubled footprint renders 712 px wide, so a 512 px texture would have been upscaled past native and gone soft under nearest filtering. Now 1024×736, 1.1 MB — heavier than the other buildings, justified for a hero structure at this size.
- Verified in-engine: `cells=16`, scale 0.696, rendered **712×512** — exactly double the previous 356×256.
- Note: `matter_forge.size` is still `[3, 3]`. Nothing reads `size` today (grid-footprint validation is still deferred); `footprint_cells` is the field that matters. Worth reconciling if size-based placement validation ever lands.
- Test: **PASS** — full regression phases 2–9 plus gamepad.

## Economy overhaul: realistic lunar ISRU resource chain
- Status: completed
- Replaced the abstract `materials` stockpile (and the "1 iron + 1 silicon → 100 materials" MatterForge) with a three-tier chain modelled on real in-situ resource utilisation:
  - **Raw** (extracted): `regolith` (excavator, anywhere), `water_ice`, `ilmenite` (FeTiO₃), `anorthite` (plagioclase), `helium3`, `kreep`, `samples`.
  - **Refined**: `hydrogen`, `iron`, `titanium`, `aluminum`, `silicon`, `glass`, `regolith_bricks`, `rare_metals`.
  - **Components** (all building costs are paid in these): `alloy_beams`, `hull_panels`, `solar_cells`, `wiring`, `machine_parts`, `electronics`.
  - Vitals unchanged: `power`, `oxygen`, `water`, `food`, `science`, `crew`.
- **`data/resources.json`** (new) is the single source for every resource: display name, glyph, colour, HUD group, start stock, cap, `per_crew_drain`, description. `ResourceManager` now loads it instead of hard-coding 13 entries; exposes `ordered_keys()`, `keys_in_group()`, `display_name()`, `glyph()`, `color()`, `format_cost()`.
- **Crew life support**: each crew member drains O₂ 0.15, water 0.10, food 0.10 per minute, published as a negative rate so the HUD and the win/lose day checkpoint see the real net figure. Re-derived whenever the `crew` resource changes. Habitat no longer conjures oxygen; O₂ comes from the Electrolyzer (water → O₂ + H₂) and the MRE Smelter.
- **Processing loop** (`data/recipes.json`): drill → ilmenite; Reduction Plant does `ilmenite + hydrogen → iron + titanium + water` (hydrogen reduction; the water goes back through the Electrolyzer, which is the classic closed ISRU loop). MRE Smelter: `anorthite → aluminum + silicon + oxygen`, or bulk `regolith → oxygen + iron + silicon`. Sintering Kiln: regolith → bricks / glass. MatterForge is now the fabricator with six component recipes.
- **`stop_at`** recipe field (RecipeProcessor `_outputs_wanted`): a recipe idles once any output reaches its stop level, or when every output is at cap. That is what stops the fabricator draining all iron into beams before it ever makes machine parts. Published HUD rates now only count recipes that would actually cycle (inputs in stock, outputs wanted) — no more phantom +/min on a starved recipe.
- **`raises_cap` was never wired up** — Storage Silo did nothing. `building.gd` now applies it on `_ready` and unwinds on `_exit_tree`, same pattern as rates.
- Four new buildings + scenes (placeholder rects): Regolith Excavator, Sintering Kiln, Reduction Plant, MRE Smelter. Supply-drop event now delivers electronics + rare metals + machine parts ("imported from Earth" lever). Deposits renamed everywhere (ground layout, orbit_deposits, save default, node colours): iron→ilmenite, silicon→anorthite, titanium merged into ilmenite, rare_metals→kreep.
- **HUD**: `hud_panel_resources.gd` builds from `resources.json` — vitals row on top, collapsible 10-column stockpile grid beneath. Values tint amber at cap, red at zero; tooltips carry the description and the current life-support drain.
- Starter kit (lander) is sized so the opening order — 2× Solar Array, Excavator, Drill, Kiln, Electrolyzer, Reduction Plant — is affordable; after that the loop has to close. `economy_test` check 9 asserts this against the data so rebalancing can't silently strand a new game.
- Test added — `tests/economy_test.gd`: resources load + grouped, life-support drain scales with crew, every building cost / recipe input / output / stop_at names a real resource and every recipe a real building, zero-input excavator recipe runs, reduction loop returns water, `stop_at` halts/resumes, silo cap applies and unwinds, starter kit affords the opening order.
- Tests updated: `phase_5` (cost assertion now iterates the whole cost dict instead of hard-coding materials/silicon), `phase_8` (iron → ilmenite deposit), `phase_9` (supply drop asserts machine_parts), `gamepad` (tops up solar components).
- Test: **PASS** — economy + full regression phases 2–9 plus gamepad. Headless 120-frame boot clean.
- Not done / deferred: `active_phases` on solar is still ignored (solar produces at night); extraction recipes still run once per drill *type* rather than per drill instance; no per-recipe job queue on the fabricator (stop_at is the stand-in); old saves carry a `materials` entry that is now ignored on load.
- Files added: `data/resources.json`, `scenes/buildings/{RegolithExcavator,SinteringKiln,ReductionPlant,MRESmelter}.tscn`, `tests/economy_test.gd`; modified: `data/{buildings,recipes,events,orbit_deposits}.json`, `resource_manager.gd`, `recipe_processor.gd`, `building_database.gd`, `building.gd`, `event_manager.gd`, `save_system.gd`, `main.gd`, `build_menu.gd`, `debug_hud.gd`, `hud_panel_resources.gd`, `ground.gd`, `resource_node.gd`, tests 5/8/9/gamepad

## Stockpile HUD redesign
- Status: completed
- `HUDPanelResources` rebuilt as a two-tier instrument strip (860 px wide). Vitals stay large on top, each with a 3-px stock bar (current / cap) in its resource colour and a ▲/▼ rate in green/red. Below a hairline divider with a `▾ STOCKPILE` collapse button, three labelled rows — **RAW** (amber tick), **REFINED** (cyan), **COMPONENTS** (violet) — one chip per resource: tier-tinted glyph badge, value, small ▲/▼ rate, fill bar. Chip state: amber border + amber bar when pinned at cap (production being wasted), dimmed value + faint border when empty, normal otherwise. Tooltip carries display name, cap, description and current life-support drain.
- The `.tscn` now owns the structure (`Margin/VBox/{Vitals,Divider,Stock}`); the script only fills it. Vitals keep the `Col_<key>` node names and the `[glyph, value]` HBox shape that `phase_6_test` walks, so the test contract held.
- **`tools/screenshot.gd`** (new) — `Godot_console.exe --path godot --resolution 1920x1080 -s tools/screenshot.gd -- out.png [frames] [seed]`. Boots Ground, confirms a landing, waits N frames, saves the viewport. `seed` fills stockpiles to a spread of 0 / 15 / 40 / 70 / 100 % with mixed rates so every chip state is visible in one shot. Needs a real renderer (no `--headless`). Used to iterate this layout without launching the editor.
- Test: **PASS** — phase 6, phase 9, economy.
- Files added: `tools/screenshot.gd`; modified: `scenes/ui/panels/HUDPanelResources.tscn`, `scripts/ui/panels/hud_panel_resources.gd`

## HUD chrome: every panel movable, collapsible, resizable, dockable
- Status: completed
- **`scripts/ui/hud_chrome.gd`** (new, no `class_name` — headless discovery trap) — one component installed into a PanelContainer at runtime; nothing per-scene to author. `hud.gd` installs it on all eight `HUDPanel*` children; `build_menu.gd`, `terrain_debug_slider.gd`, `zoom_controls.gd` install it on their `$Panel`. Old `floating_panel.gd` (drag only) deleted, and the hand-built Header/CollapseButton rows in `BuildMenu.tscn` / `TerrainDebugSlider.tscn` removed — the chrome header replaces them.
- What each panel gets:
  - **Header bar** — ⠿ grip glyph, title, ▾ collapse. Panels that drew their own title Label (Log, Crew, Minimap, Tutorial) have it hidden via `inner_header` so titles don't double up.
  - **Move** — drag the header. Edges are magnetic: snap within 14 px to the 16 px screen margin and to every other chrome'd panel's edges (left↔left/right, top↔top/bottom), so panels butt up cleanly.
  - **Collapse** — ▾ button or double-click the header. Folds to the header; width kept, expanded size remembered.
  - **Resize** — ⋱ grip bottom-right, drawn as three cyan dots. Clamped to the panel's combined minimum and the screen. Grip is a `top_level` Control so the PanelContainer's layout skips it.
  - **Dock** — right-click the header: Float, eight edge/corner slots (Top-Left … Bottom-Right), Reset this panel. A docked panel re-seats itself after collapse/resize so a bottom-docked bar stays on the bottom edge. Dragging undocks.
  - **Persist** — `user://hud_layout.json`, keyed by panel node name (x, y, w, h, collapsed, dock). Writes are coalesced 0.5 s after the last change. Restored on install, clamped to screen.
  - **Reset all** — new `reset_hud` action (F9, `game_state.gd`), handled in `hud.gd`: wipes the file and returns every panel to its scene rect.
- Install runs deferred so the panel's own `@onready` lookups resolve before its children are re-parented under `Frame/Content`. A second deferred step (`_settle`) fixes the rect once the header has been laid out: keeps the scene's anchored edge fixed (a bottom-anchored hotbar grows *upward* when the header adds 22 px), then clamps to screen.
- **Pre-existing bug surfaced while doing this:** `HUDPanelTutorial` was 7027 px tall at boot — its autowrapped tip labels get measured at zero width during its own `_ready`, report a giant minimum height, and containers never shrink. The bottom border was simply off-screen so nobody noticed. `_settle` treats any scene rect larger than the screen as blown and falls back to the real minimum; the guide is now 344×267 at (1560, 80). Root cause in the tutorial (autowrap before first layout) left as-is, since the chrome guard fixes it generically.
- Default layout still has the historical overlaps (Zoom over Terrain Debug, Guide under it, Actions over Crew, Minimap under Build) — every one is now draggable, so left for the player.
- Tutorial tip updated (stale "Press 1–6" line → Tab/Shift+Tab, plus the drag/collapse/dock/F9 hint).
- Test: **PASS** — full regression phases 2–9, gamepad, economy. `phase_6` still walks `Col_power` under the Resources panel through `find_child(recursive)`, so the re-parent under `Frame/Content` didn't break it. Rendered screenshots via `tools/screenshot.gd` used to verify all eleven panels seat correctly.
- Files added: `scripts/ui/hud_chrome.gd`; deleted: `scripts/ui/floating_panel.gd`; modified: `hud.gd`, `build_menu.gd`, `terrain_debug_slider.gd`, `zoom_controls.gd`, `game_state.gd`, `hud_panel_tutorial.gd`, `BuildMenu.tscn`, `TerrainDebugSlider.tscn`

## HUD default layout baked from the player's arrangement
- Status: completed
- User arranged the panels in-game and the rects were lifted from `user://hud_layout.json` and written into each scene as plain top-left offsets (anchors/grow removed — the chrome freezes to top-left anyway). Defaults, 1920×1080 logical: Mission Clock (16,16) 342×178 · Messages (16,194) 342×590 · Guide (16,800) 342×264 · Resources (553,16) 878×226 · Actions (358,850) 564×91 · Hotbar (947,850) 614×91 · Crew (358,941) 1203×123 · Zoom (1561,16) 343×68 · Minimap (1561,94) 343×302 · Terrain Debug (1561,420) 343×364 **collapsed** · Build (1561,494) 343×570 (its 15-button minimum is ~610 tall, so the screen clamp seats it at y≈462). Left column, bottom strip and right column are edge-to-edge; F9 and fresh installs land here.
- Two chrome bugs surfaced by the exercise:
  - **Layout key collision** — Build, Zoom and Terrain Debug each wrap a node literally named `Panel`, so all three saved under one `"Panel"` entry and the last one to move won on reload. Keys are now `<owner scene>/<node>` (`BuildMenu/Panel`, `HUD/HUDPanelLog`). Old files are orphaned, not migrated.
  - **Boot wrote the layout file** — applying a default-collapsed state went through `set_collapsed()`, which queued a save, so a scene default got persisted on first run and could never be changed by editing the scene again. `set_collapsed(collapsed, persist)` now takes `persist=false` from `_settle` and `_load_layout`; only player actions write.
- New `install(..., start_collapsed)` option; Terrain Debug uses it.
- Test: **PASS** — phases 5, 6, 7, 9, gamepad, economy. Rendered screenshot matches the reference arrangement.
- Files modified: `hud_chrome.gd`, `terrain_debug_slider.gd`, all eight `HUDPanel*.tscn`, `BuildMenu.tscn`, `ZoomControls.tscn`, `TerrainDebugSlider.tscn`

## Hotbar removed
- Status: completed
- `HUDPanelHotbar` was a Phase-6 placeholder whose "Phase 8 wiring" never landed: ten toggle buttons, 0–9 keys selected a slot, and the only effect was a log line. Nothing read `current_slot()`. Dropped per user decision ("drop it for now"); the Build menu already covers placement. If it comes back, the spec's intent (§8 / §5.3) is build shortcuts on 1–9, demolish on 0.
- Removed: `HUDPanelHotbar.tscn`, `hud_panel_hotbar.gd`; HUD.tscn instance and `hud.gd` chrome entry; `phase_6_test` check 6 (renumbered, 7 panels).
- Its slot in the default layout — (947,850) 614×91, right of Actions — is now empty.
- Also noted: `HUDPanelActions` is the same kind of stub. The five buttons log "Action: X (Phase 8 wiring)"; the real Scan / Probe / Sample actions run off R / F / G in `crew_selection_manager.gd`, so the panel is a key-hint strip only. Left in place pending a decision.
- Test: **PASS** — phase 6, phase 7.

## Actions panel removed; key hints folded into the Guide
- Status: completed
- `HUDPanelActions` was the same Phase-6 stub as the hotbar: five buttons whose click only logged "Action: X (Phase 8 wiring)". The real Scan / Probe / Sample already run off R / F / G in `crew_selection_manager.gd`; "Crew Menu [C]" had no handler at all. Dropped per user decision.
- Guide (`hud_panel_tutorial.gd` TIPS) rewritten to carry the hints instead: movement + click-to-send, Tab cycling, **R scan / F probe / G sample** on one line, build menu (corrected — it's on the right, not bottom-left), zoom + Space pause + F1–F3 speed, panel chrome, F1 to hide.
- Seven tips at 342 px wide wrap to ~290 px, which pushed the Guide up into Messages. Defaults re-seated: Messages (16,194) 342×510, Guide (16,720) 342×344 (eight tips incl. build order). Left column is Clock / Messages / Guide edge to edge again.
- Note for later: **F1 is double-bound** — `speed_1x` in `game_state.gd` and the guide toggle in `hud_panel_tutorial.gd`. Pre-existing; the tip lists both truthfully. Worth moving speed to 1/2/3 or the guide to H.
- Removed: `HUDPanelActions.tscn`, `hud_panel_actions.gd`; HUD.tscn instance; `hud.gd` chrome entry; `phase_6_test` panel lists (6 panels).
- Test: **PASS** — phase 6. Screenshot verified.

## Economy: machine-parts bootstrap deadlock fixed
- Status: completed
- Found while writing the recommended build order. Machine parts are made only by the MatterForge, and the forge's recipe needed aluminum, which needs the MRE Smelter. Parts to reach a working forge + smelter: Drill 6 + Electrolyzer 4 + Reduction Plant 8 + Smelter 8 + Forge 10 = 36, kit had 32 — unreachable without a random supply drop. Also: build the Excavator or Kiln first (9 parts) and you were stuck even earlier.
- Fix: `fab_machine_parts` = iron 3 + rare_metals 1 (aluminum dropped — bearings and motors are iron; rare metals cover magnets), so parts flow as soon as the Reduction Plant runs. Kit `machine_parts` 32 → 40 for slack. Rare metals remain the true bottleneck (kit 12 → 12 parts; then KREEP refining or supply drops), which is the intended pressure.
- `economy_test` check 9 now asserts the *full* bootstrap — Solar ×2, Drill, Electrolyzer, Reduction Plant, MatterForge, Solar, MRE Smelter — is affordable from the kit, not just the first six buildings.
- Test: **PASS** — economy.

## Economy: power bootstrap gap fixed (user-caught)
- Status: completed
- User checked the recommended order and found the arithmetic fails at the smelter: 3 kit arrays = 45 power, chain to a running smelter draws 55, and new solar cells need smelter silicon + kiln glass + forge — so there's no way to add PV before going negative. Worse than "short": nothing pauses a building, and `WinLoseManager` treats power 0 as **defeat**. With a 400 buffer at −10/min the plan lost the game ~40 min after the smelter went up.
- Fix is in the kit, not the order: lander now carries `solar_cells` 40 (5 arrays = 75/min), `alloy_beams` 72, `wiring` 56 and `machine_parts` 48 — enough to erect the arrays and the whole 12-building bootstrap from cargo alone, before the forge makes a single part. Opening order Solar ×2 → Drill → Electrolyzer → Reduction → Solar ×3 → Forge → Smelter → Excavator → Kiln stays ≥ +6/min at every step (30 → 25 → 17 → 5 → 50 → 40 → 20 → 16 → 6). Second drill (−5) and RTG (+8) fit after; further arrays come from the forge once silicon and glass flow.
- `economy_test` check 9 now walks that 12-building order tracking net power per step and fails if it ever goes negative, alongside the kit-affordability check.
- Guide tip updated with the corrected order and "keep power positive — 0 power = mission lost".
- Still open (pre-existing): solar `active_phases` is ignored, so arrays produce at night. When that lands the night budget will need RTGs or batteries and this margin will not survive — revisit then.
- Test: **PASS** — economy.

## Build menu reordered to bootstrap sequence
- Status: completed
- `build_menu.gd` `BUILDABLE_KEYS` now lists buildings in the order they need to go up, matching the Guide tip and `economy_test` check 9: Solar Array, Mining Drill, Electrolyzer, Reduction Plant, MatterForge, MRE Smelter, Regolith Excavator, Sintering Kiln, then expansion — Comms Dish, RTG, Storage Silo, Habitat, Hydroponics, Research Lab. Previously in Phase-5/8 authoring order.
- Test: **PASS** — phase 5.

## Art swap-in: Mining Drill + Electrolyzer sprites
- Status: completed
- User supplied `level-1-drill.png` and `level-1-electrolyzer.png` (1536×1024 iso renders on black). Ran each through `tools/import_building_art.gd` at tolerance 24 / max width 512 — flood-fill background to alpha, crop to used rect (1410×991 and 1319×908), Lanczos downscale. Results: `assets/sprites/buildings/mining_drill.png` 512×360 (313 KB), `electrolyzer.png` 512×352 (277 KB). Import pass run.
- Verified in-engine: both `_is_real_sprite == true`; at the default 6-cell footprint (384×192 box) they render 273×192 and 279×192, height-limited. Reads well next to the crew at gameplay zoom. If they should read larger relative to the 16-cell MatterForge, bump `footprint_cells` to 8 in `buildings.json` — that scales the visual, blocker and nav obstacle together.
- `tools/screenshot.gd` gained a `place:SceneA,SceneB` arg that drops finished building scenes beside the landing site, so art swaps can be eyeballed at game scale without playing to a build.
- Cosmetic: Godot's import pass logs "Cannot navigate to hud_panel_actions.gd" — the editor's layout cache (`.godot/editor/editor_layout.cfg`) still remembers the deleted script as an open tab. Clears on next editor launch; not tracked in git.
- Files added: `assets/sprites/buildings/{mining_drill,electrolyzer}.png` (+ `.import`); modified: `tools/screenshot.gd`

## Resource inspector panel
- Status: completed
- Clicking any vital column or stockpile chip in the Resources panel opens **HUDPanelResourceInfo** (new scene + `hud_panel_resource_info.gd`), a real HUD panel with the same chrome as the rest — drag, dock, collapse, resize, layout persisted. Hidden at boot; ✕ closes; clicking another resource retargets it. Default rect (553,258) 440×600, directly under the Resources bar.
- Content, for the selected resource:
  - Title: glyph, name, tier tag (VITAL / RAW / REFINED / COMPONENT), description from `resources.json`.
  - **STOCK** — stored / cap (amber + "production wasted" when full), net rate, and "empty in / full in N min" at the current rate.
  - **CURRENT FLOW** — live contributors, sorted: standing buildings' flat produces/consumes (×count), recipes that are actually cycling (from the new `RecipeProcessor.applied_rates()`), crew life support with crew count.
  - **REQUIRED BY** — from data: every building that costs it ("8 to build"), consumes it ("8/min to run"), or feeds it into a recipe ("2 per cycle → 2 Oxygen, 1 Hydrogen (Electrolyze Water)").
  - **PRODUCED BY** — buildings' flat production, storage-cap raisers, recipes with per-cycle amount, /min and inputs ("+4 per 8s (30.0/min) from Water Ice 4").
- Live refresh throttled to 4×/s while visible; re-renders on building completed/destroyed so the flow section tracks the base.
- Wiring: new `EventBus.resource_inspect_requested(name)`; Resources panel columns/chips get pointer cursor and emit it on left-click (inner HBox/badge set to MOUSE_FILTER_IGNORE so the whole chip is the hit target). `RecipeProcessor` gained `get_recipe()` and `applied_rates()`.
- HUD.tscn's node list had been left with concatenated lines by the hotbar/actions removals (Godot parsed it, but it was wrong); rewritten cleanly while registering the new panel.
- Test added — `phase_6_test` check 7: inspector hidden at boot, opens on the signal with the right subject, REQUIRED BY lists Solar Array's alloy_beams build cost. `find_child` is used because chrome re-parents content under Frame/Content.
- Test: **PASS** — phase 5, phase 6, economy. Screenshot verified (`tools/screenshot.gd` gained `inspect:<resource>`).
- Files added: `scenes/ui/panels/HUDPanelResourceInfo.tscn`, `scripts/ui/panels/hud_panel_resource_info.gd`; modified: `event_bus.gd`, `recipe_processor.gd`, `hud_panel_resources.gd`, `hud.gd`, `HUD.tscn`, `phase_6_test.gd`, `tools/screenshot.gd`

## Drill + Electrolyzer scaled to the MatterForge
- Status: completed
- `buildings.json`: `mining_drill` and `electrolyzer` get `footprint_cells: 16` (was default 6) so they occupy the same 1024×512 iso box as the forge — visual, blocker and nav obstacle scale together. Art re-imported at `max_width 1024` (1024×720 and 1024×705, ~1 MB each) so nothing is upscaled at the new size.
- Note: `size` is still `[2, 2]` for both; nothing reads it (same caveat as the forge).

## Drills: regolith anywhere, full ore on a hotspot, trace ore elsewhere
- Status: completed
- Ask: a Mining Drill on a resource hotspot should still mine regolith, and mine that resource faster than a drill placed on plain ground. Doing it exposed a bigger limitation — `RecipeProcessor` fired each recipe **once per recipe type**, not per building, so a second drill, electrolyzer or forge did nothing. Fixed at the root.
- **Per-building scaling** (`recipe_processor.gd` rewritten): every cycle scales with `multiplier(key)` = number of standing buildings of the recipe's type. Input-driven recipes run in whole units and fall back to as many units as stock affords (two forges with iron for one batch make one, not zero). Published HUD rates carry the same multiplier.
- **Extraction** (`input_resource` recipes): each drill is classified ON a matching deposit (within 1 cell, same radius rule as before, now per drill via `_near_node`) or OFF. Multiplier = on-deposit drills + off-deposit drills × `trace_factor`. New `trace_factor` field in `recipes.json`: ilmenite 0.25, anorthite 0.25, water ice 0.1, helium-3 0.15, KREEP 0 (only in hotspots). So one drill on an ilmenite hotspot + one in open ground = 1.25× the recipe.
- New `drill_regolith` recipe: any Mining Drill yields 3 regolith / 6 s (half an Excavator), on or off a deposit.
- Mining Drill description and the inspector's PRODUCED BY line updated ("+5 per 10s on an Ilmenite deposit, ×0.25 elsewhere").
- Gotcha: GDScript's `%` formatting has no `%g`. Two `×%.2g` strings threw "String formatting error: unsupported format character" at runtime (not parse time), caught only because the economy test's cycle log fired. Replaced with `str(snappedf(x, 0.01))`.
- Test added — `economy_test` check 6b: second excavator → multiplier 2 and 12 regolith/cycle; off-deposit drill drills regolith, yields 1.25 ilmenite (×0.25) and no KREEP; an ilmenite node placed beside it → multiplier 1.0 and 5 ilmenite; drill on a deposit still drills regolith.
- Test: **PASS** — economy, phase 5, 6, 8, 9.
- Files modified: `recipe_processor.gd`, `data/recipes.json`, `data/buildings.json`, `hud_panel_resource_info.gd`, `tests/economy_test.gd`

## Recipes made rate-driven; full stocks no longer flicker
- Status: completed
- User report: water and water ice bounced between max and max-1. Two causes.
  1. At cap the recipe idled (`_outputs_wanted` false), consumers kept drawing, stock dipped, next 1 s refresh woke the recipe, its lump refilled to cap — a visible 600 / 599 oscillation.
  2. **Recipe output was double-counted.** Since Phase 8 the processor both published a per-minute rate (which `ResourceManager._process` integrates every frame) *and* added a lump each cycle. Every recipe ran at ~2×. Pre-existing; carried through the economy overhaul unnoticed because tests drive `try_run()` directly.
- Fix: the simulation loop is now purely rate-driven — active recipes publish rates, nothing lumps. `try_run()` survives as the manual "one discrete cycle" used by tests (and a future craft-now action). `_timers` gone. Net effect on balance: recipe throughput halves to the number the data actually says.
- `_outputs_wanted(key, recipe)`: a capped output idles the recipe only if nothing *else* is draining that resource (`get_rate(r) − this recipe's published rate ≥ 0`). If something is, the recipe keeps running, the clamp holds the stock at max, and only when drain exceeds production does the number fall — exactly the asked-for rule. `stop_at` unchanged.
- New `active_multiplier(key)` — the multiplier a recipe actually runs at (0 when idle, floored / stock-limited for input recipes). `_refresh_rates` publishes from it; tests read it.
- Test added — `economy_test` check 6c: sinter_bricks with bricks at cap and no consumer → idle; add an external drain → active. (First draft used water and failed correctly: crew drink water, so water is always drained. Kept as a comment in the test.)
- Test: **PASS** — economy, phase 5, 6, 8, 9.
- Files modified: `recipe_processor.gd`, `tests/economy_test.gd`

## Shortfall messages on placement; Messages panel renamed Chat
- Status: completed
- `build_placement_controller.gd::place_building`: an unaffordable placement now logs every short line with what you hold, then the full cost — e.g. *"Cannot build Solar Array — need Solar Cells 8 (have 3), Alloy Beams 4 (have 0). Full cost: Solar Cells 8, Alloy Beams 4, Wiring 4."* Category changed `build` → `alert` so it renders red in the log, not amber like a normal build event. Uses `ResourceManager.display_name` / `format_cost`, so names track `resources.json`.
- `HUDPanelLog` chrome title and inner header label renamed **MESSAGES → CHAT** (`hud.gd`, `HUDPanelLog.tscn`). Node name unchanged, so saved layouts and `phase_6_test` are unaffected.
- Test added — `phase_5_test` check 7: with solar cells at 0, `place_building("solar_array")` returns null and the logged message names Solar Cells, "have 0", and the rest of the cost.
- Test: **PASS** — phase 5, phase 6.

## Hospital building
- Status: completed
- New `hospital` in `buildings.json`: **`cost: {}` — free to place** (user: "not supposed to need any materials to build or run"; a first cut with a component cost was corrected); build 120 s; `footprint_cells` 16 (same box as the forge, drill, electrolyzer). **No `produces` / `consumes`** per the ask — it's a placed structure with no grid draw; crew health / radiation treatment can hook onto it later (crew_member.gd already tracks health and the solar-flare event is a stub).
- Scene `Hospital.tscn` (MatterForge template), registered in `BuildingDatabase.SCENE_PATHS`, last entry in the Build menu (expansion tier), placeholder palette white.
- Art: user's `level-1-hospital.png` through `import_building_art.gd` at 1024 → `assets/sprites/buildings/hospital.png` 1024×648. Verified in-engine at game scale.
- Test: **PASS** — economy (validates the cost lines against resources.json and that a scene exists), phase 5.
- Files added: `scenes/buildings/Hospital.tscn`, `assets/sprites/buildings/hospital.png`; modified: `buildings.json`, `building_database.gd`, `build_menu.gd`, `building.gd`
