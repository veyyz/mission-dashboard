# Lunar Colony — Character Generation Guide

A focused art-direction doc for Claude Code when calling Pixellab MCP `create_character`. **This supersedes the character section of `lunar_colony_pixellab_pipeline.md`.** Use these prompts and parameters verbatim — they're tuned to match the reference screenshots while pushing slightly more futuristic.

---

## Visual Vision

The crew should feel like **a cozy, optimistic exploration team** — cute, capable, slightly chubby/normal proportions, the kind of pixel-art protagonists you'd find in Stardew Valley, Eastward, or Moonlighter rather than Halo or Mass Effect. Think indie space comic, not military sci-fi. The reference (`fq_player.png`) is the canonical look for **Alex** — every other crew member must feel like they came out of the same artist's sketchbook.

Key qualities the reference establishes:
- **Stylized JRPG proportions** — large expressive head, compact body, ~4–5 heads tall. Direct family with Eastward, Sea of Stars, CrossCode. Use the `stylized` preset; it gives the JRPG/anime sensibility without going full deformed-chibi.
- **Layered cozy outfits over a sealed pressure suit** — visible jacket/vest piece *over* a base spacesuit. Alex has a navy-blue flight jacket with high collar over a white pressure suit. The cozy layer is what makes them feel approachable; the pressure suit underneath is what makes them read as astronauts.
- **Warm human anchor details** — Alex's glossy red boots are the signature element. Every crew member needs an equivalent: a piece in a warm, friendly color or material that humanizes the suit.
- **Tousled, lived-in hair** — not styled, not slick. Brown messy hair on Alex.
- **Small simple face** — eye dots, hint of a friendly expression, not over-detailed.
- **Subtle, not dominant futuristic touches** — small accent lines, a single LED or seam-glow. The character reads as a *person* first, technology second.

**The astronaut tells — every prompt must include these or the model produces casual streetwear:**

The word "spacesuit" alone isn't enough. Without explicit pressure-suit features, Pixellab will read "white spacesuit with navy jacket" as "white clothes under a navy jacket" and ship you a park ranger. Every per-character prompt below includes:
- `sealed pressure suit with rigid chest module` — locks in the suit silhouette
- `compact life support backpack` — the unmistakable astronaut tell from any angle
- `pressure gauntlet gloves` — kills the "regular hands" reading
- `neck ring visible at collar` — tells the model the jacket sits on a sealed suit, not a t-shirt
- `pressurized boots` (instead of just "boots") — completes the sealed silhouette

For un-helmeted crew (the canonical look per `fq_player.png`), the helmet doesn't disappear from the design — it's `clipped to belt at hip` for Commander. Other crew can have it implied by the visible neck ring and life support backpack.

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
top-down 3/4 view game sprite, full body, astronaut [ROLE] wearing a sealed
[COLOR] pressure suit with rigid chest module, [LAYERED OUTFIT: jacket/vest
over the suit], neck ring visible at collar, compact life support backpack,
[HAIR/FACE DETAIL], [EXPRESSION], [WARM ANCHOR DETAIL — pressurized boots in
warm color], pressure gauntlet gloves, [SUBTLE TECH ACCENT — small LED
somewhere], JRPG-style game sprite, retro-futuristic exploration crew, clean
pixel art, friendly approachable
```

The bracketed slots are what varies per character. Everything else is constant. **Do not omit the astronaut features** — `sealed pressure suit`, `rigid chest module`, `neck ring`, `life support backpack`, `pressure gauntlet gloves`, `pressurized boots`. These are what stop the model from defaulting to casual streetwear.

Always end with `retro-futuristic exploration crew, clean pixel art, friendly approachable`. Do not vary that suffix.

---

## Per-Character Prompts

### Alex — Engineer
*Canonical reference. Match `fq_player.png` as closely as possible.*
```
top-down 3/4 view game sprite, full body, astronaut engineer wearing a sealed
white pressure suit with rigid chest module, navy-blue flight jacket over the
suit with high collar resting on the suit's neck ring, compact life support
backpack, brown tousled messy hair, friendly warm smile, glossy red pressurized
boots, pressure gauntlet gloves, small cyan LED accent line along jacket trim,
JRPG-style game sprite, retro-futuristic exploration crew, clean pixel art,
friendly approachable
```

### Maya — Scientist
```
top-down 3/4 view game sprite, full body, astronaut scientist wearing a sealed
violet pressure suit with rigid chest module and darker purple panel seams,
high collar resting on the suit's neck ring, compact life support backpack,
integrated wrist computer with glowing magenta display, dark hair in high
ponytail, curious intelligent smile, lavender pressurized boots, pressure
gauntlet gloves, JRPG-style game sprite, retro-futuristic exploration crew,
clean pixel art, friendly approachable
```

### Zane — Botanist
```
top-down 3/4 view game sprite, full body, astronaut botanist wearing a sealed
white pressure suit with rigid chest module, forest-green utility vest over
the suit, neck ring visible at collar, compact life support backpack, green
tactical cap over short brown hair, light stubble, gentle warm smile, dark
green pressurized boots, pressure gauntlet gloves, small green LED on vest
collar, JRPG-style game sprite, retro-futuristic exploration crew, clean
pixel art, friendly approachable
```

### Rin — Geologist
```
top-down 3/4 view game sprite, full body, astronaut geologist wearing a
sealed heavy-duty amber-orange pressure suit with rigid chest module and
charcoal-grey panels, neck ring visible at collar, compact life support
backpack, sleek yellow hardhat with integrated headlamp, determined friendly
smile, brown pressurized work boots, pressure gauntlet gloves, small amber
LED accent on shoulder, JRPG-style game sprite, retro-futuristic exploration
crew, clean pixel art, friendly approachable
```

### Medic (Phase 5+ unlock)
```
top-down 3/4 view game sprite, full body, astronaut medic wearing a sealed
white pressure suit with rigid chest module and red cross emblem on chest,
light-grey medical jacket over the suit, neck ring visible at collar, compact
life support backpack, short dark hair, calm reassuring smile, white
pressurized boots with red soles, pressure gauntlet gloves, small red LED
accent on sleeve, JRPG-style game sprite, retro-futuristic exploration crew,
clean pixel art, friendly approachable
```

### Commander (Phase 5+ unlock)
```
top-down 3/4 view game sprite, full body, astronaut commander wearing a
sealed dark navy pressure suit with rigid chest module, gold trim and silver
shoulder insignia, neck ring visible at collar, compact life support backpack,
helmet clipped to belt at hip, no helmet on head, short silver-grey hair,
confident warm smile, polished black pressurized boots, pressure gauntlet
gloves, small gold LED accent on collar, JRPG-style game sprite,
retro-futuristic exploration crew, clean pixel art, friendly approachable
```

---

## What To Avoid (Negative Direction)

These descriptors will pull the output in the wrong direction. Do **not** include them, and watch for outputs that drift this way:

- ❌ "athletic", "lean", "fit", "slim", "form-fitting", "muscular" → fitness-model body language; the reference is a normal cute character
- ❌ "bodysuit", "skintight", "catsuit" → these pull straight into fitness-model territory regardless of what color you specify. Always say "spacesuit"
- ❌ "bulky armor", "heavy armor", "tactical gear" → makes them look military
- ❌ "ribbed suit", "cables", "wires" → makes them look 1980s Aliens
- ❌ "mask", "full helmet covering face" → loses the friendliness; we want faces
- ❌ "grim", "stern", "serious", "battle-hardened" → wrong emotional tone
- ❌ "neon", "cyberpunk", "dystopian" → too far on the futuristic dial
- ❌ "realistic", "photorealistic" → loses the JRPG pixel-art charm
- ❌ "anime portrait", "anime illustration", "front-facing portrait" → these produce static portraits, not gameplay sprites. Always lead with "top-down 3/4 view game sprite"
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
| Looks like casual streetwear / park ranger / not an astronaut | The astronaut tells are missing from the prompt. Verify all of these are present: `sealed pressure suit`, `rigid chest module`, `neck ring visible at collar`, `compact life support backpack`, `pressure gauntlet gloves`, `pressurized boots` |
| Suit comes back as a skintight bodysuit / catsuit | Check that the prompt says "sealed pressure suit" not "spacesuit" or "bodysuit" or "jumpsuit" |
| Front-facing portrait pose instead of game sprite | Verify "top-down 3/4 view game sprite, full body" leads the prompt and "JRPG-style game sprite" is in the suffix |
| Too deformed / Funko-Pop oversized head | Switch `proportions` to `{"type": "preset", "name": "default"}` |
| Heads too small, looks too realistic | Switch `proportions` to `{"type": "preset", "name": "chibi"}` |
| Suit too plain, no future-tech feel | Add: "with subtle glowing [color] accent line along the seams" |
| Looks too military / too dark | Add: "warm friendly atmosphere, soft lighting, cozy" |
| Looks like a fitness model / too muscular | Remove any body descriptor; lead with the outfit only |
| Style feels generic, not JRPG-flavored | Make sure `JRPG-style game sprite` appears in the suffix |
| Face is blank or unreadable | At 128 this should be rare — first try regenerating; if still bad, bump to `size=160` for that character |
| Style doesn't match siblings | Re-read the others' prompts; use more parallel phrasing |
| Hair/feature wrong | Lead the description with the corrected feature: "**short red hair**, astronaut engineer wearing..." |

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
