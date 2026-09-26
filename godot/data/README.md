# Data Files

All gameplay content (buildings, recipes, events) lives here as JSON.
Loaded at runtime by relevant systems — never hard-code these values in scripts.

## Files

- `resources.json` — every tracked resource: display, HUD group, start/cap, per-crew life-support drain. Display order = file order.
- `buildings.json` — building definitions (cost in fabricated components, size, production, consumption, raises_cap)
- `recipes.json` — extraction / refining / fabrication recipes. `stop_at` idles a recipe once an output stock is reached.
- `events.json` — random mission events

## Loader Convention

Each consuming system loads its file once at startup and caches the dictionary.
Example pattern (Phase 5):

```gdscript
const BUILDINGS_PATH := "res://data/buildings.json"

var _buildings: Dictionary = {}

func _ready() -> void:
    var f := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
    _buildings = JSON.parse_string(f.get_as_text())
```

## Schema

See each file's structure. Loaders should be **forward-compatible** —
tolerate unknown fields rather than erroring. Removing fields requires
a code update.

## Modding (stretch goal, post-v1)

Player mods will load additional JSON from `user://mods/` and merge over
these defaults. Keep keys stable to avoid breaking saves.
