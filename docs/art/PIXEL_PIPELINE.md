# Pixel art production pipeline

Status: frozen pre-implementation production decision for Ludus Gladiator Simulator.

## Decision

Use **Pixelorama 1.2** as the primary pixel-art authoring tool for combat sprites and modular equipment.

Do **not** make Importality, Aseprite Wizard, or another art importer a runtime or build dependency of Ludus.

The production boundary is:

```text
source_assets/pixel/*.pxo
        |
        | Pixelorama CLI / local art workstation
        v
PNG spritesheets + JSON metadata
        |
        | validation / conversion tooling
        v
game/assets/... standard Godot-ready assets
        |
        v
Godot 4.5.2
```

Godot must be able to import, test, export, and run the game without Pixelorama or any art-editor plugin installed.

## Why this pipeline

Pixelorama provides the features Ludus needs directly:

- layers and layer groups;
- animation timeline and tags;
- frame durations;
- palettes;
- spritesheet export;
- JSON project/export data;
- split-layer export;
- headless/CLI export on desktop platforms.

This is a better fit for a modular fighter pipeline than adding an editor importer solely to transform source art into standard textures/resources.

## Source-of-truth rule

- Editable art source: `source_assets/pixel/`.
- Runtime art source of truth: committed standard outputs under `game/assets/`.
- `.pxo` files are production masters, not runtime dependencies.
- Generated `.godot/imported/` data is never a source of truth and is never committed.

Only project-owned or explicitly redistributable `.pxo` masters may enter `source_assets/`; the repository asset-provenance policy still applies.

## Modular character contract

Every compatible combat layer must share:

- logical canvas size;
- origin/pivot;
- ground line;
- facing direction;
- frame count within an animation family;
- animation/tag names;
- frame timing contract.

Recommended logical combat canvas: **64x64 px** per standard layer. Weapons, large shields, capes, and effects may use a larger canvas only when they retain the same origin and ground line.

Recommended layer families include:

- rear equipment;
- rear arm/body segment where needed;
- body;
- cloth/belt;
- hair;
- helmet;
- shield/offhand;
- foreground weapon;
- effects/wounds.

The goal is to reuse body animation while allowing equipment, hair, skin details, and selected visual traits to change without redrawing every fighter from zero.

## Export contract

Pixelorama CLI supports headless export, spritesheet export, JSON export, and split-layer export. Production automation should use those built-in capabilities rather than screen automation.

Representative command shape:

```text
Pixelorama --headless --quit -- --spritesheet --json --split-layers --output <output.png> <source.pxo>
```

The exact executable path is local-machine configuration and must not be hard-coded into gameplay code.

Exports must be deterministic enough for production. Before adding automated bulk generation, validate the same unchanged source twice and compare SHA-256 hashes for produced PNG/JSON outputs.

## Godot import policy

For combat pixel art:

- use lossless texture import;
- use nearest-neighbor filtering / integer presentation scaling;
- do not create separate high/medium/low-resolution sprite sets;
- do not require an art plugin in release builds;
- do not store final gameplay references to temporary export directories.

Runtime scenes/resources may use standard `Texture2D`, `AtlasTexture`, `SpriteFrames`, `AnimationPlayer`, or project-owned metadata generated from the exported PNG/JSON.

## Tool evaluation

### Pixelorama 1.2 + built-in CLI — ADOPT

Reasons:

- open-source and suitable for local production;
- active project;
- native layers/timeline/tags;
- native spritesheet + JSON export;
- native split-layer export;
- CLI/headless automation;
- avoids a Godot plugin dependency.

### Importality 0.4.x — OPTIONAL WORKBENCH / WATCHLIST

Importality remains useful if an artist wants direct `.pxo`, Aseprite, Krita, Piskel, or Pencil2D preview/import inside a separate Godot art workbench. Its 0.4.x line fixed Godot 4.5-related SpriteFrames issues and supports split layers/per-layer offsets.

Do not make it part of the game's required import/build path unless the native Pixelorama CLI pipeline proves insufficient.

### Aseprite Spritesheet Importer — SECONDARY / WATCHLIST

This is the strongest Aseprite-specific alternative found because it is resource-oriented and explicitly supports multiple layers/groups/slices, including body + equipment organization. It is MIT and targets Godot 4.4.1+.

It is currently young and marked unstable in the Godot Asset Store, so it does not replace the primary pipeline today.

### Aseprite Wizard — DO NOT ADOPT AS PRIMARY

It is feature-rich, MIT, and active, but it is also marked unstable and is more Aseprite-specific/node-oriented than Ludus currently needs. It adds dependency and editor state without solving a problem the selected Pixelorama CLI workflow cannot already solve.

Aseprite itself remains a valid artist-side tool if a future collaborator prefers it. Source art can be exported to standard PNG/JSON or converted through a controlled art pipeline without making Aseprite a Ludus runtime/build requirement.

## Dependency rule

Art tools may accelerate production, but the game repository must remain buildable from standard committed runtime assets.

If any future importer becomes mandatory for a clean clone to build Ludus, that change requires a new technical review and a pinned-version compatibility probe against Godot 4.5.2.

## Acceptance gate before mass asset production

Before producing the full gladiator/equipment library:

1. Create one adult base gladiator at 64x64.
2. Create at least `idle`, `light_attack`, `heavy_attack`, `block`, `dodge`, `hit`, and `defeat` animation families.
3. Create at least two helmets, two weapons, one shield, two hair variants, and two cloth/color variants.
4. Export body/equipment layers twice from the same unchanged `.pxo` source.
5. Verify matching alignment, frame counts, tags, frame timing, origin, and ground line.
6. Compare export hashes and investigate any nondeterministic output.
7. Load the exported standard assets into a Godot 4.5.2 dev scene with no art importer enabled.
8. Swap equipment during animation without per-item positional fixes.
9. Verify crisp presentation at integer scales.
10. Only after this passes, bulk-produce the remaining character/equipment assets.
