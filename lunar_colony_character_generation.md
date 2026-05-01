# Lunar Colony — Character Generation Guide

A focused art-direction doc for Claude Code when calling Pixellab MCP `create_character`. **This supersedes the character section of `lunar_colony_pixellab_pipeline.md`.** Use these prompts and parameters verbatim — they're tuned to match the reference screenshots while pushing slightly more futuristic.

---

## Visual Vision

The crew should feel like **a cozy, optimistic exploration team** — cute, capable, slightly chubby/normal proportions, the kind of pixel-art protagonists you'd find in Stardew Valley, Eastward, or Moonlighter rather than Halo or Mass Effect. Think indie space comic, not military sci-fi. The reference (`fq_player.png`) is the canonical look for **Alex** — every other crew member must feel like they came out of the same artist's sketchbook.

Key qualities the reference establishes:
- **Stylized JRPG proportions** — large expressive head, compact body, ~4–5 heads tall. Direct family with Eastward, Sea of Stars, CrossCode. Use the `stylized` preset; it gives the JRPG/anime sensibility without going full deformed-chibi.
- **Layered cozy outfits** — visible jacket/vest piece *over* a base spacesuit. This is huge — it makes the characters feel dressed rather than encased. Alex has a navy-blue flight jacket with high collar over a white suit.
- **Warm human anchor details** — Alex's glossy red boots are the signature element. Every crew member needs an equivalent: a piece in a warm, friendly color or material that humanizes the suit.
- **Tousled, lived-in hair** — not styled, not slick. Brown messy hair on Alex.
- **Small simple face** — eye dots, hint of a friendly expression, not over-detailed.
- **Subtle, not dominant futuristic touches** — small accent lines, a single LED or seam-glow. The character reads as a *person* first, technology second.

**What to avoid in body language:** anything that suggests "athletic," "lean," "fit," "slim," "form-fitting." The reference is a normal cute character, not a fitness model. Let the stylized proportions handle the body — describe clothing and accessories, not physique.

---

## Constant Parameters (Use For Every Character)

These never change across the six crew. Locking them is what creates a unified set.

```python
create_character(
    description=<see per-character section>,
    body_type="humanoid",
    n_directions=8,
    size=128,                                         # large canvas for crisp face details + tech accents
    proportions={"type": "preset", "name": "stylized"}, # JRPG-style — closer to reference than chibi
    outline="single color black outline",
    shading="detailed shading",                       # not "basic" — references have multiple shade levels
    detail="highly detailed",
    view="low top-down",
    # Note: there is no `seed` param on create_character — style consistency
    # comes from identical params + parallel descriptive structure (below)
)
```

If outputs feel too realistic / heads too small for the JRPG vibe, try `chibi` for that batch. If too deformed / Funko-Pop-like, try `default`. The reference sits between `stylized` and `chibi` — `stylized` is the better starting point.

---

## Description Template

Every character description follows the same five-part structure. Parallel structure across descriptions is the strongest cohesion lever Pixellab gives you when you can't lock a seed.

```
[ROLE], in [LAYERED OUTFIT: base suit + colored jacket/garment], [HAIR/FACE
DETAIL], [EXPRESSION], [WARM ANCHOR DETAIL — boots/cap/hardhat/etc.],
[OPTIONAL SUBTLE TECH ACCENT], [OPTIONAL SIGNATURE PROP], retro-futuristic
exploration crew, clean pixel art, friendly approachable
```

Always end with `retro-futuristic exploration crew, clean pixel art, friendly approachable`. Do not vary that suffix.

---

## Per-Character Prompts

### Alex — Engineer
*Canonical reference. Match `fq_player.png` as closely as possible.*
```
engineer in white spacesuit with navy-blue flight jacket and high collar,
brown tousled messy hair, friendly warm smile, glossy red boots, small cyan
accent stripe along jacket trim, JRPG anime-influenced pixel art,
retro-futuristic exploration crew, clean pixel art, friendly approachable
```

### Maya — Scientist
```
female scientist in violet bodysuit with darker purple panel seams and high
collar, dark hair in high ponytail, curious intelligent smile, lavender accent
boots, holding a glowing handheld scanner tablet, JRPG anime-influenced pixel
art, retro-futuristic exploration crew, clean pixel art, friendly approachable
```

### Zane — Botanist
```
botanist in white shirt and forest-green work vest over green pants, green
tactical cap over short brown hair, light stubble, gentle warm smile, dark
green boots, small green leaf-pattern accent on vest, JRPG anime-influenced
pixel art, retro-futuristic exploration crew, clean pixel art, friendly
approachable
```

### Rin — Geologist
```
female geologist in heavy-duty amber-orange jumpsuit with charcoal-grey panels,
sleek yellow hardhat with integrated headlamp, determined friendly smile, brown
work boots, holding a sonic pickaxe with glowing tip, JRPG anime-influenced
pixel art, retro-futuristic exploration crew, clean pixel art, friendly
approachable
```

### Medic (Phase 5+ unlock)
```
medic in white spacesuit with light-grey medical jacket and red cross emblem
on chest, short dark hair, calm reassuring smile, white boots with red soles,
holding a small medkit, JRPG anime-influenced pixel art, retro-futuristic
exploration crew, clean pixel art, friendly approachable
```

### Commander (Phase 5+ unlock)
```
commander in dark navy spacesuit with gold trim and silver shoulder insignia,
no helmet, short silver-grey hair, confident warm smile, polished black boots,
hands relaxed at sides, JRPG anime-influenced pixel art, retro-futuristic
exploration crew, clean pixel art, friendly approachable
```

---

## What To Avoid (Negative Direction)

These descriptors will pull the output in the wrong direction. Do **not** include them, and watch for outputs that drift this way:

- ❌ "athletic", "lean", "fit", "slim", "form-fitting", "muscular" → fitness-model body language; the reference is a normal cute character
- ❌ "bulky armor", "heavy armor", "tactical gear" → makes them look military
- ❌ "ribbed suit", "cables", "wires" → makes them look 1980s Aliens
- ❌ "mask", "full helmet covering face" → loses the friendliness; we want faces
- ❌ "grim", "stern", "serious", "battle-hardened" → wrong emotional tone
- ❌ "neon", "cyberpunk", "dystopian" → too far on the futuristic dial
- ❌ "realistic", "photorealistic" → loses the JRPG pixel-art charm
- ❌ "anime portrait", "anime illustration" → we want anime-*influenced* pixel art (`JRPG anime-influenced pixel art`), not full anime portrait rendering
- ❌ Specifying exact ages ("25 years old") → the model handles this fine implicitly

---

## Animation Prompts

After all six characters are queued, immediately queue animations (no need to wait for character completion). Use the template animations and add `action_description` to keep the cozy/friendly mood:

```python
for char_id in [alex_id, maya_id, zane_id, rin_id, medic_id, commander_id]:
    animate_character(
        character_id=char_id,
        template_animation_id="walking",
        action_description="walking with a relaxed natural pace"
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
| `running` | "running with quick urgent steps" | Emergency events, low-O2 alerts |

---

## Iteration Protocol

When a character comes back and doesn't hit, do **not** keep blindly retrying. Diagnose what's off, then retry with a targeted edit.

| Symptom | Fix |
|---|---|
| Too deformed / Funko-Pop oversized head | Switch `proportions` to `{"type": "preset", "name": "default"}` |
| Heads too small, looks too realistic | Switch `proportions` to `{"type": "preset", "name": "chibi"}` |
| Suit too plain, no future-tech feel | Add: "with subtle glowing [color] accent line along the seams" |
| Looks too military / too dark | Add: "warm friendly atmosphere, soft lighting, cozy" |
| Looks like a fitness model / too muscular | Remove any body descriptor; lead with the outfit only |
| Style feels generic, not JRPG-flavored | Make sure `JRPG anime-influenced pixel art` appears in the prompt |
| Face is blank or unreadable | At 128 this should be rare — first try regenerating; if still bad, bump to `size=160` for that character |
| Style doesn't match siblings | Re-read the others' prompts; use more parallel phrasing |
| Hair/feature wrong | Lead the description with the corrected feature: "**short red hair**, engineer in..." |

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

**World scale:** characters at `size=128` produce sprites ~77px tall. The world tilemap uses **64×64 tiles** (updated from the original 32×32 spec to match this character scale), so a crew member spans roughly 1.2 tiles tall — proportional to the reference screenshots.

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
