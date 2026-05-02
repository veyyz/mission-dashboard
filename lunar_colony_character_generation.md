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
- `sealed angular pressure suit with rigid chest module and geometric panel seams` — locks in the suit silhouette and gives it a constructed, faceted look (not rounded organic curves)
- `compact life support backpack` — the unmistakable astronaut tell from any angle
- `pressure gauntlet gloves` — kills the "regular hands" reading
- `neck ring visible at collar` — tells the model the jacket sits on a sealed suit, not a t-shirt
- `pressurized boots` (instead of just "boots") — completes the sealed silhouette

For un-helmeted crew (the canonical look per `fq_player.png`), the helmet doesn't disappear from the design — it's `clipped to belt at hip` for Commander. Other crew can have it implied by the visible neck ring and life support backpack.

**On suit silhouette — angular, not rounded:** the suits should read as constructed from rigid geometric plates with hard panel breaks, not soft organic shapes. Think Apollo-era hard suit with modern faceted styling — angular shoulder pauldrons, knee plates, chest module corners, segmented forearm and shin guards. Keep the softness in the *face and hair*; let the *suit* be hard and angular.

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

Every character description follows the same structural skeleton — but **the character-specific slots must contain genuinely different content**, not just different colors. Six characters in the same suit color palette but otherwise identical (same age, same build, same face shape, same expression, same hair) read as siblings, not crewmates. That's the sibling-problem failure mode — it's the next thing that breaks after you fix the catsuit/streetwear problems.

**Parallel structure for cohesion. Distinct content for differentiation.** Each character must vary on at least:
- **Age** — spread across young (early 20s) through late career (50s+)
- **Build** — slim, average, stocky, athletic, strong — not all the same
- **Face/ethnicity** — explicit ethnic features, freckles, weathered skin, glasses, beards, scars, etc.
- **Hair** — meaningfully different cuts and colors, not all "tousled brown"
- **Expression** — not all "friendly warm smile." Mix in focused, paternal, smirking, authoritative, calm

Skeleton:

```
top-down 3/4 view game sprite, full body, [DISTINCT AGE + BUILD + ETHNICITY]
astronaut [ROLE], [DISTINCT FACE/HAIR DETAIL], [DISTINCT EXPRESSION], wearing
a sealed angular [COLOR] pressure suit with rigid chest module and geometric
panel seams, [LAYERED OUTFIT: jacket/vest over the suit], angular shoulder
pauldrons and segmented knee plates, neck ring visible at collar, compact
life support backpack, [WARM ANCHOR DETAIL — pressurized boots in warm
color], pressure gauntlet gloves, [SUBTLE TECH ACCENT — small LED somewhere],
JRPG-style game sprite, clean pixel art
```

The bracketed slots are what varies per character. The astronaut features (`sealed pressure suit`, `rigid chest module`, `neck ring`, `life support backpack`, `pressure gauntlet gloves`, `pressurized boots`) are constant — these are what stop the model from defaulting to casual streetwear.

**Suffix note:** earlier versions ended with `retro-futuristic exploration crew, clean pixel art, friendly approachable`. The "friendly approachable" was making every character smile identically; the "retro-futuristic exploration crew" was making them look like uniformed siblings. Both removed. `JRPG-style game sprite, clean pixel art` is enough to anchor the visual style.

Always end with `retro-futuristic exploration crew, clean pixel art, friendly approachable`. Do not vary that suffix.

---

## Per-Character Prompts

### Alex — Engineer
*Canonical reference. Match `fq_player.png` as closely as possible.*
```
top-down 3/4 view game sprite, full body, young astronaut engineer in his
mid-twenties with average build, brown tousled messy hair and a few freckles,
warm easy grin, wearing a sealed angular white pressure suit with rigid chest
module and geometric panel seams, navy-blue flight jacket over the suit with
high collar resting on the suit's neck ring, angular shoulder pauldrons and
segmented knee plates, compact life support backpack, glossy red pressurized
boots, pressure gauntlet gloves, small cyan LED accent line along jacket trim,
JRPG-style game sprite, clean pixel art
```

### Maya — Scientist
```
top-down 3/4 view game sprite, full body, astronaut scientist in her thirties
with slim build and East Asian features, sharp intelligent eyes behind small
round glasses, dark hair pulled into a tight high ponytail, focused half-smile
of someone mid-thought, wearing a sealed angular violet pressure suit with
rigid chest module and darker purple geometric panel seams, high collar
resting on the suit's neck ring, angular shoulder pauldrons and segmented
knee plates, compact life support backpack, integrated wrist computer with
glowing magenta display, lavender pressurized boots, pressure gauntlet gloves,
JRPG-style game sprite, clean pixel art
```

### Zane — Botanist
```
top-down 3/4 view game sprite, full body, astronaut botanist in his late
forties with stocky sturdy build and weathered tan skin, salt-and-pepper beard
and laugh lines around the eyes, gentle paternal smile, short greying brown
hair under a forest-green tactical cap, wearing a sealed angular white
pressure suit with rigid chest module and geometric panel seams, forest-green
utility vest over the suit with bulging seed pockets, angular shoulder
pauldrons and segmented knee plates, neck ring visible at collar, compact
life support backpack, dark green pressurized boots, pressure gauntlet gloves,
small green LED on vest collar, JRPG-style game sprite, clean pixel art
```

### Rin — Geologist
```
top-down 3/4 view game sprite, full body, young astronaut geologist in her
early twenties with athletic build and South Asian features, determined
focused expression with a slight smirk, short black undercut hair visible
beneath a sleek yellow hardhat with integrated headlamp, wearing a sealed
angular heavy-duty amber-orange pressure suit with rigid chest module and
charcoal-grey geometric panel seams, angular shoulder pauldrons and segmented
knee plates, neck ring visible at collar, compact life support backpack,
brown pressurized work boots, pressure gauntlet gloves, small amber LED
accent on shoulder, JRPG-style game sprite, clean pixel art
```

### Medic (Phase 5+ unlock)
```
top-down 3/4 view game sprite, full body, astronaut medic in his thirties
with lean build and dark brown skin, calm reassuring expression with kind
eyes, short dark coily hair, wearing a sealed angular white pressure suit
with rigid chest module and geometric panel seams, red cross emblem on chest,
light-grey medical jacket over the suit, angular shoulder pauldrons and
segmented knee plates, neck ring visible at collar, compact life support
backpack, white pressurized boots with red soles, pressure gauntlet gloves,
small red LED accent on sleeve, JRPG-style game sprite, clean pixel art
```

### Commander (Phase 5+ unlock)
```
top-down 3/4 view game sprite, full body, astronaut commander in her late
fifties with strong build and pale skin lined from years in service, sharp
authoritative gaze softened by a small confident smile, short silver-grey
hair in a practical cut, wearing a sealed angular dark navy pressure suit
with rigid chest module and geometric panel seams, gold trim and silver
shoulder insignia, angular shoulder pauldrons and segmented knee plates,
neck ring visible at collar, compact life support backpack, helmet clipped
to belt at hip, no helmet on head, polished black pressurized boots, pressure
gauntlet gloves, small gold LED accent on collar, JRPG-style game sprite,
clean pixel art
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
| All characters look like siblings / variations of the same person | Each character needs a DISTINCT age, build, ethnicity, hair, and expression — not just a different suit color. Verify each prompt's `[DISTINCT AGE + BUILD + ETHNICITY]` and `[DISTINCT EXPRESSION]` slots actually differ from the others |
| Suits look too rounded / too organic / not angular enough | Reinforce: "rigid faceted plates with hard panel breaks, mechanical paneling like Apollo hard suit" |
| Suits look too angular / too robotic / mecha-like | Soften: drop "angular shoulder pauldrons and segmented knee plates" and keep only "geometric panel seams" |
| Looks like casual streetwear / park ranger / not an astronaut | The astronaut tells are missing from the prompt. Verify all of these are present: `sealed angular pressure suit`, `rigid chest module`, `geometric panel seams`, `neck ring visible at collar`, `compact life support backpack`, `pressure gauntlet gloves`, `pressurized boots` |
| Suit comes back as a skintight bodysuit / catsuit | Check that the prompt says "sealed pressure suit" not "spacesuit" or "bodysuit" or "jumpsuit" |
| Front-facing portrait pose instead of game sprite | Verify "top-down 3/4 view game sprite, full body" leads the prompt and "JRPG-style game sprite" is in the suffix |
| Too deformed / Funko-Pop oversized head | Switch `proportions` to `{"type": "preset", "name": "default"}` |
| Heads too small, looks too realistic | Switch `proportions` to `{"type": "preset", "name": "chibi"}` |
| Suit too plain, no future-tech feel | Add: "with subtle glowing [color] accent line along the seams" |
| Looks too military / too dark | Add: "warm friendly atmosphere, soft lighting, cozy" |
| Style feels generic, not JRPG-flavored | Make sure `JRPG-style game sprite` appears in the suffix |
| Face is blank or unreadable | At 128 this should be rare — first try regenerating; if still bad, bump to `size=160` for that character |
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
