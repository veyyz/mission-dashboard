# Plan — Strategic Hero Overlay (User-Supplied) + Gameplay Tilemap with Scattered Decorations

## Context

Reference `fq_full_world_view.png` shows a composed lunar landing-site view: dramatic crater shading, varied surface, Earth in corner, starfield. Current strategic zoom (`world_camera.gd:28` step ≤ 2 over `Ground.tscn`) renders a single procedurally-tinted grey diamond tile across 145×145 cells.

Pixellab MCP caps single images at 400×400. World is ~9216×4608 px. Stretching one Pixellab image across the world = unacceptable blur. **User will supply the giant hero overlay externally** (NASA imagery, hand-rendered, or external SD). Pipeline only needs:
1. Import + mode-swap wiring for the user-supplied backdrop (visible strategic zoom only).
2. Wang terrain tilesets for gameplay zoom (2 already in flight).
3. Optional scattered hero decorations for gameplay-zoom landmark detail.

HUD/UI is owned by parallel session — out of scope.

## Asset Inventory

### User-supplied hero backdrop

Drop file at `godot/assets/sprites/world/strategic_backdrop.png`. Any resolution (recommend ≥1920×1080; engine scales to fit world bounds).

### Base terrain tilesets (in flight)

| # | Lower → Upper | Status |
|---|---|---|
| 1 | smooth grey lunar regolith dust → cratered rocky lunar surface | **queued** `31992135-4b76-4200-847a-75fbf855ee85` |
| 2 | cratered rocky lunar surface → bright water ice patches in lunar shadow | **queued** `55dcacd5-6655-4f63-83c2-dbd2e72773e4` |

Visible only at gameplay zoom (covered by hero backdrop at strategic zoom).

### Hero decorations (optional, gameplay-zoom polish)

`create_map_object`, 256–400 px transparent, scattered as `Sprite2D` on a Decorations layer above the tilemap. Visible at gameplay zoom; covered by backdrop at strategic.

| # | Name | Size |
|---|---|---|
| 1 | crater_hero_a | 400×400 |
| 2 | crater_hero_b | 400×400 |
| 3 | crater_hero_c | 320×320 |
| 4 | crater_medium_a | 256×256 |
| 5 | crater_medium_b | 256×256 |
| 6 | crater_small_a | 192×192 |
| 7 | crater_small_b | 192×192 |
| 8 | ridge_long | 400×320 |
| 9 | ridge_short_a | 256×192 |
| 10 | ridge_short_b | 256×192 |
| 11 | rille_segment | 320×192 |
| 12 | ejecta_blanket | 400×400 |
| 13 | boulder_cluster_a | 192×192 |
| 14 | boulder_cluster_b | 256×256 |
| 15 | dust_swirl | 256×256 |

15 decorations baseline. ~20–30 instances scattered across world.

### Total batch math

- Already in flight: 2 wang tilesets
- New to queue (decorations only): 15 jobs
- Concurrent limit 8 (`art_queue.json:_concurrent_job_limit`); 6 free now
- Wall time ~3 min/job; 2 batches × 3 min ≈ 6 min total

## Generation Schedule

**Batch 1** (now, 6 jobs alongside 2 in-flight tilesets): decorations #1–6.
**Batch 2** (after Batch 1 ~3 min, 8 jobs): decorations #7–14.
**Batch 3** (after Batch 2): decoration #15 + any retries.

## Folder + Naming Convention

```
godot/assets/sprites/
├── terrain/
│   ├── regolith_to_rocky/       ← wang set 1: 16 tiles + metadata.json + tileset.tres
│   └── rocky_to_ice/            ← wang set 2
├── decorations/                  ← scattered hero overlays (gameplay zoom polish)
│   ├── crater_hero_a.png
│   └── …
└── world/
    └── strategic_backdrop.png    ← USER-SUPPLIED giant hero overlay
```

Each terrain folder: `metadata.json` (16 wang corner→tile mappings per `pixellab://docs/godot/wang-tilesets`) + `tileset.tres` Godot resource.

## Code Changes (Critical Files)

| File | Change | Reason |
|---|---|---|
| `godot/scenes/world/Ground.tscn` | Add `Sprite2D` "StrategicBackdrop" as child of Ground, `texture = preload("res://assets/sprites/world/strategic_backdrop.png")`. Position centered on world bounds (~9216×4608 px area). `z_index = -100` so tilemap and everything else paints over it when visible. Initial `modulate.a = 0`. | Backdrop covers world; mode-swap controls visibility. |
| `godot/scripts/world/ground.gd` (new function `_on_zoom_changed(level)`) | Connect to `EventBus.zoom_changed`. On `"strategic"`: tween StrategicBackdrop alpha to 1.0 + tilemap alpha to 0.0 over 0.35s. On `"gameplay"`: reverse. Reuse Tween pattern from `godot/scripts/world/orbit_map.gd:68–81`. | Mode-swap. |
| `godot/scripts/world/ground.gd:10–141` | Replace single placeholder paint: load 2 wang `TileSet` resources, pick base terrain per cell from deterministic `FastNoiseLite` (seed=42 from `art_queue.json:_seed`), `set_cell` with wang corner lookup. | Real tilemap for gameplay zoom. |
| `godot/scripts/world/ground.gd` (new function `_scatter_decorations()`) | Add `Node2D` "Decorations" child of Ground. Deterministic Poisson-disk scatter (seed=42, second noise channel) of 20–30 decoration `Sprite2D`s across world bounds. Min spacing ~6 cells. Each sprite picks a random decoration texture from `assets/sprites/decorations/`. Skip cells reserved for buildings/landing zone (`data/orbit_deposits.json`). Z-index between tilemap (0) and YSort layer. | Gameplay-zoom landmark polish. |
| `godot/scripts/tools/import_wang_tileset.gd` (new) | Per `pixellab://docs/godot/wang-tilesets` MCP doc — load 16 tile PNGs + `metadata.json` into a Godot `TileSet` resource. Reused for both wang sets. | Single converter, two inputs. |
| `godot/art_queue.json` | Add 15 decoration entries. | Track UUIDs and integration status. |

## Reusable Patterns

- `EventBus.zoom_changed` (`godot/scripts/world/world_camera.gd:49–53,86`) — fires on threshold cross. Drives the mode-swap fade.
- `_animate_fade` Tween in `godot/scripts/world/orbit_map.gd:68–81` — reuse pattern for backdrop+tilemap fade.
- Wang→Godot conversion in MCP resource `pixellab://docs/godot/wang-tilesets` — copy snippet once into `import_wang_tileset.gd`.
- `art_queue.json` schema (`godot/art_queue.json:1–4`) — supports new categories; append.
- `_seed: 42` (`godot/art_queue.json:3`) — same seed for generation + same seed for terrain noise + scatter = reproducible-on-regen world.
- `data/orbit_deposits.json` — landing zones to **exclude** from decoration scatter.

## Integration Order

1. Queue Batch 1 immediately (6 decorations). Record UUIDs in `art_queue.json`.
2. While generation runs:
   - Stub `import_wang_tileset.gd` from MCP doc.
   - Stub `_scatter_decorations()` with placeholder textures.
   - Add StrategicBackdrop `Sprite2D` to `Ground.tscn` with placeholder texture.
   - Wire `_on_zoom_changed()` mode-swap fade.
3. User drops `strategic_backdrop.png` into `godot/assets/sprites/world/`. Reload scene → backdrop visible at strategic zoom.
4. Per asset completion: download via `https://api.pixellab.ai/mcp/<resource>/<id>/<sub-path>` (UUID-gated, no API key — per `godot/docs/pixellab_godot.md:68–70`). Save into folder per convention. Mark `integrated: true` in `art_queue.json`.
5. Queue Batch 2 once Batch 1 slots free.
6. Wang tilesets done → enable variant-aware paint. Verify gameplay zoom.
7. Decorations done → enable scatter. Tune density 15–35 sprite range.

## Verification

- **Strategic squint test**: `godot/scenes/main/Main.tscn`, zoom step 0 (`world_camera.gd:10–21`). Backdrop fills viewport; tilemap and decorations hidden. Compare to `fq_full_world_view.png`.
- **Mode-swap test**: scroll-zoom from step 0 → step 9. At threshold (step 2 → 3) backdrop fades out, tilemap+decorations fade in over 0.35s. No flicker, no black frame.
- **Gameplay-zoom check**: zoom step 9. Crew walks past hero decorations → render large + sharp. Tilemap shows wang terrain variation. No clipping/sort-order bugs vs YSort buildings/crew.
- **Save/load round-trip**: scatter is deterministic (seeded). Save → load → identical decoration positions. Test via Phase 9 SaveSystem.
- **Per-tileset import test**: each wang tileset loads via `import_wang_tileset.gd` without missing-corner errors; preview scene paints autotiles cleanly.

## Out of Scope (Owned by Parallel Session)

- All HUD panel work in `OrbitMap.tscn`: Environment, Landing Module thumbnail, Confirm Landing button, Terrain Analysis / Hazards / Recommendation panes.
- Deposit ring overlays (cyan/purple/yellow dashed circles + labels).
- Resource node sprites (water_ice_node, helium3_node, iron_node, titanium_node, silicon_node, rare_metals_node, probe).
- Confirm Landing flow + camera auto-zoom-in.

## Out of Scope (Deferred / User-Owned)

- The strategic backdrop image itself (user generates externally and drops at `godot/assets/sprites/world/strategic_backdrop.png`).
- Real fog-of-war shader (Phase 11)
- Audio + VFX (Phase 10b)
- Distance-based sprite LOD (Phase 11)
