# Adult 64 px Character Standard

Status: visual-production constraint for the experimental pixel-art pipeline.

This document prevents the 64×64 combat characters from drifting into chibi, childlike, or overly cartooned proportions while keeping them economical to animate.

## 1. Production target

- Logical canvas per combat layer: **64×64 px**.
- Recommended visible character height: **57–61 px** in neutral stance.
- Target presentation: mature, rugged adult gladiators.
- View used in combat: three-quarter lateral, facing left or right.
- Front view is reserved for customization, roster previews, and body-template work.
- Nearest-neighbor sampling only. Integer scaling only.

Weapons, shields, capes, and effects may use a larger logical canvas when needed, but must share the same character origin and ground line.

## 2. Adult proportion rules

The following rules are mandatory for the base bodies:

- Head height should be approximately **15–18%** of total character height.
- Full body should read as roughly **5.5–6.25 heads tall** after pixel simplification.
- Shoulder width should be **2.1–2.6 head widths**, depending on body archetype.
- Crotch line should sit close to the vertical midpoint of the body.
- Legs must be visibly longer than the combined head and torso block.
- Hands must not exceed the apparent size of the character's face.
- Feet should be compact and grounded, not oversized cartoon shoes.
- Eyes should normally occupy one pixel each at native resolution.
- Avoid large round eyes, oversized cheeks, very short limbs, and a head wider than the upper torso.

The silhouette must still communicate an adult body when shown as a solid single-color shape.

## 3. Base body archetypes

### Athletic

- Balanced shoulder and hip width.
- Defined but simplified torso.
- Neutral reference body for most gladiators.
- Intended visible height: 59–61 px.

### Heavy

- Wider rib cage, abdomen, thighs, and neck.
- Head remains adult-sized; do not enlarge it to imply body mass.
- Slightly shorter visible height: 57–60 px.

### Agile

- Narrower torso and arms.
- Longer visual leg line.
- Reduced internal muscle clusters.
- Intended visible height: 59–61 px.

### Veteran

- Adult proportions with asymmetric posture.
- Slight forward lean, old injuries, scars, or uneven shoulder height.
- Age is expressed through stance, hair, and facial pixels—not a larger head.

## 4. Pixel-detail budget

At native resolution, prioritize silhouette over anatomy rendering.

- Use one base skin tone, one light, one shadow, and optionally one deep-shadow tone.
- Suggest major muscle groups; do not outline every abdominal or pectoral division.
- Use a restrained total palette, normally **16–28 colors** for a fully equipped fighter.
- Keep uninterrupted one-pixel noise to a minimum.
- Avoid anti-aliased semi-transparent edge pixels in combat sprites.
- Use readable clusters of pixels rather than isolated highlights.

## 5. Modular layer contract

Recommended runtime layer order:

1. rear weapon or cape;
2. rear arm;
3. base body;
4. cloth and belt;
5. front leg or front arm when required by animation;
6. hair;
7. helmet;
8. shield;
9. foreground weapon;
10. wounds and temporary effects.

Every interchangeable layer must share:

- canvas dimensions;
- origin;
- ground line;
- facing direction;
- frame count for the compatible animation family;
- animation names;
- frame durations.

A modular item must not require manual positional correction for every gladiator using the same body archetype.

## 6. Animation constraints

Suggested frame budgets:

| Animation | Frames | Primary readability goal |
|---|---:|---|
| idle | 4 | weight, breathing, weapon readiness |
| attack | 5–7 | anticipation, contact, recovery |
| block | 3–4 | shield or weapon clearly intercepts |
| hit | 3–4 | impact direction and loss of balance |
| defeat | 5–7 | controlled fall and final pose |
| surrender | 4–6 | unmistakable non-combat posture |

Do not animate every anatomical detail. Animation quality should come from pose, timing, arcs, and clear contact frames.

## 7. Visual rejection checklist

Reject a body or animation pass when any of these are true:

- the head reads as more than one fifth of total height;
- the character resembles a child or mascot;
- legs appear shorter than the torso block;
- hands or feet dominate the silhouette;
- facial features use large expressive cartoon eyes;
- muscle detail creates visual noise at ×1 scale;
- equipment cannot be recognized at ×2 scale;
- a silhouette test does not clearly distinguish athletic, heavy, and agile bodies;
- the equipped sprite loses the shared origin or ground line;
- movement depends on subpixel filtering to look acceptable.

## 8. Relationship to detailed portraits

Combat sprites and detailed portraits have different jobs.

- Combat sprites communicate class, body type, equipment, posture, and action.
- Profile portraits communicate identity, emotion, age, scars, and narrative character.
- Portraits may use 256×256 or 512×512 illustration and limited animation.
- Hair, scars, skin tone, primary equipment colors, and signature helmet details must remain consistent between both representations.

The portrait should restore personality lost through 64 px simplification rather than forcing the combat sprite to carry excessive detail.

## 9. Acceptance test for the prototype

Before adopting a base body commercially, validate it in these views:

- native 64×64 canvas;
- ×2 integer scale;
- ×4 integer scale;
- dark arena background;
- light arena background;
- unarmed front view;
- equipped three-quarter combat view;
- silhouette-only comparison beside all body archetypes;
- one full `idle` loop;
- one full `attack` loop.

The prototype passes when it remains recognizably adult, readable, modular, and stable across all tests without filtering.

## 10. Current pipeline decision

- Use 64×64 pixel art for combat characters and visible equipment.
- Use detailed illustrated portraits for character profiles and narrative screens.
- Use limited portrait animation inside Godot rather than continuous AI-generated video.
- Keep vector animation as an optional tool for portraits, UI, ornaments, or special cases.
- Evaluate Gator Sprite Studio locally only; version exported project-owned assets, not the editor plugin.
