# Pixellab → Godot Integration Notes

Distilled from `pixellab://docs/overview`, `pixellab://docs/godot/wang-tilesets`,
and `pixellab://docs/godot/isometric-tiles`. For full text re-fetch the MCP resources.

## Non-blocking pipeline
- All `create_*` tools return UUIDs immediately. Generation is 2–5 min in the background.
- Use `get_*` tools to poll status. UUID is the access key — no auth on download URLs.
- Animations can be queued **right after** `create_character` — no need to wait for the
  character to finish.

## Wang (top-down) tilesets — Phase 2 ground tiles
Generation: ~100 seconds.
After completion, two split-format downloads are exposed:
- `/mcp/tilesets/{id}/metadata` → `<name>_metadata.json`
- `/mcp/tilesets/{id}/image`    → `<name>_image.png`

Convert to Godot terrain `.tres` with the headless converter:
```bash
godot --headless -s pixellab_tileset_converter.gd \
  regolith_to_rocky_metadata.json regolith_to_rocky_image.png \
  > logs/wang_convert.log 2>&1
```
Output is `combined_terrain.tres` plus an atlas preview PNG.

Critical TileSet settings (non-iso):
- `tile_shape = 0` (square)
- `terrain_set_0/mode = 0` (corner matching — must use Rect Tool R, NOT Paint D)

Connect tilesets via `lower_base_tile_id = previous.upper_base_id` to keep palettes
contiguous (regolith → rocky → ice etc.).

## Isometric tiles — Phase 5 buildings
Generation: ~10–20 seconds.
Recommended params: `size=32`, `tile_shape="block"`, `seed=42` for cohesion across all
buildings. The block shape gives ~50% canvas height for the chunky 3D look.

Critical TileSet settings (iso):
- `tile_size = Vector2i(32, 16)` — diamond grid
- `tile_shape = 1` (isometric)
- `tile_layout = 5` (Diamond Down)
- `texture_origin = Vector2i(0, -8)` — pulls tile up so it sits on grid floor
- `y_sort_enabled = true` on Node2D **and** the TileMapLayer

For our buildings we likely don't need a tilemap — each building is its own scene and
just uses the iso tile as its sprite. Y-sort still required for the parent Node2D
that contains crew + buildings.

## Characters — Phase 4 crew
- `n_directions=4` (S/W/E/N) is enough for WASD-style movement and finishes faster
  (~2–3 min vs 3–5 min for 8-dir).
- `proportions='{"type":"preset","name":"chibi"}'` matches the reference `fq_player.png`.
- `size=48`, `view="low top-down"`.
- For walking, queue immediately after create with `animate_character(id, template_animation_id="walking")`.
  Template animations are 1 generation per direction — cheap.

## Map objects — resource nodes
Use `create_map_object` with `view="high top-down"` and transparent background. Per the
reference screenshots, nodes sit on top of the tilemap as decals.

## Style consistency
- `seed=42` across every isometric tile and every map object.
- Echo phrases like *"retro-futuristic"*, *"white and grey panels"*, *"rounded shapes"*
  in every building prompt to match the reference landing module.
- Pure black/white forbidden — the in-game palette uses `#0d1420` and `#e8edf2`.

## Download URL pattern
`https://api.pixellab.ai/mcp/<resource>/<id>/<sub-path>` — UUID gates access; no API
key required for the download leg. Use `curl --fail -o local.png "<url>"` from the
project root so paths line up with `res://assets/sprites/...`.
