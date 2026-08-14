# Demo Data Foundation

## Objective

Build the playable demo on a data model that remains valid for the full game. Demo limits must be configuration, not hard-coded structural limits.

## Principles

- One canonical catalog per domain.
- Stable IDs stored in saves.
- Legacy aliases migrated on load.
- Full-game maximums remain in data even when the demo exposes less content.
- UI reads availability and demo caps from data.
- Visual assets remain replaceable without changing gameplay IDs.

## Estate

### Canonical buildings

1. dominus_house
2. barracks
3. training_yard
4. forge
5. infirmary
6. kitchen
7. mine
8. warehouse
9. worker_quarters
10. wall_and_gate
11. beast_area
12. sanctuary
13. private_arena
14. stable

### Demo availability

Available in the demo:

- dominus_house
- barracks
- training_yard
- forge
- infirmary
- mine
- beast_area

Visible but blocked in the demo:

- warehouse
- worker_quarters
- wall_and_gate
- kitchen
- sanctuary
- private_arena
- stable

### Levels

- Structural full-game levels: 0 to 10.
- Demo-visible upgrade cap: 3.
- Level 0 means absent, ruined, provisional, or not yet operational according to building data.
- Demo caps are presentation and progression rules, not catalog limits.

### Legacy aliases

- quarters -> barracks
- guard_post -> wall_and_gate
- security -> wall_and_gate

## Gladiators

### Initial demo roster

- 5 male gladiators.
- 2 female gladiators.
- All begin as unspecialized gladiators.

Gender/body presentation must not determine specialization access.

### Specializations

Canonical IDs:

- gladiator
- murmillo
- secutor
- retiarius
- dimachaerus

Legacy aliases:

- balanced -> gladiator
- thraex -> dimachaerus

The base `gladiator` state is not a fifth advanced class. It is the initial state before specialization.

## Equipment

Equipment is modular and referenced by stable IDs. Character identity, body presentation, class kit, weapon, shield, helmet, armor, and animation profile must remain separable.

The demo catalog must support:

- generic training equipment
- Murmillo kit
- Secutor kit
- Retiarius kit
- Dimachaerus dual-weapon kit

## Skills

The demo exposes 8 skills. Skills must be catalog-driven and may define:

- specialization requirements
- equipment requirements
- energy cost
- combat action mapping
- animation event key
- icon key
- unlock conditions

## Save migration

Current save version: 14. This phase does not introduce Save v15.

Migration requirements:

- preserve old roster and economy data
- migrate building aliases before clamping levels
- allow estate level 0
- migrate specialization aliases
- preserve unknown future-safe fields when possible
- seed only missing data instead of replacing valid player data

## Economy

- The demo campaign starts with exactly 650 denarii.
- This value is owned by `data/economy_rules.json` and consumed through `DataRepository`.
- Food, ore, maintenance, prices and monthly income are not frozen by this section.
- Missing balance values remain pending instead of being inferred from legacy weekly formulas.

## Implementation order

1. Canonical estate catalog and aliases.
2. Save v10 to v11 migration.
3. Specialization catalog and migration.
4. Equipment catalog expansion.
5. Eight-skill catalog.
6. Seven-character initial roster.
7. Automated compatibility tests.
8. Visual estate scene and HUD integration.

## Non-goals for this branch phase

- Final art integration.
- Final HUD styling.
- Final balance.
- Full-game building unlock progression.
- Animation asset production.
