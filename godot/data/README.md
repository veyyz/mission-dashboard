# Data Files

All gameplay content (buildings, recipes, events) lives here as JSON.
Loaded at runtime by relevant systems — never hard-code these values in scripts.

## Files

- `buildings.json` — building definitions (cost, size, production, consumption)
- `recipes.json` — crafting / extraction / research recipes
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
