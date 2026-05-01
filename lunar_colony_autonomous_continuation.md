# Lunar Colony — Autonomous Continuation Prompt

Paste this into Claude Code after Phase 1 deliverables are confirmed present. The agent will then work through Phases 2–10 sequentially with self-verification gates, committing after each, without waiting for human approval **except at the two mandatory check-ins**.

---

## Mode of Operation

You are running autonomously. **Do not wait for approval between phases.** Complete each phase's workflow (plan → implement → build-check → test → commit → log → next), then continue.

There are exactly three things that pause you:
1. A **stop condition** (listed below) — write a STOP entry and halt.
2. A **mandatory check-in** at Phases 5 and 9 — write a CHECK-IN entry and halt.
3. **Phase 10** — do not start. Stop after Phase 9.

---

## One-Time Setup (before Phase 2)

```bash
# Verify Godot is on PATH and the right version.
godot --version    # must report 4.3 or higher

# Initialize git so we have rollback points between phases.
git init
git add -A
git commit -m "Phase 1: project skeleton"

# Working directories.
mkdir -p tests logs
: > progress.md
```

If `godot` isn't on PATH, search common locations (`which godot4`, `/Applications/Godot.app/Contents/MacOS/Godot`, `C:/Program Files/Godot/...`) and either alias it or use the full path in every command. If you can't find it at all, **STOP**.

---

## Per-Phase Workflow

Repeat this loop for each phase 2 through 9.

### 1. Plan

Append to `progress.md`:

```markdown
## Phase N: <name>
- Status: in_progress
- Started: <ISO timestamp>
- Plan:
  - <bullet list — what you'll build, in order>
```

### 2. Implement

Build to the spec in `lunar_colony_godot_prompt.md` Section 9. Stay in scope — defer anything not explicitly required to the appropriate later phase, and log what you deferred.

Use **placeholder art** (solid-color rectangles, simple shapes drawn in code, or generated SVG/PNG) for any sprite or texture. Do not block on art assets — that's Phase 10's job.

### 3. Build-check

Boot the project headlessly and look for errors:

```bash
timeout 30 godot --headless --quit-after 120 project.godot \
  > logs/phase_N_build.log 2>&1
```

Then scan the log:

```bash
grep -iE "ERROR|SCRIPT ERROR|Parse Error|Failed|Cannot" logs/phase_N_build.log
```

If grep finds anything, fix and re-run. After **3 consecutive failures** on the same phase, STOP.

### 4. Functional test

Write `tests/phase_N_test.gd` (a `SceneTree` script) that exercises the phase's new functionality. The test must print **`PASS`** on success or **`FAIL: <reason>`** on failure, and call `quit()` either way.

Run it:

```bash
godot --headless --script tests/phase_N_test.gd > logs/phase_N_test.log 2>&1
grep -E "^(PASS|FAIL)" logs/phase_N_test.log
```

If the test fails, fix and re-run. Same 3-failure stop rule.

A test stub:

```gdscript
extends SceneTree

func _init() -> void:
    var failures: Array[String] = []

    # Check 1: Ground scene loads
    var scene = load("res://scenes/world/Ground.tscn")
    if scene == null:
        failures.append("Ground.tscn missing")
    
    # Check 2: ...

    if failures.is_empty():
        print("PASS")
    else:
        for f in failures: print("FAIL: ", f)
    quit()
```

### 5. Commit

```bash
git add -A
git commit -m "Phase N: <one-line summary>"
```

### 6. Update progress.md

```markdown
- Status: completed
- Completed: <timestamp>
- Implemented:
  - <bullets>
- Deferred to later phases:
  - <bullets, with target phase>
- Files added/changed: <count + key paths>
- Test: PASS
```

### 7. Continue

Move directly to Phase N+1. Do not wait.

---

## Stop Conditions

Write a `## STOP at Phase N` entry to `progress.md` describing the issue, then halt and yield to the human, if any of these are true:

- **3 consecutive build or test failures** you cannot resolve
- **A design decision is needed** that isn't covered by the spec or the reference screenshots
- **The spec contradicts the screenshots** in a way that affects implementation
- **You'd need a real (non-placeholder) art or audio asset** to proceed — you should never hit this if you use placeholders correctly, but flag it if you do
- **An external dependency** is required (a Godot addon, a font file, a system library)
- **Godot CLI isn't available** or doesn't support a flag you need
- **A previous phase's invariant breaks** and the fix would be larger than the current phase's scope

---

## Mandatory Check-Ins

These are not stop conditions — the build is healthy, you just shouldn't continue without a human eye.

### CHECK-IN after Phase 5

The first runnable prototype: crew, resources, time, three buildings. Visual fidelity is still placeholder.

Write to `progress.md`:

```markdown
## CHECK-IN at Phase 5
- Built: <high-level summary>
- Run: `godot project.godot`
- What to verify visually:
  - Crew member moves with WASD
  - Day/night tint cycles
  - Resource bar updates when a Solar Array completes
  - Construction progress bar advances when Engineer is adjacent
- Known placeholders: <list>
- Deferred items so far: <consolidated list>
```

Halt.

### CHECK-IN after Phase 9

Mechanically complete. Win/lose works, save/load works, events fire. Ready for art and audio.

Write a similar entry. **Do not start Phase 10** — that's a separate human-driven session.

---

## Per-Phase Done Criteria (testable)

Your test scripts must verify these. They're the contract for "phase complete."

### Phase 2 — Ground scene + crew movement
- `res://scenes/world/Ground.tscn` exists and loads without errors
- Contains a `TileMap` (any cell size) with ≥1 painted tile
- Contains exactly one `CharacterBody2D` named `CrewMember` with a `Sprite2D` (placeholder colored rect is fine)
- Contains a `Camera2D` whose `target` is the crew member, OR a script attaching it to the crew
- A parent `Node2D` has `y_sort_enabled = true`
- Programmatically simulating an `InputEventKey` for `move_up` for 0.5s causes the crew's `position.y` to decrease

### Phase 3 — Resources + time
- `ResourceManager.add("power", -50)` reduces current power by 50 and the test catches `EventBus.resource_changed`
- `TimeManager.set_time_scale(60.0)` causes `current_minute_of_day` to advance ≥1 game minute per real second (verify with `await get_tree().create_timer(1.0).timeout`)
- A `CanvasModulate` node exists in the ground scene and its color changes when phase changes
- Fast-forwarding through a full day fires `phase_changed` for each of `day`, `twilight`, `night`

### Phase 4 — Full crew + selection
- Six `CrewMember` instances exist as children of a `CrewContainer` (or equivalent) node
- Each has a unique `crew_name`, `role` (enum), and `role_skill` between 70 and 95
- Sending the `select_crew_3` input action emits `EventBus.crew_selected` with `crew_id == 3`
- Calling `crew.move_to(Vector2(100, 100))` sets a `NavigationAgent2D.target_position`
- After `await get_tree().physics_frame; await get_tree().physics_frame`, `agent.get_next_path_position()` returns a non-zero vector (the Phase 4 navigation gotcha is handled)

### Phase 5 — Buildings v1
- ≥3 building scenes in `scenes/buildings/`: `SolarArray.tscn`, `HabitatModule.tscn`, `MiningDrill.tscn`
- A `BuildingDatabase` autoload or system loads `data/buildings.json` and exposes definitions by key
- A build menu UI (any visual style) lets the player pick a building and place it on the tilemap with a ghost preview
- Placing a Solar Array (after passing cost check) deducts the listed `materials` and `silicon` from `ResourceManager`
- A `ConstructionSite` node spawns at the placement; an Engineer pathfinding adjacent ticks its progress
- On completion, the construction site is replaced with the building scene and `EventBus.building_completed` fires
- After completion, the building's `produces` and `consumes` rates are reflected in `ResourceManager.set_rate()`

### **CHECK-IN — halt here.**

### Phase 6 — Full HUD
- `scenes/ui/HUD.tscn` exists as a `CanvasLayer`
- All panels from Section 8 of the spec are present as **separate scenes** instantiated under HUD
- Resource bar values bind to `EventBus.resource_changed`
- Crew bar binds to crew selection events
- Hotbar slots 0–9 are visible and respond to number-key presses
- Tutorial guide panel can be dismissed with F1
- Layout matches the bottom/top/side anchoring shown in `fq_game_ui.png` (exact pixel match not required, but panels must be in the right corners)

### Phase 7 — Strategic map + landing flow
- `scenes/world/OrbitMap.tscn` exists with a 10×10 grid overlay (A–J × 1–10)
- Resource deposit markers are clickable and their data lives in `data/orbit_deposits.json` (you create this file)
- Hovering a tile shows a tooltip with terrain type, hazards, recommendation
- "Confirm Landing" stores the chosen tile in `GameState.selected_landing_tile` and transitions to the ground scene
- Ground scene `_ready()` reads `GameState.selected_landing_tile` and seeds the local resource node distribution accordingly

### Phase 8 — Scanning, fog of war, samples
- `R` (scan) reveals resource nodes within radius; Geologist gets 2× radius
- `F` (deploy probe, Scientist only) places a static probe that permanently reveals fog in a large radius
- `G` (collect sample) on a node adds a `samples` resource and emits `sample_collected`
- A fog-of-war shader on a `CanvasLayer` darkens unexplored areas; crew vision and probes punch holes
- `samples` delivered to a Research Lab convert to `science` via the recipe in `recipes.json`

### Phase 9 — Win/lose, events, save/load
- Win: net rate on `power`, `oxygen`, `food` all positive for 3 in-game days continuously triggers a win screen
- Lose: any of those three hitting 0 triggers a fail screen
- `events.json` events trigger probabilistically per the `trigger_chance_per_day` and `min_day` fields
- `SaveSystem.save_game()` produces a JSON file in `user://saves/` containing all state needed to fully restore the session
- `SaveSystem.load_game()` restores resources, time, all crew positions/states, all placed buildings, and the fog bitmap
- Round-trip test: save → modify state → load → state matches the save (verify in test script)

### **CHECK-IN — halt here. Do not start Phase 10.**

---

## Logging Convention

Everything goes in `progress.md`. The user should be able to read that one file and know:
- What phase you're on
- What you built in each completed phase
- What you deferred and to where
- Any STOPs or CHECK-INs

Keep entries terse — bullets, not paragraphs.

---

## Begin

Start with Phase 2 now. Good luck.
