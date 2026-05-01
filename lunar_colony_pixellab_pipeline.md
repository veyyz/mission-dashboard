# Lunar Colony — Pixellab Art Pipeline

A companion doc to `lunar_colony_autonomous_continuation.md`. Add this to your Claude Code session **alongside** the continuation prompt. Together they give the agent a parallel pipeline: code phases run on the main thread, art generation runs async in the background.

---

## The Insight

Pixellab MCP creation tools are **non-blocking**. Every `create_*` returns a UUID immediately and processes for 2–5 minutes in the background. That means:

- You can queue 30+ assets at the very start
- The code phases (2–9) take hours; the art queue completes in parallel
- By Phase 10, most assets are ready — Phase 10 shrinks to integration + audio
- Failed/missing assets fall back to the placeholder colored rects from earlier phases

**Rule:** Code phases never block on art. Always use placeholders during implementation. Swap in real art only when an asset is confirmed ready.

---

## Pre-Phase 2: Read the Godot Guides, Queue All Tier-1 Assets

Before starting Phase 2, the agent should do two things in this order:

### Step A — Fetch the Pixellab Godot guides

These are MCP resources (not tools). They contain the exact GDScript needed to convert Pixellab tileset outputs into Godot `TileSet` resources. The agent must read them before implementing any tilemap code.

```
Read MCP resources:
  pixellab://docs/godot/wang-tilesets        # for Phase 2 (ground)
  pixellab://docs/godot/isometric-tiles      # for Phase 5 (buildings)
  pixellab://docs/overview                   # general orientation
```

Save the relevant snippets to `docs/pixellab_godot.md` for later reference.

### Step B — Queue all Tier-1 assets

Submit every job below in one batch. Save the returned UUIDs to `art_queue.json`. Then continue to Phase 2.

`art_queue.json` schema:

```json
{
  "characters": [
    { "name": "alex", "id": "uuid-...", "status": "pending", "integrated": false }
  ],
  "buildings": [
    { "name": "solar_array", "id": "uuid-...", "status": "pending", "integrated": false }
  ],
  "terrain": [
    { "name": "regolith_to_rocky", "id": "uuid-...", "base_tile_ids": null,
      "status": "pending", "integrated": false }
  ],
  "objects": [
    { "name": "water_ice_node", "id": "uuid-...", "status": "pending", "integrated": false }
  ]
}
```

---

## Tier-1 Asset List

All assets below should be queued before Phase 2. Use a **consistent seed** (e.g., `seed=42`) across each category for visual cohesion.

### Crew Characters

Use `create_character` with `n_directions=8`, `size=48`, `proportions={"type":"preset","name":"chibi"}` (matches the proportions in `fq_player.png`), `view="low top-down"`. Six total — the four named in the screenshots plus two for later phases.

| Name | Description prompt |
|---|---|
| `alex` | "engineer in white and blue spacesuit with red boots, brown hair, holding a small wrench, retro-futuristic astronaut" |
| `maya` | "female scientist in purple spacesuit with ponytail, holding a handheld scanner tablet, retro-futuristic astronaut" |
| `zane` | "botanist in green spacesuit and matching cap, holding a small plant sample, retro-futuristic astronaut" |
| `rin` | "female geologist in yellow-orange spacesuit with hardhat, holding a pickaxe, retro-futuristic astronaut" |
| `medic` | "medic in white spacesuit with red cross emblem, holding a medkit, retro-futuristic astronaut" |
| `commander` | "commander in dark blue spacesuit with insignia and gold trim, no helmet on, short grey hair, retro-futuristic astronaut" |

After characters are queued, **immediately** queue their animations (no need to wait for character completion):

```python
for char_id in [alex_id, maya_id, zane_id, rin_id, medic_id, commander_id]:
    animate_character(char_id, template_animation_id="walking")
    animate_character(char_id, template_animation_id="idle")
```

### Buildings

Use `create_isometric_tile` (or `create_tiles_pro` if you want more control) with `size=32`, `tile_shape="block"`, **same seed across all** for cohesive style.

| Name | Description prompt |
|---|---|
| `landing_module` | "lunar landing module, dome-shaped with four landing legs, retro-futuristic, white and grey metal panels with rivets" |
| `solar_array` | "solar panel array on white frame, dark blue photovoltaic cells, lunar surface" |
| `rtg` | "small cylindrical RTG generator with cooling fins, grey weathered metal, glowing yellow vents" |
| `habitat_module` | "white pressurized cylindrical habitat with airlock door and small porthole windows, retro-futuristic" |
| `electrolyzer` | "industrial electrolyzer machine, white and blue with visible pipes and pressure tanks" |
| `hydroponics_bay` | "transparent geodesic dome filled with green plants and grow lights, on white base" |
| `storage_silo` | "metallic cylindrical storage silo, grey with horizontal banding and ladder" |
| `comms_dish` | "white satellite communications dish on slim tower with cabling" |
| `research_lab` | "white modular research lab with antenna array and scientific equipment on top" |
| `mining_drill` | "large industrial mining drill on tracked base, yellow and grey, lunar mining equipment" |

### Terrain (Wang Tilesets, Chained)

Use `create_topdown_tileset` with `view="low top-down"`, `tile_size={"width": 32, "height": 32}`, `transition_size=0.25`. Chain via `lower_base_tile_id` for visual continuity.

```python
# Base lunar surface variations
t1 = create_topdown_tileset(
    lower_description="smooth grey lunar regolith dust",
    upper_description="cratered rocky lunar surface with small impact pits"
)
# Chain to ice transition (for polar / shadowed regions)
t2 = create_topdown_tileset(
    lower_description="cratered rocky lunar surface",
    upper_description="bright water ice patches in lunar shadow",
    lower_base_tile_id=t1.upper_base_id  # use t1's upper as t2's lower
)
```

Save both `tileset_id` AND the returned `base_tile_id` values — they're needed both for downloading the tiles and for further chaining.

### Resource Node Objects

Use `create_map_object` with `view="high top-down"`, transparent background. These are placed on top of the terrain tilemap.

| Name | Description prompt |
|---|---|
| `water_ice_node` | "cluster of glowing cyan ice crystals on grey lunar rock, top-down view" |
| `helium3_node` | "patch of glowing purple helium-3 deposits in lunar regolith, top-down view" |
| `iron_node` | "outcropping of rusty red-brown iron ore on lunar surface, top-down view" |
| `titanium_node` | "metallic light-blue titanium veins in dark rock, top-down view" |
| `silicon_node` | "cluster of angular green-tinged silicon crystals, top-down view" |
| `rare_metals_node` | "small rocks with golden flecks of rare metals, top-down view" |
| `probe` | "small white scientific probe with antenna and solar panels, deployed on ground, top-down view" |

---

## Per-Phase Integration Step

Add this between steps 5 (commit) and 6 (update progress.md) of each phase:

### 5b. Art swap-in pass

```python
# Load queue
queue = read_json("art_queue.json")
swapped_in_this_phase = []

for category in ["characters", "buildings", "terrain", "objects"]:
    for asset in queue[category]:
        if asset["integrated"]:
            continue
        status = get_*(asset["id"])  # the appropriate get_ tool for this type
        if status.is_complete():
            download(asset["id"], save_to_assets_folder)
            replace_placeholder_in_scenes(asset["name"])
            asset["integrated"] = True
            swapped_in_this_phase.append(asset["name"])

write_json("art_queue.json", queue)
```

Then re-run the build-check (step 3) to confirm scenes still load with the swapped assets.

Log to `progress.md`:
```
- Art swapped in this phase: alex, maya, regolith_to_rocky, solar_array, water_ice_node
- Art still pending: zane, rin, habitat_module, ...
```

This is opportunistic — assets that aren't ready stay as placeholders. They'll get picked up in a later phase or in Phase 10.

---

## What This Does to Phase 10

Phase 10 in the original spec was: "Swap placeholder art for final pixel art. Add ambient hum, footstep crunch, UI clicks. Tweak balancing."

With the art pipeline running in parallel, Phase 10 collapses to:

1. **Final art sweep** — any assets still pending or that errored, retry or generate variants. Verify all scenes use real art.
2. **Audio** — Pixellab doesn't do audio. Use placeholder ambient/SFX or source from freesound.org / OpenGameArt. Wire up `AudioManager.play_sfx()`.
3. **VFX** — particle effects (dust on footsteps, drill sparks, comms ping). Pure Godot, no external assets needed.
4. **Balance pass** — tweak resource rates and building costs in `data/buildings.json` based on playtest.

This means Phase 10 becomes a 1–2 hour session instead of 5–8.

---

## Style Consistency Tips

The single biggest win for art cohesion in this pipeline:

- **Use the same `seed` value across all buildings.** Pick a number and stick with it (`seed=42` is fine). Pixellab's outputs vary considerably with seed — locking it ensures buildings feel like they came from the same world.
- **Chain tilesets via `base_tile_id`.** Each subsequent terrain transition uses the previous one's tile as its base, so colors and textures flow naturally.
- **Match the spec screenshots in your prompts.** Reference `fq_landing_site_view.png` — the existing landing module sets the visual direction (white/grey panels, rounded shapes, retro-futuristic). Echo that in every building prompt with phrases like "retro-futuristic," "white and grey panels," "rounded shapes."
- **Use `proportions: chibi` for all crew.** The reference `fq_player.png` shows a slightly chibi proportion (large head relative to body), and matching this across all six crew avoids the "one of these doesn't belong" effect.

---

## Cost / Budget Awareness

Pixellab generations cost credits. The Tier-1 batch is roughly:
- 6 characters × (1 base + 2 animations) = 18 character jobs
- 10 buildings = 10 isometric tile jobs
- 2 terrain Wang tilesets = 2 jobs (each contains 16 tiles)
- 7 resource node objects = 7 jobs
- **Total: ~37 jobs**

If your account has a job/credit limit, queue conservatively — start with the 4 named crew, the 5 most-used buildings (solar, habitat, electrolyzer, hydroponics, mining drill), one tileset, and the 6 named resource nodes. That's ~25 jobs and covers everything visible in Phases 2–9.

---

## Stop Conditions Specific to Art

In addition to the stop conditions in the continuation prompt, halt and ask if:

- Pixellab MCP tools are not available in the agent's tool list (then fall back to original placeholder-through-Phase-10 plan)
- Any asset fails generation 2 times in a row — flag it for manual review rather than retrying indefinitely
- Style across generated assets is wildly inconsistent in a way that would require regenerating most of them — better to stop and have the human review than to plow through

---

## Begin

When starting the autonomous run, the agent's first three actions should now be:

1. Read `pixellab://docs/godot/wang-tilesets`, `pixellab://docs/godot/isometric-tiles`, `pixellab://docs/overview`
2. Queue the Tier-1 asset list above, save UUIDs to `art_queue.json`
3. Begin Phase 2 per the continuation prompt
