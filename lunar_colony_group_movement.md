# Lunar Colony — Group Movement (Convoy Follow)

A retrofit spec for crew movement when multiple crew members are selected and given a single move order. Add this to the project's behavior spec; the agent will need to update Phase 4's selection/movement code to implement it.

---

## Problem

Right now (Phase 4 default behavior), when multiple crew members are selected and the player clicks a destination, every crew member paths to the same target tile. They all leave at the same frame, take the same path (or wildly different ones), and pile up on or near the destination. This reads as broken — the squad looks like a swarm, not a team.

## Desired Behavior

When 2+ crew members are selected and given a move order, they should move as a **convoy in single file**.

**Leader rule (non-negotiable):** the leader is always the **first character the player selected** in the current selection set. The other crew become followers in the order they were added to the selection. The leader paths to the destination; followers walk the leader's footsteps with a spacing delay.

The visual read is "the squad is moving together, with whoever the player picked first leading the line" — cinematic and predictable.

This is the RimWorld / Stardew NPC pattern, not the RTS formation pattern. Pick the convoy pattern over alternatives because it matches the cozy JRPG tone and avoids the "swarm bunching at the goal" failure mode of independent pathing.

---

## Specification

### Leader selection

When a group move order is issued, the leader is determined by **selection order**, not by crew slot index.

1. The **leader** is the first crew member added to the current selection set, regardless of which crew slot they occupy. If the player presses `3` first (selecting Zane) and then shift-presses `1` (adding Alex), Zane is the leader and Alex is a follower.
2. The **followers** are the remaining selected crew members, in the order they were added to the selection. If the player selected in order 3, 1, 4, the convoy is Zane (leader) → Alex → Rin.
3. **Box-select** (drag-select with the mouse): use selection order as the box's hits are processed. If your box-select implementation processes hits in screen order (top-down, left-right), follow that order — just be consistent and document it. The first hit in the box is the leader.
4. **Selection persists across move orders.** If the player selects 3, 1, 4 and clicks a destination, then clicks a new destination without changing the selection, Zane remains the leader. The convoy order is locked to the selection, not re-derived per click.
5. **Re-selecting changes the leader.** If the player deselects everyone and then selects 1 first, then 3, then 4, Alex is now the leader for the next group move order.

To support this, the selection system needs to track **insertion order** of the current selection, not just membership. If your current implementation uses an unordered `Set` or `Dictionary` for selected crew, change it to an ordered structure (an `Array` of `CrewMember` references with append-only insertion semantics; remove duplicates by checking `has()` before appending).

### Path assignment

1. The leader runs `NavigationAgent2D` pathing to the player-clicked destination, exactly as a single-crew move order does.
2. Each follower **does not run their own pathfinding to the destination**. Instead, they trace the leader's path with a delay. (See "Trail recording" below.)
3. If the leader's path fails (no route), the entire group move fails — surface a brief HUD log entry ("No path to destination") and cancel the order for everyone.

### Trail recording

The leader records its own position into a `trail_buffer` every fixed interval (suggested: every 0.15s or every ~16px of movement, whichever comes first). The buffer is a circular queue of `(world_position, timestamp)` entries.

Each follower has a `trail_position_index` indicating which entry in the buffer they are currently walking toward. The first follower trails the leader by `follow_spacing_seconds` (suggested: 0.6s — enough that they're clearly behind, not so much that they look disconnected). The second follower trails by `2 * follow_spacing_seconds`, the third by `3 * follow_spacing_seconds`, and so on.

This means at any frame, follower `n` is walking toward the position the leader was at `n * follow_spacing_seconds` ago. They're literally stepping in the leader's footsteps with a fixed time-spacing.

### Movement of followers

Each follower:
- Reads its target position from the trail buffer at index `trail_position_index`
- Moves toward it at the same speed as the leader (or slightly faster if behind, slightly slower if catching up — see "Catch-up smoothing" below)
- When the follower reaches the target trail point, advances `trail_position_index` to the next entry
- Animates with the same walk cycle and faces the direction it's moving (same as a single-crew move)

The followers do NOT use `NavigationAgent2D`. They use direct `position += direction * speed * delta` movement toward the trail point. This is correct because the leader has already validated the path is walkable — followers retracing the same path inherit that validation.

### Catch-up smoothing

If a follower falls more than `2 * follow_spacing_seconds` behind their target (because the leader sped up, or the follower was briefly blocked, or a player issued a new order mid-move), the follower runs at `1.2x` speed until they catch up to within the normal spacing. Conversely, if the leader stops while followers are still walking the trail, followers should NOT speed up to overtake — they walk normally to their final position.

### Leader-stopped behavior

When the leader reaches the destination and stops:
1. The leader stops walking and idles facing the click direction.
2. Followers continue walking the trail until each one reaches the trail point that puts them at their **convoy spacing** from the leader.
3. The convoy spacing for follower `n` is `n * convoy_idle_spacing` pixels behind the leader along the leader's last-facing direction (suggested: 24px per slot, so follower 1 ends up 24px behind, follower 2 at 48px, etc.).
4. Once all followers are in their idle convoy positions, every crew member's `trail_position_index` and the trail buffer can be cleared.

This means the convoy "settles" into a tidy line behind the leader rather than every follower bunching up on the leader's exact tile.

### New order while convoy is moving

If the player issues a new move order while the convoy is mid-walk:
- If the new selection is the **same group**, recompute the leader's path from the leader's current position to the new destination, clear the trail buffer, and start a new convoy from current positions. Followers need a few frames to catch up and re-stagger but the visual is acceptable.
- If the new selection is a **different group** (e.g., player selected only Alex now), every previously-selected follower should immediately stop walking and idle in place. They lose their convoy assignment; the new (now smaller) selection runs as a new move order.

### Single-crew move

When only one crew member is selected and given a move order, behavior is unchanged from the current Phase 4 implementation — `NavigationAgent2D` paths to the goal, no trail buffer, no follower logic.

---

## Implementation Notes

### Where the code lives

This is movement-system logic, not a per-crew property. Suggested home: a new `ConvoyController` autoload (or a node attached to the world scene) that owns:
- The current leader reference
- The list of followers in convoy order
- The trail buffer
- The frame-by-frame update loop

Each `CrewMember` gets two new fields:
```gdscript
var convoy_role: ConvoyRole  # enum: NONE, LEADER, FOLLOWER
var convoy_follower_index: int = -1  # 0 for first follower, 1 for second, etc.
```

When the group move order fires (in `select_and_move()` or wherever multi-select move is dispatched), the controller assigns roles and starts the trail.

### Trail buffer sizing

At a movement speed of ~80px/sec and a sample interval of 0.15s, each trail entry is ~12px apart. For the largest plausible convoy (9 crew members) with `follow_spacing_seconds = 0.6s` and a generous catch-up margin, you need to retain about `9 * 0.6 / 0.15 = 36` trail entries minimum. Round to 64 entries for safety. Circular buffer; oldest entries are overwritten when full.

### Avoiding diagonal jitter

When the leader's path turns sharply, followers walking toward a recently-recorded trail point may briefly appear to walk through walls or cut corners. Mitigate by storing one trail point at every change of direction (in addition to the time-based sampling) so the trail accurately captures corners. If pathfinding is to actual nav mesh polygons, this matters less; if it's to grid-snapped tiles, it matters more.

### Pause / time-scale interaction

Group movement should respect the existing `TimeManager.time_scale` and `GameState.is_paused`. Trail-buffer recording and follower advancement both gate on `_process(delta)` continuing, so as long as the existing pause logic halts `_process` for crew, this works correctly with no extra changes.

### Save / load

When saving, serialize the convoy state as part of the world save: leader id, follower ids in order, trail buffer (positions only — drop timestamps and recompute), each follower's `trail_position_index`. On load, the convoy resumes from the saved state. If saving is mid-stop (leader has stopped, followers still settling), saving the state mid-settle is acceptable — followers continue settling on load.

---

## Done Criteria (for the agent's verification)

- [ ] Selecting 1 crew and moving — unchanged behavior, single-agent pathfinding
- [ ] Selecting 2+ crew and moving — leader is the **first crew added to the selection**, not the lowest crew slot
- [ ] Selecting in order 3 → 1 → 4 and moving — Zane leads, then Alex, then Rin
- [ ] Selecting 1 → 3 → 4 and moving — Alex leads, then Zane, then Rin
- [ ] Issuing a second move order to the same selection — leader does NOT change
- [ ] Followers walk single-file behind the leader, not all stacked at the destination
- [ ] Spacing between crew during walk is visually consistent (~0.6s apart)
- [ ] When the leader stops, followers continue walking to staggered idle positions behind the leader (not bunched at the leader's tile)
- [ ] Issuing a new move order to the same group restarts the convoy cleanly without crew teleporting
- [ ] Deselecting and reselecting a different subset stops the previous convoy
- [ ] Pause / unpause works correctly mid-convoy
- [ ] Save / load works correctly mid-convoy
- [ ] No crew member ever pathfinds through a wall or off the navmesh (the follower direct-movement only follows the leader's already-validated path)

---

## Tunable Parameters (put in `data/movement.json` or as `@export` vars on the controller)

```json
{
  "trail_sample_interval_seconds": 0.15,
  "trail_sample_distance_pixels": 16,
  "trail_buffer_size": 64,
  "follow_spacing_seconds": 0.6,
  "catchup_speed_multiplier": 1.2,
  "catchup_threshold_seconds": 1.2,
  "convoy_idle_spacing_pixels": 24
}
```

These should be data-driven so balancing the feel doesn't require code changes. Default values above are starting suggestions — playtest and adjust.
