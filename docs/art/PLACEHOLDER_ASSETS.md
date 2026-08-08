# Placeholder asset policy and selected sources

Status: frozen pre-implementation decision for Ludus Gladiator Simulator.

## Goal

Use placeholders only to unblock implementation, tests and demo flow. Placeholder art must never dictate final art direction, architecture or gameplay scope.

## Selection rules

A placeholder may enter the public repository only when:

- commercial use is permitted;
- raw public redistribution from this repository is permitted or the asset is otherwise clearly CC0/public-domain;
- provenance is recorded;
- no attribution obligation is forgotten;
- no AI/ML restriction is violated;
- the asset does not force a runtime/editor dependency.

When a source is visually unsuitable but technically unnecessary, prefer a Godot graybox primitive instead of importing a mismatched pack.

## Approved default placeholder sources

### Gladiator combat placeholder

Source: OpenGameArt — `RPG Asset Character 'Gladiator' SMS` by Chasersgaming.
License: CC0.
Use: temporary human fighter animation/reference only.
Notes: very low resolution and not representative of final Ludus quality. It is for collision/animation/state-flow testing, not art direction.

### Roman weapons

Source: OpenGameArt — `Pixel Art Roman Weapons` by Yakhmet.
License: CC0.
Use: temporary gladius/pilum/trident-style weapon visuals where useful.
Notes: final Ludus weapons will be replaced by project-owned Scenario -> Python -> Aseprite production assets.

### UI

Source: Kenney — `Pixel UI Pack`.
License: CC0.
Use: temporary buttons, panels and basic interface affordances.
Notes: use only where the existing Ludus UI does not already have a sufficient graybox/control. Do not let Kenney's visual style redefine the final UI bible.

### UI audio

Source: Kenney — `UI Audio`.
License: CC0.
Use: temporary click/confirm/cancel/toggle feedback.
Notes: safe for the public repository under CC0.

### Beasts

Primary source: Kenney — `Animal Pack Remastered`.
License: CC0.
Secondary source: OpenGameArt — `Forest Animals Sprite Sheet` by Vomdrache.
License: CC0.
Use: temporary animal silhouettes/sprites for beast flow, targeting and combat integration.
Notes: if an exact lion/bear/boar placeholder is not present or readable enough, use a simple project-owned silhouette/shape rather than importing another uncertain source.

### Arena / estate / backgrounds

Default: project-owned graybox inside Godot using ColorRect, Polygon2D, simple tiles and primitive textures.
Reason: no current third-party environment pack is close enough to the final Roman visual direction to justify adding it merely as filler.

### Icons

Optional source: Game-icons.net.
License: CC BY 3.0 for the main collection, with some public-domain icons.
Use: temporary system/status icons only when Kenney/project-owned symbols are insufficient.
Requirement: record author and provide attribution in the final credits/notices if any CC BY icon ships.
Preference: replace with project-owned final icons before release when practical.

## Explicitly not approved for the public source repository

### Sonniss GameAudioGDC bundles

The sounds are commercially usable in games and attribution is not required, but their license prohibits standalone/raw redistribution and prohibits AI/ML training or usage.

Therefore:

- do not commit raw Sonniss files into this public repository;
- do not feed Sonniss sounds into Scenario or any generative AI workflow;
- reconsider only if the asset-bearing workflow becomes private and the exact license obligations remain satisfied.

For current placeholders, use Kenney CC0 UI audio and project-owned/simple temporary combat audio instead.

## Final-art boundary

The selected placeholders are implementation aids only. Final production assets follow the frozen visual pipeline:

Scenario -> Python -> Aseprite -> standard PNG/spritesheet -> Godot 4.5.2.

No placeholder source becomes a mandatory build dependency.

## Replacement gate

Before Steam demo submission:

- remove visually conflicting placeholders from player-facing core screens/combat where final art exists;
- verify every remaining third-party asset against `docs/ASSET_PROVENANCE.md`;
- ensure all CC BY attribution is present;
- ensure no restricted raw vendor media is tracked;
- keep graybox assets only in dev/test scenes unless deliberately accepted as final.
