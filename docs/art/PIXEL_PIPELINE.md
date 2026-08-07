# Pixel art production pipeline

Status: frozen pre-implementation production decision for Ludus Gladiator Simulator.

## Decision

Use **Aseprite 1.3.x** as the primary manual editing/animation and modular sprite authoring tool for combat characters and equipment.

Use **Python** for repeatable preprocessing/postprocessing (background removal, normalization, resizing, validation, batch conversion) and keep AI image-generation tools upstream of the manual pixel-art pass.

Keep **Pixelorama** as a free fallback/secondary editor, not as a required production dependency.

Do **not** make Importality, Aseprite Wizard, Aseprite Spritesheet Importer, or another art importer a runtime/build dependency of Ludus.

The production boundary is:

```text
AI generation / reference art
        |
        v
Python preprocessing / normalization
        |
        v
source_assets/pixel/*.aseprite
        |
        | Aseprite layers + tags + timeline + CLI
        v
PNG spritesheets + JSON metadata / split layers
        |
        | Python validation / conversion tooling
        v
game/assets/... standard Godot-ready assets
        |
        v
Godot 4.5.2
```

Godot must be able to import, test, export, and run the game without Aseprite, Pixelorama, or any art-editor plugin installed.

## Why Aseprite is included

Aseprite materially helps Ludus because the expensive part of our art pipeline is not only generating a still image: it is maintaining many aligned animation frames and interchangeable layers across gladiators and equipment.

Its useful production features include:

- animation timeline with per-frame timing;
- onion skinning for frame-to-frame correction;
- layers and layer groups;
- tags for animation families (`idle`, `attack`, `block`, etc.);
- linked cels/frames for reuse;
- palette and pixel-art-specific drawing tools;
- sprite-sheet export;
- JSON metadata export;
- CLI/batch export;
- split-layer and split-tag export;
- scripting/automation support.

This makes Aseprite especially valuable for the body/equipment modularity required by Ludus. It does not replace AI generation or Python automation; it is the controlled cleanup, animation, alignment, and export stage between them and Godot.

## Source-of-truth rule

- Editable art masters: `source_assets/pixel/`.
- Preferred master format for manually maintained combat sprites: `.aseprite` / `.ase`.
- Pixelorama `.pxo` masters are permitted only when intentionally used as fallback/editor-specific sources.
- Runtime art source of truth: committed standard outputs under `game/assets/`.
- Art-editor project files are production masters, not runtime dependencies.
- Generated `.godot/imported/` data is never a source of truth and is never committed.

Only project-owned or explicitly redistributable masters may enter `source_assets/`; the repository asset-provenance policy still applies.

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

Aseprite CLI supports batch/headless export, spritesheets, JSON metadata, layer filtering, split-layer export, split-tag export, and texture-atlas generation.

Representative command shape:

```text
aseprite -b --split-layers --list-tags fighter.aseprite --sheet fighter.png --data fighter.json
```

The exact executable path is local-machine configuration and must never be hard-coded into gameplay code.

Exports must be deterministic enough for production. Before bulk generation, validate the same unchanged source twice and compare SHA-256 hashes for produced PNG/JSON outputs.

## Godot import policy

For combat pixel art:

- use lossless texture import;
- use nearest-neighbor filtering / integer presentation scaling;
- do not create separate high/medium/low-resolution sprite sets;
- do not require an art plugin in release builds;
- do not store final gameplay references to temporary export directories.

Runtime scenes/resources may use standard `Texture2D`, `AtlasTexture`, `SpriteFrames`, `AnimationPlayer`, or project-owned metadata generated from the exported PNG/JSON.

## Tool roles

### Aseprite 1.3.x — ADOPT FOR PRODUCTION

Role:

- manual pixel cleanup;
- frame-by-frame animation;
- onion-skin correction;
- modular body/equipment layers;
- animation tags/timing;
- controlled sprite-sheet/JSON export;
- optional CLI/script automation.

Aseprite is a production workstation tool only. It must not become a Godot runtime/build dependency.

### Python — ADOPT FOR AUTOMATION

Role:

- remove/clean backgrounds;
- normalize canvas and alpha;
- resize/crop/pad consistently;
- batch rename/validate outputs;
- verify frame dimensions/counts;
- compare hashes;
- generate reports/manifests;
- perform repetitive transformations that do not benefit from manual pixel editing.

Python should handle repetitive deterministic work; Aseprite should handle visual judgment and animation correction.

### Pixelorama — SECONDARY / FREE FALLBACK

Pixelorama remains useful as an open-source alternative for manual pixel work and can export standard assets. It is not required if Aseprite is available and should not duplicate the same production step by default.

### Importality — OPTIONAL WORKBENCH / WATCHLIST

Importality can be useful in a separate art workbench, but the selected pipeline does not need it to build or run Ludus.

### Aseprite Spritesheet Importer — WATCHLIST

Potentially useful if we later want direct Aseprite-resource workflows inside a dedicated art project, but not needed in the main game repository.

### Aseprite Wizard — DO NOT ADOPT AS PRIMARY

It adds Godot-editor coupling without providing enough value over Aseprite's own export + our Python/Godot pipeline.

## Dependency rule

Art tools may accelerate production, but the game repository must remain buildable from standard committed runtime assets.

If any future importer becomes mandatory for a clean clone to build Ludus, that change requires a new technical review and a pinned-version compatibility probe against Godot 4.5.2.

## Acceptance gate before mass asset production

Before producing the full gladiator/equipment library:

1. Create one adult base gladiator at 64x64.
2. Create at least `idle`, `light_attack`, `heavy_attack`, `block`, `dodge`, `hit`, and `defeat` animation families.
3. Create at least two helmets, two weapons, one shield, two hair variants, and two cloth/color variants.
4. Keep body/equipment in modular Aseprite layers/groups with shared origin and ground line.
5. Export body/equipment layers twice from the same unchanged source.
6. Verify matching alignment, frame counts, tags, frame timing, origin, and ground line.
7. Compare export hashes and investigate any nondeterministic output.
8. Load the exported standard assets into a Godot 4.5.2 dev scene with no art importer enabled.
9. Swap equipment during animation without per-item positional fixes.
10. Verify crisp presentation at integer scales.
11. Only after this passes, bulk-produce the remaining character/equipment assets.

## Cost/usage note

Aseprite is a paid workstation tool rather than a game dependency. The official minimum purchase price is currently USD 19.99 for the 1.x series, with commercial use of created assets allowed. The trial can be used to evaluate the workflow but cannot save files.
