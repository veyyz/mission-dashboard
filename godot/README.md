# Lunar Colony

A 3/4 top-down moon colony management game built in Godot 4.

## Status

**Phase 1 of 10 — Project Skeleton.** This is the starter scaffold.
The boot scene verifies all autoloads come up and prints a status report.

See the project development prompt (`lunar_colony_godot_prompt.md`) for the
full 10-phase plan.

## Requirements

- **Godot 4.3** or newer
- Forward+ renderer (default — runs on most desktop GPUs)

## Running

1. Launch Godot 4.3+.
2. Click **Import**, select this folder's `project.godot`.
3. Open the project, then press **F5**.
4. You should see "LUNAR COLONY" with **"All systems online. Ready for Phase 2."** in green.
5. The Output panel at the bottom prints autoload status + a resource/time smoke test.
6. Press **Esc** to quit.

If the status reads red, check the Output panel — every autoload should
print `[Name] Ready.` on startup.

## Project Tour

```
res://
├── project.godot       # config: autoloads, display, rendering
├── icon.svg            # app icon (placeholder moon)
├── README.md           # this file
├── assets/             # art, audio, fonts (empty for now)
│   ├── sprites/
│   ├── fonts/
│   ├── audio/
│   └── shaders/
├── scenes/
│   ├── main/Main.tscn  # boot scene (current entry point)
│   ├── world/          # ground / orbit scenes (Phase 2 / 7)
│   ├── crew/           # CrewMember.tscn etc. (Phase 4)
│   ├── buildings/      # one .tscn per building (Phase 5)
│   ├── ui/             # HUD panels (Phase 6)
│   └── fx/
├── scripts/
│   ├── autoload/       # GameState, EventBus, ResourceManager,
│   │                   #   TimeManager, SaveSystem, AudioManager
│   ├── main/main.gd    # boot script
│   ├── crew/           # (Phase 4)
│   ├── buildings/      # (Phase 5)
│   ├── systems/        # pathfinding, fog, etc. (Phase 4+)
│   ├── ui/             # (Phase 6)
│   └── utils/
├── data/               # JSON content: buildings, recipes, events
└── saves/              # mirrored to user:// at runtime
```

## Autoload Architecture

Six singletons, declared in `project.godot` under `[autoload]`:

| Autoload          | Responsibility                                          |
|-------------------|---------------------------------------------------------|
| `GameState`       | Game mode, pause, mission day, **InputMap setup**       |
| `EventBus`        | Global signals — every cross-system event flows here    |
| `ResourceManager` | Six tracked resources with current/max/rate             |
| `TimeManager`     | Day/night cycle, time scale, in-game minute tick        |
| `SaveSystem`      | JSON save/load (Phase 9 — currently stubs)              |
| `AudioManager`    | SFX/music playback (Phase 10 — currently stubs)         |

**Rule:** systems never hold direct references to each other. They emit on
`EventBus` and listen for what they care about. Keep it that way.

## Input Bindings

Set up programmatically in `GameState._setup_input_map()` so the project
runs out of the box without InputMap config. You can migrate them to
**Project > Project Settings > Input Map** any time and the bindings
will persist via `project.godot`.

| Action            | Default Key |
|-------------------|-------------|
| `move_up/down/left/right` | W / S / A / D |
| `select_crew_1..6`        | 1–6           |
| `scan`                    | R             |
| `deploy_probe`            | F             |
| `collect_sample`          | G             |
| `crew_menu`               | C             |
| `pause_game`              | Space         |
| `speed_1x/2x/4x`          | F1 / F2 / F3  |

## Conventions

- `snake_case` vars/funcs, `PascalCase` classes/scenes, `SCREAMING_SNAKE` for constants/enums
- One class per file. Use `class_name` for any class instantiated externally
- **Signals over polling.** Connect to `EventBus`, don't read state across systems
- Pixel-perfect: `default_texture_filter = 0` (Nearest), `snap_2d_transforms_to_pixel = true`
- Game content (buildings, recipes, events) lives in `data/*.json`, never hard-coded

## Next Phase

Open this project in your coding agent (Claude Code, Cursor, etc.) along with
the `lunar_colony_godot_prompt.md` development plan, and say:

> **"Begin Phase 2."**

Phase 2 builds the ground scene with a basic moon-surface tilemap, one
controllable crew member with WASD movement, a follow camera, and a
placeholder rock to verify Y-sort works.
