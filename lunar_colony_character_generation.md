# Lunar Colony — Character Generation Guide

A focused art-direction doc for Claude Code when calling Pixellab MCP `create_character`. **This supersedes the character section of `lunar_colony_pixellab_pipeline.md`.** Use these prompts and parameters verbatim — they're tuned to match the reference screenshots while pushing slightly more futuristic.

---

## Visual Vision

The crew is **a junior cadet space team plus three robot companions** — the kind of pixel-art protagonists you'd find in indie JRPGs (Eastward, Sea of Stars, CrossCode). Think "junior astronaut corps with utility droids," not military, not adult crew. The reference (`fq_player.png`) is the canonical look for **Alex** (the human cadet aesthetic). The robots share the same suit vocabulary (faceted plates, glowing seam lines, hexagonal modules) so they read as built by the same studio that made the humans' suits. Every crew member — human or robot — must feel like they came out of the same artist's sketchbook.

**Why no direct age words like "kid," "child," "young," or "teen":** every direct youth word is a blush-priming token in pixel art training data. Even "young" and "teen" trigger blush at meaningful rates because their training-set neighbors are kawaii sprites. The strategy is **age implication through indirect signals only**:

- **Role context** does most of the work: `cadet`, `trainee`, `rookie`, `apprentice`, `junior officer`, `academy graduate`. These imply someone early in their career without naming an age.
- **Build descriptors** add second-pass signal: `slight compact build`, `slim petite build`, `slight wiry build`. These read as not-fully-grown without saying so.
- **Face geometry** completes the picture: `smooth unlined face`, `soft jawline`, `rounded face shape`. These read as young without using youth words.

Combined, these produce visibly young characters (~12-15 reading age) that resist the blush default. **Never use the words `kid`, `child`, `young`, `teen`, `youthful`, `little`, or `boy/girl` in any character prompt.**

Key qualities the reference establishes:
- **Stylized JRPG cadet proportions** — large expressive head, compact body, ~4–4.5 heads tall (between adult stylized and chibi, but not deformed). Direct family with Eastward, Sea of Stars, CrossCode. Use the `stylized` preset.
- **Layered cozy outfits over a sealed pressure suit** — visible jacket/vest piece *over* a base spacesuit. Alex has a navy-blue flight jacket with high collar over a white pressure suit. The cozy layer is what makes them feel approachable; the pressure suit underneath is what makes them read as astronauts.
- **Warm human anchor details** — Alex's glossy red boots are the signature element. Every crew member needs an equivalent: a piece in a warm, friendly color or material that humanizes the suit.
- **Distinct, well-defined hairstyles** — every cadet has a clear silhouette-readable haircut. **Avoid generic "messy/tousled" descriptors** which produce ambiguous mid-length blob hair (the issue seen in the round-5 Alex generation). Use specific cut names: short crop, bowl cut, pixie cut, shoulder-length bob, twin braids, undercut, swept side-fringe, twin buns, etc. Hair color also varies meaningfully across the crew.
- **Friendly faces only — no angry eyebrows, ever.** Every face should read as warm, kind, and approachable. Eyebrows should be **soft and relaxed**, not furrowed, slanted, or angled-down. Words that produce angry eyebrows in pixel art models include: "determined," "fierce," "intense," "stern," "sharp gaze," "piercing," and even "focused" if not paired with a softening word. Always include the phrase `friendly soft eyebrows` somewhere in the expression slot. Always pair any non-smile expression with a smile or grin.
- **No cheek blush, ever.** Pixel art models default to adding pink/red cheek blush circles on characters described as kids/chibi/cute — it reads as cartoonish and infantilizing. The `create_character` endpoint does not accept negative prompts, and inline negation in the description (e.g., "no cheek blush") *amplifies* the unwanted feature by raising the salience of the noun. **Defense in depth:**
  1. **Never use blush-priming words.** Banned in main prompt: `kid`, `child`, `young`, `teen`, `teenage`, `teenager`, `little`, `boy`, `girl`, `chibi`, `cute`, `kawaii`, `rosy`, `youthful`, `adorable`. Use indirect age signals instead: role context (`cadet`, `trainee`, `rookie`, `apprentice`), build cues (`slight compact build`), face geometry (`smooth unlined face`).
  2. **Use positive counter-descriptors.** Every prompt includes `matte even skin tone, neutral pale complexion` after the expression slot. These crowd out the blush default with a competing positive description rather than negating.
  3. **Never mention blush** — not even with negation. Saying "no blush" makes blush more likely.
  4. **Repair via `/v2/vary-object`** if blush appears anyway. See the v2 workflow section above for the call signature.
- **Subtle, not dominant futuristic touches** — small accent lines, a single LED or seam-glow. The character reads as a *young person* first, technology second.

**The astronaut tells — every prompt must include these or the model produces casual streetwear:**

The word "spacesuit" alone isn't enough. Without explicit pressure-suit features, Pixellab will read "white spacesuit with navy jacket" as "white clothes under a navy jacket" and ship you a park ranger. Every per-character prompt below includes:
- `sleek high-tech [color] exosuit with sharply faceted armor plates and crisp panel breaks` — locks in the suit silhouette as a maxed-out futuristic exosuit, not soft cloth or rounded curves
- `hexagonal chest module with multiple bevel edges` — reinforces the angular construction at the most visible point of the suit
- `glowing-[color] seam lines tracing every panel` — unmistakable high-tech tell, color-coded per role
- `sharp triangular shoulder pauldrons, segmented knee plates with diagonal cuts, geometric forearm guards, beveled shin armor` — the angular hardpoints that prevent the model from defaulting to a smooth jumpsuit
- `low-profile life support backpack with angled vents and visible coolant lines` — the unmistakable astronaut tell from any angle, now with a futuristic profile
- `pressure gauntlet gloves` — kills the "regular hands" reading
- `neck ring visible at collar` — tells the model the jacket sits on a sealed suit, not a t-shirt
- `pressurized boots` (instead of just "boots") — completes the sealed silhouette

For un-helmeted crew (the canonical look per `fq_player.png`), the helmet doesn't disappear from the design — it's `clipped to belt at hip` for Commander. Other crew can have it implied by the visible neck ring and life support backpack.

**On suit silhouette — maximum futurism, maximum angularity:** the suits are **sleek high-tech exosuits** assembled from sharply faceted armor plates with crisp panel breaks. Think advanced EVA hardshells from Mass Effect Andromeda, Halo Mjolnir Mark VII, Destiny exosuits, Star Citizen pilot armor — cutting-edge sci-fi, never Apollo-era, never soft cloth. **Every visible panel is faceted and angular**: hexagonal chest module with multiple bevel edges, trapezoidal abdominal plates, sharp triangular shoulder pauldrons, segmented knee and elbow plates with diagonal cuts, geometric forearm guards with raised vents, beveled shin armor with hard angled edges, faceted helmet attachment ring at the neck, angular utility hardpoints on the hips. Subtle integrated tech is visible throughout: thin glowing seam lines tracing the panel breaks, recessed panel indicator lights, holographic wrist displays, low-profile life support backpack with angled vents and visible coolant lines. The silhouette must look constructed, mechanical, futuristic, and unmistakably high-tech. Keep the softness in the *face and hair*; let the *suit* be aggressively hard, sharp, angular, and advanced.

**What to avoid in body language:** anything that suggests "athletic," "lean," "fit," "slim," "form-fitting." Let the stylized cadet proportions handle the body — describe clothing, accessories, and a build cue (`slight compact build`, `slim petite build`, etc.) but never describe physique with youth-explicit words.

**What to avoid in age cues:** ALL direct youth words are banned: `kid`, `child`, `young`, `teen`, `teenager`, `teenage`, `youthful`, `little`, `boy`, `girl`, `chibi`. Also avoid adult-coded words: `twenties`, `thirties`, `weathered`, `bearded`, `wrinkled`, `lined skin`. Age is implied indirectly via role context (`cadet`, `trainee`, `rookie`, `apprentice`), build descriptors (`slight compact build`, `slim petite build`), and face geometry (`smooth unlined face`, `soft jawline`, `rounded face shape`).

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

### Why the character endpoints don't take a negative prompt

Pixellab's `create_character` (both MCP and v2 REST `/create-character-with-{4,8}-directions`) does **not** accept a `negative_description` parameter. Confirmed from the v2 API spec at https://api.pixellab.ai/v2/llms.txt as of this writing. Negative prompting only exists on the lower-level image endpoints (`create-image-pixflux`, `create-image-bitforge`, `inpaint`, `animate-with-text`).

This means **inline negation in the description is the only lever the character endpoints expose for exclusions** — and inline negation can backfire by amplifying the noun ("blush" mentioned anywhere increases the chance of blush). There is no clean fix at the prompt level alone.

### What v2 actually offers (verified against the spec)

I checked https://api.pixellab.ai/v2/llms.txt directly. Here's what's actually there for our blush problem:

**Endpoints that accept `negative_description`** (verified in spec): `/create-image-bitforge`, `/inpaint`, `/animate-with-text` (and `/create-image-pixflux` but it's marked deprecated). **None of the modern character/object/rotation endpoints accept it.** Specifically these do NOT have `negative_description`:
- `/create-character-with-4-directions`, `/create-character-with-8-directions`
- `/objects` (POST), `/vary-object`
- `/generate-8-rotations-v2`, `/generate-8-rotations-v3`, `/generate-with-style-v2`
- `/edit-image`, `/edit-images-v2`, `/inpaint-v3`

So switching MCP → v2 REST does **not** unlock negative prompts on the character pipeline. The only realistic levers are:

**1. `POST /v2/vary-object`** — verified. Takes `object_id` + `edit_description`. After Alex generates with blush, call:
```
POST /v2/vary-object
{
  "object_id": "<alex-id>",
  "edit_description": "remove all pink and red coloring from cheeks, leave skin tone natural"
}
```
This is post-hoc surgery, not prevention. Costs the same as a generation but is targeted.

**2. Don't mention blush in the description at all.** Inline negation amplifies the noun — this is the existing rule and it stays.

**3. Avoid blush-amplifying descriptors.** Words that pull the model toward kawaii defaults (and therefore blush): "chibi", "cute", "kawaii", "rosy", "youthful". The proportions preset `stylized` is less blush-prone than `chibi`.

**4. Build a verification loop yourself.** When you download an image via `/v2/characters/{id}/zip`, you can run a quick pixel-check script to scan the cheek region for unexpected pink/red and auto-trigger a `vary-object` repair before integration. This isn't a Pixellab feature, but the raw image access makes it possible.

### What I previously claimed that turned out to be wrong

In an earlier revision of this doc I claimed that `/generate-with-style-v2` accepts `negative_description` and that `/create-character-with-8-directions` accepts a `reference_image` parameter for style cohesion. **Both were wrong** — I had not actually checked the spec. Re-verified above. If a future revision is tempted to recommend either, check the spec at https://api.pixellab.ai/v2/llms.txt first.

### Recommended workflow for this project

```python
# 1. Generate all six characters via create_character (MCP or v2 REST, same params).
#    Use the per-character prompts from the section below.
alex = create_character(description=ALEX_PROMPT, **CONSTANTS)
# ...etc for all 6

# 2. After completion, eyeball each. For any with blush, glasses, or other
#    unwanted features, repair via vary-object:
if has_unwanted_feature(alex):
    alex_repaired = vary_object(
        object_id=alex.id,
        edit_description="remove all pink and red coloring from cheeks, "
                         "leave skin tone natural and clean"
    )

# 3. If multiple repairs fail on the same character, regenerate with the
#    description tweaked: drop "chibi"/"cute" if present, switch
#    proportions from "stylized" to "default", or change "kid" to
#    "young teen" (which pulls toward older, less blush-prone defaults).
```

### When to fall back to MCP

Use MCP for the **first generation pass** — it's the easiest path and most characters will come back clean. Switch to v2 REST only for:
- Characters that came back with stubborn unwanted features after 1–2 retries (use `vary_object`)
- Enforcing style consistency across the second-wave characters (use `reference_image`)
- Programmatic verification on a CI-like loop


## Description Template

Every character description follows the same structural skeleton — but **the character-specific slots must contain genuinely different content**, not just different colors. Six characters in the same suit color palette but otherwise identical (same age, same build, same face shape, same expression, same hair) read as siblings, not crewmates. That's the sibling-problem failure mode — it's the next thing that breaks after you fix the catsuit/streetwear problems.

**Parallel structure for cohesion. Distinct content for differentiation.** Each character must vary on at least:
- **Age implied through role and build** — spread the role tags (cadet, trainee, rookie, apprentice, junior officer, academy graduate) and build cues (slight compact, slim petite, slight wiry, slim) across the crew. A `rookie with slight athletic build` reads visibly younger than an `academy graduate with slight wiry build`.
- **Ethnicity / face details** — explicitly different: East Asian, South Asian, dark brown skin, pale-with-freckles, warm tan skin, etc. Pair with face shape variations: round face, chubby cheeks, narrower face, dimples, gap-toothed grin
- **Eye color** — spread across blue, brown (varied shades), hazel, steel-grey, etc.
- **Hair color and cut** — meaningfully different. Cuts: swept side-fringe, high ponytail, shaggy curly mop, twin braids, low-volume crop, pixie cut. Colors: brown, black, dark brown, platinum-blonde, etc.
- **Expression** — still all friendly, but vary the flavor: warm easy grin, soft curious smile, gentle wide grin with dimples, bright eager grin, calm reassuring smile, warm confident smile

Skeleton:

```
top-down 3/4 view game sprite, full body, [ROLE TAG: cadet/trainee/rookie/apprentice/junior officer/academy graduate] [ROLE], [BUILD CUE: slight compact build / slim petite build / slight wiry build / etc.] with [ETHNICITY/FACE DETAIL], [DISTINCT EYE COLOR],
[DISTINCT WELL-DEFINED HAIRSTYLE WITH HAIR COLOR], [DISTINCT FRIENDLY
EXPRESSION WITH friendly soft eyebrows], matte even skin tone,
neutral pale complexion, smooth even skin tone on cheeks, matte natural complexion, no cheek
blush, no rosy cheeks, no pink circles on face, wearing a sleek high-tech [COLOR] exosuit with sharply faceted
armor plates and crisp panel breaks, hexagonal chest module with multiple
bevel edges, glowing-[ROLE COLOR] seam lines tracing every panel, [LAYERED
OUTFIT: jacket/vest over the suit], sharp triangular shoulder pauldrons,
segmented knee plates with diagonal cuts, geometric forearm guards with
raised vents, beveled shin armor with hard angled edges, neck ring visible
at collar, low-profile life support backpack with angled vents and visible
coolant lines, [WARM ANCHOR DETAIL — pressurized boots in warm color],
pressure gauntlet gloves, [SUBTLE TECH ACCENT — small LED somewhere],
JRPG-style game sprite, clean pixel art
```

The bracketed slots are what varies per character. Two non-negotiable rules:

1. **Astronaut features are constant** — `sealed angular high-tech pressure suit`, `hexagonal chest module`, `sharp glowing-[color] panel seams`, `sharp angular shoulder pauldrons and segmented knee plates`, `neck ring`, `low-profile life support backpack with angled vents`, `pressure gauntlet gloves`, `pressurized boots`. Omitting any of these collapses the suit back into casual streetwear.
2. **Friendly soft eyebrows are constant** — every expression slot must include the literal phrase `friendly soft eyebrows`, and the expression itself must be a smile or grin. No "determined," no "stern," no "sharp gaze." See the iteration guide below.
3. **Negative prompts are NOT available on character endpoints** — the `create_character` endpoint (MCP and v2 REST) does not accept a negative_description parameter. Stubborn unwanted features (blush, glasses, etc.) are repaired via the `/v2/vary-object` REST endpoint with an `edit_description` like `"remove pink blush from cheeks"`. See the v2 workflow section above. Do NOT add inline negations like `no cheek blush` to the main description — they amplify the unwanted feature.
4. **Indirect age signals are constant** — every prompt leads with `[ROLE TAG] [ROLE]` (e.g. `cadet engineer`, `trainee scientist`, `rookie geologist`) plus a build cue and `smooth unlined face`. Never use direct youth words (`kid`, `young`, `teen`, etc.). The role tag + build + face geometry combination implies young age without naming it, which avoids priming blush.

The bracketed slots are what varies per character. The astronaut features (`sealed pressure suit`, `rigid chest module`, `neck ring`, `life support backpack`, `pressure gauntlet gloves`, `pressurized boots`) are constant — these are what stop the model from defaulting to casual streetwear.

**Suffix note:** earlier versions ended with `retro-futuristic exploration crew, clean pixel art, friendly approachable`. The "friendly approachable" was making every character smile identically; the "retro-futuristic exploration crew" was making them look like uniformed siblings. Both removed. `JRPG-style game sprite, clean pixel art` is enough to anchor the visual style.

Always end with `retro-futuristic exploration crew, clean pixel art, friendly approachable`. Do not vary that suffix.

---

## Per-Character Prompts

### Alex — Engineer
*Canonical reference. Closest to `fq_player.png` aesthetic, now as a junior cadet.*
```
top-down 3/4 view game sprite, full body, cadet engineer with slight compact build, smooth unlined face, with chubby cheeks and a few freckles across the nose, short swept
brown side-fringe haircut neatly framing the forehead, big bright blue eyes,
warm easy grin with friendly soft eyebrows, matte even skin tone, neutral pale complexion, wearing a sleek high-tech white exosuit with sharply faceted armor plates and crisp panel breaks, hexagonal chest module with multiple bevel edges, glowing-cyan seam lines tracing every panel, navy-blue flight jacket over the suit with high collar resting on
the suit's neck ring, sharp triangular shoulder pauldrons, segmented knee plates with diagonal cuts, geometric forearm guards with raised vents, beveled shin armor with hard angled edges, neck ring visible at collar, low-profile life support backpack with angled vents and visible coolant lines, glossy red
pressurized boots, pressure gauntlet gloves, small cyan LED accent line along
jacket trim, JRPG-style game sprite, clean pixel art
```

### Maya — Scientist
```
top-down 3/4 view game sprite, full body, trainee scientist with slim petite build, smooth unlined face, with East Asian features, bright dark almond-shaped
eyes, sleek black hair in a tight high ponytail tied with a small purple
ribbon, soft curious smile with friendly soft eyebrows, matte even skin tone, neutral pale complexion, wearing a sleek
high-tech violet exosuit with sharply faceted armor plates and crisp panel
breaks, hexagonal chest module with multiple bevel edges, glowing-magenta
seam lines tracing every panel, high collar resting on the suit's neck ring,
sharp triangular shoulder pauldrons, segmented knee plates with diagonal
cuts, geometric forearm guards with raised vents, beveled shin armor with
hard angled edges, low-profile life support backpack with angled vents and
visible coolant lines, integrated wrist
computer with glowing magenta display, lavender pressurized boots, pressure
gauntlet gloves, JRPG-style game sprite, clean pixel art
```

### Zane — Botanist
```
top-down 3/4 view game sprite, full body, apprentice botanist with average compact build, smooth unlined face, with warm tan skin, round cheerful face, big hazel eyes,
shaggy mop of dark brown curly hair, gentle wide grin with friendly soft eyebrows, matte even skin tone, neutral pale complexion and dimples, wearing a sleek high-tech
forest-green exosuit with sharply faceted armor plates and crisp panel
breaks, hexagonal chest module with multiple bevel edges, glowing-green seam
lines tracing every panel, dark green accent stripes, sharp triangular
shoulder pauldrons, segmented knee plates with diagonal cuts, geometric
forearm guards with raised vents, beveled shin armor with hard angled edges,
neck ring visible at collar, low-profile life support backpack with angled
vents and visible coolant lines and small plant specimen tubes mounted on the
side, dark green pressurized boots, pressure gauntlet gloves, small green
LED accent on chest module, JRPG-style game sprite, clean pixel art
```

### Rin — Geologist
```
top-down 3/4 view game sprite, full body, rookie geologist with slight athletic build, smooth unlined face, with South Asian features, big bright brown eyes, two short
black braids tied with small amber bands, bright eager grin with friendly soft eyebrows, matte even skin tone, neutral pale complexion showing a small gap between her front teeth, sleek yellow
hardhat with integrated headlamp tilted slightly back, wearing a sleek
high-tech heavy-duty amber-orange exosuit with sharply faceted armor plates
and crisp panel breaks, hexagonal chest module with multiple bevel edges,
glowing-amber seam lines tracing every panel over charcoal-grey panels,
sharp triangular shoulder pauldrons, segmented knee plates with diagonal
cuts, geometric forearm guards with raised vents, beveled shin armor with
hard angled edges, neck ring visible at collar, low-profile life support
backpack with angled vents and visible coolant lines, brown
pressurized work boots, pressure gauntlet gloves, small amber LED accent on
shoulder, JRPG-style game sprite, clean pixel art
```

### Medic (Phase 5+ unlock)
```
top-down 3/4 view game sprite, full body, junior officer medic with slim build, smooth unlined face, with dark brown skin and a round friendly face, big bright brown
eyes, short dark coily hair in a low-volume crop, calm reassuring smile with friendly soft eyebrows, matte even skin tone, neutral pale complexion, wearing a sleek high-tech
white exosuit with sharply faceted armor plates and crisp panel breaks,
hexagonal chest module with multiple bevel edges and red cross emblem,
glowing-red seam lines tracing every panel, light-grey medical jacket over
the suit, sharp triangular shoulder pauldrons, segmented knee plates with
diagonal cuts, geometric forearm guards with raised vents, beveled shin
armor with hard angled edges, neck ring visible at collar, low-profile life
support backpack with angled vents and visible coolant lines, white
pressurized boots with red soles, pressure gauntlet gloves, small red LED
accent on sleeve, JRPG-style game sprite, clean pixel art
```

### Commander (Phase 5+ unlock)
```
top-down 3/4 view game sprite, full body, academy graduate commander with slight wiry build, smooth unlined face, with pale skin and a small smattering of freckles, big
bright steel-grey eyes, platinum-blonde hair in a sharp pixie cut, warm
confident smile with friendly soft eyebrows, matte even skin tone, neutral pale complexion, wearing a sleek high-tech dark
navy exosuit with sharply faceted armor plates and crisp panel breaks,
hexagonal chest module with multiple bevel edges, glowing-gold seam lines
tracing every panel, gold trim and silver shoulder insignia, sharp
triangular shoulder pauldrons, segmented knee plates with diagonal cuts,
geometric forearm guards with raised vents, beveled shin armor with hard
angled edges, neck ring visible at collar, low-profile life support backpack
with angled vents and visible coolant lines, sleek helmet clipped to belt at hip,
no helmet on head, polished black pressurized boots, pressure gauntlet
gloves, small gold LED accent on collar, JRPG-style game sprite, clean pixel
art
```

---

## Robot Crew (3 additional characters)

The three robot crew members exist in the same world as the humans and share the same JRPG pixel-art aesthetic. They differ in three deliberate ways:

1. **No human face features.** Robots have screen-faces or visor-strip faces. This sidesteps the cheek-blush problem entirely — there's no skin to blush.
2. **Three distinct silhouettes.** Echo is round/cute, Vex is sleek/humanoid, Bolt is heavy/boxy. This prevents sibling-look across the trio just like age/build spreads do for the humans.
3. **Utility framing instead of cadet.** Robots use `field unit`, `survey droid`, `service unit` instead of `cadet`/`trainee`/`rookie`. The framing implies role-without-named-age the same way it does for humans.

Robots reuse the same suit-aesthetic vocabulary as the human crew — `sharply faceted armor plates`, `glowing-[color] seam lines tracing every panel`, `hexagonal chest module with multiple bevel edges`, `sharp triangular shoulder pauldrons`, `segmented knee plates with diagonal cuts` — because their bodies *are* the suit. This is what makes them look like they came from the same design studio as the humans.

### Echo — Service Unit
*The cute one. Round silhouette. Wide visor face.*
```
top-down 3/4 view game sprite, full body, small round service unit robot with
chubby compact proportions, sleek glossy white body shell with sharply faceted
armor plates and crisp panel breaks, large rectangular cyan visor screen
showing two bright simple pixel eyes and a soft smile shape made of glowing
dots, hexagonal chest module with multiple bevel edges, glowing-cyan seam
lines tracing every panel, two stubby rounded arms with three-finger
manipulator hands, short tank-tread base, small antenna with blinking light
on top, small holographic indicator panel on chest, JRPG-style game sprite,
clean pixel art
```

### Vex — Field Unit
*The sleek one. Lean humanoid silhouette. Visor strip face.*
```
top-down 3/4 view game sprite, full body, sleek humanoid field unit robot
with slim athletic proportions, matte charcoal-grey and white body shell
with sharply faceted armor plates and crisp panel breaks, narrow horizontal
amber visor strip across the head where eyes would be, small radio antenna
fin on top of head, hexagonal chest module with multiple bevel edges,
glowing-amber seam lines tracing every panel, sharp triangular shoulder
pauldrons, segmented elbow and knee plates with diagonal cuts, geometric
forearm guards with raised vents, beveled shin armor, articulated five-finger
hands, two-toed reinforced boots, low-profile life support backpack with
angled vents and visible coolant lines, JRPG-style game sprite, clean pixel
art
```

### Bolt — Heavy Service Droid
*The industrial one. Boxy heavy silhouette. Twin sensor optics.*
```
top-down 3/4 view game sprite, full body, heavy industrial service droid
with boxy stocky proportions and broad shoulders, weathered safety-yellow
and dark-grey body shell with sharply faceted armor plates and crisp panel
breaks, two large round cyan optical sensors set into a flat wide head with
a hazard-stripe panel above them, hexagonal chest module with multiple bevel
edges and a small glowing warning light, glowing-yellow seam lines tracing
every panel, oversized angular shoulder pauldrons with reinforced bolts,
thick segmented knee plates with diagonal cuts, heavy-duty geometric
forearm guards with mounted hardpoints, beveled shin armor with hard angled
edges, three-finger heavy manipulator hands, wide-stance reinforced foot
plates, prominent life support backpack with angled vents, visible coolant
lines, and a tow hook on the back, JRPG-style game sprite, clean pixel art
```

### Robot-Specific Iteration Tips

| Symptom | Fix |
|---|---|
| Robot looks too humanoid / has visible skin | Reinforce: `entirely mechanical, no skin, no organic parts, screen face only` |
| Robot face too detailed / looks like a helmet | Specify the face style: for screen-faces use `flat rectangular display screen face with simple pixel features`; for visor-strip use `narrow horizontal glowing strip, no other facial features` |
| All three robots look like the same model | Reinforce silhouette: Echo `chubby round`, Vex `slim athletic humanoid`, Bolt `boxy heavy industrial`. If needed, add scale cues: Echo `small`, Vex `average`, Bolt `large` |
| Robot looks like a generic mech / military | Add: `friendly companion robot, exploration utility design, not military` |
| Robots don't feel like they're from the same world as the humans | Verify each prompt includes the shared vocabulary: `sharply faceted armor plates`, `hexagonal chest module with multiple bevel edges`, `glowing-[color] seam lines tracing every panel`, `JRPG-style game sprite` |

---

## What To Avoid (Negative Direction)

These descriptors pull the output in the wrong direction if included in the **main description**. Since `create_character` doesn't accept a negative prompt, the only way to suppress these is to (a) avoid mentioning them in the description and (b) use `/v2/vary-object` to repair after generation if they appear anyway. Watch for outputs that drift this way:

- ❌ "determined", "fierce", "intense", "stern", "sharp gaze", "piercing", "focused" (alone) → these all produce furrowed, angled-down, angry-looking eyebrows in pixel art models. Always use a smile or grin and always include the phrase `friendly soft eyebrows`
- ❌ "young adult", "twenties", "thirties", "forties", "weathered", "bearded", "wrinkled", "lined skin", "laugh lines" → these produce adult crew that reads too old. Lead with `[role tag] [role]` (cadet, trainee, rookie, apprentice, junior officer, academy graduate) plus a build cue, never with a direct age word
- ❌ "messy hair", "tousled hair" without a specific cut → produces ambiguous blob hair. Always pair with a named haircut and a hair color
- ❌ "kid", "child", "young", "teen", "teenage", "teenager", "little", "boy", "girl", "chibi", "cute", "kawaii", "rosy", "youthful", "adorable" → every direct youth word is a blush-priming token in pixel art models. Use indirect signals: role tag (`cadet`, `trainee`, `rookie`, `apprentice`), build cue (`slight compact build`), face geometry (`smooth unlined face`)
- ❌ "rosy cheeks", "blushing", "cute blush", "chibi blush", and even "no cheek blush" itself → the noun "blush" appearing anywhere in the main prompt amplifies the chance of blush. Don't mention blush at all. If a character generates with blush anyway, repair via `/v2/vary-object`
- ❌ "glasses", "spectacles", "eyewear" → no crew member wears glasses. Don't mention them in the prompt at all (mentioning them — even with negation — increases their likelihood). If they appear anyway, repair via `/v2/vary-object` with `edit_description="remove glasses, show full unobstructed eyes"`
- ❌ "earrings", "necklace", "bracelet", "rings", "jewelry", "piercings", "pendant", "chain" → no crew member wears jewelry. Don't mention any jewelry in the prompt at all (mentioning increases its likelihood). If jewelry appears anyway, repair via `/v2/vary-object` with `edit_description="remove all jewelry, earrings, and accessories from face and ears"`
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
| Character comes back as a young adult, not young-looking enough | Verify the prompt uses indirect age signals: `[role tag] [role]` + build cue + `smooth unlined face`. If still too adult, intensify: change `cadet` to `young trainee` (still indirect-er than `teen`), add `slight slender build`, add `soft rounded jawline`. Do NOT add `kid`, `young`, `teen`, `child`, `youthful` — these trigger blush |
| Hair looks ambiguous / blob-shaped / not well-defined | Replace any vague descriptor ("messy," "tousled") with a specific cut name: `short crop`, `bowl cut`, `swept side-fringe`, `pixie cut`, `twin braids`, `low-volume crop`, `shaggy curly mop`, etc. Always specify hair color too |
| Character has glasses or eyewear | No crew member should have glasses. Verify the prompt does not name glasses, spectacles, or eyewear (don't even mention them with negation). If glasses still appear, repair via `/v2/vary-object` with `edit_description="remove glasses, show full unobstructed eyes"`. If still present, regenerate from scratch with a different distinguishing facial feature (eye color, freckles, dimples, hair ribbon) |
| Character has earrings, necklace, or other jewelry | No crew member should wear jewelry. Verify the prompt does not name any jewelry, accessories, earrings, piercings, etc. If jewelry appears anyway, repair via `/v2/vary-object` with `edit_description="remove all jewelry, earrings, and accessories from face and ears"` |
| Character has pink/red blush circles on cheeks | The `create_character` endpoint has no negative-prompt parameter. **Do not** add inline negation — it amplifies the problem. Best fix: call `/v2/vary-object` with `edit_description="remove all pink and red coloring from cheeks, leave skin tone natural"`. If still appearing, drop any "chibi" or "cute" wording from the main description, and try `proportions: default` instead of `stylized` |
| Character looks angry / scowling / has furrowed eyebrows | Replace any "determined / fierce / intense / focused / sharp" word with a smile or grin variant. Add or strengthen the phrase `friendly soft eyebrows` in the expression slot. If still scowling, replace the entire expression with `warm easy grin with friendly soft eyebrows` |
| All characters look like siblings / variations of the same person | Each character needs a DISTINCT age, build, ethnicity, hair, and expression — not just a different suit color. Verify each prompt's `[DISTINCT AGE + BUILD + ETHNICITY]` and `[DISTINCT EXPRESSION]` slots actually differ from the others |
| Suits look too rounded / too organic / not angular enough | Reinforce with maxed-out language: `aggressively faceted armor plates`, `every panel is a sharp polygon`, `no curves anywhere on the suit`, `Mass Effect Andromeda exosuit`, `Halo Mjolnir armor`. Add specific hardpoint lists from the skeleton if missing |
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
