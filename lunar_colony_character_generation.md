# Lunar Colony — Character Generation Guide

A focused art-direction doc for Claude Code when calling Pixellab MCP `create_character`. **This supersedes the character section of `lunar_colony_pixellab_pipeline.md`.** Use these prompts and parameters verbatim — they're tuned to match the reference screenshots while pushing slightly more futuristic.

---

## Visual Vision

The crew should feel like **an athletic, optimistic exploration team in next-generation space gear**. Think NASA Artemis program circa 2050 — the suits are sleek and form-fitting (not bulky), with subtle glowing tech accents woven into seams and equipment. Characters look capable and confident but warm and approachable, not grim, not military, not cyberpunk.

The references (`fq_player.png` + `fq_landing_site_characters.png`) establish:
- **Chibi-leaning proportions** — large expressive head, compact body, ~4 heads tall
- **Distinctive face details** — visible eyes, hair, sometimes a friendly half-smile
- **Role-coded color** — each crew member has one dominant hue tied to their role
- **Warm anchoring details** — red boots on Alex, the green cap on Zane, the yellow hardhat on Rin keep the suits from feeling sterile
- **Signature props** — wrench, scanner, plant sample, pickaxe — instantly readable role

**Where we push further:** form-fitting athletic silhouettes (lean, capable, no bulk), subtle cyan/role-color glowing seams along the suit panels, integrated wrist displays or visors, holographic equipment instead of mechanical tools. Still warm, still smiling, still *approachable* — just upgraded by ~30 years.

---

## Constant Parameters (Use For Every Character)

These never change across the six crew. Locking them is what creates a unified set.

```python
create_character(
    description=<see per-character section>,
    body_type="humanoid",
    n_directions=8,
    size=64,                                          # 64 not 48 — enough resolution for face details
    proportions={"type": "preset", "name": "chibi"},  # matches the reference proportions
    outline="single color black outline",
    shading="detailed shading",                       # not "basic" — references have multiple shade levels
    detail="highly detailed",
    view="low top-down",
    # Note: there is no `seed` param on create_character — style consistency
    # comes from identical params + parallel descriptive structure (below)
)
```

If the first batch comes back too cute / too cartoony, drop `proportions` to `{"type": "preset", "name": "stylized"}`. If too realistic / not enough head presence, that's the wrong direction — go back to `chibi`.

---

## Description Template

Every character description follows the same five-part structure. Parallel structure across descriptions is the strongest cohesion lever Pixellab gives you when you can't lock a seed.

```
[ROLE + BUILD + AGE], in [SUIT COLOR/STYLE] with [FUTURISTIC TECH ACCENT],
[HAIR/FACE DETAIL], [EXPRESSION], [SIGNATURE PROP], retro-futuristic
exploration crew, clean pixel art, friendly approachable
```

Always end with `retro-futuristic exploration crew, clean pixel art, friendly approachable`. Do not vary that suffix.

---

## Per-Character Prompts

### Alex — Engineer
```
young athletic engineer with lean build, in form-fitting white and electric-blue
spacesuit with glowing cyan circuit-pattern seams, brown tousled hair, warm
confident smile, holding a sleek silver plasma wrench, red accent boots,
retro-futuristic exploration crew, clean pixel art, friendly approachable
```

### Maya — Scientist
```
young athletic female scientist with lean build, in form-fitting violet spacesuit
with glowing magenta data-line accents along the arms, dark hair in high ponytail,
small holographic visor across forehead, curious intelligent smile, holding a
glowing handheld scanner tablet, retro-futuristic exploration crew, clean pixel
art, friendly approachable
```

### Zane — Botanist
```
athletic botanist with lean build, in form-fitting forest-green spacesuit with
bioluminescent leaf-pattern accents and small green LED on chest, short brown
hair under green tactical cap, light stubble, gentle warm smile, holding a small
glowing plant cutting in a clear vial, retro-futuristic exploration crew, clean
pixel art, friendly approachable
```

### Rin — Geologist
```
young athletic female geologist with lean build, in form-fitting amber and
charcoal spacesuit with glowing orange seam accents, sleek modern yellow hardhat
with integrated headlamp, determined friendly smile, holding a sonic pickaxe
with glowing tip, retro-futuristic exploration crew, clean pixel art, friendly
approachable
```

### Medic (Phase 5+ unlock)
```
athletic medic with lean build, in form-fitting white spacesuit with glowing
red caduceus emblem on chest and red seam trim, integrated medical scanner on
left forearm, short dark hair, calm reassuring smile, holding a small
holographic medkit, retro-futuristic exploration crew, clean pixel art, friendly
approachable
```

### Commander (Phase 5+ unlock)
```
athletic commander with lean build, in form-fitting dark navy-blue spacesuit
with gold trim and glowing silver insignia on shoulders, no helmet, short
silver-grey hair, confident warm smile, hands relaxed at sides, retro-futuristic
exploration crew, clean pixel art, friendly approachable
```

---

## What To Avoid (Negative Direction)

These descriptors will pull the output in the wrong direction. Do **not** include them, and watch for outputs that drift this way:

- ❌ "bulky armor", "heavy armor", "tactical gear" → makes them look military
- ❌ "ribbed suit", "cables", "wires" → makes them look 1980s Aliens
- ❌ "mask", "full helmet covering face" → loses the friendliness; we want faces
- ❌ "grim", "stern", "serious", "battle-hardened" → wrong emotional tone
- ❌ "neon", "cyberpunk", "dystopian" → too far on the futuristic dial
- ❌ "realistic", "photorealistic" → loses the pixel-art chibi charm
- ❌ "anime" → wrong stylistic family; we want stylized pixel art, not anime
- ❌ Specifying exact ages ("25 years old") → the model handles this fine implicitly

---

## Animation Prompts

After all six characters are queued, immediately queue animations (no need to wait for character completion). Use the template animations and add `action_description` to reinforce the athletic, confident vibe:

```python
for char_id in [alex_id, maya_id, zane_id, rin_id, medic_id, commander_id]:
    animate_character(
        character_id=char_id,
        template_animation_id="walking",
        action_description="walking with confident athletic stride"
    )
    animate_character(
        character_id=char_id,
        template_animation_id="idle",
        action_description="standing relaxed and alert, slight breathing motion"
    )
```

Optional Phase 5+ animations (do these in a second wave after walking/idle complete):

| Template | Action description | Used for |
|---|---|---|
| `working` | "operating equipment with focused attention" | Engineer at construction sites, Scientist at lab |
| `interacting` | "examining something carefully with both hands" | Geologist at deposits, Botanist at hydroponics |
| `running` | "running with athletic urgency" | Emergency events, low-O2 alerts |

---

## Iteration Protocol

When a character comes back and doesn't hit, do **not** keep blindly retrying. Diagnose what's off, then retry with a targeted edit.

| Symptom | Fix |
|---|---|
| Too cute / too cartoony / oversized head | Switch `proportions` to `{"type": "preset", "name": "stylized"}` |
| Suit too plain, no future-tech feel | Add: "with glowing [color] energy lines tracing the suit panels" |
| Looks too military / too dark | Add: "warm friendly atmosphere, soft lighting, optimistic" |
| Looks bulky despite "athletic" | Add: "slim form-fitting suit, lean silhouette" |
| Face is blank or unreadable at this size | Bump `size` from 64 → 80 for that character |
| Style doesn't match siblings | Re-read the others' prompts; use more parallel phrasing |
| Hair/feature wrong | Lead the description with the corrected feature: "**short red hair**, athletic engineer in..." |

After 2 failed attempts on the same character, stop and surface the outputs to the human for direction rather than burning more credits.

---

## Verification Checklist

Before marking the character batch complete in `art_queue.json` and integrating into scenes, eyeball the six together:

- [ ] All six are clearly the same art style (same line weight, same shading approach)
- [ ] All six have similar overall scale (one isn't visibly larger than the others)
- [ ] Each role is instantly readable from silhouette + color (squint test — can you tell who's who?)
- [ ] Faces are visible and read as friendly across all six
- [ ] No two crew share the same dominant suit color
- [ ] Each has at least one warm/human anchor detail (boots, cap, hair color, hardhat, etc.)
- [ ] The futuristic accents (glowing seams, integrated tech) are present but not dominant — the characters still read as people first, tech second

If any check fails, regenerate the offender(s) using the iteration protocol above. **Do not ship the batch until the squint test passes.**

---

## Output Integration Notes

Once a character is `completed` in Pixellab:

1. Download the ZIP via the `download_url` from `get_character()`
2. Extract the 8 directional rotations (south, southeast, east, northeast, north, northwest, west, southwest) plus animation frames
3. Save to `assets/sprites/crew/<name>/` with the directory structure:
   ```
   assets/sprites/crew/alex/
   ├── idle/
   │   ├── south.png
   │   ├── southeast.png
   │   └── ...
   ├── walking/
   │   ├── south_0.png
   │   ├── south_1.png
   │   └── ...
   ```
4. Update the `CrewMember` scene to use an `AnimatedSprite2D` with sprite frames pointing at these files
5. Mark the asset `integrated: true` in `art_queue.json`

The exact extraction layout depends on Pixellab's ZIP structure — read the first downloaded ZIP to confirm naming, then templatize.
