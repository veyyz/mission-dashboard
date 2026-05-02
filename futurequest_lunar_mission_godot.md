# Lunar Colony — Godot 4 Development Prompt

> Paste this into Claude Code (or any capable coding agent) along with the attached reference screenshots. Work through it phase by phase rather than asking for everything at once — the agent will produce far better code if you let it complete and verify each phase before moving on.

---

## 1. Project Identity

**Working title:** FutureQuest Lunar Settlement Mission
**Engine:** Godot 4.6+ (use GDScript, not C#)
**Genre:** Real-time colony management / survival sim
**Perspective:** True isometric. Use Godot 4's native isometric `TileMap` mode (`tile_shape = 1` Isometric, `tile_layout = 5` Diamond Down). Single seamlessly-zoomable world — there are **no scene transitions** between strategic and gameplay views, only camera zoom. The strategic landing-site selection screen and the close-up gameplay screen are the **same world** at different zoom levels.
**Target platforms:** Desktop first (Windows/Mac/Linux). Keep mobile in mind but don't optimize for it yet.
**Art style:** Hand-pixeled, 128 px characters, muted lunar palette (greys, deep blues, warm UI accents in amber and cyan). Reference the attached screenshots for exact tone — dark backdrop, glowing UI panels with rounded corners and 1px highlight strokes, color-coded character name tags.

---

## 2. Vision in One Paragraph

The player commands a multiplayer expedition that lands on the Moon and must build a self-sustaining colony before resources run out. The game opens **zoomed out** on a single isometric world map where the player picks a landing site based on resource deposits and terrain. Confirming the landing site spawns the crew + landing module on the chosen tile and **smoothly zooms the camera in** — no scene change. From the close-up zoom the player directly controls crew members (WASD or click-to-move), assigns them to extract resources, deploy probes, run experiments, and construct habitat modules. The player can **zoom back out at any time** to see the broader map and re-survey deposits; the strategic UI panels reappear at strategic zoom and fade out as the camera zooms back in. The fantasy is "Rimworld meets Into the Breach meets Moonlighter" — tactile pixel art, deep systems, but a tighter scope and a clear win condition (build a sustainable colony).

---

## 3. Visual Style Reference

Five reference images are attached. Treat them as **canonical** for UI layout, color, and character proportions:

| File | Purpose |
|---|---|
| `fq_landing_site_view.png` | Ground-level 3/4 gameplay view with HUD, crew nameplates, suggested landing zone beacons |
| `fq_landing_site_characters.png` | Zoomed landing-site selection screen — terrain analysis, landing module preview, confirm/cancel buttons |
| `fq_full_world_view.png` | Strategic orbital map with grid coordinates (A–J × 1–10), resource deposits color-coded by type, Earth in background |
| `fq_game_ui.png` | Full in-game HUD with all panels, crew bar, hotbar, minimap, system status |
| `fq_player.png` | Reference character sprite — astronaut in white/blue suit |

**Hard style rules:**
- All UI panels: dark navy background (`#0d1420`-ish) at ~92% opacity, 1px cyan border, subtle inner glow, rounded ~6px corners.
- Section headers: small caps, cyan (`#5db5d6`), letter-spaced.
- Resource icons in HUD: amber lightning (power), cyan O₂, green leaf (food), grey cube (materials), purple flask (science), amber person silhouette (crew).
- Character nameplates: rounded rectangle, color matches role (Engineer = blue, Scientist = purple, Botanist = green, Geologist = amber).
- All text: monospace or pixel font (use a free one like `m5x7`, `Pixeloid`, or `Press Start 2P` for headers + a cleaner pixel font for body).
- Never use pure white or pure black. Off-white `#e8edf2` and near-black `#070a10`.

---

## 4. Core Gameplay Loop

```
Strategic zoom (camera zoomed out, full world visible)
  → Browse 10×10 grid (A–J × 1–10), inspect resource deposits and tile data
  → Pick landing site → camera smooth-zooms in to the chosen tile
  → Crew + landing module spawn there
Gameplay zoom (camera zoomed in, real-time, pausable)
  → Move crew, scan, extract, build, research
  → Manage hourly resource tick (power/O₂/food consumption)
  → Day cycle (6:00 → 22:00 → night phase, lower power gen, higher O₂ drain)
  → Mission objectives unlock progressively
  → Player can zoom out to strategic at any time (and back)
Endgame
  → Sustainability achieved (positive net rate on power/O₂/food for 3 in-game days) → win
  → Any of power/O₂/food hits 0 → fail state
```

A full session should land around 4–8 hours of play.

---

## 5. Game Systems (Implementation Spec)

### 5.1 Resource System

Six tracked resources, each with `current`, `max`, and `rate_per_min`:

| Resource | Icon | Sources | Sinks |
|---|---|---|---|
| Power ⚡ | amber bolt | solar panels, RTGs, helium-3 reactors | every powered building, life support |
| Oxygen O₂ | cyan | electrolyzers (need water + power), oxygen tanks | crew breathing, airlock cycles |
| Food 🌱 | green leaf | hydroponics (need water + power + silicon), ration stockpile | crew daily consumption |
| Materials 📦 | grey cube | iron/titanium extractors, asteroid debris | construction, repairs |
| Science 🧪 | purple flask | research lab, sample analysis | unlocking tech tree nodes |
| Crew 👥 | amber person | rescue events, future arrivals | deaths, illness |

Implement as an autoload singleton `ResourceManager` with signals: `resource_changed(name, current, max, rate)`. UI subscribes to the signal — never poll.

### 5.2 Crew System

Six initial crew members, four roles. Each crew member is a `CharacterBody2D` with:

```gdscript
class_name CrewMember
extends CharacterBody2D

@export var crew_name: String
@export var role: Role  # enum: ENGINEER, SCIENTIST, BOTANIST, GEOLOGIST, MEDIC, COMMANDER
@export var max_health: int = 100
@export var max_stamina: int = 100
@export var role_skill: int = 80  # 0-100, the "85" / "92" shown on nameplates

var current_health: int
var current_stamina: int
var current_oxygen: float = 100.0  # depletes when outside habitat
var current_task: Task  # null when idle
var nameplate: Nameplate  # child UI node
```

**Role bonuses (do not skip — these make roles feel different):**
- **Engineer** — +50% build speed, can repair structures, only role that can construct power infrastructure.
- **Scientist** — analyzes samples (converts samples → science), runs research lab faster, only role that can deploy probes.
- **Botanist** — +50% hydroponics yield, can cultivate moon-soil experiments, tends to crew morale.
- **Geologist** — +50% extraction speed on ore deposits, finds hidden resource nodes when scanning, identifies safe terrain.
- **Medic** (unlock later) — heals injured crew, treats radiation exposure.
- **Commander** (unlock later) — passive +10% to all crew nearby.

Selection: keys `1`–`6` select crew member. Selected crew has a glowing ring under their feet. Multi-select with shift-click. WASD moves selected crew (or just commander); click-to-move issues pathfinding orders to selected crew.

Note: WASD and click-to-move only operate in gameplay zoom; in strategic zoom the same clicks select tiles for landing-site review (or, post-landing, recenter the camera on a tile).

### 5.3 Building / Construction System

Buildings are `StaticBody2D` scenes with a `Buildable` component. Construction flow:
1. Player opens build menu (hotbar slots 5–9 or a dedicated build panel).
2. Selects building type → ghost preview follows cursor, snapped to the **isometric** tilemap grid (one tile per cell — see §6 for tile dimensions).
3. Red tint = invalid (collision, off-map, missing resources). Green tint = valid.
4. Click to place → spawns "construction site" node with a progress bar.
5. Engineer auto-pathfinds to the site (or player assigns one); construction ticks while engineer is adjacent.
6. On completion, swap construction site for finished building scene.

**Minimum building set for v1:**
- Habitat Module (provides O₂ regen + sleep slots for crew)
- Solar Array (power, daytime only)
- RTG (power, constant, costs rare metals)
- Electrolyzer (water → O₂)
- Hydroponics Bay (food)
- Storage Silo (raises material/water cap)
- Comms Dish (unlocks events, optional)
- Research Lab (converts samples → science)
- Mining Drill (extracts from a resource node)

### 5.4 Exploration & Scanning

- **Move (WASD)** — direct control of selected crew.
- **Scan (R)** — short cooldown, reveals resource nodes within radius. Geologist gets 2× radius.
- **Deploy Probe (F)** — Scientist only. Probe is a small static unit that reveals fog-of-war in a large radius for the rest of the mission.
- **Collect Sample (G)** — interact with a resource node or anomaly to take a sample (consumed → science at lab).

Use a fog-of-war shader on a `CanvasLayer` above the tilemap. Probes / crew vision punch holes in the fog with a soft falloff.

### 5.5 Time & Day Cycle

- 1 in-game day = 16 minutes real-time at 1× speed.
- Speed controls: pause, 1×, 2×, 4× (keys `Space`, `1`, `2`, `3` on the time panel — note: don't conflict with crew select; put time controls on F-keys or a UI button).
- Day phase (06:00–18:00): solar panels active, normal O₂ drain.
- Twilight (18:00–22:00): solar at 30%.
- Night (22:00–06:00): solar at 0%, O₂ drain +20% outside habitat (suit cooling overhead).
- Implement as a `TimeManager` autoload emitting `phase_changed(phase)` and `tick(in_game_minutes)`.

### 5.6 Strategic Zoom (Landing Site Selection)

**Same scene as gameplay.** The Strategic view is the world camera zoomed all the way out, with a UI overlay drawn on top.

- A 10×10 grid (A–J × 1–10) is rendered as a UI overlay above the isometric tilemap.
- Resource deposit markers are clickable at this zoom; clicking selects the tile and opens the per-tile readout (terrain type, hazards, nearby resource access, recommendation).
- The "suggested landing zone" pulses gently.
- Earth renders in the sky/corner of the same world view.
- **Confirm Landing** spawns the crew + landing module on the chosen tile and triggers a smooth camera zoom-in to gameplay range — no scene change, no asset reload, the same `TileMap` continues to render the same world data.
- After landing, the player can press a "Zoom out" button (or scroll wheel out to a threshold) to return to strategic zoom; the strategic-only UI panels (Mission Day, Resources Detected, Landing Module info, Terrain Analysis, Hazards, Recommendation) re-fade-in. This is how the player re-surveys deposits or repositions across the map.

This unification means: one persistent world state, one resource manager, one time manager, one save format. Strategic and gameplay are camera modes, not separate game states.

### 5.7 Save / Load

JSON-based save (use `FileAccess` + `JSON.stringify`). Save: resources, time, crew states + positions, all placed buildings, fog-of-war bitmap (compressed). Autosave every in-game day.

---

## 6. Technical Stack & Conventions

- **Godot 4.6+**, GDScript, Forward+ renderer (or Compatibility for low-end).
- **Resolution:** design at 1920×1080 with `viewport` stretch mode + `keep` aspect. Pixel-art assets use `texture_filter = NEAREST` and `snap_2d_transforms_to_pixel = true`.
- **Tilemap (true isometric, committed):**
  - Use a `TileMapLayer` for the ground; a second `TileMapLayer` for overlay decals (rocks, dust, craters).
  - `TileSet.tile_shape = 1` (Isometric)
  - `TileSet.tile_layout = 5` (Diamond Down)
  - `TileSet.tile_size = Vector2i(W, W/2)` — typical values: `(32, 16)`, `(64, 32)`, `(128, 64)`. We're using `(64, 32)` to match the 128px crew sprite scale.
  - `TileSetAtlasSource.texture_origin = Vector2i(0, -H/2)` (or whatever offset puts the visible tile face on the diamond floor) — without this, tiles float above grid centers.
  - Pixellab outputs `block`-shape isometric tiles whose visible face is the top diamond; the texture_origin offset is what aligns those to the iso grid.
- **Y-sort:** the parent `Node2D` and the iso `TileMapLayer` itself both need `y_sort_enabled = true`. Buildings and crew live as siblings under a Y-sorted parent; their `y_sort_origin` should be set to put their "feet" at the cell floor (not the sprite top).
- **Camera & zoom:** single `Camera2D` whose `zoom` is animated via `Tween` between strategic and gameplay ranges. Two named zoom presets (`STRATEGIC_ZOOM = Vector2(0.4, 0.4)`, `GAMEPLAY_ZOOM = Vector2(2.0, 2.0)` — tune to taste). Strategic UI panels listen for camera zoom-changed signals and fade themselves in/out. Mouse-wheel scrolls between presets; pressing a UI "zoom out" button snaps back to strategic.
- **World map size:** single map of ~256×256 iso cells covers the 10×10 strategic grid (each strategic cell = ~25×25 iso cells of detailed terrain). Procedurally generate or pre-author resource deposits per strategic cell.
- **Input:** define actions in `InputMap`, never check raw key codes in code.
- **Signals over polling.** Always.
- **Autoloads:** `GameState`, `ResourceManager`, `TimeManager`, `EventBus`, `SaveSystem`, `AudioManager`.
- **Code style:** snake_case for vars/funcs, PascalCase for classes/scenes, SCREAMING_SNAKE for enums and constants. One class per file. Use `class_name` for any class instantiated from elsewhere.

---

## 7. Project Structure

```
res://
├── assets/
│   ├── sprites/        # crew/, buildings/, tiles/, ui/, fx/
│   ├── fonts/
│   ├── audio/          # sfx/, music/, ambient/
│   └── shaders/
├── scenes/
│   ├── main/           # Main.tscn, MainMenu.tscn
│   ├── world/          # GroundScene.tscn, OrbitMap.tscn
│   ├── crew/           # CrewMember.tscn, Nameplate.tscn
│   ├── buildings/      # one .tscn per building
│   ├── ui/             # HUD.tscn, panels/, modals/
│   └── fx/
├── scripts/
│   ├── autoload/
│   ├── crew/
│   ├── buildings/
│   ├── systems/        # resource, time, fog, pathfinding helpers
│   ├── ui/
│   └── utils/
├── data/               # JSON: building definitions, recipes, events
├── saves/              # user save dir (mirrored to user://)
└── project.godot
```

Define buildings, recipes, and events as **data files** (JSON or `.tres` Resources), not hard-coded. This is non-negotiable — it makes balancing and modding trivial.

Example `data/buildings.json`:
```json
{
  "solar_array": {
    "display_name": "Solar Array",
    "cost": { "materials": 40, "silicon": 20 },
    "build_time_seconds": 30,
    "size": [2, 2],
    "produces": { "power": 15 },
    "active_phases": ["day", "twilight"]
  }
}
```

---

## 8. UI Implementation Notes

Build the HUD as a single `CanvasLayer` scene with these child panels (match screenshot 4 exactly for layout):

- **Top-left:** Day/time block + Mission Overview + Environment + Resources Detected (collapsible)
- **Top-center:** Resource bar (power, O₂, food, materials, science, crew) with `+X/min` rate text underneath each
- **Top-right:** Tutorial Guide (first-run only, dismissible) + buttons (map, mail/events, settings, menu)
- **Middle-left:** Messages/Log (scrollable, filter tabs)
- **Bottom-left:** Crew bar (1–4 portraits with stamina/skill bars, click to select)
- **Bottom-center:** Quick Actions (Move, Scan, Deploy Probe, Collect Sample, Crew Menu) with key hints
- **Bottom-right:** Minimap + System Status + Power/O₂ meters
- **Bottom edge:** 0–9 hotbar (build menu, tools, blueprints, flag/marker)

Every panel should be its own scene (`HUDPanelResources.tscn`, `HUDPanelCrew.tscn`, etc.) so they can be toggled, repositioned, or replaced without touching the main HUD scene. Use `Control` nodes with anchors set so the layout survives any resolution.

---

## 9. Development Phases

**Do not try to build all of this in one go.** Have the agent work through these phases in order, committing after each one and showing a runnable build before moving on.

### Phase 1 — Project skeleton (1 session)
- Create the project, set rendering settings, create the folder structure, add placeholder autoloads with stub functions.
- Make a minimal `Main.tscn` that boots into a black scene with "Lunar Colony" text. Verify it runs.

### Phase 2 — World scene + crew movement
- Single **isometric** `TileMapLayer` (per §6 settings — `tile_shape=1`, `tile_layout=5`, diamond grid). A placeholder iso tileset (one solid-color block tile generated at runtime is fine) painted across a small patch.
- One `CrewMember` you can move with WASD. Camera follows. Y-sort works so the crew sprite passes behind a placeholder rock when it should — both the parent Node2D and the TileMapLayer have `y_sort_enabled = true`.

### Phase 3 — Resources + time
- `ResourceManager` with all six resources, a debug panel showing current values + rates.
- `TimeManager` with day/night cycle. Visual day/night tint via a `CanvasModulate`.

### Phase 4 — Full crew (4–6 members) + selection
- All crew members with role data, nameplates, 1–6 selection, shift-multi-select, click-to-move pathfinding (Godot's `NavigationAgent2D`).

### Phase 5 — Buildings v1
- 3 buildings end-to-end: Solar Array, Habitat, Mining Drill. Build menu, ghost preview, construction progress, engineer assignment, completion → resource production.

### Phase 6 — Full HUD
- Replace debug panel with the real HUD per Section 8. Match screenshot 4 layout.

### Phase 7 — Strategic zoom + landing flow
- Camera zoom system with two presets (strategic / gameplay) and `Tween`-animated transitions; mouse-wheel + UI button trigger.
- Expand the world to the full 10×10 strategic-grid scale (~256×256 iso cells); seed resource deposits per strategic cell from `data/orbit_deposits.json`.
- Strategic-only UI overlay (Mission Day, Environment, Resources Detected, Landing Module info, Terrain Analysis, Hazards, Recommendation, A–J × 1–10 grid labels, Suggested Landing Zone marker) per `fq_full_world_view.png` — fade in at strategic zoom, fade out at gameplay zoom.
- Resource deposit markers clickable at strategic zoom; tile-readout panel updates from the clicked tile.
- "Confirm Landing" spawns crew + landing module on the chosen tile and `Tween`-zooms the camera to gameplay range. Landing is one-shot per session (post-landing, the strategic zoom still works for re-surveying but the Confirm Landing button hides).

### Phase 8 — Remaining buildings, scanning, fog of war, samples
- Round out the building set, add R/F/G actions, fog shader, sample → science loop.

### Phase 9 — Win/lose conditions, events, save/load
- Sustainability check, fail states, basic random events (meteor shower, equipment failure, supply drop), JSON save/load.

### Phase 10 — Art, audio, polish
- Swap placeholder art for final pixel art. Add ambient hum, footstep crunch on regolith, UI clicks. Tweak balancing.

### Phase 11 — Performance & culling
With the iso world at ~145×145 cells (~21,000 tiles) the strategic-zoom view paints the entire map every frame. At gameplay zoom most of that is off-screen. Items to land in this phase:
- **TileMapLayer viewport culling** — Godot 4 already culls cells outside the camera's visible rect, but the rect grows huge at strategic zoom. Add a tighter clip rect when at gameplay-zoom steps.
- **Crew + building visibility distance** — hide (or set `visible = false` on) any `CrewMember` / `Building` / `ConstructionSite` whose `global_position` lies outside `Camera2D.get_screen_center_position()` ± a margin. Gameplay loops still tick (resources, navigation, construction progress); only rendering is suppressed.
- **Group-tagged scan**: artifacts in group `cullable` get hidden when off-screen. Same convention as `screen_upright`.
- **Distance-based LOD for sprites** at extreme zoom-out — swap the 128px crew sprite for a small dot/pip at strategic zoom so the strategic view reads as a map view (per `fq_full_world_view.png`).
- **Strategic-zoom UI overlay**: when zoomed all the way out, hide individual crew/building sprites and replace with the resource-deposit / landing-zone overlay panels (per spec §5.6). Reduces draw calls and matches the reference screenshot.
- **Profile pass** — verify FPS at all 10 zoom steps with full crew + 30 placed buildings; flag any draw-call hotspots.

---

## 10. Specific Godot 4 Gotchas

- `@onready` not `onready var`. `@export` not `export var`.
- Signals are connected with `signal_name.connect(callable)`, not `connect("signal_name", ...)`.
- For pixel-perfect, set the project's stretch mode to `viewport`, set the base resolution low (e.g., 480×270 → 4× scale to 1920×1080) **OR** keep 1920×1080 and rely on per-texture nearest filtering. Don't mix both approaches.
- `NavigationAgent2D` works but you must `await get_tree().physics_frame` once before reading its first path, or you'll get a zero-length path on the first call.
- Use `Tween` for UI animations, not `AnimationPlayer`, when the animation is dynamic (e.g., resource bar lerps).
- Y-sort's `y_sort_origin` lets you tweak the "feet" position of multi-tile sprites — set it for buildings so they sort against crew correctly.
- **Isometric TileMap pitfalls:**
  - If tiles "float" inside grid cells, your `TileSetAtlasSource.texture_origin` is wrong — for `tile_shape=1` with `tile_size=(64, 32)`, the offset is typically `Vector2i(0, -16)` to anchor the visual top to the diamond floor. Adjust per source if Pixellab's `block`-shape iso tiles render with extra height.
  - `tile_layout = 5` (Diamond Down) is the layout that matches Pixellab's iso block tiles. Diamond Right (4) inverts the long axis and looks broken with their tile shape.
  - Use the **Rect Tool (R)** in the TileMap editor when painting iso terrains in corner-matching mode (`terrain_set_0/mode = 0`); the Paint Tool (D) fights the corner system.
  - Y-sort must be enabled on **both** the parent Node2D and each iso `TileMapLayer`, not just the parent. Without it on the layer, multi-cell buildings sort as a single y position and clip wrong.
  - Pixellab character sprites are rendered "low top-down" — they composite over an iso tilemap correctly when their `y_sort_origin` puts their feet at `position.y` (not the sprite top).
- **Camera zoom for unified strategic/gameplay:** animate `Camera2D.zoom` via `Tween`, not by reparenting or reloading scenes. Connect a custom signal (e.g., `EventBus.zoom_changed(level: String)` where level is `"strategic"` or `"gameplay"`) so UI panels know when to fade.

---

## 11. Stretch Goals (only after v1 ships)

- Tech tree (spend science to unlock recipes/buildings)
- Multi-floor habitat interiors (interior view when crew enters habitat)
- Trading with Earth (comms dish events)
- More biomes (mare, highlands, polar with permanent ice)
- Modding hooks (load extra `data/` JSON from `user://mods/`)
- Steam achievements
- Multi-language (Godot's tr() + CSV)

---

## 12. Deliverables Checklist for Each Phase

For every phase, the agent should produce:
- [ ] Working code committed
- [ ] A runnable build (no console errors on startup)
- [ ] A short list of what was implemented and what was deferred
- [ ] Any new `data/` files documented in a `data/README.md`
- [ ] A 30-second test plan I can run myself to verify the phase works

---

## How to Use This Prompt

1. Start a fresh Claude Code session in an empty directory.
2. Paste the **whole document above**, then say: *"Begin Phase 1. When you're done, stop and wait for me to verify before starting Phase 2."*
3. After each phase, run the build, report any issues, and tell the agent to proceed.
4. Keep the reference screenshots accessible — re-attach them when working on UI phases (6, 7).

Good luck, Commander.
